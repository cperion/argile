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
local demo_tab_index = 1
local demo_time = 0
local hovered_metric_index = 0
local active_metric_index = 0
local hovered_nav_index = 0

-- Element IDs (created via FFI, not hardcoded hashes)
local root_id
local card_id
local title_id
local body_id
local footer_id
local id_cache = {}
local frame_string_pins = {}

local lj_capabilities = {
    host_compiler_exports = false,
    host_callback_backend_exports = false,
    missing_count = 0,
}

local lj_ast_probe = {
    portable_ok = false,
    error_count = 0,
}
local colors
local demo_preview_image
local demo_preview_image_key_buf
local demo_preview_image_key

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
            local ok_w, w_or_err = pcall(current_font.getWidth, current_font, text)
            local h = current_font:getHeight()
            -- Scale based on font size ratio
            local scale = font_size / current_font:getHeight()
            if ok_w then
                out_dims.width = w_or_err * scale
            else
                -- Defensive fallback: malformed UTF-8 can happen if caller-provided
                -- string memory goes stale. Keep layout alive instead of crashing.
                out_dims.width = #text * font_size * 0.6
            end
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
    frame_string_pins[#frame_string_pins + 1] = s
    return ffi.new("struct String", {
        isStaticallyAllocated = true,
        length = #s,
        chars = ffi.cast("char*", s),
    })
end

local function get_id(name)
    local cached = id_cache[name]
    if cached ~= nil then
        return cached
    end
    local v = argile.GetElementId(mk_string(name))
    id_cache[name] = v
    return v
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

local function mk_text_block_layout(width)
    return ffi.new("struct LayoutConfig", {
        sizing = ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = width, max = width }, percent = 0 },
            height = { type = argile.SIZING_FIT, size = { min = 0, max = 0 }, percent = 0 }
        }),
        padding = mk_padding(0, 0, 0, 0),
        childGap = 0,
        childAlignment = ffi.new("struct ChildAlignment", {
            x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP
        }),
        layoutDirection = argile.LEFT_TO_RIGHT
    })
end

local function mk_text_cfg(opts)
    opts = opts or {}
    local tc = runtime_client:mk_text_config({
        fontSize = opts.size or opts.fontSize or 16,
        lineHeight = opts.line_height or opts.lineHeight or (opts.size or opts.fontSize or 16),
        wrapMode = opts.wrap or opts.wrapMode or argile.TEXT_WRAP_NONE,
        textAlignment = opts.align or opts.textAlignment or argile.TEXT_ALIGN_LEFT,
        textColor = opts.color,
    })
    tc.fontId = opts.font_id or opts.fontId or tc.fontId
    tc.letterSpacing = opts.letter_spacing or opts.letterSpacing or tc.letterSpacing
    return tc
end

local function open_el(id_name, layout)
    argile.OpenElementWithId(get_id(id_name))
    if layout ~= nil then
        argile.SetOpenElementLayoutConfig(layout)
    end
end

local function close_el()
    argile.CloseElement()
end

local function shared(bg, radius)
    argile.AttachSharedConfig(ffi.new("struct SharedConfig", {
        backgroundColor = bg,
        cornerRadius = mk_corner_radius(radius or 0),
        userData = nil,
    }))
end

local function border(color, width)
    local w = width or 1
    argile.AttachBorderConfig(ffi.new("struct BorderConfig", {
        color = color,
        width = ffi.new("struct BorderWidth", {
            left = w, right = w, top = w, bottom = w, betweenChildren = 0
        }),
    }))
end

local function attach_image(image_data_key)
    if image_data_key == nil then return end
    argile.AttachImageConfig(ffi.new("struct ImageConfig", {
        imageData = image_data_key,
    }))
end

