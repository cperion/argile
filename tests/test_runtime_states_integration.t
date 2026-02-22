local C = terralib.includecstring [[
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
]]

local ui = require("src.builder")
import "src/lang.argile"

-- New FFI-friendly signature: out pointer + int32 return
terra state_test_measure_text(text: &ui.StringSlice, textCfg: &ui.TextConfig, _userData: &opaque, out: &ui.Dimensions) : int32
    out.width = [float](text.length * 8)
    if textCfg ~= nil and textCfg.lineHeight > 0 then
        out.height = [float](textCfg.lineHeight)
    else
        out.height = 16.0
    end
    return 1  -- success
end

local compiled_state_scene = argile el
    id("state_probe")
    layout
        width_fixed(120.0)
        height_fixed(40.0)
        padding(4)
    end
    style
        bg({ r = 0.10, g = 0.10, b = 0.10, a = 1.0 })
    end
    when hover
        style
            bg({ r = 0.20, g = 0.40, b = 0.90, a = 1.0 })
        end
    end
    when active
        style
            bg({ r = 0.15, g = 0.30, b = 0.70, a = 1.0 })
        end
    end
    when focus
        style
            bg({ r = 0.20, g = 0.60, b = 0.30, a = 1.0 })
        end
    end
    when selected
        style
            bg({ r = 0.60, g = 0.40, b = 0.10, a = 1.0 })
        end
    end
    when disabled
        style
            bg({ r = 0.35, g = 0.35, b = 0.35, a = 1.0 })
        end
    end
    text("S")
        id("state_probe_label")
        typography
            color({ r = 1.0, g = 1.0, b = 1.0, a = 1.0 })
            font_size(12)
            line_height(12)
        end
        when hover
            typography
                color({ r = 1.0, g = 0.85, b = 0.20, a = 1.0 })
            end
        end
    end
end

terra color_equal(a: ui.Color, b: ui.Color) : bool
    return ui.FloatEqual(a.r, b.r) and ui.FloatEqual(a.g, b.g) and ui.FloatEqual(a.b, b.b) and ui.FloatEqual(a.a, b.a)
end

terra init_context(ctx: &ui.Context, arena: &ui.Arena, capacity: int32) : bool
    arena.nextAllocation = 0
    arena.capacity = 4 * 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))
    if arena.memory == nil then
        return false
    end
    return ctx:initialize(arena, capacity)
end

terra free_context_arena(arena: &ui.Arena)
    if arena.memory ~= nil then
        C.free(arena.memory)
        arena.memory = nil
    end
end

terra find_root_rect(ctx: &ui.Context, id: ui.ElementId, outCmd: &ui.RenderCommand) : bool
    var i: int32 = 0
    while i < ctx.renderCommands.length do
        var cmd = ui.GetRenderCommandAtForContext(ctx, i)
        if cmd.id == id.id and cmd.commandType == ui.RENDER_RECTANGLE then
            @outCmd = cmd
            return true
        end
        i = i + 1
    end
    return false
end

terra find_first_text(ctx: &ui.Context, outCmd: &ui.RenderCommand) : bool
    var i: int32 = 0
    while i < ctx.renderCommands.length do
        var cmd = ui.GetRenderCommandAtForContext(ctx, i)
        if cmd.commandType == ui.RENDER_TEXT then
            @outCmd = cmd
            return true
        end
        i = i + 1
    end
    return false
end

terra render_frame(ctx: &ui.Context, w: float, h: float) : int32
    ui.SetCurrentContext(ctx)
    ui.BeginLayoutForContext(ctx, w, h)
    [compiled_state_scene]
    return ui.FinalizeLayoutForContext(ctx)
end

terra expect_state_colors(ctx: &ui.Context, rootId: ui.ElementId, expectBg: ui.Color, expectText: ui.Color, label: &int8) : int32
    var failed: int32 = 0
    var rectCmd: ui.RenderCommand
    var textCmd: ui.RenderCommand
    if not find_root_rect(ctx, rootId, &rectCmd) then
        C.printf("FAIL: %s: root rectangle not found\n", label)
        return 1
    end
    if not find_first_text(ctx, &textCmd) then
        C.printf("FAIL: %s: text command not found\n", label)
        return 1
    end

    if not color_equal(rectCmd.renderData.rectangle.backgroundColor, expectBg) then
        C.printf("FAIL: %s: background color mismatch\n", label)
        failed = failed + 1
    end
    if not color_equal(textCmd.renderData.text.textColor, expectText) then
        C.printf("FAIL: %s: text color mismatch\n", label)
        failed = failed + 1
    end
    return failed
end

