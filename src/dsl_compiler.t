--[[
    Argile DSL Compiler - Direct DSL AST to Terra Quotes
    
    Compiles DSL AST (component invocations, slots, fills) directly into
    Terra Quotes, eliminating the V2 intermediate representation.
    
    Key design:
    - Components are Lua functions that return Terra Quotes
    - Slots/fills are passed as Quote lists (terralib.newlist)
    - No deep_clone_node - Terra's quote engine handles hygiene
    - Single-pass compilation aligned with Terra's Builder Pattern
]]

local ui = require("src.init")
local style = require("src/style/core")
local AST = require("src/lang/ast")
local Span = require("src/lang/argile_span")
local DslRegistry = require("src/dsl_registry")

local M = {}

local function value_or(v, default)
    if v == nil then return default end
    return v
end

local function is_table(v)
    return type(v) == "table"
end

local function is_terra_node(v)
    return terralib.isquote(v) or terralib.issymbol(v)
end

local function terra_value_type(v)
    if terralib.issymbol(v) then
        return v.type
    end
    if type(v) == "table" and v.gettype then
        return v:gettype()
    end
    return nil
end

local function deep_copy(t)
    if not is_table(t) then return t end
    local copy = {}
    for k, v in pairs(t) do
        if is_table(v) then
            copy[k] = deep_copy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function deep_merge(a, b)
    if not is_table(a) then return deep_copy(b) end
    if not is_table(b) then return deep_copy(a) end
    local result = deep_copy(a)
    for k, v in pairs(b) do
        if is_table(v) and is_table(result[k]) then
            result[k] = deep_merge(result[k], v)
        else
            result[k] = deep_copy(v)
        end
    end
    return result
end

local function merge_into(target, source)
    if not source then return target end
    if not target then return deep_copy(source) end
    return deep_merge(target, source)
end

local runtime_states = {
    hover = true,
    active = true,
    disabled = true,
    focus = true,
    selected = true,
}

local runtime_state_order = {
    "selected",
    "focus", 
    "hover",
    "active",
    "disabled",
}

local layout_dir_values = {
    left_to_right = ui.LEFT_TO_RIGHT,
    top_to_bottom = ui.TOP_TO_BOTTOM,
}

local align_x_values = {
    left = ui.ALIGN_X_LEFT,
    right = ui.ALIGN_X_RIGHT,
    center = ui.ALIGN_X_CENTER,
}

local align_y_values = {
    top = ui.ALIGN_Y_TOP,
    bottom = ui.ALIGN_Y_BOTTOM,
    center = ui.ALIGN_Y_CENTER,
}

local text_wrap_values = {
    words = ui.TEXT_WRAP_WORDS,
    newlines = ui.TEXT_WRAP_NEWLINES,
    none = ui.TEXT_WRAP_NONE,
}

local function normalize_value(value)
    if AST.IsKind(value, "Symbol") then
        return value.name
    end
    return value
end

local function eval_dsl_value(expr, env_fn)
    return normalize_value(AST.EvalExpr(expr, env_fn))
end

local function resolve_symbol(value, is_variant, env_fn)
    if not AST.IsKind(value, "Symbol") then
        return value
    end
    if is_variant then
        return value.name
    end
    local env = env_fn and env_fn() or nil
    local resolved = env and env[value.name] or nil
    if resolved == nil then
        resolved = rawget(_G, value.name)
    end
    if resolved == nil then
        Span.Raise(value._span,
            "cannot resolve symbol '" .. value.name .. "' — not found in scope")
    end
    return resolved
end

local function compileLayoutConfig(cfg)
    local widthType = cfg.widthType or ui.SIZING_FIT
    local heightType = cfg.heightType or ui.SIZING_FIT
    local minWidth = cfg.minWidth or 0.0
    local minHeight = cfg.minHeight or 0.0
    local maxWidth = cfg.maxWidth or ui.MAXFLOAT
    local maxHeight = cfg.maxHeight or ui.MAXFLOAT
    local widthPercent = cfg.widthPercent or 0.0
    local heightPercent = cfg.heightPercent or 0.0
    local paddingLeft = cfg.paddingLeft or 0
    local paddingRight = cfg.paddingRight or 0
    local paddingTop = cfg.paddingTop or 0
    local paddingBottom = cfg.paddingBottom or 0
    local childGap = cfg.childGap or 0
    local alignX = cfg.alignX or ui.ALIGN_X_LEFT
    local alignY = cfg.alignY or ui.ALIGN_Y_TOP
    local layoutDir = cfg.layoutDir or ui.LEFT_TO_RIGHT
    
    return quote
        var c : ui.LayoutConfig
        c.sizing.width.type = [widthType]
        c.sizing.width.size.min = [minWidth]
        c.sizing.width.size.max = [maxWidth]
        c.sizing.width.percent = [widthPercent]
        c.sizing.height.type = [heightType]
        c.sizing.height.size.min = [minHeight]
        c.sizing.height.size.max = [maxHeight]
        c.sizing.height.percent = [heightPercent]
        c.padding.left = [paddingLeft]
        c.padding.right = [paddingRight]
        c.padding.top = [paddingTop]
        c.padding.bottom = [paddingBottom]
        c.childGap = [childGap]
        c.childAlignment.x = [alignX]
        c.childAlignment.y = [alignY]
        c.layoutDirection = [layoutDir]
    in
        c
    end
end

local function compileSharedConfig(cfg)
    if cfg == nil then return nil end
    
    local bg = cfg.backgroundColor
    local userData = cfg.userData
    local cr = cfg.cornerRadius
    
    if is_terra_node(bg) or is_terra_node(cr) then
        return quote
            var s : ui.SharedConfig
            s.backgroundColor = [is_terra_node(bg) and bg or `{0.0, 0.0, 0.0, 0.0}]
            s.cornerRadius = [is_terra_node(cr) and cr or `{0.0, 0.0, 0.0, 0.0}]
            s.userData = [userData ~= nil and userData or nil]
        in
            s
        end
    end
    
    local r = bg and value_or(bg.r, 0.0) or 0.0
    local g = bg and value_or(bg.g, 0.0) or 0.0
    local b = bg and value_or(bg.b, 0.0) or 0.0
    local a = bg and value_or(bg.a, 1.0) or 0.0
    local tl = cr and value_or(cr.topLeft, 0.0) or 0.0
    local tr = cr and value_or(cr.topRight, 0.0) or 0.0
    local bl = cr and value_or(cr.bottomLeft, 0.0) or 0.0
    local br = cr and value_or(cr.bottomRight, 0.0) or 0.0

    if userData ~= nil then
        return quote
            var s : ui.SharedConfig
            s.backgroundColor.r = [r]
            s.backgroundColor.g = [g]
            s.backgroundColor.b = [b]
            s.backgroundColor.a = [a]
            s.cornerRadius.topLeft = [tl]
            s.cornerRadius.topRight = [tr]
            s.cornerRadius.bottomLeft = [bl]
            s.cornerRadius.bottomRight = [br]
            s.userData = [userData]
        in
            s
        end
    end

    return quote
        var s : ui.SharedConfig
        s.backgroundColor.r = [r]
        s.backgroundColor.g = [g]
        s.backgroundColor.b = [b]
        s.backgroundColor.a = [a]
        s.cornerRadius.topLeft = [tl]
        s.cornerRadius.topRight = [tr]
        s.cornerRadius.bottomLeft = [bl]
        s.cornerRadius.bottomRight = [br]
        s.userData = nil
    in
        s
    end
end

