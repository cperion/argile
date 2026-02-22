local C = terralib.includecstring [[
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
]]

local ui = require("src.builder")
import "src/lang.argile_v3"

local capi = ui.capi
local capi_get_render_command_at_for_context = capi.GetRenderCommandAtForContext
local capi_get_render_command_count_for_context = capi.GetRenderCommandCountForContext

terra v3_render_measure_text(text: ui.StringSlice, textCfg: &ui.TextConfig, _userData: &opaque) : ui.Dimensions
    var out: ui.Dimensions
    out.width = [float](text.length * 8)
    if textCfg ~= nil and textCfg.lineHeight > 0 then
        out.height = [float](textCfg.lineHeight)
    else
        out.height = 16.0
    end
    return out
end

theme v3_rt_theme
    token color.pill.bg = { r = 0.16, g = 0.22, b = 0.30, a = 1.0 }
    token color.pill.bg_hover = { r = 0.22, g = 0.34, b = 0.52, a = 1.0 }
    token color.pill.border = { r = 0.45, g = 0.56, b = 0.67, a = 1.0 }
    token color.pill.paint_fill = { r = 0.85, g = 0.51, b = 0.22, a = 1.0 }
    token color.pill.paint_hover = { r = 0.96, g = 0.67, b = 0.30, a = 1.0 }
    token color.pill.text = { r = 0.96, g = 0.98, b = 1.00, a = 1.0 }
    token radius.pill = 6

    recipe pill_root(opts)
        layout
            width_fixed(180)
            height_fixed(42)
            padding(6)
            dir(left_to_right)
        end
        style
            bg(token(color.pill.bg))
            radius(token(radius.pill))
            border_width(1)
            border_color(token(color.pill.border))
        end
        paint
            fill(token(color.pill.paint_fill))
            round_rect(3, 3, 20, 10, 2)
        end
    end

    recipe pill_label(opts)
        typography
            color(token(color.pill.text))
            font_size(14)
            line_height(14)
        end
    end
end

component pill(props)
    variant tone = primary | secondary

    root
        id(props.id)
        use(v3_rt_theme.pill_root(tone = props.tone))

        state hover
            style
                bg(token(v3_rt_theme.color.pill.bg_hover))
            end
            paint
                fill(token(v3_rt_theme.color.pill.paint_hover))
            end
        end

        text(props.label)
            part(label)
            use(v3_rt_theme.pill_label())
        end
    end
end

local v3_scene_node = argile
    pill(label = "V3 OK", tone = primary)
        id("v3_pill")
    end
end

local compiled_v3_scene = ui.compileResolved(v3_scene_node)

terra color_equal(a: ui.Color, b: ui.Color) : bool
    return ui.FloatEqual(a.r, b.r) and ui.FloatEqual(a.g, b.g) and ui.FloatEqual(a.b, b.b) and ui.FloatEqual(a.a, b.a)
end

terra text_slice_equal(a: ui.StringSlice, b: ui.StringSlice) : bool
    if a.length ~= b.length then return false end
    if a.length <= 0 then return true end
    return C.strncmp(a.chars, b.chars, [uint64](a.length)) == 0
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

terra find_command_for_id_type(ctx: &ui.Context, targetId: uint32, commandType: ui.RenderCommandType, outCmd: &ui.RenderCommand, outIndex: &int32) : bool
    if ctx == nil then return false end
    var i: int32 = 0
    while i < ctx.renderCommands.length do
        var cmd = capi_get_render_command_at_for_context(ctx, i)
        if cmd.id == targetId and cmd.commandType == commandType then
            if outCmd ~= nil then @outCmd = cmd end
            if outIndex ~= nil then @outIndex = i end
            return true
        end
        i = i + 1
    end
    return false
end

