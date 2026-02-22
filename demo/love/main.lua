local ffi = require("ffi")
dofile("build/argile_api_ffi.lua")
ffi.cdef[[
void* malloc(size_t size);
void free(void* ptr);
]]

local argile = ffi.load("build/libargile.so")

local arena_bytes = 256 * 1024 * 1024
local arena_mem
local ctx
local cmd_count = 0
local cmd_buffer = nil
local card_id
local demo_focus = false
local demo_selected = false
local demo_disabled = false

local function mk_string(s)
    return ffi.new("struct String", {
        isStaticallyAllocated = true,
        length = #s,
        chars = ffi.cast("char*", s),
    })
end

function love.load()
    love.window.setTitle("Argile + Love2D Demo")
    love.window.setMode(1280, 720, { resizable = true, vsync = 1 })

    arena_mem = ffi.C.malloc(arena_bytes)
    if arena_mem == nil then
        error("malloc failed")
    end

    local arena = argile.CreateArenaWithCapacityAndMemory(arena_bytes, arena_mem)
    local dims = ffi.new("struct Dimensions", { width = 1280, height = 720 })
    ctx = argile.Initialize(arena, dims)
    if ctx == nil then
        error("Argile Initialize failed")
    end

    local api_version = tonumber(argile.GetApiVersion())
    if api_version ~= tonumber(argile.ARGILE_API_VERSION) then
        error(("Argile API version mismatch: lib=%d expected=%d"):format(api_version, tonumber(argile.ARGILE_API_VERSION)))
    end

    argile.SetCurrentContext(ctx)
    card_id = argile.GetElementId(mk_string("love_v3_demo_card"))
end

function love.update()
    local ww, hh = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()
    local down = love.mouse.isDown(1)

    argile.SetCurrentContext(ctx)
    argile.SetElementFocused(card_id, demo_focus)
    argile.SetElementSelected(card_id, demo_selected)
    argile.SetElementDisabled(card_id, demo_disabled)

    cmd_count = tonumber(argile.LoveDemoV3Frame(ww, hh, mx, my, down))
    cmd_buffer = argile.GetRenderCommandBuffer()
end

local function set_color(c)
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

local function draw_border(cmd)
    local b = cmd.renderData.border
    local w = math.max(tonumber(b.width.left), tonumber(b.width.right), tonumber(b.width.top), tonumber(b.width.bottom))
    if w <= 0 then return end
    local r = tonumber(b.cornerRadius.topLeft or 0)
    set_color(b.color)
    local prev = love.graphics.getLineWidth()
    love.graphics.setLineWidth(w)
    love.graphics.rectangle("line", cmd.boundingBox.x + w * 0.5, cmd.boundingBox.y + w * 0.5,
        math.max(0, cmd.boundingBox.width - w), math.max(0, cmd.boundingBox.height - w), r, r)
    love.graphics.setLineWidth(prev)
end

local function draw_text(cmd)
    local t = cmd.renderData.text
    local slice = t.stringContents
    if slice == nil or slice.chars == nil or slice.length <= 0 then return end
    set_color(t.textColor)
    local s = ffi.string(slice.chars, tonumber(slice.length))
    love.graphics.print(s, cmd.boundingBox.x, cmd.boundingBox.y)
end

local function draw_paint(cmd)
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
        if op.kind == argile.PAINT_OP_FILL then
            fill_color = op.color
        elseif op.kind == argile.PAINT_OP_STROKE then
            stroke_color = op.color
            stroke_width = tonumber(op.width)
        elseif op.kind == argile.PAINT_OP_RECT then
            set_color(fill_color)
            love.graphics.rectangle("fill", ox + op.x, oy + op.y, op.w, op.h)
        elseif op.kind == argile.PAINT_OP_ROUND_RECT then
            set_color(fill_color)
            love.graphics.rectangle("fill", ox + op.x, oy + op.y, op.w, op.h, op.r, op.r)
        elseif op.kind == argile.PAINT_OP_CIRCLE then
            set_color(fill_color)
            love.graphics.circle("fill", ox + op.x, oy + op.y, op.r)
        elseif op.kind == argile.PAINT_OP_LINE then
            set_color(stroke_color)
            local prev = love.graphics.getLineWidth()
            love.graphics.setLineWidth(stroke_width)
            love.graphics.line(ox + op.x, oy + op.y, ox + op.x2, oy + op.y2)
            love.graphics.setLineWidth(prev)
        end
        i = i + 1
    end
end

function love.draw()
    love.graphics.clear(0.06, 0.08, 0.12, 1.0)

    if cmd_buffer ~= nil then
        for i = 0, cmd_count - 1 do
            local cmd = cmd_buffer[i]
            if cmd.commandType == argile.RENDER_RECTANGLE then
                local c = cmd.renderData.rectangle.backgroundColor
                set_color(c)
                local r = tonumber(cmd.renderData.rectangle.cornerRadius.topLeft or 0)
                love.graphics.rectangle("fill", cmd.boundingBox.x, cmd.boundingBox.y, cmd.boundingBox.width, cmd.boundingBox.height, r, r)
            elseif cmd.commandType == argile.RENDER_BORDER then
                draw_border(cmd)
            elseif cmd.commandType == argile.RENDER_TEXT then
                draw_text(cmd)
            elseif cmd.commandType == argile.RENDER_PAINT then
                draw_paint(cmd)
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(("Argile commands: %d"):format(cmd_count), 14, 12)
    love.graphics.print(("FPS: %d"):format(love.timer.getFPS()), 14, 30)
    love.graphics.print(("States: [F]ocus=%s [S]elected=%s [D]isabled=%s"):format(
        tostring(demo_focus), tostring(demo_selected), tostring(demo_disabled)
    ), 14, 48)
    love.graphics.print("Hover/click card for hover/active. Terra V3 scene is emitted by LoveDemoV3Frame().", 14, 66)
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
    if arena_mem ~= nil then
        ffi.C.free(arena_mem)
        arena_mem = nil
    end
end
