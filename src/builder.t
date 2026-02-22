local ui = require("src.init")
local style = require("src/style/core")

local function value_or(v, default)
    if v == nil then
        return default
    end
    return v
end

local function is_table(v)
    return type(v) == "table"
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
    local r = bg and value_or(bg.r, 0.0) or 0.0
    local g = bg and value_or(bg.g, 0.0) or 0.0
    local b = bg and value_or(bg.b, 0.0) or 0.0
    -- SharedConfig is also used for corner radius / user data. If no explicit
    -- background color is provided, default to transparent to avoid painting a
    -- visible rectangle as a side effect.
    local a = bg and value_or(bg.a, 1.0) or 0.0
    local tl = cfg.cornerRadius and cfg.cornerRadius.topLeft or 0.0
    local tr = cfg.cornerRadius and cfg.cornerRadius.topRight or 0.0
    local bl = cfg.cornerRadius and cfg.cornerRadius.bottomLeft or 0.0
    local br = cfg.cornerRadius and cfg.cornerRadius.bottomRight or 0.0

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
    if uniformWidth == nil then
        uniformWidth = 0
    end

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

local function compileTextConfig(cfg)
    local textColor = cfg.textColor or cfg.color or {}
    local userData = cfg.userData

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
    
    if #paint_ops > 16 then
        error("paint: maximum 16 ops supported per element")
    end
    
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
        local color = op.color or { r = 0, g = 0, b = 0, a = 1 }
        local kind_value = op.kind
        if type(kind_value) == "string" then
            kind_value = kind_map[kind_value]
        end
        if kind_value == nil then
            kind_value = ui.PAINT_OP_FILL
        end
        local kind_t = terralib.constant(uint8, kind_value)
        local color_r = terralib.constant(float, value_or(color.r, 0.0))
        local color_g = terralib.constant(float, value_or(color.g, 0.0))
        local color_b = terralib.constant(float, value_or(color.b, 0.0))
        local color_a = terralib.constant(float, value_or(color.a, 1.0))
        local x = terralib.constant(float, value_or(op.x, value_or(op.x1, value_or(op.cx, 0.0))))
        local y = terralib.constant(float, value_or(op.y, value_or(op.y1, value_or(op.cy, 0.0))))
        local w = terralib.constant(float, value_or(op.w, 0.0))
        local h = terralib.constant(float, value_or(op.h, 0.0))
        local r = terralib.constant(float, value_or(op.r, 0.0))
        local x2 = terralib.constant(float, value_or(op.x2, 0.0))
        local y2 = terralib.constant(float, value_or(op.y2, 0.0))
        local width = terralib.constant(uint16, value_or(op.width, 1))
        
        op_init_list:insert(`(ui.PaintOp {
            kind = [kind_t],
            color = ui.Color { r = [color_r], g = [color_g], b = [color_b], a = [color_a] },
            x = [x], y = [y], w = [w], h = [h], r = [r],
            x2 = [x2], y2 = [y2], width = [width]
        }))
    end
    
    local ops_array = `arrayof(ui.PaintOp, [op_init_list])
    
    return quote
        var ops = [ops_array]
        var cfg : ui.PaintConfig
        cfg.ops = ops
        cfg.count = [count_t]
        ui.AttachPaintConfig(cfg)
    end
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

local function merge_state_overlay(base_node, state_node)
    local merged = deep_copy(base_node)
    
    if state_node.shared then
        merged.shared = merge_into(merged.shared, state_node.shared)
    end
    if state_node.border then
        merged.border = merge_into(merged.border, state_node.border)
    end
    if state_node.textConfig then
        merged.textConfig = merge_into(merged.textConfig, state_node.textConfig)
    end
    if state_node.paint then
        merged.paint = merged.paint or {}
        for _, op in ipairs(state_node.paint) do
            table.insert(merged.paint, deep_copy(op))
        end
    end
    
    return merged
end

local function validate_runtime_states(node)
    if not node.states then return end
    
    for state_name, state_node in pairs(node.states) do
        if runtime_states[state_name] == nil then
            error("argile: unknown state '" .. tostring(state_name) .. "'")
        end
        if not node.id then
            error("argile: state '" .. state_name .. "' requires element to have an id")
        end
        if type(node.id) ~= "string" then
            error("argile: state '" .. state_name .. "' currently requires a string id")
        end
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

local function merge_states_for_mask(base_node, state_names, mask)
    local merged = deep_copy(base_node)
    if mask == 0 then
        return merged
    end
    for i, state_name in ipairs(state_names) do
        local bit = 2 ^ (i - 1)
        if mask_has_bit(mask, bit) then
            merged = merge_state_overlay(merged, base_node.states[state_name])
        end
    end
    return merged
end

local function build_state_combo_table(node, state_names)
    local combo_count = 2 ^ #state_names
    local combos = {}
    for mask = 0, combo_count - 1 do
        local merged = merge_states_for_mask(node, state_names, mask)
        combos[mask] = {
            node = merged,
            shared_cfg = merged.shared and compileSharedConfig(merged.shared) or nil,
            border_cfg = merged.border and compileBorderConfig(merged.border) or nil,
            paint_stmt = merged.paint and compilePaintConfig(merged.paint) or nil,
            text_cfg_expr = merged.textConfig and compileTextConfig(merged.textConfig) or nil,
        }
    end
    return combos, combo_count
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
    stmts:insert(quote
        var [mask_var] = [zero_t]
    end)
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
    if not has_any then
        return nil
    end
    return quote [stmts] end
end

function ui.compile(node)
    validate_runtime_states(node)
    
    local stmts = terralib.newlist()

    local runtime_state_names = collect_present_runtime_states(node)
    local has_runtime_state_overlays = #runtime_state_names > 0 and node.id and type(node.id) == "string"
    local state_mask_var = nil
    local state_combos = nil
    local state_combo_count = 0
    
    local elem_id_var = nil
    if node.id then
        if type(node.id) == "string" then
            elem_id_var = symbol(ui.ElementId, "elem_id")
            stmts:insert(quote
                var id_str = ui.String {
                    isStaticallyAllocated = true,
                    length = [#node.id],
                    chars = [node.id]
                }
                var [elem_id_var] = ui.GetElementId(id_str)
                ui.OpenElementWithId([elem_id_var])
            end)
        else
            stmts:insert(quote ui.OpenElement() end)
        end
    else
        stmts:insert(quote ui.OpenElement() end)
    end
    
    if node.layout then
        stmts:insert(quote ui.SetOpenElementLayoutConfig([compileLayoutConfig(node.layout)]) end)
    end

    if has_runtime_state_overlays then
        state_combos, state_combo_count = build_state_combo_table(node, runtime_state_names)
        state_mask_var = symbol(uint8, "state_mask")
        stmts:insert(emit_state_mask_compute(state_mask_var, runtime_state_names, elem_id_var))

        local visual_dispatch = emit_state_mask_dispatch(state_mask_var, state_combo_count, function(mask)
            local combo = state_combos[mask]
            local branch = terralib.newlist()
            if combo.shared_cfg then
                branch:insert(quote ui.AttachSharedConfig([combo.shared_cfg]) end)
            end
            if combo.border_cfg then
                branch:insert(quote ui.AttachBorderConfig([combo.border_cfg]) end)
            end
            return branch
        end)
        if visual_dispatch then
            stmts:insert(visual_dispatch)
        end
    else
        if node.shared then
            stmts:insert(quote ui.AttachSharedConfig([compileSharedConfig(node.shared)]) end)
        end
        if node.border then
            stmts:insert(quote ui.AttachBorderConfig([compileBorderConfig(node.border)]) end)
        end
    end

    if node.clip then
        stmts:insert(quote ui.AttachClipConfig([compileClipConfig(node.clip)]) end)
    end

    if node.aspect then
        stmts:insert(quote ui.AttachAspectRatioConfig([compileAspectConfig(node.aspect)]) end)
    end

    if node.image then
        stmts:insert(quote ui.AttachImageConfig([compileImageConfig(node.image)]) end)
    end

    if node.custom then
        stmts:insert(quote ui.AttachCustomConfig([compileCustomConfig(node.custom)]) end)
    end

    if node.floating then
        stmts:insert(quote ui.AttachFloatingConfig([compileFloatingConfig(node.floating)]) end)
    end

    if has_runtime_state_overlays then
        local paint_dispatch = emit_state_mask_dispatch(state_mask_var, state_combo_count, function(mask)
            local combo = state_combos[mask]
            local branch = terralib.newlist()
            if combo.paint_stmt then
                branch:insert(combo.paint_stmt)
            end
            return branch
        end)
        if paint_dispatch then
            stmts:insert(paint_dispatch)
        end
    elseif node.paint then
        local paint_stmts = compilePaintConfig(node.paint)
        if paint_stmts then
            stmts:insert(paint_stmts)
        end
    end

    if node.text then
        local textStr = node.text
        if type(textStr) ~= "string" then
            textStr = tostring(textStr)
        end

        if has_runtime_state_overlays then
            local text_dispatch = emit_state_mask_dispatch(state_mask_var, state_combo_count, function(mask)
                local combo = state_combos[mask]
                local branch = terralib.newlist()
                if combo.text_cfg_expr then
                    branch:insert(quote
                        var txt_cfg = [combo.text_cfg_expr]
                        var txt_cfg_ptr = ui.GetCurrentContext():storeTextConfig(txt_cfg)
                        ui.OpenTextElementWithLength([textStr], [#textStr], txt_cfg_ptr)
                    end)
                else
                    branch:insert(quote
                        ui.OpenTextElementWithLength([textStr], [#textStr], nil)
                    end)
                end
                return branch
            end)
            if text_dispatch then
                stmts:insert(text_dispatch)
            end
        else
            local textConfig = node.textConfig
            if textConfig then
                stmts:insert(quote
                    var txt_cfg = [compileTextConfig(textConfig)]
                    var txt_cfg_ptr = ui.GetCurrentContext():storeTextConfig(txt_cfg)
                    ui.OpenTextElementWithLength([textStr], [#textStr], txt_cfg_ptr)
                end)
            else
                stmts:insert(quote
                    ui.OpenTextElementWithLength([textStr], [#textStr], nil)
                end)
            end
        end
    end

    if node.children then
        for _, child in ipairs(node.children) do
            stmts:insert(ui.compile(child))
        end
    end
    
    stmts:insert(quote ui.CloseElement() end)
    
    return quote [stmts] end
end

-- Generate an exported function that can be called via FFI
function ui.compileFunction(name, node)
    local body = ui.compile(node)
    
    local fn = terra()
        [body]
    end
    fn:setinlined(false)
    
    -- Make it available globally for export
    _G[name] = fn
    
    return fn
end

-- Generate a render function that returns RenderCommandArray via FFI
function ui.compileRenderFunction(name, layoutNode)
    local body = ui.compile(layoutNode)
    
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

function ui.resolve_node(node)
    if not node then return {} end
    
    local resolved = {}
    
    resolved.id = node.id
    resolved.text = node.text
    
    resolved.layout = deep_copy(node.layout)
    resolved.shared = deep_copy(node.shared)
    resolved.border = deep_copy(node.border)
    resolved.textConfig = deep_copy(node.textConfig)
    resolved.clip = deep_copy(node.clip)
    resolved.aspect = deep_copy(node.aspect)
    resolved.image = deep_copy(node.image)
    resolved.custom = deep_copy(node.custom)
    resolved.floating = deep_copy(node.floating)
    resolved.paint = deep_copy(node.paint)
    
    if node.use_patches then
        for _, patch in ipairs(node.use_patches) do
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
    
    if node.style_ops then
        for _, op in ipairs(node.style_ops) do
            local n = op.name
            local args = op.args or {}
            
            if n == "bg" then
                resolved.shared = resolved.shared or {}
                resolved.shared.backgroundColor = args[1]
            elseif n == "radius" then
                resolved.shared = resolved.shared or {}
                resolved.shared.cornerRadius = style.corner_radius(args[1])
            elseif n == "radius4" then
                resolved.shared = resolved.shared or {}
                resolved.shared.cornerRadius = style.corner_radius(args[1], args[2], args[3], args[4])
            elseif n == "border_width" then
                resolved.border = resolved.border or {}
                resolved.border.width = style.border_width(args[1])
            elseif n == "border_width4" then
                resolved.border = resolved.border or {}
                resolved.border.width = style.border_width(args[1], args[2], args[3], args[4])
            elseif n == "border_between_children" then
                resolved.border = resolved.border or {}
                resolved.border.width = resolved.border.width or style.border_width(0)
                resolved.border.width.betweenChildren = args[1] or 0
            elseif n == "border_color" then
                resolved.border = resolved.border or {}
                resolved.border.color = args[1]
            elseif n == "user_data" then
                resolved.shared = resolved.shared or {}
                resolved.shared.userData = args[1]
            else
                error("argile style: unknown operation '" .. tostring(n) .. "'")
            end
        end
    end
    
    if node.typography_ops then
        resolved.textConfig = resolved.textConfig or {}
        for _, op in ipairs(node.typography_ops) do
            local n = op.name
            local args = op.args or {}
            
            if n == "color" then
                resolved.textConfig.textColor = args[1]
            elseif n == "font_id" then
                resolved.textConfig.fontId = args[1]
            elseif n == "font_size" then
                resolved.textConfig.fontSize = args[1]
            elseif n == "letter_spacing" then
                resolved.textConfig.letterSpacing = args[1]
            elseif n == "line_height" then
                resolved.textConfig.lineHeight = args[1]
            elseif n == "wrap" then
                resolved.textConfig.wrapMode = args[1]
            elseif n == "align" then
                resolved.textConfig.textAlignment = args[1]
            elseif n == "user_data" then
                resolved.textConfig.userData = args[1]
            else
                error("argile typography: unknown operation '" .. tostring(n) .. "'")
            end
        end
    end
    
    if node.paint_ops then
        resolved.paint = resolved.paint or {}
        for _, op in ipairs(node.paint_ops) do
            local n = op.name
            local args = op.args or {}
            
            if n == "fill" then
                table.insert(resolved.paint, style.paint_fill(args[1]))
            elseif n == "stroke" then
                table.insert(resolved.paint, style.paint_stroke(args[1], args[2]))
            elseif n == "rect" then
                table.insert(resolved.paint, style.paint_rect(args[1], args[2], args[3], args[4]))
            elseif n == "round_rect" then
                table.insert(resolved.paint, style.paint_round_rect(args[1], args[2], args[3], args[4], args[5]))
            elseif n == "circle" then
                table.insert(resolved.paint, style.paint_circle(args[1], args[2], args[3]))
            elseif n == "line" then
                table.insert(resolved.paint, style.paint_line(args[1], args[2], args[3], args[4]))
            else
                error("argile paint: unknown operation '" .. tostring(n) .. "'")
            end
        end
    end
    
    if node.states then
        resolved.states = {}
        for state_name, state_node in pairs(node.states) do
            resolved.states[state_name] = ui.resolve_node(state_node)
        end
    end
    
    if node.children then
        resolved.children = {}
        for _, child in ipairs(node.children) do
            table.insert(resolved.children, ui.resolve_node(child))
        end
    end
    
    return resolved
end

function ui.compileResolved(node)
    local resolved = ui.resolve_node(node)
    return ui.compile(resolved)
end

return ui
