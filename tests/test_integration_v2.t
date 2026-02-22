local C = terralib.includecstring [[
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
]]

local ui = require("src.builder")
local ds = require("src/style/default_theme")
import "src/lang.argile"

local capi = ui.capi
local capi_begin_layout_for_context = capi.BeginLayoutForContext
local capi_finalize_layout_for_context = capi.FinalizeLayoutForContext
local capi_get_render_command_at_for_context = capi.GetRenderCommandAtForContext
local capi_get_render_command_count_for_context = capi.GetRenderCommandCountForContext
local capi_open_element_with_id_chars_for_context = capi.OpenElementWithIdCharsForContext
local capi_set_open_element_layout_config_for_context = capi.SetOpenElementLayoutConfigForContext
local capi_attach_shared_config_for_context = capi.AttachSharedConfigForContext
local capi_attach_border_config_for_context = capi.AttachBorderConfigForContext
local capi_attach_paint_config_for_context = capi.AttachPaintConfigForContext
local capi_open_text_element_with_length_for_context = capi.OpenTextElementWithLengthForContext
local capi_close_element_for_context = capi.CloseElementForContext

-- New FFI-friendly signature: out pointer + int32 return
terra integration_mock_measure_text(text: &ui.StringSlice, textCfg: &ui.TextConfig, _userData: &opaque, out: &ui.Dimensions) : int32
    out.width = [float](text.length * 8)
    if textCfg ~= nil and textCfg.lineHeight > 0 then
        out.height = [float](textCfg.lineHeight)
    else
        out.height = 16.0
    end
    return 1  -- success
end

local compiled_dsl_scene = argile el
    id("integration_root")
    layout
        width_fixed(220.0)
        height_fixed(120.0)
        dir(top_to_bottom)
        padding(8)
        gap(4)
    end
    style
        bg(ds.colors.surface_700)
        radius(6.0)
        border_width(1)
        border_color(ds.colors.border_default)
    end
    paint
        fill(ds.colors.primary_500)
        round_rect(4, 4, 24, 12, 3)
        stroke(ds.colors.primary_700, 2)
        line(4, 20, 28, 20)
    end
    text("Hello")
        id("integration_label")
        typography
            color(ds.colors.white)
            font_size(14)
            line_height(14)
        end
    end
end

local compiled_hover_dsl_scene = argile el
    id("hover_probe")
    layout
        width_fixed(100.0)
        height_fixed(40.0)
    end
    style
        bg(ds.colors.surface_700)
        radius(4.0)
    end
    when hover
        style
            bg(ds.colors.primary_500)
        end
    end
end

terra color_equal(a: ui.Color, b: ui.Color) : bool
    return ui.FloatEqual(a.r, b.r) and ui.FloatEqual(a.g, b.g) and ui.FloatEqual(a.b, b.b) and ui.FloatEqual(a.a, b.a)
end

terra bbox_equal(a: ui.BoundingBox, b: ui.BoundingBox) : bool
    return ui.FloatEqual(a.x, b.x) and ui.FloatEqual(a.y, b.y) and
           ui.FloatEqual(a.width, b.width) and ui.FloatEqual(a.height, b.height)
end

terra corner_equal(a: ui.CornerRadius, b: ui.CornerRadius) : bool
    return ui.FloatEqual(a.topLeft, b.topLeft) and ui.FloatEqual(a.topRight, b.topRight) and
           ui.FloatEqual(a.bottomLeft, b.bottomLeft) and ui.FloatEqual(a.bottomRight, b.bottomRight)
end

terra border_width_equal(a: ui.BorderWidth, b: ui.BorderWidth) : bool
    return a.left == b.left and a.right == b.right and a.top == b.top and
           a.bottom == b.bottom and a.betweenChildren == b.betweenChildren
end

terra text_slice_equal(a: ui.StringSlice, b: ui.StringSlice) : bool
    if a.length ~= b.length then return false end
    if a.length <= 0 then return true end
    return C.strncmp(a.chars, b.chars, [uint64](a.length)) == 0
