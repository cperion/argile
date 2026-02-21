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
local rect_count = 0
local cmd_buffer = nil

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
end

function love.update()
    local ww, hh = love.graphics.getDimensions()
    local t = love.timer.getTime()
    local mx, my = love.mouse.getPosition()
    local down = love.mouse.isDown(1)
    local pulse = 0.5 + 0.5 * math.sin(t * 1.6)

    argile.BeginLayout(ww, hh)
    argile.OpenStyledElement(ww - 40, hh - 40, argile.TOP_TO_BOTTOM, 12, 10, 20, 24, 33, 255)
    argile.OpenStyledElement(ww - 64, 72, argile.LEFT_TO_RIGHT, 10, 0, 34, 46, 66, 255)
    argile.CloseElement()

    local i = 0
    while i < 12 do
        local ri = 65 + (55 * (0.5 + 0.5 * math.sin(t * 1.7 + i * 0.45)))
        local gi = 85 + (40 * (0.5 + 0.5 * math.sin(t * 1.7 + i * 0.45)))
        local bi = 120 + (50 * (0.5 + 0.5 * math.sin(t * 1.7 + i * 0.45)))
        argile.OpenStyledElement(ww - 64, 34, argile.LEFT_TO_RIGHT, 8, 0, ri, gi, bi, 255)
        argile.CloseElement()
        i = i + 1
    end

    argile.OpenStyledElement(ww - 64, 36, argile.LEFT_TO_RIGHT, 8, 0, 34 + 8 * pulse, 46 + 8 * pulse, 66 + 8 * pulse, 255)
    argile.CloseElement()

    local txt = mk_string(("mouse: %d,%d down:%s"):format(mx, my, tostring(down)))
    argile.OpenTextElement(txt, nil)

    argile.CloseElement()
    rect_count = tonumber(argile.FinalizeLayout())
    cmd_buffer = argile.GetRenderCommandBuffer()
end

function love.draw()
    love.graphics.clear(0.06, 0.08, 0.12, 1.0)

    if cmd_buffer ~= nil then
        for i = 0, rect_count - 1 do
            local cmd = cmd_buffer[i]
            if cmd.commandType == argile.RENDER_RECTANGLE then
                local c = cmd.renderData.rectangle.backgroundColor
                love.graphics.setColor(c.r / 255.0, c.g / 255.0, c.b / 255.0, c.a / 255.0)
                love.graphics.rectangle("fill", cmd.boundingBox.x, cmd.boundingBox.y, cmd.boundingBox.width, cmd.boundingBox.height, 8, 8)
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(("Argile rectangles: %d"):format(rect_count), 14, 12)
    love.graphics.print(("FPS: %d"):format(love.timer.getFPS()), 14, 30)
    love.graphics.print("Main lib path: libargile.so (no special demo bridge)", 14, 48)
end

function love.quit()
    if arena_mem ~= nil then
        ffi.C.free(arena_mem)
        arena_mem = nil
    end
end
