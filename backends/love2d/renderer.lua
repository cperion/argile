-- Love2D renderer for Argile render commands
-- Backend-neutral command dispatch

local ffi = require("ffi")

local renderer = {}
renderer._font_cache = {}
renderer._scissor_stack = {}

local function clamp_nonnegative(v)
    if v < 0 then return 0 end
    return v
end

local function intersect_rect(a, b)
    local x1 = math.max(a.x, b.x)
    local y1 = math.max(a.y, b.y)
    local x2 = math.min(a.x + a.w, b.x + b.w)
    local y2 = math.min(a.y + a.h, b.y + b.h)
    if x2 <= x1 or y2 <= y1 then
        return { x = x1, y = y1, w = 0, h = 0 }
    end
    return { x = x1, y = y1, w = x2 - x1, h = y2 - y1 }
end

local function get_font(size, line_height)
    size = math.max(1, math.floor(tonumber(size) or 16))
    line_height = math.floor(tonumber(line_height) or 0)
    local key = tostring(size) .. ":" .. tostring(line_height)
    local font = renderer._font_cache[key]
    if font ~= nil then
        return font
    end
    font = love.graphics.newFont(size)
    if line_height > 0 then
        local base_h = font:getHeight()
        if base_h > 0 then
            font:setLineHeight(line_height / base_h)
        end
    end
    renderer._font_cache[key] = font
    return font
end

function renderer.begin_frame()
    renderer._scissor_stack = {}
    love.graphics.setScissor()
end

function renderer.end_frame()
    renderer._scissor_stack = {}
    love.graphics.setScissor()
end

function renderer.set_color(c)
    local r = tonumber(c.r or 0)
    local g = tonumber(c.g or 0)
    local b = tonumber(c.b or 0)
    local a = tonumber(c.a or 1)
    -- Argile render commands use normalized float colors. Keep compatibility
    -- with any byte-style colors by normalizing only when values exceed 1.
    if r > 1 or g > 1 or b > 1 or a > 1 then
        r = r / 255.0
        g = g / 255.0
        b = b / 255.0
        a = a / 255.0
    end
    love.graphics.setColor(r, g, b, a)
end

function renderer.draw_rectangle(cmd)
    local c = cmd.renderData.rectangle.backgroundColor
    renderer.set_color(c)
    local r = tonumber(cmd.renderData.rectangle.cornerRadius.topLeft or 0)
    love.graphics.rectangle("fill", cmd.boundingBox.x, cmd.boundingBox.y, 
        cmd.boundingBox.width, cmd.boundingBox.height, r, r)
end

function renderer.draw_border(cmd)
    local b = cmd.renderData.border
    local w = math.max(tonumber(b.width.left), tonumber(b.width.right), 
                       tonumber(b.width.top), tonumber(b.width.bottom))
    if w <= 0 then return end
    local r = tonumber(b.cornerRadius.topLeft or 0)
    renderer.set_color(b.color)
    local prev = love.graphics.getLineWidth()
    love.graphics.setLineWidth(w)
    love.graphics.rectangle("line", cmd.boundingBox.x + w * 0.5, cmd.boundingBox.y + w * 0.5,
        math.max(0, cmd.boundingBox.width - w), math.max(0, cmd.boundingBox.height - w), r, r)
    love.graphics.setLineWidth(prev)
end

function renderer.draw_text(cmd)
    local t = cmd.renderData.text
    local slice = t.stringContents
    if slice == nil or slice.chars == nil or slice.length <= 0 then return end
    renderer.set_color(t.textColor)
    local prev_font = love.graphics.getFont()
    local font = get_font(t.fontSize, t.lineHeight)
    love.graphics.setFont(font)
    local s = ffi.string(slice.chars, tonumber(slice.length))
    local x = tonumber(cmd.boundingBox.x)
    local y = tonumber(cmd.boundingBox.y)
    -- Argile already performs text layout/wrapping and emits positioned text
    -- commands. The Love backend should only draw the provided slice.
    love.graphics.print(s, x, y)
    love.graphics.setFont(prev_font)
end

-- Paint operation kinds from FFI: PAINT_OP_FILL=0, PAINT_OP_STROKE=1, etc.
-- These are accessed through the loaded argile library
function renderer.draw_paint(cmd, argile)
    local p = cmd.renderData.paint
    if p == nil or p.ops == nil or p.count <= 0 then return end
    local ox = cmd.boundingBox.x
    local oy = cmd.boundingBox.y

    local fill_color = { r = 255, g = 255, b = 255, a = 255 }
    local stroke_color = { r = 255, g = 255, b = 255, a = 255 }
    local stroke_width = 1

    local i = 0
    while i < tonumber(p.count) do
        local op = p.ops[i]
        local kind = tonumber(op.kind)
        if kind == argile.PAINT_OP_FILL then
            fill_color = op.color
        elseif kind == argile.PAINT_OP_STROKE then
            stroke_color = op.color
            stroke_width = tonumber(op.width)
        elseif kind == argile.PAINT_OP_RECT then
            renderer.set_color(fill_color)
            love.graphics.rectangle("fill", ox + op.x, oy + op.y, op.w, op.h)
        elseif kind == argile.PAINT_OP_ROUND_RECT then
            renderer.set_color(fill_color)
            love.graphics.rectangle("fill", ox + op.x, oy + op.y, op.w, op.h, op.r, op.r)
        elseif kind == argile.PAINT_OP_CIRCLE then
            renderer.set_color(fill_color)
            love.graphics.circle("fill", ox + op.x, oy + op.y, op.r)
        elseif kind == argile.PAINT_OP_LINE then
            renderer.set_color(stroke_color)
            local prev = love.graphics.getLineWidth()
            love.graphics.setLineWidth(stroke_width)
            love.graphics.line(ox + op.x, oy + op.y, ox + op.x2, oy + op.y2)
            love.graphics.setLineWidth(prev)
        end
        i = i + 1
    end
end

function renderer.draw_scissor_start(cmd)
    local rect = {
        x = tonumber(cmd.boundingBox.x) or 0,
        y = tonumber(cmd.boundingBox.y) or 0,
        w = clamp_nonnegative(tonumber(cmd.boundingBox.width) or 0),
        h = clamp_nonnegative(tonumber(cmd.boundingBox.height) or 0),
    }
    local stack = renderer._scissor_stack
    local top = stack[#stack]
    if top ~= nil then
        rect = intersect_rect(top, rect)
    end
    stack[#stack + 1] = rect
    love.graphics.setScissor(rect.x, rect.y, rect.w, rect.h)
end

function renderer.draw_scissor_end()
    local stack = renderer._scissor_stack
    if #stack > 0 then
        stack[#stack] = nil
    end
    local top = stack[#stack]
    if top ~= nil then
        love.graphics.setScissor(top.x, top.y, top.w, top.h)
    else
        love.graphics.setScissor()
    end
end

return renderer
