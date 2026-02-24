-- Love2D FFI Authoring Demo for Argile
-- Purpose: prove non-Terra users can author UIs with Argile through FFI
-- Authoring source: LuaJIT (ui.capi only)
-- Scene source: no Terra scene export - UI is authored imperatively in LuaJIT
-- Backend: Love2D
-- Public message: "You can use Argile from another language/runtime."
--
-- HARD RULE: This demo MUST NOT call:
--   - ArgileDemoFrameForContext
--   - ArgileConformanceFrameForContext
--   - ArgileStateMatrixFrameForContext
-- Those are for portable-scene demos/tests, not FFI authoring showcase.

local ffi = require("ffi")
package.path = "./?.lua;./?/init.lua;./?.t;" .. package.path

-- Load Argile FFI bindings, runtime wrapper, and demo renderer
-- Path is relative to repo root when running: love backends/love2d/demo_ffi
local argile_lj = require("bindings.luajit.argile_lj")
local renderer = dofile("backends/love2d/renderer.lua")

ffi.cdef[[
void* malloc(size_t size);
void free(void* ptr);
]]

local runtime_client = argile_lj.runtime.load({
    ffi_def_path = "build/argile_api_ffi.lua",
    lib_path = "build/libargile.so",
})
local argile = runtime_client.lib

-- ============================================================================
-- Demo State
-- ============================================================================

local arena_bytes = 256 * 1024 * 1024
local ctx
local runtime_ctx
local cmd_count = 0
local cmd_buffer = nil

-- State toggles for demo
local demo_focus = false
local demo_selected = false
local demo_disabled = false
local demo_hover = false
local demo_active = false

-- Element IDs (created via FFI, not hardcoded hashes)
local root_id
local card_id
local title_id
local body_id
local footer_id

local lj_capabilities = {
    host_compiler_exports = false,
    host_callback_backend_exports = false,
    missing_count = 0,
}

local lj_ast_probe = {
    portable_ok = false,
    error_count = 0,
}

-- ============================================================================
-- Text Measurement Callback
-- ============================================================================
-- The callback must be stored to prevent GC collection
-- New FFI-friendly signature: takes out pointer, returns int32 success
-- Pattern: int32_t (*)(struct StringSlice*, struct TextConfig*, void*, struct Dimensions*)

local function text_measure_callback(text_slice_ptr, text_config, user_data, out_dims)
        -- text_slice_ptr is a pointer to StringSlice
        local text_slice = text_slice_ptr[0]
        
        -- Convert StringSlice to Lua string
        local text = ""
        if text_slice.chars ~= nil and text_slice.length > 0 then
            text = ffi.string(text_slice.chars, tonumber(text_slice.length))
        end
        
        -- Get font size from config or default
        local font_size = 16
        if text_config ~= nil then
            font_size = tonumber(text_config.fontSize) or 16
        end
        
        -- Use Love2D's font for measurement
        local current_font = love.graphics.getFont()
        if current_font then
            local w = current_font:getWidth(text)
            local h = current_font:getHeight()
            -- Scale based on font size ratio
            local scale = font_size / current_font:getHeight()
            out_dims.width = w * scale
            out_dims.height = h * scale
        else
            -- Fallback approximation
            out_dims.width = #text * font_size * 0.6
            out_dims.height = font_size * 1.2
        end
        
        -- Return 1 for success
        return 1
end

local function init_text_measure_callback()
    runtime_ctx:set_measure_text(text_measure_callback)
end

-- ============================================================================
-- UI Building Functions (FFI Authoring)
-- ============================================================================
-- These functions author the UI directly via FFI calls - no Terra scene export

local function mk_string(s)
    return ffi.new("struct String", {
        isStaticallyAllocated = true,
        length = #s,
        chars = ffi.cast("char*", s),
    })
end

local function mk_color(r, g, b, a)
    return ffi.new("struct Color", {
        r = r or 0, g = g or 0, b = b or 0, a = a or 1
    })
end

local function mk_corner_radius(r)
    return ffi.new("struct CornerRadius", {
        topLeft = r, topRight = r, bottomLeft = r, bottomRight = r
    })
end

local function mk_padding(left, right, top, bottom)
    return ffi.new("struct Padding", {
        left = left or 0, right = right or 0,
        top = top or 0, bottom = bottom or 0
    })
end

local function mk_sizing_fit()
    return ffi.new("struct Sizing", {
        width = { type = argile.SIZING_FIT, size = { min = 0, max = 0 }, percent = 0 },
        height = { type = argile.SIZING_FIT, size = { min = 0, max = 0 }, percent = 0 }
    })
end