local function compileBorderConfig(cfg)
    if cfg == nil then return nil end

    local color = cfg.color or {}
    local widthTable = type(cfg.width) == "table" and cfg.width or nil
    local uniformWidth = type(cfg.width) == "number" and cfg.width or cfg.uniformWidth
    if uniformWidth == nil then uniformWidth = 0 end

    local left = value_or(widthTable and widthTable.left, value_or(cfg.left, uniformWidth))
    local right = value_or(widthTable and widthTable.right, value_or(cfg.right, uniformWidth))
    local top = value_or(widthTable and widthTable.top, value_or(cfg.top, uniformWidth))
    local bottom = value_or(widthTable and widthTable.bottom, value_or(cfg.bottom, uniformWidth))
    local betweenChildren = value_or(widthTable and widthTable.betweenChildren, value_or(cfg.betweenChildren, 0))

    return quote
        var b : ui.BorderConfig
        b.color.r = [value_or(color.r, 0.0)]
        b.color.g = [value_or(color.g, 0.0)]
        b.color.b = [value_or(color.b, 0.0)]
        b.color.a = [value_or(color.a, 1.0)]
        b.width.left = [left]
        b.width.right = [right]
        b.width.top = [top]
        b.width.bottom = [bottom]
        b.width.betweenChildren = [betweenChildren]
    in
        b
    end
end

local function compileTextConfig(cfg)
    local textColor = cfg.textColor or cfg.color
    local userData = cfg.userData
    
    if is_terra_node(textColor) then
        if userData ~= nil then
            return quote
                var t : ui.TextConfig
                t.userData = [userData]
                t.textColor = [textColor]
                t.fontId = [value_or(cfg.fontId, 0)]
                t.fontSize = [value_or(cfg.fontSize, 16)]
                t.letterSpacing = [value_or(cfg.letterSpacing, 0)]
                t.lineHeight = [value_or(cfg.lineHeight, 0)]
                t.wrapMode = [value_or(cfg.wrapMode, ui.TEXT_WRAP_WORDS)]
                t.textAlignment = [value_or(cfg.textAlignment, ui.TEXT_ALIGN_LEFT)]
            in
                t
            end
        end
        return quote
            var t : ui.TextConfig
            t.userData = nil
            t.textColor = [textColor]
            t.fontId = [value_or(cfg.fontId, 0)]
            t.fontSize = [value_or(cfg.fontSize, 16)]
            t.letterSpacing = [value_or(cfg.letterSpacing, 0)]
            t.lineHeight = [value_or(cfg.lineHeight, 0)]
            t.wrapMode = [value_or(cfg.wrapMode, ui.TEXT_WRAP_WORDS)]
            t.textAlignment = [value_or(cfg.textAlignment, ui.TEXT_ALIGN_LEFT)]
        in
            t
        end
    end
    
    textColor = textColor or {}

    if userData ~= nil then
        return quote
            var t : ui.TextConfig
            t.userData = [userData]
            t.textColor.r = [value_or(textColor.r, 0.0)]
            t.textColor.g = [value_or(textColor.g, 0.0)]
            t.textColor.b = [value_or(textColor.b, 0.0)]
            t.textColor.a = [value_or(textColor.a, 1.0)]
            t.fontId = [value_or(cfg.fontId, 0)]
            t.fontSize = [value_or(cfg.fontSize, 16)]
            t.letterSpacing = [value_or(cfg.letterSpacing, 0)]
            t.lineHeight = [value_or(cfg.lineHeight, 0)]
            t.wrapMode = [value_or(cfg.wrapMode, ui.TEXT_WRAP_WORDS)]
            t.textAlignment = [value_or(cfg.textAlignment, ui.TEXT_ALIGN_LEFT)]
        in
            t
        end
    end

    return quote
        var t : ui.TextConfig
        t.userData = nil
        t.textColor.r = [value_or(textColor.r, 0.0)]
        t.textColor.g = [value_or(textColor.g, 0.0)]
        t.textColor.b = [value_or(textColor.b, 0.0)]
        t.textColor.a = [value_or(textColor.a, 1.0)]
        t.fontId = [value_or(cfg.fontId, 0)]
        t.fontSize = [value_or(cfg.fontSize, 16)]
        t.letterSpacing = [value_or(cfg.letterSpacing, 0)]
        t.lineHeight = [value_or(cfg.lineHeight, 0)]
        t.wrapMode = [value_or(cfg.wrapMode, ui.TEXT_WRAP_WORDS)]
        t.textAlignment = [value_or(cfg.textAlignment, ui.TEXT_ALIGN_LEFT)]
    in
        t
    end
end