end

terra paint_ops_equal(aops: &ui.PaintOp, acount: uint32, bops: &ui.PaintOp, bcount: uint32) : bool
    if acount ~= bcount then return false end
    if acount == 0 then return true end
    if aops == nil or bops == nil then return false end

    var i: uint32 = 0
    while i < acount do
        var a = aops[i]
        var b = bops[i]
        if a.kind ~= b.kind then return false end
        if not color_equal(a.color, b.color) then return false end
        if not ui.FloatEqual(a.x, b.x) or not ui.FloatEqual(a.y, b.y) or
           not ui.FloatEqual(a.w, b.w) or not ui.FloatEqual(a.h, b.h) or
           not ui.FloatEqual(a.r, b.r) or not ui.FloatEqual(a.x2, b.x2) or
           not ui.FloatEqual(a.y2, b.y2) then
            return false
        end
        if a.width ~= b.width then return false end
        i = i + 1
    end

    return true
end

terra command_equal(a: ui.RenderCommand, b: ui.RenderCommand) : bool
    if a.commandType ~= b.commandType then return false end
    if a.id ~= b.id then return false end
    if a.zIndex ~= b.zIndex then return false end
    if not bbox_equal(a.boundingBox, b.boundingBox) then return false end

    if a.commandType == ui.RENDER_RECTANGLE then
        return color_equal(a.renderData.rectangle.backgroundColor, b.renderData.rectangle.backgroundColor) and
               corner_equal(a.renderData.rectangle.cornerRadius, b.renderData.rectangle.cornerRadius)
    elseif a.commandType == ui.RENDER_BORDER then
        return color_equal(a.renderData.border.color, b.renderData.border.color) and
               corner_equal(a.renderData.border.cornerRadius, b.renderData.border.cornerRadius) and
               border_width_equal(a.renderData.border.width, b.renderData.border.width)
    elseif a.commandType == ui.RENDER_TEXT then
        return text_slice_equal(a.renderData.text.stringContents, b.renderData.text.stringContents) and
               color_equal(a.renderData.text.textColor, b.renderData.text.textColor) and
               a.renderData.text.fontId == b.renderData.text.fontId and
               a.renderData.text.fontSize == b.renderData.text.fontSize and
               a.renderData.text.letterSpacing == b.renderData.text.letterSpacing and
               a.renderData.text.lineHeight == b.renderData.text.lineHeight
    elseif a.commandType == ui.RENDER_PAINT then
        return paint_ops_equal(
            a.renderData.paint.ops, a.renderData.paint.count,
            b.renderData.paint.ops, b.renderData.paint.count
        )
    end

    return true
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

