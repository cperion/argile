-- UI Builder for Love2D FFI Authoring Demo
-- A small imperative convenience layer over raw FFI calls
-- This is NOT the Terra DSL; it's a Lua wrapper for readability

local ffi = require("ffi")

local ui = {}

-- Colors (normalized float 0-1)
ui.colors = {
    panel = { r = 0.12, g = 0.14, b = 0.18, a = 1.0 },
    border = { r = 0.25, g = 0.28, b = 0.35, a = 1.0 },
    text = { r = 0.9, g = 0.9, b = 0.9, a = 1.0 },
    text_muted = { r = 0.6, g = 0.65, b = 0.7, a = 1.0 },
    accent = { r = 0.2, g = 0.6, b = 0.9, a = 1.0 },
    hover_overlay = { r = 1.0, g = 1.0, b = 1.0, a = 0.05 },
    active_overlay = { r = 0.0, g = 0.0, b = 0.0, a = 0.1 },
    focus_overlay = { r = 0.2, g = 0.6, b = 0.9, a = 0.15 },
    selected_overlay = { r = 0.2, g = 0.6, b = 0.9, a = 0.25 },
    disabled_overlay = { r = 0.0, g = 0.0, b = 0.0, a = 0.35 },
}

-- Internal state
local current_ctx = nil
local paint_ops_buffer = nil
local paint_ops_count = 0
local paint_ops_capacity = 0

-- Initialize FFI (to be called after loading argile_api_ffi.lua)
function ui.init(argile_lib)
    ui.argile = argile_lib
end

-- Context/Arena helpers
function ui.begin_frame(ctx, width, height)
    current_ctx = ctx
    ui.argile.BeginLayoutForContext(ctx, width, height)
end

function ui.finish_frame(ctx)
    local count = ui.argile.FinalizeLayoutForContext(ctx)
    current_ctx = nil
    paint_ops_buffer = nil
    paint_ops_count = 0
    return count
end

-- String helper for FFI
function ui.mk_string(s)
    return ffi.new("struct String", {
        isStaticallyAllocated = true,
        length = #s,
        chars = ffi.cast("char*", s),
    })
end

-- Element ID helper
function ui.mk_id(id_string)
    local str = ui.mk_string(id_string)
    return ui.argile.GetElementId(str)
end

-- Layout configuration helpers
function ui.mk_sizing(width_type, width_value, height_type, height_value)
    local sizing = ffi.new("struct Sizing")
    -- width
    if width_type == "fit" then
        sizing.width.type = ui.argile.SIZING_FIT
        sizing.width.size.min = 0
        sizing.width.size.max = 0
    elseif width_type == "grow" then
        sizing.width.type = ui.argile.SIZING_GROW
        sizing.width.size.min = width_value or 0
        sizing.width.size.max = 0
    elseif width_type == "fixed" then
        sizing.width.type = ui.argile.SIZING_FIXED
        sizing.width.size.min = width_value or 100
        sizing.width.size.max = width_value or 100
    elseif width_type == "percent" then
        sizing.width.type = ui.argile.SIZING_PERCENT
        sizing.width.percent = width_value or 1.0
    end
    -- height
    if height_type == "fit" then
        sizing.height.type = ui.argile.SIZING_FIT
        sizing.height.size.min = 0
        sizing.height.size.max = 0
    elseif height_type == "grow" then
        sizing.height.type = ui.argile.SIZING_GROW
        sizing.height.size.min = height_value or 0
        sizing.height.size.max = 0
    elseif height_type == "fixed" then
        sizing.height.type = ui.argile.SIZING_FIXED
        sizing.height.size.min = height_value or 100
        sizing.height.size.max = height_value or 100
    elseif height_type == "percent" then
        sizing.height.type = ui.argile.SIZING_PERCENT
        sizing.height.percent = height_value or 1.0
    end
    return sizing
end

function ui.mk_padding(left, right, top, bottom)
    return ffi.new("struct Padding", {
        left = left or 0,
        right = right or 0,
        top = top or 0,
        bottom = bottom or 0,
    })
end