local function compilePaintConfig(paint_ops)
    if not paint_ops or #paint_ops == 0 then return nil end
    
    local count = #paint_ops
    local count_t = terralib.constant(int32, count)

    local kind_map = {
        fill = ui.PAINT_OP_FILL,
        stroke = ui.PAINT_OP_STROKE,
        rect = ui.PAINT_OP_RECT,
        round_rect = ui.PAINT_OP_ROUND_RECT,
        circle = ui.PAINT_OP_CIRCLE,
        line = ui.PAINT_OP_LINE,
    }
    
    local op_init_list = terralib.newlist()
    for _, op in ipairs(paint_ops) do
        local color = op.color
        local kind_value = op.kind
        if type(kind_value) == "string" then
            kind_value = kind_map[kind_value]
        end
        if kind_value == nil then kind_value = ui.PAINT_OP_FILL end
        local kind_t = terralib.constant(uint8, kind_value)
        
        if is_terra_node(color) then
            local x = value_or(op.x, value_or(op.x1, value_or(op.cx, 0.0)))
            local y = value_or(op.y, value_or(op.y1, value_or(op.cy, 0.0)))
            local w = value_or(op.w, 0.0)
            local h = value_or(op.h, 0.0)
            local r = value_or(op.r, 0.0)
            local x2 = value_or(op.x2, 0.0)
            local y2 = value_or(op.y2, 0.0)
            local width = value_or(op.width, 1)
            
            op_init_list:insert(`(ui.PaintOp {
                kind = [kind_t],
                color = [color],
                x = [float]([x]), y = [float]([y]), w = [float]([w]), h = [float]([h]), r = [float]([r]),
                x2 = [float]([x2]), y2 = [float]([y2]), width = [uint16]([width])
            }))
        else
            color = color or { r = 0, g = 0, b = 0, a = 1 }
            local color_r = value_or(color.r, 0.0)
            local color_g = value_or(color.g, 0.0)
            local color_b = value_or(color.b, 0.0)
            local color_a = value_or(color.a, 1.0)
            local x = value_or(op.x, value_or(op.x1, value_or(op.cx, 0.0)))
            local y = value_or(op.y, value_or(op.y1, value_or(op.cy, 0.0)))
            local w = value_or(op.w, 0.0)
            local h = value_or(op.h, 0.0)
            local r = value_or(op.r, 0.0)
            local x2 = value_or(op.x2, 0.0)
            local y2 = value_or(op.y2, 0.0)
            local width = value_or(op.width, 1)
            
            op_init_list:insert(`(ui.PaintOp {
                kind = [kind_t],
                color = ui.Color { r = [float]([color_r]), g = [float]([color_g]), b = [float]([color_b]), a = [float]([color_a]) },
                x = [float]([x]), y = [float]([y]), w = [float]([w]), h = [float]([h]), r = [float]([r]),
                x2 = [float]([x2]), y2 = [float]([y2]), width = [uint16]([width])
            }))
        end
    end
    
    local ops_array = `arrayof(ui.PaintOp, [op_init_list])
    
    return quote
        var ops = [ops_array]
        var cfg : ui.PaintConfig
        cfg.ops = ops
        cfg.count = [count_t]
    in
        cfg
    end
end

local function compileClipConfig(cfg)
    if cfg == nil then return nil end
    local childOffset = cfg.childOffset or {}
    return quote
        var c : ui.ClipConfig
        c.horizontal = [value_or(cfg.horizontal, false)]
        c.vertical = [value_or(cfg.vertical, false)]
        c.childOffset.x = [value_or(childOffset.x, value_or(cfg.offsetX, 0.0))]
        c.childOffset.y = [value_or(childOffset.y, value_or(cfg.offsetY, 0.0))]
    in
        c
    end
end

local function compileAspectConfig(cfg)
    if cfg == nil then return nil end
    local ratio = value_or(cfg.aspectRatio, value_or(cfg.ratio, 1.0))
    return quote
        var a : ui.AspectRatioConfig
        a.aspectRatio = [ratio]
    in
        a
    end
end

local function compileImageConfig(cfg)
    if cfg == nil then return nil end
    local imageData = value_or(cfg.imageData, cfg.data)
    if imageData ~= nil then
        return quote
            var i : ui.ImageConfig
            i.imageData = [imageData]
        in
            i
        end
    end
    return quote
        var i : ui.ImageConfig
        i.imageData = nil
    in
        i
    end
end

local function compileCustomConfig(cfg)
    if cfg == nil then return nil end
    local customData = value_or(cfg.customData, cfg.data)
    if customData ~= nil then
        return quote
            var c : ui.CustomConfig
            c.customData = [customData]
        in
            c
        end
    end
    return quote
        var c : ui.CustomConfig
        c.customData = nil
    in
        c
    end
end

local function compileFloatingConfig(cfg)
    if cfg == nil then return nil end
    local offset = cfg.offset or {}
    local expand = cfg.expand or {}
    local attachPoints = cfg.attachPoints or {}

    return quote
        var f : ui.FloatingConfig
        f.offset.x = [value_or(offset.x, value_or(cfg.offsetX, 0.0))]
        f.offset.y = [value_or(offset.y, value_or(cfg.offsetY, 0.0))]
        f.expand.width = [value_or(expand.width, value_or(cfg.expandWidth, 0.0))]
        f.expand.height = [value_or(expand.height, value_or(cfg.expandHeight, 0.0))]
        f.parentId = [value_or(cfg.parentId, 0)]
        f.zIndex = [value_or(cfg.zIndex, 0)]
        f.attachPoints.element = [value_or(attachPoints.element, value_or(cfg.elementAttach, ui.ATTACH_LEFT_TOP))]
        f.attachPoints.parent = [value_or(attachPoints.parent, value_or(cfg.parentAttach, ui.ATTACH_LEFT_TOP))]
        f.pointerCaptureMode = [value_or(cfg.pointerCaptureMode, ui.POINTER_CAPTURE)]
        f.attachTo = [value_or(cfg.attachTo, ui.ATTACH_NONE)]
        f.clipTo = [value_or(cfg.clipTo, ui.CLIP_NONE)]
    in
        f
    end
end

local function apply_layout_ops(base_layout, ops, env_fn)
    if not ops or #ops == 0 then return base_layout end
    
    local layout = base_layout and deep_copy(base_layout) or {}
    
    for _, op in ipairs(ops) do
        local n = op.name
        local args = op.args or {}
        local evaluated_args = {}
        for i, arg_expr in ipairs(args) do
            evaluated_args[i] = eval_dsl_value(arg_expr, env_fn)
        end
        
        if n == "width" then
            layout.widthType = ui.SIZING_FIXED
            layout.minWidth = evaluated_args[1]
            layout.maxWidth = evaluated_args[1]
        elseif n == "height" then
            layout.heightType = ui.SIZING_FIXED
            layout.minHeight = evaluated_args[1]
            layout.maxHeight = evaluated_args[1]
        elseif n == "sizing" then
            local mode = evaluated_args[1]
            if mode == "fit" then
                layout.widthType = ui.SIZING_FIT
                layout.heightType = ui.SIZING_FIT
            elseif mode == "fixed" then
                layout.widthType = ui.SIZING_FIXED
                layout.heightType = ui.SIZING_FIXED
            elseif mode == "percent" then
                layout.widthType = ui.SIZING_PERCENT
                layout.heightType = ui.SIZING_PERCENT
            elseif mode == "grow" then
                layout.widthType = ui.SIZING_GROW
                layout.heightType = ui.SIZING_GROW
            end
        elseif n == "min_width" then
            layout.minWidth = evaluated_args[1]
        elseif n == "min_height" then
            layout.minHeight = evaluated_args[1]
        elseif n == "max_width" then
            layout.maxWidth = evaluated_args[1]
        elseif n == "max_height" then
            layout.maxHeight = evaluated_args[1]
        elseif n == "percent_width" then
            layout.widthPercent = evaluated_args[1]
            layout.widthType = ui.SIZING_PERCENT
        elseif n == "percent_height" then
            layout.heightPercent = evaluated_args[1]
            layout.heightType = ui.SIZING_PERCENT
        elseif n == "padding" then
            local v = evaluated_args[1] or 0
            layout.paddingLeft = v
            layout.paddingRight = v
            layout.paddingTop = v
            layout.paddingBottom = v
        elseif n == "padding4" then
            layout.paddingLeft = evaluated_args[1] or 0
            layout.paddingRight = evaluated_args[2] or 0
            layout.paddingTop = evaluated_args[3] or 0
            layout.paddingBottom = evaluated_args[4] or 0
        elseif n == "padding_x" then
            layout.paddingLeft = evaluated_args[1]
            layout.paddingRight = evaluated_args[1]
        elseif n == "padding_y" then
            layout.paddingTop = evaluated_args[1]
            layout.paddingBottom = evaluated_args[1]
        elseif n == "gap" then
            layout.childGap = evaluated_args[1]
        elseif n == "width_grow" then
            layout.widthType = ui.SIZING_GROW
        elseif n == "width_fit" then
            layout.widthType = ui.SIZING_FIT
        elseif n == "width_fixed" then
            layout.widthType = ui.SIZING_FIXED
            layout.minWidth = evaluated_args[1] or 0
            layout.maxWidth = evaluated_args[1] or 0
        elseif n == "width_percent" then
            layout.widthType = ui.SIZING_PERCENT
            layout.widthPercent = evaluated_args[1] or 0
        elseif n == "height_grow" then
            layout.heightType = ui.SIZING_GROW
        elseif n == "height_fit" then
            layout.heightType = ui.SIZING_FIT
        elseif n == "height_fixed" then
            layout.heightType = ui.SIZING_FIXED
            layout.minHeight = evaluated_args[1] or 0
            layout.maxHeight = evaluated_args[1] or 0
        elseif n == "height_percent" then
            layout.heightType = ui.SIZING_PERCENT
            layout.heightPercent = evaluated_args[1] or 0
        elseif n == "align_x" then
            layout.alignX = align_x_values[evaluated_args[1]] or evaluated_args[1]
        elseif n == "align_y" then
            layout.alignY = align_y_values[evaluated_args[1]] or evaluated_args[1]
        elseif n == "dir" or n == "direction" then
            layout.layoutDir = layout_dir_values[evaluated_args[1]] or evaluated_args[1]
        end
    end
    
    return layout
end

local function apply_style_ops(base_shared, ops, env_fn)
    if not ops or #ops == 0 then return base_shared end
    
    local shared = base_shared and deep_copy(base_shared) or {}
    
    for _, op in ipairs(ops) do
        local n = op.name
        local args = op.args or {}
        local evaluated_args = {}
        for i, arg_expr in ipairs(args) do
            evaluated_args[i] = eval_dsl_value(arg_expr, env_fn)
        end
        
        if n == "bg" then
            shared.backgroundColor = evaluated_args[1]
        elseif n == "radius" then
            shared.cornerRadius = style.corner_radius(evaluated_args[1])
        elseif n == "radius4" then
            shared.cornerRadius = style.corner_radius(evaluated_args[1], evaluated_args[2], evaluated_args[3], evaluated_args[4])
        elseif n == "border_width" then
            shared.border = shared.border or {}
            shared.border.width = style.border_width(evaluated_args[1])
        elseif n == "border_width4" then
            shared.border = shared.border or {}
            shared.border.width = style.border_width(evaluated_args[1], evaluated_args[2], evaluated_args[3], evaluated_args[4])
        elseif n == "border_between_children" then
            shared.border = shared.border or {}
            shared.border.width = shared.border.width or style.border_width(0)
            shared.border.width.betweenChildren = evaluated_args[1] or 0
        elseif n == "border_color" then
            shared.border = shared.border or {}
            shared.border.color = evaluated_args[1]
        elseif n == "user_data" then
            shared.userData = evaluated_args[1]
        end
    end
    
    return shared
end

local function apply_typography_ops(base_text_config, ops, env_fn)
    if not ops or #ops == 0 then return base_text_config end
    
    local textConfig = base_text_config and deep_copy(base_text_config) or {}
    
    for _, op in ipairs(ops) do
        local n = op.name
        local args = op.args or {}
        local evaluated_args = {}
        for i, arg_expr in ipairs(args) do
            evaluated_args[i] = eval_dsl_value(arg_expr, env_fn)
        end
        
        if n == "color" then
            textConfig.textColor = evaluated_args[1]
        elseif n == "font_id" then
            textConfig.fontId = evaluated_args[1]
        elseif n == "font_size" then
            textConfig.fontSize = evaluated_args[1]
        elseif n == "letter_spacing" then
            textConfig.letterSpacing = evaluated_args[1]
        elseif n == "line_height" then
            textConfig.lineHeight = evaluated_args[1]
        elseif n == "wrap" then
            textConfig.wrapMode = text_wrap_values[evaluated_args[1]] or evaluated_args[1]
        elseif n == "align" then
            textConfig.textAlignment = evaluated_args[1]
        elseif n == "user_data" then
            textConfig.userData = evaluated_args[1]
        end
    end
    
    return textConfig
end

local function apply_paint_ops(base_paint, ops, env_fn)
    if not ops or #ops == 0 then return base_paint end
    
    local paint = base_paint and deep_copy(base_paint) or {}
    
    for _, op in ipairs(ops) do
        local n = op.name
        local args = op.args or {}
        local evaluated_args = {}
        for i, arg_expr in ipairs(args) do
            evaluated_args[i] = eval_dsl_value(arg_expr, env_fn)
        end
        
        if n == "fill" then
            table.insert(paint, style.paint_fill(evaluated_args[1]))
        elseif n == "stroke" then
            table.insert(paint, style.paint_stroke(evaluated_args[1], evaluated_args[2]))
        elseif n == "rect" then
            table.insert(paint, style.paint_rect(evaluated_args[1], evaluated_args[2], evaluated_args[3], evaluated_args[4]))
        elseif n == "round_rect" then
            table.insert(paint, style.paint_round_rect(evaluated_args[1], evaluated_args[2], evaluated_args[3], evaluated_args[4], evaluated_args[5]))
        elseif n == "circle" then
            table.insert(paint, style.paint_circle(evaluated_args[1], evaluated_args[2], evaluated_args[3]))
        elseif n == "line" then
            table.insert(paint, style.paint_line(evaluated_args[1], evaluated_args[2], evaluated_args[3], evaluated_args[4]))
        end
    end
    
    return paint
end

local function apply_use_patches(node, env_fn)
    if not node.uses or #node.uses == 0 then return node end
    
    local resolved = deep_copy(node)
    
    for _, use_expr in ipairs(node.uses) do
        local patch = AST.EvalExpr(use_expr, env_fn)
        if patch then
            if patch.layout then
                resolved.layout = merge_into(resolved.layout, patch.layout)
            end
            if patch.shared then
                resolved.shared = merge_into(resolved.shared, patch.shared)
            end
            if patch.border then
                resolved.border = merge_into(resolved.border, patch.border)
            end
            if patch.textConfig then
                resolved.textConfig = merge_into(resolved.textConfig, patch.textConfig)
            end
            if patch.clip then
                resolved.clip = merge_into(resolved.clip, patch.clip)
            end
            if patch.aspect then
                resolved.aspect = merge_into(resolved.aspect, patch.aspect)
            end
            if patch.image then
                resolved.image = merge_into(resolved.image, patch.image)
            end
            if patch.custom then
                resolved.custom = merge_into(resolved.custom, patch.custom)
            end
            if patch.floating then
                resolved.floating = merge_into(resolved.floating, patch.floating)
            end
            if patch.paint then
                resolved.paint = resolved.paint or {}
                for _, op in ipairs(patch.paint) do
                    table.insert(resolved.paint, deep_copy(op))
                end
            end
        end
    end
    
    return resolved
end

local function resolve_node_ops(node, env_fn)
    local resolved = apply_use_patches(node, env_fn)
    
    resolved.layout = apply_layout_ops(resolved.layout, node.layout_ops, env_fn)
    resolved.shared = apply_style_ops(resolved.shared, node.style_ops, env_fn)
    resolved.textConfig = apply_typography_ops(resolved.textConfig, node.typography_ops, env_fn)
    resolved.paint = apply_paint_ops(resolved.paint, node.paint_ops, env_fn)
    
    if resolved.shared and resolved.shared.border then
        resolved.border = merge_into(resolved.border, resolved.shared.border)
        resolved.shared.border = nil
    end
    
    return resolved
end

local function merge_state_overlay(base_node, state_overlay, env_fn)
    local merged = deep_copy(base_node)
    
    local resolved_state = resolve_node_ops(state_overlay, env_fn)
    
    if resolved_state.shared then
        merged.shared = merge_into(merged.shared, resolved_state.shared)
    end
    if resolved_state.border then
        merged.border = merge_into(merged.border, resolved_state.border)
    end
    if resolved_state.textConfig then
        merged.textConfig = merge_into(merged.textConfig, resolved_state.textConfig)
    end
    if resolved_state.paint then
        merged.paint = merged.paint or {}
        for _, op in ipairs(resolved_state.paint) do
            table.insert(merged.paint, deep_copy(op))
        end
    end
    
    return merged
end

local function validate_runtime_states(node, dsl_node)
    if not node.states then return end
    
    local has_any_state = false
    for _ in pairs(node.states) do
        has_any_state = true
        break
    end
    if not has_any_state then return end
    
    for state_name, _ in pairs(node.states) do
        if runtime_states[state_name] == nil then
            error("argile: unknown state '" .. tostring(state_name) .. "'")
        end
    end
    
    local has_id = dsl_node and dsl_node.id_expr
    if not has_id then
        error("argile: state requires element to have an id")
    end
end

local function collect_present_runtime_states(node)
    local names = {}
    if not node.states then return names end
    for _, state_name in ipairs(runtime_state_order) do
        if node.states[state_name] ~= nil then
            names[#names + 1] = state_name
        end
    end
    return names
end

local function mask_has_bit(mask, bit)
    local span = bit * 2
    return (mask % span) >= bit
end

local function merge_states_for_mask(base_node, state_names, mask, env_fn)
    local merged = deep_copy(base_node)
    if mask == 0 then return merged end
    
    for i, state_name in ipairs(state_names) do
        local bit = 2 ^ (i - 1)
        if mask_has_bit(mask, bit) then
            merged = merge_state_overlay(merged, base_node.states[state_name], env_fn)
        end
    end
    return merged
end

local function state_condition_expr(state_name, elem_id_var)
    if state_name == "hover" then
        return `ui.PointerOver([elem_id_var])
    elseif state_name == "active" then
        return `ui.ElementActive([elem_id_var])
    elseif state_name == "focus" then
        return `ui.ElementFocused([elem_id_var])
    elseif state_name == "selected" then
        return `ui.ElementSelected([elem_id_var])
    elseif state_name == "disabled" then
        return `ui.ElementDisabled([elem_id_var])
    end
    error("argile: unsupported runtime state condition '" .. tostring(state_name) .. "'")