terra validate_expected_scene_correctness(ctx: &ui.Context, count: int32, label: &int8) : int32
    var failed: int32 = 0
    if ctx == nil then
        C.printf("FAIL: %s: nil context\n", label)
        return 1
    end
    if count <= 0 then
        C.printf("FAIL: %s: no render commands\n", label)
        return 1
    end

    var rootId = ui.GetElementIdFromChars("integration_root", 16).id

    var rectCmd: ui.RenderCommand
    var borderCmd: ui.RenderCommand
    var paintCmd: ui.RenderCommand
    var textCmd: ui.RenderCommand
    var rectIdx: int32 = -1
    var borderIdx: int32 = -1
    var paintIdx: int32 = -1
    var textIdx: int32 = -1
    var foundText = false

    var foundRect = find_command_for_id_type(ctx, rootId, ui.RENDER_RECTANGLE, &rectCmd, &rectIdx)
    var foundBorder = find_command_for_id_type(ctx, rootId, ui.RENDER_BORDER, &borderCmd, &borderIdx)
    var foundPaint = find_command_for_id_type(ctx, rootId, ui.RENDER_PAINT, &paintCmd, &paintIdx)

    var i: int32 = 0
    while i < count and not foundText do
        var cmd = capi_get_render_command_at_for_context(ctx, i)
        if cmd.commandType == ui.RENDER_TEXT then
            textCmd = cmd
            textIdx = i
            foundText = true
        end
        i = i + 1
    end

    if not foundRect then
        C.printf("FAIL: %s: root rectangle command not found\n", label)
        failed = failed + 1
    end
    if not foundBorder then
        C.printf("FAIL: %s: root border command not found\n", label)
        failed = failed + 1
    end
    if not foundPaint then
        C.printf("FAIL: %s: root paint command not found\n", label)
        failed = failed + 1
    end
    if not foundText then
        C.printf("FAIL: %s: text command not found\n", label)
        failed = failed + 1
    end

    if foundRect then
        if not color_equal(rectCmd.renderData.rectangle.backgroundColor, ui.Color {
            r = [ds.colors.surface_700.r], g = [ds.colors.surface_700.g], b = [ds.colors.surface_700.b], a = [ds.colors.surface_700.a]
        }) then
            C.printf("FAIL: %s: root rectangle background color mismatch\n", label)
            failed = failed + 1
        end
        if not corner_equal(rectCmd.renderData.rectangle.cornerRadius, ui.CornerRadius {
            topLeft = 6.0, topRight = 6.0, bottomLeft = 6.0, bottomRight = 6.0
        }) then
            C.printf("FAIL: %s: root rectangle corner radius mismatch\n", label)
            failed = failed + 1
        end
        if rectCmd.boundingBox.width < 200.0 or rectCmd.boundingBox.height < 100.0 then
            C.printf("FAIL: %s: root rectangle bbox too small (%.1f x %.1f)\n", label, rectCmd.boundingBox.width, rectCmd.boundingBox.height)
            failed = failed + 1
        end
    end

    if foundBorder then
        if not color_equal(borderCmd.renderData.border.color, ui.Color {
            r = [ds.colors.border_default.r], g = [ds.colors.border_default.g], b = [ds.colors.border_default.b], a = [ds.colors.border_default.a]
        }) then
            C.printf("FAIL: %s: root border color mismatch\n", label)
            failed = failed + 1
        end
        if not border_width_equal(borderCmd.renderData.border.width, ui.BorderWidth {
            left = 1, right = 1, top = 1, bottom = 1, betweenChildren = 0
        }) then
            C.printf("FAIL: %s: root border width mismatch\n", label)
            failed = failed + 1
        end
    end

    if foundPaint then
        if paintCmd.renderData.paint.count ~= 4 then
            C.printf("FAIL: %s: paint op count mismatch (%u)\n", label, paintCmd.renderData.paint.count)
            failed = failed + 1
        elseif paintCmd.renderData.paint.ops == nil then
            C.printf("FAIL: %s: paint ops pointer nil\n", label)
            failed = failed + 1
        else
            var op0 = paintCmd.renderData.paint.ops[0]
            var op1 = paintCmd.renderData.paint.ops[1]
            var op2 = paintCmd.renderData.paint.ops[2]
            var op3 = paintCmd.renderData.paint.ops[3]
            if op0.kind ~= ui.PAINT_OP_FILL then
                C.printf("FAIL: %s: paint op0 kind mismatch\n", label)
                failed = failed + 1
            end
            if not color_equal(op0.color, ui.Color {
                r = [ds.colors.primary_500.r], g = [ds.colors.primary_500.g], b = [ds.colors.primary_500.b], a = [ds.colors.primary_500.a]
            }) then
                C.printf("FAIL: %s: paint fill color mismatch\n", label)
                failed = failed + 1
            end
            if op1.kind ~= ui.PAINT_OP_ROUND_RECT or not ui.FloatEqual(op1.x, 4.0) or not ui.FloatEqual(op1.y, 4.0) or
               not ui.FloatEqual(op1.w, 24.0) or not ui.FloatEqual(op1.h, 12.0) or not ui.FloatEqual(op1.r, 3.0) then
                C.printf("FAIL: %s: paint round_rect geometry mismatch\n", label)
                failed = failed + 1
            end
            if op2.kind ~= ui.PAINT_OP_STROKE or op2.width ~= 2 then
                C.printf("FAIL: %s: paint stroke mismatch\n", label)
                failed = failed + 1
            end
            if not color_equal(op2.color, ui.Color {
                r = [ds.colors.primary_700.r], g = [ds.colors.primary_700.g], b = [ds.colors.primary_700.b], a = [ds.colors.primary_700.a]
            }) then
                C.printf("FAIL: %s: paint stroke color mismatch\n", label)
                failed = failed + 1
            end
            if op3.kind ~= ui.PAINT_OP_LINE or not ui.FloatEqual(op3.x, 4.0) or not ui.FloatEqual(op3.y, 20.0) or
               not ui.FloatEqual(op3.x2, 28.0) or not ui.FloatEqual(op3.y2, 20.0) then
                C.printf("FAIL: %s: paint line geometry mismatch\n", label)
                failed = failed + 1
            end
        end
    end

    if foundText then
        if not text_slice_equal(textCmd.renderData.text.stringContents, ui.StringSlice {
            length = 5, chars = "Hello", baseChars = "Hello"
        }) then
            C.printf("FAIL: %s: text contents mismatch\n", label)
            failed = failed + 1
        end
        if not color_equal(textCmd.renderData.text.textColor, ui.Color {
            r = [ds.colors.white.r], g = [ds.colors.white.g], b = [ds.colors.white.b], a = [ds.colors.white.a]
        }) then
            C.printf("FAIL: %s: text color mismatch\n", label)
            failed = failed + 1
        end
        if textCmd.renderData.text.fontSize ~= 14 or textCmd.renderData.text.lineHeight ~= 14 then
            C.printf("FAIL: %s: text metrics mismatch (font=%d line=%d)\n", label,
                [int32](textCmd.renderData.text.fontSize), [int32](textCmd.renderData.text.lineHeight))
            failed = failed + 1
        end
        if foundRect then
            if textCmd.boundingBox.x < rectCmd.boundingBox.x or textCmd.boundingBox.y < rectCmd.boundingBox.y or
               textCmd.boundingBox.x + textCmd.boundingBox.width > rectCmd.boundingBox.x + rectCmd.boundingBox.width + ui.EPSILON or
               textCmd.boundingBox.y + textCmd.boundingBox.height > rectCmd.boundingBox.y + rectCmd.boundingBox.height + ui.EPSILON then
                C.printf("FAIL: %s: text bbox not inside root bbox\n", label)
                failed = failed + 1
            end
        end
    end

    if foundRect and foundPaint and paintIdx <= rectIdx then
        C.printf("FAIL: %s: paint command should come after rectangle (paint=%d rect=%d)\n", label, paintIdx, rectIdx)
        failed = failed + 1
    end
    if foundPaint and foundBorder and borderIdx <= paintIdx then
        C.printf("FAIL: %s: border command should come after paint (border=%d paint=%d)\n", label, borderIdx, paintIdx)
        failed = failed + 1
    end
    if foundText and foundRect and textIdx <= rectIdx then
        C.printf("FAIL: %s: text command should come after root rectangle (text=%d rect=%d)\n", label, textIdx, rectIdx)
        failed = failed + 1
    end

    return failed
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