function ui.mk_child_alignment(x, y)
    local align_x = ui.argile.ALIGN_X_LEFT
    if x == "center" then align_x = ui.argile.ALIGN_X_CENTER
    elseif x == "right" then align_x = ui.argile.ALIGN_X_RIGHT end
    
    local align_y = ui.argile.ALIGN_Y_TOP
    if y == "center" then align_y = ui.argile.ALIGN_Y_CENTER
    elseif y == "bottom" then align_y = ui.argile.ALIGN_Y_BOTTOM end
    
    return ffi.new("struct ChildAlignment", { x = align_x, y = align_y })
end

function ui.mk_layout(opts)
    opts = opts or {}
    local layout = ffi.new("struct LayoutConfig")
    layout.sizing = opts.sizing or ui.mk_sizing("fit", 0, "fit", 0)
    layout.padding = opts.padding or ui.mk_padding(0, 0, 0, 0)
    layout.childGap = opts.gap or 0
    layout.childAlignment = opts.alignment or ui.mk_child_alignment("left", "top")
    layout.layoutDirection = opts.direction == "col" and ui.argile.TOP_TO_BOTTOM or ui.argile.LEFT_TO_RIGHT
    return layout
end

-- Element building (imperative style)
function ui.open_element(id_or_string)
    if type(id_or_string) == "string" then
        ui.argile.OpenElementWithIdForContext(current_ctx, ui.mk_id(id_or_string))
    else
        ui.argile.OpenElementWithIdForContext(current_ctx, id_or_string)
    end
end

function ui.close_element()
    ui.argile.CloseElementForContext(current_ctx)
end

-- Apply layout config to open element
function ui.layout(opts)
    local layout = ui.mk_layout(opts)
    ui.argile.SetOpenElementLayoutConfigForContext(current_ctx, layout)
end

-- Apply style (shared config + border)
function ui.style(opts)
    opts = opts or {}
    
    -- Shared config (background, corner radius)
    if opts.bg or opts.radius then
        local shared = ffi.new("struct SharedConfig")
        shared.backgroundColor = opts.bg or ui.colors.panel
        shared.cornerRadius = ffi.new("struct CornerRadius", {
            topLeft = opts.radius or 0,
            topRight = opts.radius or 0,
            bottomLeft = opts.radius or 0,
            bottomRight = opts.radius or 0,
        })
        shared.userData = nil
        ui.argile.AttachSharedConfigForContext(current_ctx, shared)
    end
    
    -- Border config
    if opts.border_width or opts.border_color then
        local border = ffi.new("struct BorderConfig")
        border.color = opts.border_color or ui.colors.border
        local w = opts.border_width or 1
        border.width.left = w
        border.width.right = w
        border.width.top = w
        border.width.bottom = w
        border.width.betweenChildren = 0
        ui.argile.AttachBorderConfigForContext(current_ctx, border)
    end
end

-- Text element
function ui.text(content, opts)
    opts = opts or {}
    local text_config = ffi.new("struct TextConfig")
    text_config.userData = nil
    text_config.textColor = opts.color or ui.colors.text
    text_config.fontId = opts.font_id or 0
    text_config.fontSize = opts.size or 16
    text_config.letterSpacing = opts.letter_spacing or 0
    text_config.lineHeight = opts.line_height or 0
    text_config.wrapMode = ui.argile.TEXT_WRAP_NONE
    text_config.textAlignment = ui.argile.TEXT_ALIGN_LEFT
    
    local str = ui.mk_string(content)
    ui.argile.OpenTextElementForContext(current_ctx, str, text_config)
end

-- Paint configuration (for accent stripes, etc)
function ui.begin_paint()
    paint_ops_buffer = {}
    paint_ops_count = 0
end

function ui.fill(color)
    local op = ffi.new("struct PaintOp")
    op.kind = ui.argile.PAINT_OP_FILL
    op.color = color or ui.colors.accent
    table.insert(paint_ops_buffer, op)
end

function ui.stroke(color, width)
    local op = ffi.new("struct PaintOp")
    op.kind = ui.argile.PAINT_OP_STROKE
    op.color = color or ui.colors.border
    op.width = width or 1
    table.insert(paint_ops_buffer, op)