local function mk_sizing_grow(min_w, min_h)
    return ffi.new("struct Sizing", {
        width = { type = argile.SIZING_GROW, size = { min = min_w or 0, max = 0 }, percent = 0 },
        height = { type = argile.SIZING_GROW, size = { min = min_h or 0, max = 0 }, percent = 0 }
    })
end

local function mk_sizing_fixed(w, h)
    return ffi.new("struct Sizing", {
        width = { type = argile.SIZING_FIXED, size = { min = w or 100, max = w or 100 }, percent = 0 },
        height = { type = argile.SIZING_FIXED, size = { min = h or 100, max = h or 100 }, percent = 0 }
    })
end

local function mk_layout(sizing, padding, gap, direction)
    return ffi.new("struct LayoutConfig", {
        sizing = sizing or mk_sizing_fit(),
        padding = padding or mk_padding(0, 0, 0, 0),
        childGap = gap or 0,
        childAlignment = ffi.new("struct ChildAlignment", {
            x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP
        }),
        layoutDirection = direction == "col" and argile.TOP_TO_BOTTOM or argile.LEFT_TO_RIGHT
    })
end

-- ============================================================================
-- Scene Building (FFI Authoring Demo)
-- ============================================================================
-- This builds a small card scene directly in LuaJIT
-- Requirements:
--   - Root panel background
--   - Card rectangle with border + radius
--   - Title text
--   - Body text
--   - Footer text
--   - One paint accent stripe (to prove RENDER_PAINT)
--   - Hover/active/focus/selected/disabled state overlays

local colors = {
    panel = mk_color(0.08, 0.10, 0.14, 1.0),
    card_bg = mk_color(0.12, 0.14, 0.18, 1.0),
    card_hover = mk_color(0.17, 0.25, 0.40, 1.0),
    card_active = mk_color(0.12, 0.19, 0.33, 1.0),
    card_focus = mk_color(0.13, 0.32, 0.25, 1.0),
    card_selected = mk_color(0.40, 0.27, 0.12, 1.0),
    card_disabled = mk_color(0.26, 0.26, 0.28, 1.0),
    border = mk_color(0.25, 0.28, 0.35, 1.0),
    text = mk_color(0.9, 0.9, 0.9, 1.0),
    text_muted = mk_color(0.6, 0.65, 0.7, 1.0),
    accent = mk_color(0.2, 0.6, 0.9, 1.0),
    hover = mk_color(1.0, 1.0, 1.0, 0.05),
    active = mk_color(0.0, 0.0, 0.0, 0.1),
    focus = mk_color(0.2, 0.6, 0.9, 0.15),
    selected = mk_color(0.2, 0.6, 0.9, 0.25),
    disabled = mk_color(0.0, 0.0, 0.0, 0.35),
}

local function run_lj_ast_probe()
    local DSL = argile_lj.dsl
    local AST = argile_lj.ast

    local program = DSL.program({
        decls = {
            DSL.theme("demo", {
                tokens = {
                    DSL.token_decl("colors.text", { r = 0.9, g = 0.9, b = 0.9, a = 1.0 }),
                },
            }),
            DSL.component("Label", {
                params = { "text", "tone" },
                variants = { tone = { "primary", "muted" } },
                root = DSL.el({
                    id = "label_root",
                    children = {
                        DSL.text({
                            id = "label_text",
                            text = DSL.path("props.text"),
                            typography = {
                                { "font_size", 16 },
                                { "color", DSL.token("colors.text") },
                            },
                        }),
                    },
                }),
            }),
        },
        body = {
            DSL.invoke("Label", { text = "LJ DSL AST probe", tone = DSL.sym("primary") }),
        },
    })

    local ok, errors = AST.validate_portable(program)
    lj_ast_probe.portable_ok = ok
    lj_ast_probe.error_count = ok and 0 or #errors
end