terra run_runtime_state_integration() : int32
    var failed: int32 = 0
    var arena: ui.Arena
    var ctx: ui.Context
    if not init_context(&ctx, &arena, 256) then
        C.printf("FAIL: could not init context\n")
        return 1
    end

    ui.SetMeasureTextFunction(state_test_measure_text, nil)
    ui.ResetMeasureTextCache()
    ui.SetCurrentContext(&ctx)

    var rootId = ui.GetElementIdFromChars("state_probe", 11)

    var baseBg = ui.Color { r = 0.10, g = 0.10, b = 0.10, a = 1.0 }
    var hoverBg = ui.Color { r = 0.20, g = 0.40, b = 0.90, a = 1.0 }
    var activeBg = ui.Color { r = 0.15, g = 0.30, b = 0.70, a = 1.0 }
    var focusBg = ui.Color { r = 0.20, g = 0.60, b = 0.30, a = 1.0 }
    var selectedBg = ui.Color { r = 0.60, g = 0.40, b = 0.10, a = 1.0 }
    var disabledBg = ui.Color { r = 0.35, g = 0.35, b = 0.35, a = 1.0 }
    var baseText = ui.Color { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
    var hoverText = ui.Color { r = 1.0, g = 0.85, b = 0.20, a = 1.0 }

    var p_out: ui.Vector2
    p_out.x = 1000.0
    p_out.y = 1000.0
    var p_in: ui.Vector2
    p_in.x = 10.0
    p_in.y = 10.0

    -- Base frame
    ui.SetElementFocusedForContext(&ctx, rootId, false)
    ui.SetElementSelectedForContext(&ctx, rootId, false)
    ui.SetElementDisabledForContext(&ctx, rootId, false)
    ui.SetPointerStateForContext(&ctx, p_out, false)
    if render_frame(&ctx, 300.0, 200.0) <= 0 then
        C.printf("FAIL: base frame emitted no commands\n")
        failed = failed + 1
    else
        failed = failed + expect_state_colors(&ctx, rootId, baseBg, baseText, "base")
    end

    -- Hover affects background + text typography overlay
    ui.SetPointerStateForContext(&ctx, p_in, false)
    if render_frame(&ctx, 300.0, 200.0) <= 0 then
        C.printf("FAIL: hover frame emitted no commands\n")
        failed = failed + 1
    else
        failed = failed + expect_state_colors(&ctx, rootId, hoverBg, hoverText, "hover")
    end

    -- Active overrides hover background, hover typography remains (active has no text overlay)
    ui.SetPointerStateForContext(&ctx, p_in, true)
    if not ui.ElementActive(rootId) then
        C.printf("FAIL: ElementActive should be true when pointer down over element\n")
        failed = failed + 1
    end
    if render_frame(&ctx, 300.0, 200.0) <= 0 then
        C.printf("FAIL: active frame emitted no commands\n")
        failed = failed + 1
    else
        failed = failed + expect_state_colors(&ctx, rootId, activeBg, hoverText, "active")
    end

    -- Focus (pointer out)
    ui.SetPointerStateForContext(&ctx, p_out, false)
    ui.SetElementFocusedForContext(&ctx, rootId, true)
    if not ui.ElementFocused(rootId) then
        C.printf("FAIL: ElementFocused should be true after SetElementFocusedForContext\n")
        failed = failed + 1
    end
    if render_frame(&ctx, 300.0, 200.0) <= 0 then
        C.printf("FAIL: focus frame emitted no commands\n")
        failed = failed + 1
    else
        failed = failed + expect_state_colors(&ctx, rootId, focusBg, baseText, "focus")
    end

    -- Selected
    ui.SetElementFocusedForContext(&ctx, rootId, false)
    ui.SetElementSelectedForContext(&ctx, rootId, true)
    if not ui.ElementSelected(rootId) then
        C.printf("FAIL: ElementSelected should be true after SetElementSelectedForContext\n")
        failed = failed + 1
    end
    if render_frame(&ctx, 300.0, 200.0) <= 0 then
        C.printf("FAIL: selected frame emitted no commands\n")
        failed = failed + 1
    else
        failed = failed + expect_state_colors(&ctx, rootId, selectedBg, baseText, "selected")
    end

    -- Disabled overrides hover/active due precedence
    ui.SetElementSelectedForContext(&ctx, rootId, false)
    ui.SetElementDisabledForContext(&ctx, rootId, true)
    ui.SetPointerStateForContext(&ctx, p_in, true)
    if not ui.ElementDisabled(rootId) then
        C.printf("FAIL: ElementDisabled should be true after SetElementDisabledForContext\n")
        failed = failed + 1
    end
    if render_frame(&ctx, 300.0, 200.0) <= 0 then
        C.printf("FAIL: disabled frame emitted no commands\n")
        failed = failed + 1
    else
        failed = failed + expect_state_colors(&ctx, rootId, disabledBg, hoverText, "disabled")
    end

    free_context_arena(&arena)
    return failed
end

local rc = run_runtime_state_integration()
if rc == 0 then
    print("test_runtime_states_integration: PASS")
else
    print("test_runtime_states_integration: FAIL (" .. tostring(rc) .. " checks)")
end
os.exit(rc)