end

local function emit_state_mask_compute(mask_var, state_names, elem_id_var)
    local stmts = terralib.newlist()
    local zero_t = terralib.constant(uint8, 0)
    stmts:insert(quote var [mask_var] = [zero_t] end)
    
    for i, state_name in ipairs(state_names) do
        local bit_t = terralib.constant(uint8, 2 ^ (i - 1))
        local cond = state_condition_expr(state_name, elem_id_var)
        stmts:insert(quote
            if [cond] then
                [mask_var] = [mask_var] + [bit_t]
            end
        end)
    end
    return quote [stmts] end
end

local function emit_state_mask_dispatch(mask_var, combo_count, branch_builder)
    local stmts = terralib.newlist()
    local has_any = false
    
    for mask = 0, combo_count - 1 do
        local branch = branch_builder(mask)
        if branch and #branch > 0 then
            has_any = true
            local mask_t = terralib.constant(uint8, mask)
            stmts:insert(quote
                if [mask_var] == [mask_t] then
                    [branch]
                end
            end)
        end
    end
    
    if not has_any then return nil end
    return quote [stmts] end
end

local compile_dsl_node
local compile_dsl_invoke

local function compile_children(child_nodes, env_fn, registry, fills_by_slot, inherited_text_cfg)
    local child_stmts = terralib.newlist()
    
    for _, child in ipairs(child_nodes or {}) do
        if AST.IsKind(child, "NodeDecl") then
            child_stmts:insert(compile_dsl_node(child, env_fn, registry, fills_by_slot, inherited_text_cfg))
        elseif AST.IsKind(child, "ComponentInvoke") then
            child_stmts:insert(compile_dsl_invoke(child, env_fn, registry, fills_by_slot, inherited_text_cfg))
        elseif AST.IsKind(child, "Splice") then
            local spliced = child.expr_fn(env_fn)
            if spliced ~= nil then
                if terralib.isquote(spliced) then
                    child_stmts:insert(spliced)
                elseif type(spliced) == "table" and spliced[1] then
                    for _, s in ipairs(spliced) do
                        if terralib.isquote(s) then
                            child_stmts:insert(s)
                        end
                    end
                end
            end
        end
    end
    
    return child_stmts