local function attach_paint_ops(ops)
    if ops == nil or #ops == 0 then return end
    local arr = ffi.new("struct PaintOp[?]", #ops)
    for i = 1, #ops do
        local src = ops[i]
        local op = arr[i - 1]
        op.kind = src.kind
        if src.color ~= nil then op.color = src.color end
        if src.x ~= nil then op.x = src.x end
        if src.y ~= nil then op.y = src.y end
        if src.w ~= nil then op.w = src.w end
        if src.h ~= nil then op.h = src.h end
        if src.r ~= nil then op.r = src.r end
        if src.x2 ~= nil then op.x2 = src.x2 end
        if src.y2 ~= nil then op.y2 = src.y2 end
        if src.width ~= nil then op.width = src.width end
    end
    argile.AttachPaintConfig(ffi.new("struct PaintConfig", { ops = arr, count = #ops }))
end

local function make_demo_preview_image()
    local w, h = 160, 96
    local img = love.image.newImageData(w, h)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local u = x / math.max(1, w - 1)
            local v = y / math.max(1, h - 1)
            local grid = (((math.floor(x / 12) + math.floor(y / 12)) % 2) == 0) and 1 or 0
            local r = 0.10 + 0.18 * u + 0.10 * grid
            local g = 0.16 + 0.30 * (1 - v) + 0.06 * (1 - grid)
            local b = 0.24 + 0.55 * u * (1 - v)

            local cx, cy = w * 0.72, h * 0.42
            local dx = (x - cx) / w
            local dy = (y - cy) / h
            local dist = math.sqrt(dx * dx + dy * dy)
            local glow = math.max(0, 1 - dist * 4.4)
            r = math.min(1, r + glow * 0.22)
            g = math.min(1, g + glow * 0.28)
            b = math.min(1, b + glow * 0.42)

            if y >= h - 20 then
                local stripe = 0.20 + 0.55 * u
                r = r * 0.55 + stripe * 0.15
                g = g * 0.55 + stripe * 0.22
                b = b * 0.55 + stripe * 0.45
            end

            img:setPixel(x, y, r, g, b, 1.0)
        end
    end
    local image = love.graphics.newImage(img)
    image:setFilter("linear", "linear")
    return image
end

local function label(id_name, text, opts)
    opts = opts or {}
    local label_layout = opts.layout
    if label_layout == nil and opts.wrap_width ~= nil then
        label_layout = mk_text_block_layout(opts.wrap_width)
    end
    open_el(id_name, label_layout or mk_layout(
        opts.sizing or mk_sizing_fit(),
        opts.padding or mk_padding(0, 0, 0, 0),
        0,
        "row"
    ))
    if opts.bg then
        shared(opts.bg, opts.radius or 0)
    end
    if opts.border then
        border(opts.border, opts.border_width or 1)
    end
    if opts.paint_ops then
        attach_paint_ops(opts.paint_ops)
    end
    local tc = mk_text_cfg({
        color = opts.color or mk_color(0.9, 0.9, 0.9, 1.0),
        size = opts.size or 14,
        lineHeight = opts.line_height or opts.size or 14,
        wrap = opts.wrap or argile.TEXT_WRAP_NONE,
        align = opts.align or argile.TEXT_ALIGN_LEFT,
    })
    argile.OpenTextElement(mk_string(text), tc)
    close_el()
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

colors = {
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
    -- Keep all Lua strings passed to Argile alive for the duration of this frame.
    -- Argile render commands and text measurement may still reference them until draw().
    frame_string_pins = {}
    runtime_ctx:set_current()
    argile.BeginLayout(width, height)

    local hud_reserve = math.max(320, math.min(360, math.floor(width * 0.28)))
    local shell_w = math.max(760, math.min(width - hud_reserve - 32, 1040))
    local shell_h = math.max(560, math.min(height - 56, 680))
    local side_w = 300
    local gap = 18
    local main_w = math.max(480, shell_w - side_w - gap)
    local hero_content_w = main_w - 54
    local side_panel_w = side_w - 18
    local side_text_w = side_panel_w - 24

    local progress = 0.35 + 0.25 * math.sin(demo_time * 0.9) + 0.15 * math.cos(demo_time * 0.3)
    if progress < 0.1 then progress = 0.1 end
    if progress > 0.95 then progress = 0.95 end
    local progress_w = math.floor((main_w - 36) * progress)

    local metrics = {
        { key = "latency", label = "Latency", value = string.format("%.1f ms", 12.8 + 3.4 * math.sin(demo_time * 1.2)), delta = "-18%", tone = colors.accent },
        { key = "throughput", label = "Throughput", value = string.format("%dk/s", 84 + math.floor(9 * math.cos(demo_time * 0.8))), delta = "+6%", tone = mk_color(0.28, 0.80, 0.56, 1.0) },
        { key = "errors", label = "Error Budget", value = string.format("%.2f%%", 0.14 + 0.05 * (1 + math.sin(demo_time * 0.7))), delta = "stable", tone = mk_color(0.95, 0.69, 0.23, 1.0) },
    }
    local nav_items = { "Overview", "Pipelines", "Deployments", "Alerts" }
    local feed_items = {
        { title = "Deploy completed", subtitle = "edge-router-v2 -> prod-eu-west", tone = mk_color(0.28, 0.80, 0.56, 1.0), status = "live" },
        { title = "Schema migration queued", subtitle = "billing-db / shard 03", tone = colors.accent, status = "pending" },
        { title = "Canary health warning", subtitle = "search-api / p95 latency drift", tone = mk_color(0.95, 0.69, 0.23, 1.0), status = "watch" },
        { title = "Retry storm suppressed", subtitle = "worker-batch / circuit breaker engaged", tone = mk_color(0.92, 0.38, 0.38, 1.0), status = "mitigated" },
    }

    open_el("root", mk_layout(mk_sizing_fixed(width, height), mk_padding(hud_reserve, 32, 24, 24), 0, "row"))
    shared(colors.panel, 0)

    local root_layout = mk_layout(
        ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = shell_w, max = shell_w }, percent = 0 },
            height = { type = argile.SIZING_FIXED, size = { min = shell_h, max = shell_h }, percent = 0 }
        }),
        mk_padding(0, 0, 0, 0),
        gap,
        "row"
    )
    root_layout.childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP })

    open_el("dashboard_shell", root_layout)
    shared(mk_color(0.10, 0.12, 0.17, 0.98), 16)
    border(mk_color(0.20, 0.24, 0.32, 1.0), 1)

    -- Main column
    open_el("main_col", ffi.new("struct LayoutConfig", {
        sizing = ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = main_w, max = main_w }, percent = 0 },
            height = { type = argile.SIZING_FIXED, size = { min = shell_h, max = shell_h }, percent = 0 }
        }),
        padding = mk_padding(18, 0, 18, 18),
        childGap = 14,
        childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
        layoutDirection = argile.TOP_TO_BOTTOM
    }))

    -- Hero panel (uses demo focus/selected/disabled + real hover/active state)
    local hero_bg = colors.card_bg
    if demo_selected then hero_bg = colors.card_selected end
    if demo_focus then hero_bg = colors.card_focus end
    if demo_hover then hero_bg = colors.card_hover end
    if demo_active then hero_bg = colors.card_active end
    if demo_disabled then hero_bg = colors.card_disabled end

    open_el("hero_panel", ffi.new("struct LayoutConfig", {
        sizing = ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = main_w - 18, max = main_w - 18 }, percent = 0 },
            height = { type = argile.SIZING_FIT, size = { min = 0, max = 0 }, percent = 0 }
        }),
        padding = mk_padding(18, 18, 16, 16),
        childGap = 12,
        childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
        layoutDirection = argile.TOP_TO_BOTTOM
    }))
    shared(hero_bg, 14)
    border(demo_focus and colors.accent or colors.border, demo_focus and 2 or 1)
    attach_paint_ops({
        { kind = argile.PAINT_OP_FILL, color = mk_color(1, 1, 1, 1) },
        { kind = argile.PAINT_OP_ROUND_RECT, x = 18, y = 14, w = 84, h = 5, r = 3 },
        { kind = argile.PAINT_OP_FILL, color = colors.accent },
        { kind = argile.PAINT_OP_ROUND_RECT, x = 18, y = 14, w = math.max(16, progress_w * 0.25), h = 5, r = 3 },
    })

    open_el("hero_header_row", mk_layout(
        ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = main_w - 54, max = main_w - 54 }, percent = 0 },
            height = { type = argile.SIZING_FIT, size = { min = 0, max = 0 }, percent = 0 }
        }),
        mk_padding(0, 0, 0, 0), 8, "row"
    ))
    local hero_header_layout = mk_layout(
        mk_sizing_fit(), mk_padding(0, 0, 0, 0), 0, "row"
    )
    open_el("hero_title_group", ffi.new("struct LayoutConfig", {
        sizing = ffi.new("struct Sizing", {
            width = { type = argile.SIZING_GROW, size = { min = 0, max = 0 }, percent = 0 },
            height = { type = argile.SIZING_FIT, size = { min = 0, max = 0 }, percent = 0 }
        }),
        padding = mk_padding(0, 0, 0, 0),
        childGap = 4,
        childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
        layoutDirection = argile.TOP_TO_BOTTOM
    }))
    label("hero_title", "Argile LuaJIT FFI Control Plane", { size = 22, color = colors.text })
    label("hero_subtitle", "Large imperative scene authored in LuaJIT using low-level runtime bindings + custom helpers", {
        size = 12,
        color = colors.text_muted,
        wrap = argile.TEXT_WRAP_WORDS,
        line_height = 16,
        wrap_width = hero_content_w,
    })
    close_el()
    close_el() -- hero_header_row

    open_el("hero_badges", mk_layout(mk_sizing_fit(), mk_padding(0, 0, 0, 0), 6, "row"))
    local badges = {
        { "FFI", colors.accent, mk_color(0.12, 0.20, 0.30, 1.0) },
        { "AST", mk_color(0.28, 0.80, 0.56, 1.0), mk_color(0.12, 0.24, 0.20, 1.0) },
        { "RUNTIME", mk_color(0.95, 0.69, 0.23, 1.0), mk_color(0.24, 0.19, 0.12, 1.0) },
    }
    for i = 1, #badges do
        local b = badges[i]
        label("badge_" .. i, b[1], {
            size = 11,
            color = b[2],
            bg = b[3],
            radius = 8,
            padding = mk_padding(8, 8, 6, 6),
        })
    end
    close_el() -- hero_badges

    label("hero_summary", "This scene intentionally stresses nested rows/columns, paint ops, repeated text measurement, hover/active state queries, runtime toggles, and the official argile_lj runtime/AST DSL wrappers.", {
        size = 13,
        color = colors.text_muted,
        wrap = argile.TEXT_WRAP_WORDS,
        line_height = 18,
        layout = ffi.new("struct LayoutConfig", {
            sizing = ffi.new("struct Sizing", {
                width = { type = argile.SIZING_FIXED, size = { min = main_w - 54, max = main_w - 54 }, percent = 0 },
                height = { type = argile.SIZING_FIT, size = { min = 0, max = 0 }, percent = 0 }
            }),
            padding = mk_padding(0, 0, 0, 0),
            childGap = 0,
            childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
            layoutDirection = argile.LEFT_TO_RIGHT
        }),
    })

    open_el("hero_progress_panel", ffi.new("struct LayoutConfig", {
        sizing = ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = main_w - 54, max = main_w - 54 }, percent = 0 },
            height = { type = argile.SIZING_FIXED, size = { min = 56, max = 56 }, percent = 0 }
        }),
        padding = mk_padding(12, 12, 10, 10),
        childGap = 8,
        childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_CENTER }),
        layoutDirection = argile.TOP_TO_BOTTOM
    }))
    shared(mk_color(0.09, 0.11, 0.15, 0.8), 10)
    attach_paint_ops({
        { kind = argile.PAINT_OP_FILL, color = mk_color(1, 1, 1, 1) },
        { kind = argile.PAINT_OP_ROUND_RECT, x = 0, y = 30, w = main_w - 78, h = 10, r = 5 },
        { kind = argile.PAINT_OP_FILL, color = mk_color(0.14, 0.18, 0.24, 1.0) },
        { kind = argile.PAINT_OP_ROUND_RECT, x = 0, y = 30, w = main_w - 78, h = 10, r = 5 },
        { kind = argile.PAINT_OP_FILL, color = colors.accent },
        { kind = argile.PAINT_OP_ROUND_RECT, x = 0, y = 30, w = progress_w, h = 10, r = 5 },
    })
    label("hero_progress_label", ("Compile cache warm-up %.0f%%"):format(progress * 100), {
        size = 12,
        color = colors.text_muted,
        padding = mk_padding(0, 0, 0, 0),
    })
    close_el() -- hero_progress_panel
    close_el() -- hero_panel

    -- Metric cards row
    open_el("metrics_row", ffi.new("struct LayoutConfig", {
        sizing = ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = main_w - 18, max = main_w - 18 }, percent = 0 },
            height = { type = argile.SIZING_FIT, size = { min = 0, max = 0 }, percent = 0 }
        }),
        padding = mk_padding(0, 0, 0, 0),
        childGap = 10,
        childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
        layoutDirection = argile.LEFT_TO_RIGHT
    }))
    local metric_w = math.floor((main_w - 18 - 20) / 3)
    for i = 1, #metrics do
        local metric = metrics[i]
        local metric_id_name = "metric_" .. i
        local is_hover = hovered_metric_index == i
        local is_active = active_metric_index == i
        local is_selected = demo_tab_index == i
        local bg = mk_color(0.11, 0.13, 0.18, 1.0)
        if is_selected then bg = mk_color(0.15, 0.19, 0.26, 1.0) end
        if is_hover then bg = mk_color(0.16, 0.21, 0.29, 1.0) end
        if is_active then bg = mk_color(0.12, 0.17, 0.25, 1.0) end

        open_el(metric_id_name, ffi.new("struct LayoutConfig", {
            sizing = ffi.new("struct Sizing", {
                width = { type = argile.SIZING_FIXED, size = { min = metric_w, max = metric_w }, percent = 0 },
                height = { type = argile.SIZING_FIXED, size = { min = 118, max = 118 }, percent = 0 }
            }),
            padding = mk_padding(12, 12, 12, 12),
            childGap = 7,
            childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
            layoutDirection = argile.TOP_TO_BOTTOM
        }))
        shared(bg, 12)
        border(is_selected and metric.tone or colors.border, is_selected and 2 or 1)

        local spark_w = metric_w - 24
        local y_base = 94
        local x_step = spark_w / 5
        attach_paint_ops({
            { kind = argile.PAINT_OP_FILL, color = mk_color(0.10, 0.12, 0.16, 0.7) },
            { kind = argile.PAINT_OP_ROUND_RECT, x = 0, y = 70, w = spark_w, h = 30, r = 6 },
            { kind = argile.PAINT_OP_STROKE, color = metric.tone, width = 2 },
            { kind = argile.PAINT_OP_LINE, x = 0, y = y_base - 8 * math.sin(demo_time + i), x2 = x_step, y2 = y_base - 12 * math.cos(demo_time * 0.7 + i * 0.5) },
            { kind = argile.PAINT_OP_LINE, x = x_step, y = y_base - 12 * math.cos(demo_time * 0.7 + i * 0.5), x2 = x_step * 2, y2 = y_base - 7 * math.sin(demo_time * 0.6 + i) },
            { kind = argile.PAINT_OP_LINE, x = x_step * 2, y = y_base - 7 * math.sin(demo_time * 0.6 + i), x2 = x_step * 3, y2 = y_base - 11 * math.cos(demo_time * 0.5 + i) },
            { kind = argile.PAINT_OP_LINE, x = x_step * 3, y = y_base - 11 * math.cos(demo_time * 0.5 + i), x2 = x_step * 4, y2 = y_base - 9 * math.sin(demo_time * 0.8 + i) },
            { kind = argile.PAINT_OP_LINE, x = x_step * 4, y = y_base - 9 * math.sin(demo_time * 0.8 + i), x2 = spark_w, y2 = y_base - 10 * math.cos(demo_time * 0.9 + i) },
        })

        label(metric_id_name .. "_label", metric.label, { size = 11, color = colors.text_muted })
        label(metric_id_name .. "_value", metric.value, { size = 22, color = colors.text })
        label(metric_id_name .. "_delta", metric.delta, {
            size = 11,
            color = metric.tone,
            bg = mk_color(0.10, 0.12, 0.16, 0.8),
            radius = 8,
            padding = mk_padding(6, 6, 4, 4),
        })
        close_el()
    end
    close_el() -- metrics_row

    -- Bottom content row inside main column
    open_el("main_bottom_row", ffi.new("struct LayoutConfig", {
        sizing = ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = main_w - 18, max = main_w - 18 }, percent = 0 },
            height = { type = argile.SIZING_GROW, size = { min = 240, max = 0 }, percent = 0 }
        }),
        padding = mk_padding(0, 0, 0, 0),
        childGap = 10,
        childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
        layoutDirection = argile.LEFT_TO_RIGHT
    }))

    local feed_w = math.floor((main_w - 28) * 0.62)
    local queue_w = (main_w - 18) - feed_w - 10

    -- Activity feed panel
    open_el("feed_panel", ffi.new("struct LayoutConfig", {
        sizing = ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = feed_w, max = feed_w }, percent = 0 },
            height = { type = argile.SIZING_GROW, size = { min = 240, max = 0 }, percent = 0 }
        }),
        padding = mk_padding(14, 14, 14, 14),
        childGap = 10,
        childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
        layoutDirection = argile.TOP_TO_BOTTOM
    }))
    shared(mk_color(0.11, 0.13, 0.18, 1.0), 12)
    border(colors.border, 1)
    label("feed_panel_title", "Deployment Activity", { size = 16, color = colors.text })
    label("feed_panel_subtitle", "Recent pipeline and cluster events (rendered as nested rows with paint badges)", {
        size = 11, color = colors.text_muted, wrap = argile.TEXT_WRAP_WORDS, line_height = 15,
        layout = ffi.new("struct LayoutConfig", {
            sizing = ffi.new("struct Sizing", {
                width = { type = argile.SIZING_FIXED, size = { min = feed_w - 28, max = feed_w - 28 }, percent = 0 },
                height = { type = argile.SIZING_FIT, size = { min = 0, max = 0 }, percent = 0 }
            }),
            padding = mk_padding(0, 0, 0, 0), childGap = 0,
            childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
            layoutDirection = argile.LEFT_TO_RIGHT
        }),
    })

    for i = 1, #feed_items do
        local item = feed_items[i]
        local row_id = "feed_row_" .. i
        local row_hover = argile.PointerOver(get_id(row_id))
        local row_bg = row_hover and mk_color(0.16, 0.19, 0.26, 1.0) or mk_color(0.09, 0.11, 0.15, 0.65)
        open_el(row_id, ffi.new("struct LayoutConfig", {
            sizing = ffi.new("struct Sizing", {
                width = { type = argile.SIZING_FIXED, size = { min = feed_w - 28, max = feed_w - 28 }, percent = 0 },
                height = { type = argile.SIZING_FIT, size = { min = 0, max = 0 }, percent = 0 }
            }),
            padding = mk_padding(10, 10, 10, 10),
            childGap = 10,
            childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
            layoutDirection = argile.LEFT_TO_RIGHT
        }))
        shared(row_bg, 10)
        attach_paint_ops({
            { kind = argile.PAINT_OP_FILL, color = item.tone },
            { kind = argile.PAINT_OP_CIRCLE, x = 7, y = 9, r = 4 },
        })

        open_el(row_id .. "_content", ffi.new("struct LayoutConfig", {
            sizing = ffi.new("struct Sizing", {
                width = { type = argile.SIZING_GROW, size = { min = 0, max = 0 }, percent = 0 },
                height = { type = argile.SIZING_FIT, size = { min = 0, max = 0 }, percent = 0 }
            }),
            padding = mk_padding(14, 0, 0, 0),
            childGap = 3,
            childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
            layoutDirection = argile.TOP_TO_BOTTOM
        }))
        label(row_id .. "_title", item.title, { size = 13, color = colors.text })
        label(row_id .. "_subtitle", item.subtitle, { size = 11, color = colors.text_muted, wrap = argile.TEXT_WRAP_WORDS, line_height = 14 })
        close_el()

        label(row_id .. "_status", item.status, {
            size = 10,
            color = item.tone,
            bg = mk_color(0.12, 0.14, 0.18, 1.0),
            border = mk_color(0.22, 0.24, 0.30, 1.0),
            radius = 8,
            border_width = 1,
            padding = mk_padding(7, 7, 5, 5),
        })
        close_el()
    end
    close_el() -- feed_panel

    -- Queue / command palette panel
    open_el("queue_panel", ffi.new("struct LayoutConfig", {
        sizing = ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = queue_w, max = queue_w }, percent = 0 },
            height = { type = argile.SIZING_GROW, size = { min = 240, max = 0 }, percent = 0 }
        }),
        padding = mk_padding(14, 14, 14, 14),
        childGap = 10,
        childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
        layoutDirection = argile.TOP_TO_BOTTOM
    }))
    shared(mk_color(0.11, 0.13, 0.18, 1.0), 12)
    border(colors.border, 1)
    label("queue_title", "Queued Actions", { size = 16, color = colors.text })

    open_el("queue_preview_image", ffi.new("struct LayoutConfig", {
        sizing = ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = queue_w - 28, max = queue_w - 28 }, percent = 0 },
            height = { type = argile.SIZING_FIXED, size = { min = 112, max = 112 }, percent = 0 }
        }),
        padding = mk_padding(0, 0, 0, 0),
        childGap = 0,
        childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
        layoutDirection = argile.LEFT_TO_RIGHT
    }))
    shared(mk_color(0.08, 0.10, 0.14, 1.0), 12)
    border(mk_color(0.22, 0.26, 0.34, 1.0), 1)
    attach_image(demo_preview_image_key)
    close_el()

    label("queue_preview_caption", "Renderer image registry (RENDER_IMAGE) bound to a LÖVE Image via opaque imageData pointer", {
        size = 10,
        color = colors.text_muted,
        wrap = argile.TEXT_WRAP_WORDS,
        line_height = 13,
        wrap_width = queue_w - 28,
    })

    local actions = {
        { "Warm compiler host", colors.accent },
        { "Rebuild token cache", mk_color(0.28, 0.80, 0.56, 1.0) },
        { "Diff layout snapshots", mk_color(0.95, 0.69, 0.23, 1.0) },
        { "Replay input traces", mk_color(0.74, 0.52, 0.95, 1.0) },
    }
    for i = 1, #actions do
        local a = actions[i]
        label("queue_item_" .. i, a[1], {
            size = 12,
            color = colors.text,
            bg = mk_color(0.09, 0.11, 0.15, 0.9),
            radius = 8,
            padding = mk_padding(10, 10, 8, 8),
            paint_ops = {
                { kind = argile.PAINT_OP_FILL, color = a[2] },
                { kind = argile.PAINT_OP_RECT, x = 0, y = 0, w = 4, h = 28 },
            },
        })
    end
    close_el() -- queue_panel
    close_el() -- main_bottom_row

    close_el() -- main_col

    -- Side column
    open_el("side_col", ffi.new("struct LayoutConfig", {
        sizing = ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = side_w, max = side_w }, percent = 0 },
            height = { type = argile.SIZING_FIXED, size = { min = shell_h, max = shell_h }, percent = 0 }
        }),
        padding = mk_padding(0, 18, 18, 0),
        childGap = 10,
        childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
        layoutDirection = argile.TOP_TO_BOTTOM
    }))

    -- Navigation
    open_el("nav_panel", ffi.new("struct LayoutConfig", {
        sizing = ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = side_panel_w, max = side_panel_w }, percent = 0 },
            height = { type = argile.SIZING_FIT, size = { min = 0, max = 0 }, percent = 0 }
        }),
        padding = mk_padding(10, 10, 10, 10),
        childGap = 6,
        childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
        layoutDirection = argile.TOP_TO_BOTTOM
    }))
    shared(mk_color(0.11, 0.13, 0.18, 1.0), 12)
    border(colors.border, 1)
    label("nav_title", "Views", { size = 14, color = colors.text })
    for i = 1, #nav_items do
        local nav_id = "nav_" .. i
        local selected = demo_tab_index == i
        local hovered = hovered_nav_index == i
        local bg = selected and mk_color(0.15, 0.19, 0.26, 1.0) or (hovered and mk_color(0.14, 0.17, 0.23, 1.0) or mk_color(0.09, 0.11, 0.15, 0.85))
        label(nav_id, nav_items[i], {
            size = 12,
            color = selected and colors.text or colors.text_muted,
            bg = bg,
            radius = 8,
            border = selected and colors.accent or nil,
            border_width = 1,
            padding = mk_padding(10, 10, 8, 8),
        })
    end
    close_el()

    -- Runtime state panel
    open_el("state_panel", ffi.new("struct LayoutConfig", {
        sizing = ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = side_panel_w, max = side_panel_w }, percent = 0 },
            height = { type = argile.SIZING_FIT, size = { min = 0, max = 0 }, percent = 0 }
        }),
        padding = mk_padding(10, 10, 10, 10),
        childGap = 6,
        childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
        layoutDirection = argile.TOP_TO_BOTTOM
    }))
    shared(mk_color(0.11, 0.13, 0.18, 1.0), 12)
    border(colors.border, 1)
    label("state_title", "Runtime State", { size = 14, color = colors.text })
    local state_rows = {
        ("hero hover / active : %s / %s"):format(tostring(demo_hover), tostring(demo_active)),
        ("metric hover / active: %d / %d"):format(hovered_metric_index, active_metric_index),
        ("nav hover / selected : %d / %d"):format(hovered_nav_index, demo_tab_index),
        ("flags F/S/D         : %s %s %s"):format(tostring(demo_focus), tostring(demo_selected), tostring(demo_disabled)),
    }
    for i = 1, #state_rows do
        label("state_row_" .. i, state_rows[i], { size = 10, color = colors.text_muted })
    end
    close_el()

    -- Compiler capability panel
    open_el("compiler_panel", ffi.new("struct LayoutConfig", {
        sizing = ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = side_panel_w, max = side_panel_w }, percent = 0 },
            height = { type = argile.SIZING_FIT, size = { min = 0, max = 0 }, percent = 0 }
        }),
        padding = mk_padding(10, 10, 10, 10),
        childGap = 6,
        childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
        layoutDirection = argile.TOP_TO_BOTTOM
    }))
    shared(mk_color(0.11, 0.13, 0.18, 1.0), 12)
    border(colors.border, 1)
    label("compiler_title", "Compiler Exposure", { size = 14, color = colors.text })
    label("compiler_mode", "Current demo uses runtime-only ui.capi.", {
        size = 10, color = colors.text_muted, wrap = argile.TEXT_WRAP_WORDS, line_height = 13, wrap_width = side_text_w
    })
    label("compiler_flag_1", "host compiler exports", {
        size = 11,
        color = lj_capabilities.host_compiler_exports and mk_color(0.28, 0.80, 0.56, 1.0) or mk_color(0.92, 0.38, 0.38, 1.0),
        bg = mk_color(0.09, 0.11, 0.15, 0.9),
        radius = 7,
        padding = mk_padding(8, 8, 6, 6),
    })
    label("compiler_flag_1v", tostring(lj_capabilities.host_compiler_exports), { size = 11, color = colors.text })
    label("compiler_flag_2", "callback backend exports", {
        size = 11,
        color = lj_capabilities.host_callback_backend_exports and mk_color(0.28, 0.80, 0.56, 1.0) or mk_color(0.92, 0.38, 0.38, 1.0),
        bg = mk_color(0.09, 0.11, 0.15, 0.9),
        radius = 7,
        padding = mk_padding(8, 8, 6, 6),
    })
    label("compiler_flag_2v", tostring(lj_capabilities.host_callback_backend_exports), { size = 11, color = colors.text })
    label("compiler_missing", ("missing symbols checked: %d"):format(lj_capabilities.missing_count), { size = 10, color = colors.text_muted })
    close_el()

    -- AST/DSL panel
    open_el("ast_panel", ffi.new("struct LayoutConfig", {
        sizing = ffi.new("struct Sizing", {
            width = { type = argile.SIZING_FIXED, size = { min = side_panel_w, max = side_panel_w }, percent = 0 },
            height = { type = argile.SIZING_GROW, size = { min = 120, max = 0 }, percent = 0 }
        }),
        padding = mk_padding(10, 10, 10, 10),
        childGap = 6,
        childAlignment = ffi.new("struct ChildAlignment", { x = argile.ALIGN_X_LEFT, y = argile.ALIGN_Y_TOP }),
        layoutDirection = argile.TOP_TO_BOTTOM
    }))
    shared(mk_color(0.11, 0.13, 0.18, 1.0), 12)
    border(colors.border, 1)
    label("ast_title", "LuaJIT DSL / AST", { size = 14, color = colors.text })
    label("ast_portable", ("portable AST probe: %s (errors=%d)"):format(
        tostring(lj_ast_probe.portable_ok), tonumber(lj_ast_probe.error_count or 0)
    ), { size = 11, color = lj_ast_probe.portable_ok and mk_color(0.28, 0.80, 0.56, 1.0) or mk_color(0.92, 0.38, 0.38, 1.0) })
    label("ast_desc", "LuaJIT builds and validates a canonical Argile AST at startup while this dashboard renders through low-level runtime calls.", {
        size = 10, color = colors.text_muted, wrap = argile.TEXT_WRAP_WORDS, line_height = 13, wrap_width = side_text_w,
    })
    label("ast_tip", "Keys [1]-[4] switch tabs; selected-state styling updates nav and metric cards.", {
        size = 10, color = colors.text_muted, wrap = argile.TEXT_WRAP_WORDS, line_height = 13, wrap_width = side_text_w,
    })
    close_el()

    close_el() -- side_col
    close_el() -- dashboard_shell
    close_el() -- root

    return argile.FinalizeLayout()
