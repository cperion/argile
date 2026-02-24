local function prepend_path(entry)
    local p = package.path or ""
    if not p:find(entry, 1, true) then
        package.path = entry .. ";" .. p
    end
end

prepend_path("./?.lua")
prepend_path("./?/init.lua")

local dispatcher = require("render.dispatcher")

local function assert_eq(actual, expected, msg)
    if actual ~= expected then
        error((msg or "assert_eq failed") .. (": got " .. tostring(actual) .. " expected " .. tostring(expected)))
    end
end

local function test_dispatch_default_constants()
    local calls = {}
    local sink = {
        draw_rectangle = function(cmd) calls[#calls + 1] = "rect:" .. tostring(cmd.tag) end,
        draw_border = function(cmd) calls[#calls + 1] = "border:" .. tostring(cmd.tag) end,
        draw_text = function(cmd) calls[#calls + 1] = "text:" .. tostring(cmd.tag) end,
        draw_scissor_start = function(cmd) calls[#calls + 1] = "sc_start:" .. tostring(cmd.tag) end,
        draw_scissor_end = function() calls[#calls + 1] = "sc_end" end,
        on_unknown_command = function(cmd, _, t) calls[#calls + 1] = "unknown:" .. tostring(t) .. ":" .. tostring(cmd.tag) end,
    }

    local cmds = {
        [0] = { commandType = dispatcher.CMD.RECTANGLE, tag = "a" },
        [1] = { commandType = dispatcher.CMD.BORDER, tag = "b" },
        [2] = { commandType = dispatcher.CMD.TEXT, tag = "c" },
        [3] = { commandType = dispatcher.CMD.SCISSOR_START, tag = "d" },
        [4] = { commandType = dispatcher.CMD.SCISSOR_END, tag = "e" },
        [5] = { commandType = 255, tag = "z" },
    }

    local n = dispatcher.draw_commands(cmds, 6, sink, nil)
    assert_eq(n, 6, "draw_commands count")
    assert_eq(table.concat(calls, ","), "rect:a,border:b,text:c,sc_start:d,sc_end,unknown:255:z", "default dispatch order")
end

local function test_dispatch_argile_override_constants()
    local calls = {}
    local sink = {
        draw_paint = function(cmd) calls[#calls + 1] = "paint:" .. tostring(cmd.tag) end,
        draw_custom = function(cmd) calls[#calls + 1] = "custom:" .. tostring(cmd.tag) end,
    }

    local fake_argile = {
        RENDER_PAINT = 91,
        RENDER_CUSTOM = 77,
    }

    local cmds = {
        [0] = { commandType = 91, tag = "p1" },
        [1] = { commandType = 77, tag = "c1" },
    }

    dispatcher.draw_commands(cmds, 2, sink, fake_argile)
    assert_eq(table.concat(calls, ","), "paint:p1,custom:c1", "argile constant override")
end

local function test_draw_command_missing_handler_returns_false()
    local ok = dispatcher.draw_command({ commandType = dispatcher.CMD.IMAGE }, {}, nil)
    assert_eq(ok, false, "missing sink handler should return false")
end

local function test_draw_commands_nil_inputs()
    assert_eq(dispatcher.draw_commands(nil, 3, {}, nil), 0, "nil buffer")
    assert_eq(dispatcher.draw_commands({}, nil, {}, nil), 0, "nil count")
    assert_eq(dispatcher.draw_commands({}, 1, nil, nil), 0, "nil sink")
end

test_dispatch_default_constants()
test_dispatch_argile_override_constants()
test_draw_command_missing_handler_returns_false()
test_draw_commands_nil_inputs()

print("test_render_dispatcher.lua: PASS")