local function build_card_scene(width, height)
    -- Set current context and text measure callback
    runtime_ctx:set_current()
    
    -- Begin layout
    argile.BeginLayout(width, height)
    
    -- Root panel (full screen background)
    argile.OpenElementWithId(root_id)
    argile.SetOpenElementLayoutConfig(mk_layout(
        mk_sizing_fixed(width, height),
        mk_padding(40, 40, 40, 40),
        0, "row"
    ))
    argile.AttachSharedConfig(ffi.new("struct SharedConfig", {
        backgroundColor = colors.panel,
        cornerRadius = mk_corner_radius(0),
        userData = nil
    }))
    
    -- Card container
    argile.OpenElementWithId(card_id)
    argile.SetOpenElementLayoutConfigForContext(ctx, ffi.new("struct LayoutConfig", {
        sizing = ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = 440, max = 440 }, percent = 0 },
            height = { type = argile.SIZING_FIT, size = { min = 0, max = 0 }, percent = 0 }
        }),
        padding = mk_padding(20, 20, 20, 20),
        childGap = 16,
        childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
        layoutDirection = argile.TOP_TO_BOTTOM
    }))
    
    -- Card background
    local card_bg = colors.card_bg
    -- Match core state precedence: selected -> focus -> hover -> active -> disabled
    if demo_selected then card_bg = colors.card_selected end
    if demo_focus then card_bg = colors.card_focus end
    if demo_hover then card_bg = colors.card_hover end
    if demo_active then card_bg = colors.card_active end
    if demo_disabled then card_bg = colors.card_disabled end

    argile.AttachSharedConfig(ffi.new("struct SharedConfig", {
        backgroundColor = card_bg,
        cornerRadius = mk_corner_radius(12),
        userData = nil
    }))
    
    -- Card border
    argile.AttachBorderConfig(ffi.new("struct BorderConfig", {
        color = colors.border,
        width = ffi.new("struct BorderWidth", { left = 1, right = 1, top = 1, bottom = 1, betweenChildren = 0 })
    }))
    
    -- Paint accent stripe at the top
    local paint_ops = ffi.new("struct PaintOp[3]")
    -- Fill with accent color
    paint_ops[0].kind = argile.PAINT_OP_FILL
    paint_ops[0].color = colors.accent
    -- Draw rounded rect at top
    paint_ops[1].kind = argile.PAINT_OP_ROUND_RECT
    paint_ops[1].x = 20
    paint_ops[1].y = 20
    paint_ops[1].w = 60
    paint_ops[1].h = 4
    paint_ops[1].r = 2
    -- Fill rect
    paint_ops[2].kind = argile.PAINT_OP_RECT
    paint_ops[2].x = 20
    paint_ops[2].y = 20
    paint_ops[2].w = 60
    paint_ops[2].h = 4
    
    argile.AttachPaintConfig(ffi.new("struct PaintConfig", {
        ops = paint_ops,
        count = 3
    }))
    
    -- Title text
    argile.OpenElementWithId(title_id)
    argile.SetOpenElementLayoutConfig(mk_layout(
        mk_sizing_fit(),
        mk_padding(0, 0, 0, 0),
        0, "row"
    ))
    argile.OpenTextElement(mk_string("Argile FFI Demo"), ffi.new("struct TextConfig", {
        userData = nil,
        textColor = demo_hover and colors.accent or colors.text,
        fontId = 0,
        fontSize = 24,
        letterSpacing = 0,
        lineHeight = 0,
        wrapMode = argile.TEXT_WRAP_NONE,
        textAlignment = argile.TEXT_ALIGN_LEFT
    }))
    argile.CloseElement()
    
    -- Body text
    argile.OpenElementWithId(body_id)
    argile.SetOpenElementLayoutConfig(mk_layout(
        mk_sizing_fit(),
        mk_padding(0, 0, 0, 0),
        0, "row"
    ))
    argile.OpenTextElement(mk_string("This UI is authored entirely in LuaJIT via Argile's C/FFI API. No Terra scene export is used - all elements are created imperatively through BeginLayout, OpenElement*, and Attach*Config calls."), ffi.new("struct TextConfig", {
        userData = nil,
        textColor = colors.text_muted,
        fontId = 0,
        fontSize = 14,
        letterSpacing = 0,
        lineHeight = 20,
        wrapMode = argile.TEXT_WRAP_WORDS,
        textAlignment = argile.TEXT_ALIGN_LEFT
    }))
    argile.CloseElement()
    
    -- Footer text
    argile.OpenElementWithId(footer_id)
    argile.SetOpenElementLayoutConfig(mk_layout(
        mk_sizing_fit(),
        mk_padding(0, 0, 12, 0),
        0, "row"
    ))
    argile.OpenTextElement(mk_string("Keys: [F]ocus [S]elected [D]isabled [R]eset"), ffi.new("struct TextConfig", {
        userData = nil,
        textColor = colors.text_muted,
        fontId = 0,
        fontSize = 12,
        letterSpacing = 0,
        lineHeight = 0,
        wrapMode = argile.TEXT_WRAP_NONE,
        textAlignment = argile.TEXT_ALIGN_LEFT
    }))
    argile.CloseElement()
    
    -- Close card
    argile.CloseElement()
    
    -- Close root
    argile.CloseElement()
    
    -- Finalize layout
    return argile.FinalizeLayout()
end

-- ============================================================================
-- Love2D Callbacks
-- ============================================================================