end

local function is_text_node(dsl_node)
    return dsl_node._kind == "NodeDecl" and dsl_node.kind == "text"
end

local function node_has_any_states(states)
    if states == nil then return false end
    for _ in pairs(states) do
        return true
    end
    return false
end

-- `text(...)` is normally emitted as a leaf fast-path. If it has an id or any
-- non-typography body config/state, emit it as a regular element wrapper with a
-- text child so IDs/layout/style/state target the text node itself.
local function text_node_needs_wrapper(dsl_node, resolved)
    if not is_text_node(dsl_node) then return false end
    if dsl_node.id_expr ~= nil then return true end
    if resolved.layout ~= nil then return true end
    if resolved.shared ~= nil then return true end
    if resolved.border ~= nil then return true end
    if resolved.clip ~= nil then return true end
    if resolved.aspect ~= nil then return true end
    if resolved.image ~= nil then return true end
    if resolved.custom ~= nil then return true end
    if resolved.floating ~= nil then return true end
    if resolved.paint ~= nil and #resolved.paint > 0 then return true end
    if node_has_any_states(resolved.states) then return true end
    if dsl_node.slot_name ~= nil or dsl_node.has_children_marker then return true end
    if dsl_node.children ~= nil and #dsl_node.children > 0 then return true end
    return false
end

local function apply_layout_ops(base_layout, ops, env_fn)
    if not ops or #ops == 0 then return base_layout end
    
    local layout = base_layout and deep_copy(base_layout) or {}
    
    for _, op in ipairs(ops) do
        local n = op.name
        local args = op.args or {}
        local evaluated_args = {}
        for i, arg_expr in ipairs(args) do
            evaluated_args[i] = eval_dsl_value(arg_expr, env_fn)
        end
        
        if n == "width" then
            layout.widthType = ui.SIZING_FIXED
            layout.minWidth = evaluated_args[1] or 0
            layout.maxWidth = evaluated_args[1] or 0
        elseif n == "height" then
            layout.heightType = ui.SIZING_FIXED
            layout.minHeight = evaluated_args[1] or 0
            layout.maxHeight = evaluated_args[1] or 0
        elseif n == "sizing" then
            local mode = evaluated_args[1]
            if mode == "fit" then
                layout.widthType = ui.SIZING_FIT
                layout.heightType = ui.SIZING_FIT
            elseif mode == "fixed" then
                layout.widthType = ui.SIZING_FIXED
                layout.heightType = ui.SIZING_FIXED
            elseif mode == "percent" then
                layout.widthType = ui.SIZING_PERCENT
                layout.heightType = ui.SIZING_PERCENT
            elseif mode == "grow" then
                layout.widthType = ui.SIZING_GROW
                layout.heightType = ui.SIZING_GROW
            end
        elseif n == "min_width" then
            layout.minWidth = evaluated_args[1]
        elseif n == "min_height" then
            layout.minHeight = evaluated_args[1]
        elseif n == "max_width" then
            layout.maxWidth = evaluated_args[1]
        elseif n == "max_height" then
            layout.maxHeight = evaluated_args[1]
        elseif n == "percent_width" then
            layout.widthPercent = evaluated_args[1]
            layout.widthType = ui.SIZING_PERCENT
        elseif n == "percent_height" then
            layout.heightPercent = evaluated_args[1]
            layout.heightType = ui.SIZING_PERCENT
        elseif n == "padding" then
            local v = evaluated_args[1] or 0
            layout.paddingLeft = v
            layout.paddingRight = v
            layout.paddingTop = v
            layout.paddingBottom = v
        elseif n == "padding4" then
            layout.paddingLeft = evaluated_args[1] or 0
            layout.paddingRight = evaluated_args[2] or 0
            layout.paddingTop = evaluated_args[3] or 0
            layout.paddingBottom = evaluated_args[4] or 0
        elseif n == "padding_x" then
            layout.paddingLeft = evaluated_args[1]
            layout.paddingRight = evaluated_args[1]
        elseif n == "padding_y" then
            layout.paddingTop = evaluated_args[1]
            layout.paddingBottom = evaluated_args[1]
        elseif n == "gap" then
            layout.childGap = evaluated_args[1]
        elseif n == "width_grow" then
            layout.widthType = ui.SIZING_GROW
        elseif n == "width_fit" then
            layout.widthType = ui.SIZING_FIT
        elseif n == "width_fixed" then
            layout.widthType = ui.SIZING_FIXED
            layout.minWidth = evaluated_args[1] or 0
            layout.maxWidth = evaluated_args[1] or 0
        elseif n == "width_percent" then
            layout.widthType = ui.SIZING_PERCENT
            layout.widthPercent = evaluated_args[1] or 0
        elseif n == "height_grow" then
            layout.heightType = ui.SIZING_GROW
        elseif n == "height_fit" then
            layout.heightType = ui.SIZING_FIT
        elseif n == "height_fixed" then
            layout.heightType = ui.SIZING_FIXED
            layout.minHeight = evaluated_args[1] or 0
            layout.maxHeight = evaluated_args[1] or 0
        elseif n == "height_percent" then
            layout.heightType = ui.SIZING_PERCENT
            layout.heightPercent = evaluated_args[1] or 0
        elseif n == "align_x" then
            layout.alignX = align_x_values[evaluated_args[1]] or evaluated_args[1]
        elseif n == "align_y" then
            layout.alignY = align_y_values[evaluated_args[1]] or evaluated_args[1]
        elseif n == "dir" or n == "direction" then
            layout.layoutDir = layout_dir_values[evaluated_args[1]] or evaluated_args[1]
        end
    end
    
    return layout
