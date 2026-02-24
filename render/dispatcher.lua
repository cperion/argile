-- Backend-neutral Argile render-command dispatcher.
-- This module knows command routing, but knows nothing about any graphics API.

local M = {}

M.CMD = {
    RECTANGLE = 1,
    BORDER = 2,
    TEXT = 3,
    IMAGE = 4,
    SCISSOR_START = 5,
    SCISSOR_END = 6,
    CUSTOM = 7,
    PAINT = 8,
}

local function cmd_value(argile, name, fallback)
    if argile ~= nil then
        local v = argile[name]
        if v ~= nil then return tonumber(v) end
    end
    return fallback
end

local function call_if_exists(fn, ...)
    if fn == nil then return false end
    fn(...)
    return true
end

function M.draw_command(cmd, sink, argile)
    if cmd == nil or sink == nil then return false end
    local t = tonumber(cmd.commandType)

    if t == cmd_value(argile, "RENDER_RECTANGLE", M.CMD.RECTANGLE) then
        return call_if_exists(sink.draw_rectangle, cmd, argile)
    end
    if t == cmd_value(argile, "RENDER_BORDER", M.CMD.BORDER) then
        return call_if_exists(sink.draw_border, cmd, argile)
    end
    if t == cmd_value(argile, "RENDER_TEXT", M.CMD.TEXT) then
        return call_if_exists(sink.draw_text, cmd, argile)
    end
    if t == cmd_value(argile, "RENDER_IMAGE", M.CMD.IMAGE) then
        return call_if_exists(sink.draw_image, cmd, argile)
    end
    if t == cmd_value(argile, "RENDER_SCISSOR_START", M.CMD.SCISSOR_START) then
        return call_if_exists(sink.draw_scissor_start, cmd, argile)
    end
    if t == cmd_value(argile, "RENDER_SCISSOR_END", M.CMD.SCISSOR_END) then
        return call_if_exists(sink.draw_scissor_end, argile)
    end
    if t == cmd_value(argile, "RENDER_CUSTOM", M.CMD.CUSTOM) then
        return call_if_exists(sink.draw_custom, cmd, argile)
    end
    if t == cmd_value(argile, "RENDER_PAINT", M.CMD.PAINT) then
        return call_if_exists(sink.draw_paint, cmd, argile)
    end

    if sink.on_unknown_command ~= nil then
        sink.on_unknown_command(cmd, argile, t)
    end
    return false
end

function M.draw_commands(cmd_buffer, cmd_count, sink, argile)
    if cmd_buffer == nil or cmd_count == nil or sink == nil then return 0 end
    local n = tonumber(cmd_count) or 0
    for i = 0, n - 1 do
        M.draw_command(cmd_buffer[i], sink, argile)
    end
    return n
end

return M