function love.load()
    love.window.setTitle("Argile + Love2D (LuaJIT FFI Authoring Demo)")
    love.window.setMode(1280, 720, { resizable = true, vsync = 1 })
    
    -- Initialize Argile through official LuaJIT runtime wrapper
    runtime_ctx = runtime_client:create_context({
        width = 1280,
        height = 720,
        arena_bytes = arena_bytes,
    })
    ctx = runtime_ctx.ctx
    
    -- Verify API version
    local api_version = tonumber(argile.GetApiVersion())
    local expected_version = tonumber(argile.ARGILE_API_VERSION)
    if api_version ~= expected_version then
        error(("API version mismatch: got %d, expected %d"):format(api_version, expected_version))
    end
    
    -- Set current context for ID generation
    argile.SetCurrentContext(ctx)
    
    -- Create element IDs via FFI
    root_id = argile.GetElementId(mk_string("root"))
    card_id = argile.GetElementId(mk_string("card"))
    title_id = argile.GetElementId(mk_string("title"))
    body_id = argile.GetElementId(mk_string("body"))
    footer_id = argile.GetElementId(mk_string("footer"))
    
    -- Initialize text measure callback (stored in upvalue to prevent GC)
    init_text_measure_callback()

    -- Probe package capabilities and canonical AST/DSL portability.
    local caps = argile_lj.compiler.detect(argile)
    lj_capabilities.host_compiler_exports = caps.host_compiler_exports
    lj_capabilities.host_callback_backend_exports = caps.host_callback_backend_exports
    lj_capabilities.missing_count = #caps.missing
    run_lj_ast_probe()
end

function love.update(dt)
    local ww, hh = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()
    local down = love.mouse.isDown(1)
    
    -- Update pointer state
    argile.SetCurrentContext(ctx)
    argile.SetPointerState(ffi.new("struct Vector2", { x = mx, y = my }), down)
    
    -- Update element states from demo toggles
    argile.SetElementFocused(card_id, demo_focus)
    argile.SetElementSelected(card_id, demo_selected)
    argile.SetElementDisabled(card_id, demo_disabled)
    
    -- Query current hover/active state
    demo_hover = argile.PointerOver(card_id)
    demo_active = argile.ElementActive(card_id)
    
    -- Build the frame (FFI authoring - no Terra scene export)
    cmd_count = build_card_scene(ww, hh)
    cmd_buffer = argile.GetRenderCommandBuffer()
end

function love.draw()
    -- Clear background
    love.graphics.clear(0.06, 0.08, 0.12, 1.0)
    
    -- Render commands
    if cmd_buffer ~= nil then
        for i = 0, cmd_count - 1 do
            local cmd = cmd_buffer[i]
            local cmd_type = tonumber(cmd.commandType)
            
            if cmd_type == argile.RENDER_RECTANGLE then
                renderer.draw_rectangle(cmd)
            elseif cmd_type == argile.RENDER_BORDER then
                renderer.draw_border(cmd)
            elseif cmd_type == argile.RENDER_TEXT then
                renderer.draw_text(cmd)
            elseif cmd_type == argile.RENDER_PAINT then
                renderer.draw_paint(cmd, argile)
            end
        end
    end
    
    -- HUD / Debug info
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(("Argile commands: %d"):format(cmd_count), 14, 12)
    love.graphics.print(("FPS: %d"):format(love.timer.getFPS()), 14, 30)
    love.graphics.print("UI authored in LuaJIT via argile_lj runtime (no Terra scene export)", 14, 48)
    love.graphics.print(("States: [F]ocus=%s [S]elected=%s [D]isabled=%s [R]eset"):format(
        tostring(demo_focus), tostring(demo_selected), tostring(demo_disabled)
    ), 14, 66)
    love.graphics.print(("Hover: %s | Active: %s"):format(tostring(demo_hover), tostring(demo_active)), 14, 84)
    love.graphics.print(("argile_lj runtime init mode: %s"):format(tostring(runtime_ctx and runtime_ctx.init_mode or "?")), 14, 102)
    love.graphics.print(("argile_lj AST portable probe: %s (errors=%d)"):format(
        tostring(lj_ast_probe.portable_ok), tonumber(lj_ast_probe.error_count or 0)
    ), 14, 120)
    love.graphics.print(("Host compiler exports in libargile.so: compiler=%s callback_backend=%s missing=%d"):format(
        tostring(lj_capabilities.host_compiler_exports),
        tostring(lj_capabilities.host_callback_backend_exports),
        tonumber(lj_capabilities.missing_count or 0)
    ), 14, 138)
end

function love.keypressed(key)
    if key == "f" then
        demo_focus = not demo_focus
    elseif key == "s" then
        demo_selected = not demo_selected
    elseif key == "d" then
        demo_disabled = not demo_disabled
    elseif key == "r" then
        demo_focus = false
        demo_selected = false
        demo_disabled = false
    end
end

function love.quit()
    if runtime_ctx ~= nil then
        runtime_ctx:destroy()
        runtime_ctx = nil
    end
end