end

compile_dsl_node = function(dsl_node, env_fn, registry, fills_by_slot, inherited_text_cfg)
    local resolved = resolve_node_ops(dsl_node, env_fn, registry)
    validate_runtime_states(resolved, dsl_node)
    if inherited_text_cfg ~= nil then
        resolved.textConfig = merge_into(inherited_text_cfg, resolved.textConfig)
    end
    
    local stmts = terralib.newlist()
    
    local source_is_text = is_text_node(dsl_node)
    local is_text = source_is_text and not text_node_needs_wrapper(dsl_node, resolved)
    
    local runtime_state_names = collect_present_runtime_states(resolved)
    local state_mask_var = nil
    local state_combos = nil
    local state_combo_count = 0
    
    local elem_id_var = nil
    local id_value = dsl_node.id_expr and AST.EvalExpr(dsl_node.id_expr, env_fn) or nil
    
    local function emit_id_init()
        if id_value == nil then
            return
        end

        if type(id_value) == "string" then
            elem_id_var = symbol(ui.ElementId, "elem_id")
            stmts:insert(quote
                var id_str = ui.String {
                    isStaticallyAllocated = true,
                    length = [#id_value],
                    chars = [id_value]
                }
                var [elem_id_var] = ui.GetElementId(id_str)
            end)
            return
        end

        if type(id_value) == "number" then
            elem_id_var = symbol(ui.ElementId, "elem_id")
            stmts:insert(quote
                var [elem_id_var] = ui.HashNumber([id_value], 0)
            end)
            return
        end

        local t = terra_value_type(id_value)
        if t ~= nil then
            elem_id_var = symbol(ui.ElementId, "elem_id")

            if t:isintegral() then
                stmts:insert(quote
                    var [elem_id_var] = ui.HashNumber([id_value], 0)
                end)
            elseif t == rawstring or t == &int8 then
                local C = terralib.includec("string.h")
                stmts:insert(quote
                    var str_val = [id_value]
                    var id_str = ui.String {
                        isStaticallyAllocated = false,
                        length = C.strlen(str_val),
                        chars = str_val
                    }
                    var [elem_id_var] = ui.GetElementId(id_str)
                end)
            elseif t == ui.ElementId then
                stmts:insert(quote
                    var [elem_id_var] = [id_value]
                end)
            else
                error("argile: Unsupported dynamic ID type: " .. tostring(t))
            end
            return
        end
    end

    emit_id_init()
    
    local has_runtime_state_overlays = #runtime_state_names > 0 and (elem_id_var ~= nil)

    if has_runtime_state_overlays then
        state_combos = {}
        state_combo_count = 2 ^ #runtime_state_names

        for mask = 0, state_combo_count - 1 do
            local merged = merge_states_for_mask(resolved, runtime_state_names, mask, env_fn)
            state_combos[mask] = {
                shared_cfg = merged.shared and compileSharedConfig(merged.shared) or nil,
                border_cfg = merged.border and compileBorderConfig(merged.border) or nil,
                paint_cfg = merged.paint and compilePaintConfig(merged.paint) or nil,
                text_config = merged.textConfig,
            }
        end

        state_mask_var = symbol(uint8, "state_mask")
        stmts:insert(emit_state_mask_compute(state_mask_var, runtime_state_names, elem_id_var))
    end

    local function emit_open_with_desc(shared_cfg, border_cfg, paint_cfg)
        local open_stmts = terralib.newlist()
        local desc_var = symbol(ui.ElementDesc, "elem_desc")

        open_stmts:insert(quote
            var [desc_var]
            [desc_var].flags = 0
        end)

        if resolved.layout then
            open_stmts:insert(quote
                [desc_var].layout = [compileLayoutConfig(resolved.layout)]
                [desc_var].flags = [desc_var].flags or ui.DESC_HAS_LAYOUT
            end)
        end
        if shared_cfg then
            open_stmts:insert(quote
                [desc_var].shared = [shared_cfg]
                [desc_var].flags = [desc_var].flags or ui.DESC_HAS_SHARED
            end)
        end
        if border_cfg then
            open_stmts:insert(quote
                [desc_var].border = [border_cfg]
                [desc_var].flags = [desc_var].flags or ui.DESC_HAS_BORDER
            end)
        end
        if resolved.clip then
            open_stmts:insert(quote
                [desc_var].clip = [compileClipConfig(resolved.clip)]
                [desc_var].flags = [desc_var].flags or ui.DESC_HAS_CLIP
            end)
        end
        if resolved.aspect then
            open_stmts:insert(quote
                [desc_var].aspect = [compileAspectConfig(resolved.aspect)]
                [desc_var].flags = [desc_var].flags or ui.DESC_HAS_ASPECT
            end)
        end
        if resolved.image then
            open_stmts:insert(quote
                [desc_var].image = [compileImageConfig(resolved.image)]
                [desc_var].flags = [desc_var].flags or ui.DESC_HAS_IMAGE
            end)
        end
        if resolved.custom then
            open_stmts:insert(quote
                [desc_var].custom = [compileCustomConfig(resolved.custom)]
                [desc_var].flags = [desc_var].flags or ui.DESC_HAS_CUSTOM
            end)
        end
        if resolved.floating then
            open_stmts:insert(quote
                [desc_var].floating = [compileFloatingConfig(resolved.floating)]
                [desc_var].flags = [desc_var].flags or ui.DESC_HAS_FLOATING
            end)
        end
        if paint_cfg then
            open_stmts:insert(quote
                [desc_var].paint = [paint_cfg]
                [desc_var].flags = [desc_var].flags or ui.DESC_HAS_PAINT
            end)
        end

        if elem_id_var then
            open_stmts:insert(quote ui.OpenElementWithIdAndDesc([elem_id_var], &[desc_var]) end)
        else
            open_stmts:insert(quote ui.OpenElementWithDesc(&[desc_var]) end)
        end
        return quote [open_stmts] end
    end

    if not is_text then
        if has_runtime_state_overlays then
            local open_dispatch = emit_state_mask_dispatch(state_mask_var, state_combo_count, function(mask)
                local combo = state_combos[mask]
                local branch = terralib.newlist()
                branch:insert(emit_open_with_desc(combo.shared_cfg, combo.border_cfg, combo.paint_cfg))
                return branch
            end)
            if open_dispatch then stmts:insert(open_dispatch) end
        else
            local shared_cfg = resolved.shared and compileSharedConfig(resolved.shared) or nil
            local border_cfg = resolved.border and compileBorderConfig(resolved.border) or nil
            local paint_cfg = resolved.paint and compilePaintConfig(resolved.paint) or nil
            stmts:insert(emit_open_with_desc(shared_cfg, border_cfg, paint_cfg))
        end
    end
    
    local text_value = dsl_node.text_expr and AST.EvalExpr(dsl_node.text_expr, env_fn) or nil
    if text_value then
        local textConfig = resolved.textConfig
        
        if type(text_value) == "string" then
            if has_runtime_state_overlays then
                local text_dispatch = emit_state_mask_dispatch(state_mask_var, state_combo_count, function(mask)
                    local combo = state_combos[mask]
                    local branch = terralib.newlist()
                    if combo.text_config then
                        if elem_id_var then
                            branch:insert(quote
                                var txt_cfg = [compileTextConfig(combo.text_config)]
                                var txt_cfg_ptr = ui.GetCurrentContext():storeTextConfig(txt_cfg)
                                ui.OpenTextElementWithLengthAndId([elem_id_var], [text_value], [#text_value], txt_cfg_ptr)
                            end)
                        else
                            branch:insert(quote
                                var txt_cfg = [compileTextConfig(combo.text_config)]
                                var txt_cfg_ptr = ui.GetCurrentContext():storeTextConfig(txt_cfg)
                                ui.OpenTextElementWithLength([text_value], [#text_value], txt_cfg_ptr)
                            end)
                        end
                    else
                        if elem_id_var then
                            branch:insert(quote
                                ui.OpenTextElementWithLengthAndId([elem_id_var], [text_value], [#text_value], nil)
                            end)
                        else
                            branch:insert(quote
                                ui.OpenTextElementWithLength([text_value], [#text_value], nil)
                            end)
                        end
                    end
                    return branch
                end)
                if text_dispatch then stmts:insert(text_dispatch) end
            else
                if textConfig then
                    if elem_id_var then
                        stmts:insert(quote
                            var txt_cfg = [compileTextConfig(textConfig)]
                            var txt_cfg_ptr = ui.GetCurrentContext():storeTextConfig(txt_cfg)
                            ui.OpenTextElementWithLengthAndId([elem_id_var], [text_value], [#text_value], txt_cfg_ptr)
                        end)
                    else
                        stmts:insert(quote
                            var txt_cfg = [compileTextConfig(textConfig)]
                            var txt_cfg_ptr = ui.GetCurrentContext():storeTextConfig(txt_cfg)
                            ui.OpenTextElementWithLength([text_value], [#text_value], txt_cfg_ptr)
                        end)
                    end
                else
                    if elem_id_var then
                        stmts:insert(quote
                            ui.OpenTextElementWithLengthAndId([elem_id_var], [text_value], [#text_value], nil)
                        end)
                    else
                        stmts:insert(quote
                            ui.OpenTextElementWithLength([text_value], [#text_value], nil)
                        end)
                    end
                end
            end
        else
            local C = terralib.includec("string.h")
            if textConfig then
                if elem_id_var then
                    stmts:insert(quote
                        var txt_cfg = [compileTextConfig(textConfig)]
                        var txt_cfg_ptr = ui.GetCurrentContext():storeTextConfig(txt_cfg)
                        var runtime_str : rawstring = [text_value]
                        var runtime_len = C.strlen(runtime_str)
                        ui.OpenTextElementWithLengthAndId([elem_id_var], runtime_str, runtime_len, txt_cfg_ptr)
                    end)
                else
                    stmts:insert(quote
                        var txt_cfg = [compileTextConfig(textConfig)]
                        var txt_cfg_ptr = ui.GetCurrentContext():storeTextConfig(txt_cfg)
                        var runtime_str : rawstring = [text_value]
                        var runtime_len = C.strlen(runtime_str)
                        ui.OpenTextElementWithLength(runtime_str, runtime_len, txt_cfg_ptr)
                    end)
                end
            else
                if elem_id_var then
                    stmts:insert(quote
                        var runtime_str : rawstring = [text_value]
                        var runtime_len = C.strlen(runtime_str)
                        ui.OpenTextElementWithLengthAndId([elem_id_var], runtime_str, runtime_len, nil)
                    end)
                else
                    stmts:insert(quote
                        var runtime_str : rawstring = [text_value]
                        var runtime_len = C.strlen(runtime_str)
                        ui.OpenTextElementWithLength(runtime_str, runtime_len, nil)
                    end)
                end
            end
        end
    end
    
    local children_to_compile = dsl_node.children
    
    if dsl_node.slot_name and fills_by_slot then
        local fills = fills_by_slot[dsl_node.slot_name]
        if fills and #fills > 0 then
            children_to_compile = {}
            for _, fill in ipairs(fills) do
                for _, child in ipairs(fill.children) do
                    table.insert(children_to_compile, child)
                end
            end
        end
    end
    
    local child_stmts = compile_children(children_to_compile, env_fn, registry, fills_by_slot, resolved.textConfig)
    for _, stmt in ipairs(child_stmts) do
        stmts:insert(stmt)
    end
    
    if not is_text then
        stmts:insert(quote ui.CloseElement() end)
    end
    
    return quote [stmts] end
end

local function resolve_component_decl(invoke, env_fn, registry)
    local component = registry.components[invoke.name]
    if component then return component end
    
    local env = env_fn and env_fn() or nil
    local handle = env and env[invoke.name] or nil
    if type(handle) == "table" and handle._argile_dsl_kind == "component" and handle.decl then
        return handle.decl
    end
    
    Span.Raise(invoke._span, "unknown component: " .. invoke.name)
end

local function validate_invoke_args(invoke, component, env_fn)
    local declared_variants = {}
    for _, variant in pairs(component.variants) do
        declared_variants[variant.name] = variant.values
    end
    
    local seen_args = {}
    
    for arg_name, arg_expr in pairs(invoke.args) do
        if seen_args[arg_name] then
            Span.Raise(invoke._span, "duplicate argument: " .. arg_name)
        end
        seen_args[arg_name] = true
        
        if declared_variants[arg_name] then
            local raw = AST.EvalExpr(arg_expr, env_fn)
            local value = resolve_symbol(raw, true, env_fn)
            local valid = false
            for _, valid_value in ipairs(declared_variants[arg_name]) do
                if value == valid_value then
                    valid = true
                    break
                end
            end
            if not valid then
                Span.Raise(invoke._span,
                    "invalid variant value '" .. tostring(value) .. "' for '" .. arg_name .. "'. " ..
                    "Expected one of: " .. table.concat(declared_variants[arg_name], " | "))
            end
        end
    end
end

local function build_component_env_fn(component, invoke, parent_env_fn)
    local declared_variants = {}
    for _, variant in pairs(component.variants) do
        declared_variants[variant.name] = true
    end
    
    local props = {}
    for arg_name, arg_expr in pairs(invoke.args) do
        local raw = AST.EvalExpr(arg_expr, parent_env_fn)
        props[arg_name] = resolve_symbol(raw, declared_variants[arg_name], parent_env_fn)
    end
    
    return function()
        local base = parent_env_fn()
        local env = {}
        if type(base) == "table" then
            for k, v in pairs(base) do
                env[k] = v
            end
        end
        
        if type(component._argile_dsl_decl_env) == "table" then
            for k, v in pairs(component._argile_dsl_decl_env) do
                env[k] = v
            end
        end
        
        if #component.params == 1 then
            env[component.params[1]] = props
        elseif #component.params > 1 then
            for _, param_name in ipairs(component.params) do
                env[param_name] = props[param_name]
            end
        end
        
        return env
    end
end

local function group_fills_by_slot(fills)
    local grouped = {}
    for _, fill in ipairs(fills or {}) do
        if not grouped[fill.slot_name] then
            grouped[fill.slot_name] = {}
        end
        table.insert(grouped[fill.slot_name], fill)
    end
    return grouped
end

local function find_slot_names(component)
    local slots = {}
    
    local function visit(node)
        if not AST.IsKind(node, "NodeDecl") then return end
        
        if node.slot_name then
            slots[node.slot_name] = true
        end
        
        for _, child in ipairs(node.children or {}) do
            visit(child)
        end
    end
    
    visit(component.root)
    return slots
end

local function find_children_marker(node)
    if not AST.IsKind(node, "NodeDecl") then return nil end
    
    if node.has_children_marker then return node end
    
    for _, child in ipairs(node.children or {}) do
        local found = find_children_marker(child)
        if found then return found end
    end
    
    return nil
end

compile_dsl_invoke = function(invoke, env_fn, registry, parent_fills, inherited_text_cfg)
    local component = resolve_component_decl(invoke, env_fn, registry)
    validate_invoke_args(invoke, component, env_fn)
    
    local component_env_fn = build_component_env_fn(component, invoke, env_fn)
    
    local fills_by_slot = group_fills_by_slot(invoke.fills)
    
    local declared_slots = find_slot_names(component)
    for slot_name, _ in pairs(fills_by_slot) do
        if not declared_slots[slot_name] then
            Span.Raise(invoke._span,
                "fill targeting unknown slot '" .. slot_name .. "' in component '" .. tostring(component.name) .. "'")
        end
    end
    
    local root = component.root
    local marker = find_children_marker(root)
    
    if not marker and #invoke.body_nodes > 0 then
        Span.Raise(invoke._span,
            "invocation has content but component '" .. tostring(component.name) .. "' has no children marker")
    end
    
    local effective_children = {}
    if marker then
        local marker_idx = nil
        for i, child in ipairs(root.children) do
            if AST.IsKind(child, "NodeDecl") and child.has_children_marker then
                marker_idx = i
                break
            end
        end
        
        if marker_idx then
            for i = 1, marker_idx - 1 do
                table.insert(effective_children, root.children[i])
            end
            for _, body_node in ipairs(invoke.body_nodes) do
                table.insert(effective_children, body_node)
            end
            for i = marker_idx + 1, #root.children do
                table.insert(effective_children, root.children[i])
            end
        else
            for _, body_node in ipairs(invoke.body_nodes) do
                table.insert(effective_children, body_node)
            end
        end
    else
        effective_children = root.children
    end
    
    local effective_root = deep_copy(root)
    effective_root.children = effective_children
    effective_root.has_children_marker = false
    
    if invoke.id_expr then
        effective_root.id_expr = invoke.id_expr
    end
    
    return compile_dsl_node(effective_root, component_env_fn, registry, fills_by_slot, inherited_text_cfg)
end

function M.compileAstBody(body_nodes, env_fn, registry)
    local stmts = terralib.newlist()
    
    for _, node in ipairs(body_nodes) do
        if AST.IsKind(node, "NodeDecl") then
            stmts:insert(compile_dsl_node(node, env_fn, registry, nil, nil))
        elseif AST.IsKind(node, "ComponentInvoke") then
            stmts:insert(compile_dsl_invoke(node, env_fn, registry, nil, nil))
        elseif AST.IsKind(node, "Splice") then
            local spliced = node.expr_fn(env_fn)
            if spliced ~= nil then
                if terralib.isquote(spliced) then
                    stmts:insert(spliced)
                elseif type(spliced) == "table" and spliced[1] then
                    for _, s in ipairs(spliced) do
                        if terralib.isquote(s) then
                            stmts:insert(s)
                        end
                    end
                end
            end
        else
            error("Unknown DSL node type: " .. tostring(node._kind))
        end
    end
    
    return quote [stmts] end
end

local function clone_registry(registry)
    local out = DslRegistry.Create()
    if not registry then
        return out
    end
    for k, v in pairs(registry.components or {}) do
        out.components[k] = v
    end
    for k, v in pairs(registry.themes or {}) do
        out.themes[k] = v
    end
    return out
end

function M.compileAstProgram(program, env_fn, registry)
    if not AST.IsKind(program, "Program") then
        error("argile: compileAstProgram expects AST.Program")
    end

    local compile_registry = clone_registry(registry)

    local base_env = env_fn and env_fn() or nil
    local decl_scope = {}

    local function merged_decl_env()
        if base_env == nil and next(decl_scope) == nil then
            return {}
        end
        local env = {}
        if type(base_env) == "table" then
            for k, v in pairs(base_env) do
                env[k] = v
            end
        end
        for k, v in pairs(decl_scope) do
            env[k] = v
        end
        return env
    end

    for _, decl in ipairs(program.decls or {}) do
        if AST.IsKind(decl, "ThemeDecl") then
            compile_registry.themes[decl.name] = decl
            decl_scope[decl.name] = DslRegistry.BuildThemeValue(decl, merged_decl_env())
        elseif AST.IsKind(decl, "ComponentDecl") then
            compile_registry.components[decl.name] = decl
            decl_scope[decl.name] = DslRegistry.BuildComponentHandle(decl, merged_decl_env())
        else
            error("argile: unsupported top-level decl in AST.Program: " .. tostring(AST.GetKind(decl)))
        end
    end

    local function program_env_fn()
        return merged_decl_env()
    end

    return M.compileAstBody(program.body_nodes or {}, program_env_fn, compile_registry)
end

function M.compileAstProgramFunction(name, program, env_fn, registry)
    local body = M.compileAstProgram(program, env_fn, registry)

    local fn = terra()
        [body]
    end
    fn:setinlined(false)

    _G[name] = fn
    return fn
end

function M.compileAstProgramRenderFunction(name, program, env_fn, registry)
    local body = M.compileAstProgram(program, env_fn, registry)

    local RenderCommandArray = ui.Array(ui.RenderCommand)

    local fn = terra() : &RenderCommandArray
        ui.BeginLayout(1920.0, 1080.0)
        [body]
        return ui.EndLayout()
    end
    fn:setinlined(false)

    _G[name] = fn
    return fn
end

function M.compileAstFunction(name, body_nodes, env_fn, registry)
    local body = M.compileAstBody(body_nodes, env_fn, registry)
    
    local fn = terra()
        [body]
    end
    fn:setinlined(false)
    
    _G[name] = fn
    
    return fn
end

function M.compileAstRenderFunction(name, body_nodes, env_fn, registry)
    local body = M.compileAstBody(body_nodes, env_fn, registry)
    
    local RenderCommandArray = ui.Array(ui.RenderCommand)
    
    local fn = terra() : &RenderCommandArray
        ui.BeginLayout(1920.0, 1080.0)
        [body]
        return ui.EndLayout()
    end
    fn:setinlined(false)
    
    _G[name] = fn
    
    return fn
end

return M
