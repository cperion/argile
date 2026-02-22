local style = {}

local function value_or(v, default)
    if v == nil then return default end
    return v
end

local function is_table(v)
    return type(v) == "table"
end

local function shallow_copy(t)
    if not is_table(t) then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
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
    if not is_table(a) or not is_table(b) then
        return deep_copy(b)
    end
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

style.StylePatch = {}
style.StylePatch.__index = style.StylePatch

function style.StylePatch:new()
    local patch = {
        layout = nil,
        shared = nil,
        border = nil,
        textConfig = nil,
        clip = nil,
        aspect = nil,
        image = nil,
        custom = nil,
        floating = nil,
        paint = nil,
        states = nil,
    }
    setmetatable(patch, self)
    return patch
end

function style.StylePatch:clone()
    local copy = style.StylePatch:new()
    copy.layout = deep_copy(self.layout)
    copy.shared = deep_copy(self.shared)
    copy.border = deep_copy(self.border)
    copy.textConfig = deep_copy(self.textConfig)
    copy.clip = deep_copy(self.clip)
    copy.aspect = deep_copy(self.aspect)
    copy.image = deep_copy(self.image)
    copy.custom = deep_copy(self.custom)
    copy.floating = deep_copy(self.floating)
    copy.paint = deep_copy(self.paint)
    if self.states then
        copy.states = {}
        for state, state_patch in pairs(self.states) do
            copy.states[state] = style.merge_patch(nil, state_patch)
        end
    end
    return copy
end

function style.merge_patch(a, b)
    if a == nil then
        if b == nil then
            return style.StylePatch:new()
        end
        if getmetatable(b) == style.StylePatch then
            return b:clone()
        end
        local result = style.StylePatch:new()
        for k, v in pairs(b) do
            if k == "states" and is_table(v) then
                result.states = {}
                for state, sp in pairs(v) do
                    result.states[state] = style.merge_patch(nil, sp)
                end
            elseif k == "paint" then
                result.paint = v and { unpack(v) } or nil
            else
                result[k] = deep_merge(nil, v)
            end
        end
        return result
    end
    
    if getmetatable(a) ~= style.StylePatch then
        a = style.merge_patch(nil, a)
    end
    if b == nil then
        return a:clone()
    end
    
    local result = a:clone()
    
    if getmetatable(b) == style.StylePatch then
        if b.layout then result.layout = deep_merge(result.layout, b.layout) end
        if b.shared then result.shared = deep_merge(result.shared, b.shared) end
        if b.border then result.border = deep_merge(result.border, b.border) end
        if b.textConfig then result.textConfig = deep_merge(result.textConfig, b.textConfig) end
        if b.clip then result.clip = deep_merge(result.clip, b.clip) end
        if b.aspect then result.aspect = deep_merge(result.aspect, b.aspect) end
        if b.image then result.image = deep_merge(result.image, b.image) end
        if b.custom then result.custom = deep_merge(result.custom, b.custom) end
        if b.floating then result.floating = deep_merge(result.floating, b.floating) end
        if b.paint then
            result.paint = result.paint or {}
            for _, op in ipairs(b.paint) do
                table.insert(result.paint, op)
            end
        end
        if b.states then
            result.states = result.states or {}
            for state, sp in pairs(b.states) do
                result.states[state] = style.merge_patch(result.states[state], sp)
            end
        end
    else
        for k, v in pairs(b) do
            if k == "states" and is_table(v) then
                result.states = result.states or {}
                for state, sp in pairs(v) do
                    result.states[state] = style.merge_patch(result.states[state], sp)
                end
            elseif k == "paint" then
                result.paint = result.paint or {}
                for _, op in ipairs(v) do
                    table.insert(result.paint, op)
                end
            else
                result[k] = deep_merge(result[k], v)
            end
        end
    end
    
    return result
end

function style.merge_patch_list(...)
    local patches = {...}
    local result = style.StylePatch:new()
    for _, patch in ipairs(patches) do
        if patch ~= nil then
            result = style.merge_patch(result, patch)
        end
    end
    return result
end

function style.patch(opts)
    return style.merge_patch(nil, opts)
end

function style.color(r, g, b, a)
    return { r = r or 0, g = g or 0, b = b or 0, a = a or 1 }
end

function style.corner_radius(tl, tr, bl, br)
    if tr == nil then
        local v = tl or 0
        return { topLeft = v, topRight = v, bottomLeft = v, bottomRight = v }
    end
    return { topLeft = tl or 0, topRight = tr or 0, bottomLeft = bl or 0, bottomRight = br or 0 }
end

function style.border_width(left, right, top, bottom, between)
    if right == nil then
        local v = left or 0
        return { left = v, right = v, top = v, bottom = v, betweenChildren = 0 }
    end
    return {
        left = left or 0,
        right = right or 0,
        top = top or 0,
        bottom = bottom or 0,
        betweenChildren = between or 0
    }
end

style.STATE_HOVER = "hover"
style.STATE_ACTIVE = "active"
style.STATE_DISABLED = "disabled"
style.STATE_FOCUS = "focus"
style.STATE_SELECTED = "selected"

function style.with_state(patch, state_name, state_patch)
    local result = style.merge_patch(nil, patch)
    result.states = result.states or {}
    result.states[state_name] = style.merge_patch(nil, state_patch)
    return result
end