terra validate_pill_scene(ctx: &ui.Context, expect_hover: bool, label: &int8) : int32
    var failed: int32 = 0
    var count = [int32](capi_get_render_command_count_for_context(ctx))
    if count <= 0 then
        C.printf("FAIL: %s: no render commands\n", label)
        return 1
    end

    var rootId = ui.GetElementIdFromChars("v3_pill", 7).id
    var rectCmd: ui.RenderCommand
    var borderCmd: ui.RenderCommand
    var paintCmd: ui.RenderCommand
    var rectIdx: int32 = -1
    var borderIdx: int32 = -1
    var paintIdx: int32 = -1

    if not find_command_for_id_type(ctx, rootId, ui.RENDER_RECTANGLE, &rectCmd, &rectIdx) then
        C.printf("FAIL: %s: root rectangle not found\n", label)
        failed = failed + 1
    end
    if not find_command_for_id_type(ctx, rootId, ui.RENDER_BORDER, &borderCmd, &borderIdx) then
        C.printf("FAIL: %s: root border not found\n", label)
        failed = failed + 1
    end
    if not find_command_for_id_type(ctx, rootId, ui.RENDER_PAINT, &paintCmd, &paintIdx) then
        C.printf("FAIL: %s: root paint not found\n", label)
        failed = failed + 1
    end

    var textFound = false
    var textCmd: ui.RenderCommand
    var textIdx: int32 = -1
    var i: int32 = 0
    while i < count and not textFound do
        var cmd = capi_get_render_command_at_for_context(ctx, i)
        if cmd.commandType == ui.RENDER_TEXT then
            textFound = true
            textCmd = cmd
            textIdx = i
        end
        i = i + 1
    end
    if not textFound then
        C.printf("FAIL: %s: text command not found\n", label)
        failed = failed + 1
    end

    if rectIdx >= 0 and paintIdx >= 0 and paintIdx <= rectIdx then
        C.printf("FAIL: %s: paint should be emitted after rectangle (paint=%d rect=%d)\n", label, paintIdx, rectIdx)
        failed = failed + 1
    end
    if paintIdx >= 0 and borderIdx >= 0 and borderIdx <= paintIdx then
        C.printf("FAIL: %s: border should be emitted after paint (border=%d paint=%d)\n", label, borderIdx, paintIdx)
        failed = failed + 1
    end
    if rectIdx >= 0 and textIdx >= 0 and textIdx <= rectIdx then
        C.printf("FAIL: %s: text should be emitted after rectangle (text=%d rect=%d)\n", label, textIdx, rectIdx)
        failed = failed + 1
    end

    if rectIdx >= 0 then
        var expected_rect: ui.Color
        if expect_hover then
            expected_rect.r = 0.22
            expected_rect.g = 0.34
            expected_rect.b = 0.52
            expected_rect.a = 1.0
        else
            expected_rect.r = 0.16
            expected_rect.g = 0.22
            expected_rect.b = 0.30
            expected_rect.a = 1.0
        end
        if not color_equal(rectCmd.renderData.rectangle.backgroundColor, expected_rect) then
            C.printf("FAIL: %s: rectangle color mismatch (hover=%d)\n", label, [int32](expect_hover))
            failed = failed + 1
        end
        if not ui.FloatEqual(rectCmd.renderData.rectangle.cornerRadius.topLeft, 6.0) then
            C.printf("FAIL: %s: rectangle radius mismatch\n", label)
            failed = failed + 1
        end
        if rectCmd.boundingBox.width < 180.0 or rectCmd.boundingBox.height < 42.0 then
            C.printf("FAIL: %s: rectangle bbox too small (%.1f x %.1f)\n", label, rectCmd.boundingBox.width, rectCmd.boundingBox.height)
            failed = failed + 1
        end
    end

    if borderIdx >= 0 then
        if borderCmd.renderData.border.width.left ~= 1 or borderCmd.renderData.border.width.right ~= 1 or
           borderCmd.renderData.border.width.top ~= 1 or borderCmd.renderData.border.width.bottom ~= 1 then
            C.printf("FAIL: %s: border width mismatch\n", label)
            failed = failed + 1
        end
        if not color_equal(borderCmd.renderData.border.color, ui.Color { r = 0.45, g = 0.56, b = 0.67, a = 1.0 }) then
            C.printf("FAIL: %s: border color mismatch\n", label)
            failed = failed + 1
        end
    end

    if paintIdx >= 0 then
        var expected_count : uint32 = 2
        if expect_hover then
            expected_count = 3
        end
        if paintCmd.renderData.paint.count ~= expected_count then
            C.printf("FAIL: %s: paint op count mismatch (got=%u expected=%u)\n", label, paintCmd.renderData.paint.count, expected_count)
            failed = failed + 1
        elseif paintCmd.renderData.paint.ops == nil then
            C.printf("FAIL: %s: paint ops pointer nil\n", label)
            failed = failed + 1
        else
            var op0 = paintCmd.renderData.paint.ops[0]
            var op1 = paintCmd.renderData.paint.ops[1]
            if op0.kind ~= ui.PAINT_OP_FILL then
                C.printf("FAIL: %s: paint op0 kind mismatch\n", label)
                failed = failed + 1
            end
            if op1.kind ~= ui.PAINT_OP_ROUND_RECT then
                C.printf("FAIL: %s: paint op1 kind mismatch\n", label)
                failed = failed + 1
            end
            if not color_equal(op0.color, ui.Color { r = 0.85, g = 0.51, b = 0.22, a = 1.0 }) then
                C.printf("FAIL: %s: paint fill color mismatch\n", label)
                failed = failed + 1
            end
            if not ui.FloatEqual(op1.x, 3.0) or not ui.FloatEqual(op1.y, 3.0) or
               not ui.FloatEqual(op1.w, 20.0) or not ui.FloatEqual(op1.h, 10.0) or
               not ui.FloatEqual(op1.r, 2.0) then
                C.printf("FAIL: %s: paint round_rect geometry mismatch\n", label)
                failed = failed + 1
            end
            if expect_hover then
                var op2 = paintCmd.renderData.paint.ops[2]
                if op2.kind ~= ui.PAINT_OP_FILL then
                    C.printf("FAIL: %s: hover paint op2 kind mismatch\n", label)
                    failed = failed + 1
                end
                if not color_equal(op2.color, ui.Color { r = 0.96, g = 0.67, b = 0.30, a = 1.0 }) then
                    C.printf("FAIL: %s: hover paint color mismatch\n", label)
                    failed = failed + 1
                end
            end
        end
    end

    if textFound then
        if not text_slice_equal(textCmd.renderData.text.stringContents, ui.StringSlice { length = 5, chars = "V3 OK", baseChars = "V3 OK" }) then
            C.printf("FAIL: %s: text contents mismatch\n", label)
            failed = failed + 1
        end
        if textCmd.renderData.text.fontSize ~= 14 or textCmd.renderData.text.lineHeight ~= 14 then
            C.printf("FAIL: %s: text metrics mismatch (%d/%d)\n", label,
                [int32](textCmd.renderData.text.fontSize), [int32](textCmd.renderData.text.lineHeight))
            failed = failed + 1
        end
        if not color_equal(textCmd.renderData.text.textColor, ui.Color { r = 0.96, g = 0.98, b = 1.00, a = 1.0 }) then
            C.printf("FAIL: %s: text color mismatch\n", label)
            failed = failed + 1
        end
    end

    return failed