end

function ui.rect(x, y, w, h)
    local op = ffi.new("struct PaintOp")
    op.kind = ui.argile.PAINT_OP_RECT
    op.x = x
    op.y = y
    op.w = w
    op.h = h
    table.insert(paint_ops_buffer, op)
end

function ui.round_rect(x, y, w, h, r)
    local op = ffi.new("struct PaintOp")
    op.kind = ui.argile.PAINT_OP_ROUND_RECT
    op.x = x
    op.y = y
    op.w = w
    op.h = h
    op.r = r or 0
    table.insert(paint_ops_buffer, op)
end

function ui.circle(x, y, r)
    local op = ffi.new("struct PaintOp")
    op.kind = ui.argile.PAINT_OP_CIRCLE
    op.x = x
    op.y = y
    op.r = r
    table.insert(paint_ops_buffer, op)
end

function ui.line(x1, y1, x2, y2)
    local op = ffi.new("struct PaintOp")
    op.kind = ui.argile.PAINT_OP_LINE
    op.x = x1
    op.y = y1
    op.x2 = x2
    op.y2 = y2
    table.insert(paint_ops_buffer, op)
end

function ui.end_paint()
    if #paint_ops_buffer == 0 then return end
    
    -- Create C array of paint ops
    local count = #paint_ops_buffer
    local ops_array = ffi.new("struct PaintOp[?]", count)
    for i = 1, count do
        ops_array[i - 1] = paint_ops_buffer[i]
    end
    
    local paint_config = ffi.new("struct PaintConfig")
    paint_config.ops = ops_array
    paint_config.count = count
    
    ui.argile.AttachPaintConfigForContext(current_ctx, paint_config)
    
    paint_ops_buffer = nil
    paint_ops_count = 0
end

-- Utility function to build a complete card
function ui.card(id, content_fn, opts)
    opts = opts or {}
    local width_type, width_value = "fit", 0
    local height_type, height_value = "fit", 0
    if type(opts.width) == "number" then
        width_type, width_value = "fixed", opts.width
    elseif type(opts.width) == "string" then
        width_type = opts.width
    end
    if type(opts.height) == "number" then
        height_type, height_value = "fixed", opts.height
    elseif type(opts.height) == "string" then
        height_type = opts.height
    end
    local pad = opts.padding or 12
    local padding = ffi.istype("struct Padding", pad) and pad or ui.mk_padding(pad, pad, pad, pad)

    ui.open_element(id)
    ui.layout({
        sizing = ui.mk_sizing(width_type, width_value, height_type, height_value),
        direction = opts.direction or "col",
        padding = padding,
        gap = opts.gap or 8,
    })
    ui.style({
        bg = opts.bg or ui.colors.panel,
        radius = opts.radius or 10,
        border_width = opts.border_width or 1,
        border_color = opts.border_color or ui.colors.border,
    })
    
    if opts.paint then
        ui.begin_paint()
        opts.paint(ui)
        ui.end_paint()
    end
    
    if content_fn then
        content_fn()
    end
    
    ui.close_element()
end

-- State setters
function ui.set_focused(ctx, id, focused)
    ui.argile.SetElementFocusedForContext(ctx, id, focused)
end

function ui.set_selected(ctx, id, selected)
    ui.argile.SetElementSelectedForContext(ctx, id, selected)
end

function ui.set_disabled(ctx, id, disabled)
    ui.argile.SetElementDisabledForContext(ctx, id, disabled)
end

-- Query state (for open element)
function ui.is_hovered()
    return ui.argile.Hovered()
end

function ui.is_active()
    return ui.argile.ElementActive()
end

function ui.is_focused()
    return ui.argile.ElementFocused()
end

function ui.is_selected()
    return ui.argile.ElementSelected()
end

function ui.is_disabled()
    return ui.argile.ElementDisabled()
end

-- Pointer state
function ui.set_pointer(ctx, x, y, down)
    local p = ffi.new("struct Vector2", { x = x, y = y })
    ui.argile.SetPointerStateForContext(ctx, p, down)
end

return ui
