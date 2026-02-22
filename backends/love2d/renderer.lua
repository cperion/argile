-- Love2D renderer for Argile render commands
-- Backend-neutral command dispatch

local ffi = require("ffi")

local renderer = {}

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
    local s = ffi.string(slice.chars, tonumber(slice.length))
    love.graphics.print(s, cmd.boundingBox.x, cmd.boundingBox.y)
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

return renderer