terra emit_capi_scene(ctx: &ui.Context) : int32
    capi_begin_layout_for_context(ctx, 640.0, 480.0)

    capi_open_element_with_id_chars_for_context(ctx, "integration_root", 16)

    var lc: ui.LayoutConfig
    lc.sizing.width.type = ui.SIZING_FIXED
    lc.sizing.width.size.min = 220.0
    lc.sizing.width.size.max = 220.0
    lc.sizing.width.percent = 0
    lc.sizing.height.type = ui.SIZING_FIXED
    lc.sizing.height.size.min = 120.0
    lc.sizing.height.size.max = 120.0
    lc.sizing.height.percent = 0
    lc.padding.left = 8
    lc.padding.right = 8
    lc.padding.top = 8
    lc.padding.bottom = 8
    lc.childGap = 4
    lc.childAlignment.x = ui.ALIGN_X_LEFT
    lc.childAlignment.y = ui.ALIGN_Y_TOP
    lc.layoutDirection = ui.TOP_TO_BOTTOM
    if not capi_set_open_element_layout_config_for_context(ctx, lc) then
        return -1
    end

    var shared: ui.SharedConfig
    shared.backgroundColor.r = [ds.colors.surface_700.r]
    shared.backgroundColor.g = [ds.colors.surface_700.g]
    shared.backgroundColor.b = [ds.colors.surface_700.b]
    shared.backgroundColor.a = [ds.colors.surface_700.a]
    shared.cornerRadius.topLeft = 6.0
    shared.cornerRadius.topRight = 6.0
    shared.cornerRadius.bottomLeft = 6.0
    shared.cornerRadius.bottomRight = 6.0
    shared.userData = nil
    if not capi_attach_shared_config_for_context(ctx, shared) then
        return -2
    end

    var border: ui.BorderConfig
    border.color.r = [ds.colors.border_default.r]
    border.color.g = [ds.colors.border_default.g]
    border.color.b = [ds.colors.border_default.b]
    border.color.a = [ds.colors.border_default.a]
    border.width.left = 1
    border.width.right = 1
    border.width.top = 1
    border.width.bottom = 1
    border.width.betweenChildren = 0
    if not capi_attach_border_config_for_context(ctx, border) then
        return -3
    end

    var paint_ops = arrayof(ui.PaintOp,
        ui.PaintOp {
            kind = ui.PAINT_OP_FILL,
            color = ui.Color { r = [ds.colors.primary_500.r], g = [ds.colors.primary_500.g], b = [ds.colors.primary_500.b], a = [ds.colors.primary_500.a] },
            x = 0.0, y = 0.0, w = 0.0, h = 0.0, r = 0.0, x2 = 0.0, y2 = 0.0, width = 1
        },
        ui.PaintOp {
            kind = ui.PAINT_OP_ROUND_RECT,
            color = ui.Color { r = 0.0, g = 0.0, b = 0.0, a = 1.0 },
            x = 4.0, y = 4.0, w = 24.0, h = 12.0, r = 3.0, x2 = 0.0, y2 = 0.0, width = 1
        },
        ui.PaintOp {
            kind = ui.PAINT_OP_STROKE,
            color = ui.Color { r = [ds.colors.primary_700.r], g = [ds.colors.primary_700.g], b = [ds.colors.primary_700.b], a = [ds.colors.primary_700.a] },
            x = 0.0, y = 0.0, w = 0.0, h = 0.0, r = 0.0, x2 = 0.0, y2 = 0.0, width = 2
        },
        ui.PaintOp {
            kind = ui.PAINT_OP_LINE,
            color = ui.Color { r = 0.0, g = 0.0, b = 0.0, a = 1.0 },
            x = 4.0, y = 20.0, w = 0.0, h = 0.0, r = 0.0, x2 = 28.0, y2 = 20.0, width = 1
        }
    )
    var pc: ui.PaintConfig
    pc.ops = paint_ops
    pc.count = 4
    if not capi_attach_paint_config_for_context(ctx, pc) then
        return -4
    end

    capi_open_element_with_id_chars_for_context(ctx, "integration_label", 17)
    var txt: ui.TextConfig
    txt.userData = nil
    txt.textColor.r = [ds.colors.white.r]
    txt.textColor.g = [ds.colors.white.g]
    txt.textColor.b = [ds.colors.white.b]
    txt.textColor.a = [ds.colors.white.a]
    txt.fontId = 0
    txt.fontSize = 14
    txt.letterSpacing = 0
    txt.lineHeight = 14
    txt.wrapMode = ui.TEXT_WRAP_WORDS
    txt.textAlignment = ui.TEXT_ALIGN_LEFT
    capi_open_text_element_with_length_for_context(ctx, "Hello", 5, &txt)
    capi_close_element_for_context(ctx)

    capi_close_element_for_context(ctx)

    return capi_finalize_layout_for_context(ctx)