end

-- ============================================================================
-- Love2D Callbacks
-- ============================================================================

function love.load()
    love.window.setTitle("Argile + Love2D (LuaJIT FFI Authoring Demo)")
    love.window.setMode(1280, 720, { resizable = true, vsync = 1 })

    demo_preview_image = make_demo_preview_image()
    demo_preview_image_key_buf = ffi.new("char[1]")
    demo_preview_image_key = ffi.cast("void*", demo_preview_image_key_buf)
    renderer.register_image(demo_preview_image_key, {
        drawable = demo_preview_image,
        mode = "cover",
    })
    
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
    id_cache = {}
    
    -- Create element IDs via FFI
    root_id = get_id("root")
    card_id = get_id("hero_panel")
    title_id = get_id("hero_title")
    body_id = get_id("hero_summary")
    footer_id = get_id("hero_progress_label")
    for i = 1, 3 do get_id("metric_" .. i) end
    for i = 1, 4 do
        get_id("nav_" .. i)
        get_id("feed_row_" .. i)
    end
    
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
    demo_time = demo_time + dt
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
    for i = 1, 4 do
        local nav_id = get_id("nav_" .. i)
        argile.SetElementSelected(nav_id, demo_tab_index == i)
        argile.SetElementFocused(nav_id, demo_focus and demo_tab_index == i)
        argile.SetElementDisabled(nav_id, demo_disabled and i ~= demo_tab_index)
    end
    for i = 1, 3 do
        local metric_id = get_id("metric_" .. i)
        argile.SetElementSelected(metric_id, demo_tab_index == i)
        argile.SetElementFocused(metric_id, demo_focus and demo_tab_index == i)
        argile.SetElementDisabled(metric_id, demo_disabled and i == 3)
    end
    
    -- Query current hover/active state
    demo_hover = argile.PointerOver(card_id)
    demo_active = argile.ElementActive(card_id)
    hovered_metric_index = 0
    active_metric_index = 0
    for i = 1, 3 do
        local metric_id = get_id("metric_" .. i)
        if argile.PointerOver(metric_id) then hovered_metric_index = i end
        if argile.ElementActive(metric_id) then active_metric_index = i end
    end
    hovered_nav_index = 0
    for i = 1, 4 do
        if argile.PointerOver(get_id("nav_" .. i)) then
            hovered_nav_index = i
        end
    end
    
    -- Build the frame (FFI authoring - no Terra scene export)
    cmd_count = build_card_scene(ww, hh)
    cmd_buffer = argile.GetRenderCommandBuffer()