end

terra run_v3_render_integration() : int32
    var failed: int32 = 0
    var arena: ui.Arena
    var ctx: ui.Context

    if not init_context(&ctx, &arena, 512) then
        C.printf("FAIL: could not initialize context\n")
        return 1
    end

    ui.SetMeasureTextFunction(v3_render_measure_text, nil)
    ui.ResetMeasureTextCache()
    ui.SetCurrentContext(&ctx)

    var p_out: ui.Vector2
    p_out.x = 1000.0
    p_out.y = 1000.0
    ui.SetPointerStateForContext(&ctx, p_out, false)

    ui.BeginLayoutForContext(&ctx, 400.0, 200.0)
    [compiled_v3_scene]
    var count_off = ui.FinalizeLayoutForContext(&ctx)
    if count_off <= 0 then
        C.printf("FAIL: hover-off frame emitted no commands\n")
        failed = failed + 1
    else
        failed = failed + validate_pill_scene(&ctx, false, "hover-off")
    end

    var hoverId = ui.GetElementIdFromChars("v3_pill", 7)
    var p_in: ui.Vector2
    p_in.x = 10.0
    p_in.y = 10.0
    ui.SetPointerStateForContext(&ctx, p_in, false)
    if not ui.PointerOver(hoverId) then
        C.printf("FAIL: pointer should be over v3_pill after SetPointerStateForContext\n")
        failed = failed + 1
    end

    ui.BeginLayoutForContext(&ctx, 400.0, 200.0)
    [compiled_v3_scene]
    var count_on = ui.FinalizeLayoutForContext(&ctx)
    if count_on <= 0 then
        C.printf("FAIL: hover-on frame emitted no commands\n")
        failed = failed + 1
    else
        failed = failed + validate_pill_scene(&ctx, true, "hover-on")
    end

    free_context_arena(&arena)
    return failed
end

local rc = run_v3_render_integration()
if rc == 0 then
    print("test_v3_render_integration: PASS")
else
    print("test_v3_render_integration: FAIL (" .. tostring(rc) .. " checks)")
end
os.exit(rc)