end

terra run_v2_integration_test() : int32
    var failed: int32 = 0

    var arena_dsl: ui.Arena
    var arena_capi: ui.Arena
    var ctx_dsl: ui.Context
    var ctx_capi: ui.Context

    if not init_context(&ctx_dsl, &arena_dsl, 512) then
        C.printf("FAIL: could not initialize DSL context\n")
        free_context_arena(&arena_dsl)
        return 1
    end

    if not init_context(&ctx_capi, &arena_capi, 512) then
        C.printf("FAIL: could not initialize CAPI context\n")
        free_context_arena(&arena_dsl)
        free_context_arena(&arena_capi)
        return 1
    end

    ui.SetMeasureTextFunction(integration_mock_measure_text, nil)
    ui.ResetMeasureTextCache()

    ui.SetCurrentContext(&ctx_dsl)
    ui.BeginLayoutForContext(&ctx_dsl, 640.0, 480.0)
    [compiled_dsl_scene]
    var dsl_count = ui.FinalizeLayoutForContext(&ctx_dsl)
    if dsl_count <= 0 then
        C.printf("FAIL: DSL scene generated no render commands\n")
        failed = failed + 1
    end

    var capi_count = emit_capi_scene(&ctx_capi)
    if capi_count < 0 then
        C.printf("FAIL: CAPI scene emission failed (code %d)\n", capi_count)
        failed = failed + 1
    elseif capi_count <= 0 then
        C.printf("FAIL: CAPI scene generated no render commands\n")
        failed = failed + 1
    end

    if dsl_count > 0 and capi_count > 0 then
        var dsl_count_buf = capi_get_render_command_count_for_context(&ctx_dsl)
        var capi_count_buf = capi_get_render_command_count_for_context(&ctx_capi)
        if dsl_count ~= capi_count then
            C.printf("FAIL: command count mismatch DSL=%d CAPI=%d\n", dsl_count, capi_count)
            failed = failed + 1
        end
        if dsl_count_buf ~= [uint32](dsl_count) or capi_count_buf ~= [uint32](capi_count) then
            C.printf("FAIL: GetRenderCommandCountForContext mismatch DSL=%u/%d CAPI=%u/%d\n",
                dsl_count_buf, dsl_count, capi_count_buf, capi_count)
            failed = failed + 1
        end

        var found_rect = false
        var found_text = false
        var found_paint = false
        var found_border = false

        var i: int32 = 0
        while i < dsl_count and i < capi_count do
            var dcmd = capi_get_render_command_at_for_context(&ctx_dsl, i)
            var ccmd = capi_get_render_command_at_for_context(&ctx_capi, i)
            if not command_equal(dcmd, ccmd) then
                C.printf("FAIL: render command mismatch at index %d (dsl type=%d id=%u, capi type=%d id=%u)\n",
                    i, [int32](dcmd.commandType), dcmd.id, [int32](ccmd.commandType), ccmd.id)
                failed = failed + 1
            end
            if dcmd.commandType == ui.RENDER_RECTANGLE then found_rect = true end
            if dcmd.commandType == ui.RENDER_TEXT then found_text = true end
            if dcmd.commandType == ui.RENDER_PAINT then found_paint = true end
            if dcmd.commandType == ui.RENDER_BORDER then found_border = true end
            i = i + 1
        end

        if not found_rect then
            C.printf("FAIL: integration scene emitted no rectangle command\n")
            failed = failed + 1
        end
        if not found_text then
            C.printf("FAIL: integration scene emitted no text command\n")
            failed = failed + 1
        end
        if not found_paint then
            C.printf("FAIL: integration scene emitted no paint command\n")
            failed = failed + 1
        end
        if not found_border then
            C.printf("FAIL: integration scene emitted no border command\n")
            failed = failed + 1
        end

        failed = failed + validate_expected_scene_correctness(&ctx_dsl, dsl_count, "dsl")
        failed = failed + validate_expected_scene_correctness(&ctx_capi, capi_count, "capi")
    end

    var arena_hover: ui.Arena
    var ctx_hover: ui.Context
    if not init_context(&ctx_hover, &arena_hover, 256) then
        C.printf("FAIL: could not initialize hover context\n")
        failed = failed + 1
    else
        ui.SetCurrentContext(&ctx_hover)

        var p_out: ui.Vector2
        p_out.x = 500.0
        p_out.y = 500.0
        ui.SetPointerStateForContext(&ctx_hover, p_out, false)

        ui.BeginLayoutForContext(&ctx_hover, 320.0, 200.0)
        [compiled_hover_dsl_scene]
        var hover_off_count = ui.FinalizeLayoutForContext(&ctx_hover)
        if hover_off_count <= 0 then
            C.printf("FAIL: hover scene (off) generated no commands\n")
            failed = failed + 1
        else
            var hoverId = ui.GetElementIdFromChars("hover_probe", 11)
            var offRect: ui.RenderCommand
            var offRectIdx: int32 = -1
            if not find_command_for_id_type(&ctx_hover, hoverId.id, ui.RENDER_RECTANGLE, &offRect, &offRectIdx) then
                C.printf("FAIL: hover scene (off) root rectangle not found\n")
                failed = failed + 1
            elseif not color_equal(offRect.renderData.rectangle.backgroundColor, ui.Color {
                r = [ds.colors.surface_700.r], g = [ds.colors.surface_700.g], b = [ds.colors.surface_700.b], a = [ds.colors.surface_700.a]
            }) then
                C.printf("FAIL: hover scene (off) rectangle color mismatch\n")
                failed = failed + 1
            end

            var p_in: ui.Vector2
            p_in.x = 10.0
            p_in.y = 10.0
            ui.SetPointerStateForContext(&ctx_hover, p_in, false)
            if not ui.PointerOver(hoverId) then
                C.printf("FAIL: pointer should be over hover_probe after SetPointerStateForContext\n")
                failed = failed + 1
            end

            ui.BeginLayoutForContext(&ctx_hover, 320.0, 200.0)
            [compiled_hover_dsl_scene]
            var hover_on_count = ui.FinalizeLayoutForContext(&ctx_hover)
            if hover_on_count <= 0 then
                C.printf("FAIL: hover scene (on) generated no commands\n")
                failed = failed + 1
            else
                var onRect: ui.RenderCommand
                var onRectIdx: int32 = -1
                if not find_command_for_id_type(&ctx_hover, hoverId.id, ui.RENDER_RECTANGLE, &onRect, &onRectIdx) then
                    C.printf("FAIL: hover scene (on) root rectangle not found\n")
                    failed = failed + 1
                else
                    if not color_equal(onRect.renderData.rectangle.backgroundColor, ui.Color {
                        r = [ds.colors.primary_500.r], g = [ds.colors.primary_500.g], b = [ds.colors.primary_500.b], a = [ds.colors.primary_500.a]
                    }) then
                        C.printf("FAIL: hover scene (on) rectangle did not switch to hover color\n")
                        failed = failed + 1
                    end
                    if color_equal(onRect.renderData.rectangle.backgroundColor, offRect.renderData.rectangle.backgroundColor) then
                        C.printf("FAIL: hover scene rectangle color unchanged between off/on frames\n")
                        failed = failed + 1
                    end
                end
            end
        end

        free_context_arena(&arena_hover)
    end

    free_context_arena(&arena_dsl)
    free_context_arena(&arena_capi)
    return failed
end

local rc = run_v2_integration_test()
if rc == 0 then
    print("test_integration_v2: PASS")
else
    print("test_integration_v2: FAIL (" .. tostring(rc) .. " checks)")
end
os.exit(rc)