end

function love.draw()
    -- Clear background
    love.graphics.clear(0.06, 0.08, 0.12, 1.0)
    
    -- Render commands
    if cmd_buffer ~= nil then
        renderer.begin_frame()
        renderer.draw_commands(cmd_buffer, cmd_count, argile)
        renderer.end_frame()
    end
    
    -- HUD / Debug info (kept intentionally narrow so it doesn't overlap the centered card)
    local hud_x, hud_y = 14, 12
    local hud_line_h = 18
    local hud_lines = {
        ("Argile commands: %d"):format(cmd_count),
        ("FPS: %d"):format(love.timer.getFPS()),
        "LuaJIT + argile_lj runtime",
        "(no Terra scene export)",
        ("States: F=%s S=%s D=%s"):format(
            tostring(demo_focus), tostring(demo_selected), tostring(demo_disabled)
        ),
        ("Hover=%s Active=%s"):format(tostring(demo_hover), tostring(demo_active)),
        ("argile_lj runtime init: %s"):format(tostring(runtime_ctx and runtime_ctx.init_mode or "?")),
        ("AST portable: %s (errors=%d)"):format(
            tostring(lj_ast_probe.portable_ok), tonumber(lj_ast_probe.error_count or 0)
        ),
        ("Host compiler exports: c=%s cb=%s"):format(
            tostring(lj_capabilities.host_compiler_exports),
            tostring(lj_capabilities.host_callback_backend_exports)
        ),
        ("Host export checks missing: %d"):format(tonumber(lj_capabilities.missing_count or 0)),
        "Keys: [1]-[4] Tabs [F]ocus [S]elected [D]isabled [R]eset",
    }

    local font = love.graphics.getFont()
    local hud_w = 0
    for i = 1, #hud_lines do
        local w = font:getWidth(hud_lines[i])
        if w > hud_w then hud_w = w end
    end
    local hud_h = #hud_lines * hud_line_h + 12

    love.graphics.setColor(0.10, 0.12, 0.18, 0.88)
    love.graphics.rectangle("fill", hud_x - 8, hud_y - 6, hud_w + 16, hud_h, 10, 10)
    love.graphics.setColor(0.28, 0.34, 0.45, 0.9)
    love.graphics.rectangle("line", hud_x - 8, hud_y - 6, hud_w + 16, hud_h, 10, 10)

    love.graphics.setColor(1, 1, 1, 1)
    for i = 1, #hud_lines do
        love.graphics.print(hud_lines[i], hud_x, hud_y + (i - 1) * hud_line_h)
    end
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
        demo_tab_index = 1
    elseif key == "1" then
        demo_tab_index = 1
    elseif key == "2" then
        demo_tab_index = 2
    elseif key == "3" then
        demo_tab_index = 3
    elseif key == "4" then
        demo_tab_index = 4
    end
end

function love.quit()
    if demo_preview_image_key ~= nil and renderer.unregister_image ~= nil then
        renderer.unregister_image(demo_preview_image_key)
    end
    demo_preview_image = nil
    demo_preview_image_key = nil
    demo_preview_image_key_buf = nil
    if runtime_ctx ~= nil then
        runtime_ctx:destroy()
        runtime_ctx = nil
    end
end