function style.apply_style_ops(patch, ops)
    if not ops then return patch end
    local result = style.merge_patch(nil, patch)
    
    for _, op in ipairs(ops) do
        local n = op.name
        local args = op.args or {}
        
        if n == "bg" then
            result.shared = result.shared or {}
            result.shared.backgroundColor = args[1] or style.color(0, 0, 0, 1)
        elseif n == "radius" then
            result.shared = result.shared or {}
            result.shared.cornerRadius = style.corner_radius(args[1])
        elseif n == "radius4" then
            result.shared = result.shared or {}
            result.shared.cornerRadius = style.corner_radius(args[1], args[2], args[3], args[4])
        elseif n == "border_width" then
            result.border = result.border or {}
            result.border.width = style.border_width(args[1])
        elseif n == "border_width4" then
            result.border = result.border or {}
            result.border.width = style.border_width(args[1], args[2], args[3], args[4])
        elseif n == "border_between_children" then
            result.border = result.border or {}
            result.border.width = result.border.width or style.border_width(0)
            result.border.width.betweenChildren = args[1] or 0
        elseif n == "border_color" then
            result.border = result.border or {}
            result.border.color = args[1] or style.color(0, 0, 0, 1)
        elseif n == "user_data" then
            result.shared = result.shared or {}
            result.shared.userData = args[1]
        end
    end
    
    return result
end

function style.apply_typography_ops(patch, ops)
    if not ops then return patch end
    local result = style.merge_patch(nil, patch)
    
    local ui = require("src.init")
    
    for _, op in ipairs(ops) do
        local n = op.name
        local args = op.args or {}
        
        result.textConfig = result.textConfig or {}
        
        if n == "color" then
            result.textConfig.textColor = args[1] or style.color(0, 0, 0, 1)
        elseif n == "font_id" then
            result.textConfig.fontId = args[1] or 0
        elseif n == "font_size" then
            result.textConfig.fontSize = args[1] or 16
        elseif n == "letter_spacing" then
            result.textConfig.letterSpacing = args[1] or 0
        elseif n == "line_height" then
            result.textConfig.lineHeight = args[1] or 0
        elseif n == "wrap" then
            result.textConfig.wrapMode = args[1] or ui.TEXT_WRAP_WORDS
        elseif n == "align" then
            result.textConfig.textAlignment = args[1] or ui.TEXT_ALIGN_LEFT
        elseif n == "user_data" then
            result.textConfig.userData = args[1]
        end
    end
    
    return result
end

local PAINT_OP_FILL = "fill"
local PAINT_OP_STROKE = "stroke"
local PAINT_OP_RECT = "rect"
local PAINT_OP_ROUND_RECT = "round_rect"
local PAINT_OP_CIRCLE = "circle"
local PAINT_OP_LINE = "line"

style.PaintOp = {
    FILL = PAINT_OP_FILL,
    STROKE = PAINT_OP_STROKE,
    RECT = PAINT_OP_RECT,
    ROUND_RECT = PAINT_OP_ROUND_RECT,
    CIRCLE = PAINT_OP_CIRCLE,
    LINE = PAINT_OP_LINE,
}

function style.paint_fill(color)
    return { kind = PAINT_OP_FILL, color = color }
end

function style.paint_stroke(color, width)
    return { kind = PAINT_OP_STROKE, color = color, width = width or 1 }
end

function style.paint_rect(x, y, w, h)
    return { kind = PAINT_OP_RECT, x = x, y = y, w = w, h = h }
end

function style.paint_round_rect(x, y, w, h, r)
    return { kind = PAINT_OP_ROUND_RECT, x = x, y = y, w = w, h = h, r = r }
end

function style.paint_circle(cx, cy, r)
    return { kind = PAINT_OP_CIRCLE, cx = cx, cy = cy, r = r }
end

function style.paint_line(x1, y1, x2, y2)
    return { kind = PAINT_OP_LINE, x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
end

function style.apply_paint_ops(patch, ops)
    if not ops then return patch end
    local result = style.merge_patch(nil, patch)
    result.paint = result.paint or {}
    
    for _, op in ipairs(ops) do
        local n = op.name
        local args = op.args or {}
        
        if n == "fill" then
            table.insert(result.paint, style.paint_fill(args[1]))
        elseif n == "stroke" then
            table.insert(result.paint, style.paint_stroke(args[1], args[2]))
        elseif n == "rect" then
            table.insert(result.paint, style.paint_rect(args[1], args[2], args[3], args[4]))
        elseif n == "round_rect" then
            table.insert(result.paint, style.paint_round_rect(args[1], args[2], args[3], args[4], args[5]))
        elseif n == "circle" then
            table.insert(result.paint, style.paint_circle(args[1], args[2], args[3]))
        elseif n == "line" then
            table.insert(result.paint, style.paint_line(args[1], args[2], args[3], args[4]))
        end
    end
    
    return result
end

function style.resolve_to_node(patch, base_node)
    local node = base_node or {}
    
    if not patch then return node end
    
    local p = patch
    if getmetatable(p) ~= style.StylePatch then
        p = style.merge_patch(nil, patch)
    end
    
    if p.layout then
        node.layout = deep_merge(node.layout, p.layout)
    end
    if p.shared then
        node.shared = deep_merge(node.shared, p.shared)
    end
    if p.border then
        node.border = deep_merge(node.border, p.border)
    end
    if p.textConfig then
        node.textConfig = deep_merge(node.textConfig, p.textConfig)
    end
    if p.clip then
        node.clip = deep_merge(node.clip, p.clip)
    end
    if p.aspect then
        node.aspect = deep_merge(node.aspect, p.aspect)
    end
    if p.image then
        node.image = deep_merge(node.image, p.image)
    end
    if p.custom then
        node.custom = deep_merge(node.custom, p.custom)
    end
    if p.floating then
        node.floating = deep_merge(node.floating, p.floating)
    end
    if p.paint then
        node.paint = p.paint
    end
    if p.states then
        node.states = {}
        for state, sp in pairs(p.states) do
            node.states[state] = style.resolve_to_node(sp, nil)
        end
    end
    
    return node
end

return style
