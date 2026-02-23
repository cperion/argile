local C = terralib.includecstring [[
#include <stdio.h>
#include <stdlib.h>
]]

local ui = require("src.builder")
local style = require("src/style/core")
import "src/lang.argile_v3"

local inherited_text_patch = style.StylePatch:new()
inherited_text_patch.textConfig = {
    textColor = { r = 0.9, g = 0.9, b = 0.95, a = 1.0 },
    fontSize = 17,
    lineHeight = 21,
}

local scene = argile
    el id("root")
        layout width_grow() height_grow() dir(top_to_bottom) padding(10) gap(6) end
        style bg({ r = 0.10, g = 0.10, b = 0.12, a = 1.0 }) end
        el id("panel")
            use(inherited_text_patch)
            layout width_grow() height_grow() dir(top_to_bottom) padding(8) gap(4) end
            style bg({ r = 0.18, g = 0.20, b = 0.24, a = 1.0 }) end
            text("Alpha Beta")
                part(title_line)
            end
            el id("row")
                layout width_grow() height_fit() dir(left_to_right) gap(5) end
                text("A")
                    part(cell_a)
                end
                text("B")
                    part(cell_b)
                end
            end
        end
    end
end

local compiled_scene = ui.compileResolved(scene)

local measure_calls = global(int32, 0)
local inherited_cfg_hits = global(int32, 0)

terra test_measure_text(text: &ui.StringSlice, cfg: &ui.TextConfig, _userData: &opaque, out: &ui.Dimensions) : int32
    if out == nil then return 0 end
    out.width = 0.0
    out.height = 0.0
    if text == nil then return 0 end

    measure_calls = measure_calls + 1
    if cfg ~= nil and cfg.fontSize == 17 and cfg.lineHeight == 21 then
        inherited_cfg_hits = inherited_cfg_hits + 1
    end

    var len = text.length
    if len < 0 then len = 0 end
    out.width = [float](len) * 7.0
    if cfg ~= nil and cfg.lineHeight > 0 then
        out.height = [float](cfg.lineHeight)
    else
        out.height = 16.0
    end
    return 1
end

terra find_rect_for_id(cmds: &ui.RenderCommand, count: int32, targetId: uint32, outCmd: &ui.RenderCommand) : bool
    var i: int32 = 0
    while i < count do
        var cmd = &cmds[i]
        if cmd.commandType == [uint8](ui.RENDER_RECTANGLE) and cmd.id == targetId then
            if outCmd ~= nil then @outCmd = @cmd end
            return true
        end
        i = i + 1
    end
    return false
end

terra approx_eq(a: float, b: float) : bool
    var d = a - b
    if d < 0.0 then d = -d end
    return d <= 0.01
end

terra run_test() : int32
    var failed: int32 = 0
    var arena_bytes: uint64 = 8 * 1024 * 1024
    var arena_mem = C.malloc(arena_bytes)
    if arena_mem == nil then
        C.printf("FAIL: arena alloc failed\n")
        return 1
    end

    var arena = ui.CreateArenaWithCapacityAndMemory(arena_bytes, [&int8](arena_mem))
    var dims: ui.Dimensions
    dims.width = 400.0
    dims.height = 300.0
    var ctx = ui.Initialize(arena, dims)
    if ctx == nil then
        C.printf("FAIL: ui.Initialize returned nil\n")
        C.free(arena_mem)
        return 1
    end

    measure_calls = 0
    inherited_cfg_hits = 0

    ui.SetCurrentContext(ctx)
    ui.SetMeasureTextFunctionForContext(ctx, test_measure_text, nil)
    ui.BeginLayoutForContext(ctx, 400.0, 300.0)
    [compiled_scene]
    var count = ui.FinalizeLayoutForContext(ctx)
    if count <= 0 then
        C.printf("FAIL: no render commands emitted\n")
        failed = failed + 1
    end

    if measure_calls <= 0 then
        C.printf("FAIL: text measurement callback was not invoked\n")
        failed = failed + 1
    end
    if inherited_cfg_hits <= 0 then
        C.printf("FAIL: inherited textConfig did not reach text elements\n")
        failed = failed + 1
    end

    var cmds = ui.GetRenderCommandBufferForContext(ctx)
    var rootId = ui.GetElementIdFromChars("root", 4).id
    var panelId = ui.GetElementIdFromChars("panel", 5).id

    var rootRect: ui.RenderCommand
    if not find_rect_for_id(cmds, count, rootId, &rootRect) then
        C.printf("FAIL: root rectangle command not found\n")
        failed = failed + 1
    else
        if not approx_eq(rootRect.boundingBox.x, 0.0) or not approx_eq(rootRect.boundingBox.y, 0.0) or
           not approx_eq(rootRect.boundingBox.width, 400.0) or not approx_eq(rootRect.boundingBox.height, 300.0) then
            C.printf("FAIL: root layout_ops not applied (bbox=%.1f,%.1f %.1fx%.1f)\n",
                rootRect.boundingBox.x, rootRect.boundingBox.y, rootRect.boundingBox.width, rootRect.boundingBox.height)
            failed = failed + 1
        end
    end

    var panelRect: ui.RenderCommand
    if not find_rect_for_id(cmds, count, panelId, &panelRect) then
        C.printf("FAIL: panel rectangle command not found\n")
        failed = failed + 1
    else
        if not approx_eq(panelRect.boundingBox.x, 10.0) or not approx_eq(panelRect.boundingBox.y, 10.0) then
            C.printf("FAIL: panel padding/layout mismatch (x=%.1f y=%.1f)\n",
                panelRect.boundingBox.x, panelRect.boundingBox.y)
            failed = failed + 1
        end
        if panelRect.boundingBox.width < 379.0 or panelRect.boundingBox.height < 279.0 then
            C.printf("FAIL: panel grow sizing mismatch (%.1fx%.1f)\n",
                panelRect.boundingBox.width, panelRect.boundingBox.height)
            failed = failed + 1
        end
    end

    var text_count: int32 = 0
    var first_text_y: float = 0.0
    var second_text_y: float = 0.0
    var first_text_font_size: uint16 = 0
    var i: int32 = 0
    while i < count do
        var cmd = &cmds[i]
        if cmd.commandType == [uint8](ui.RENDER_TEXT) then
            if text_count == 0 then
                first_text_y = cmd.boundingBox.y
                first_text_font_size = cmd.renderData.text.fontSize
            elseif text_count == 1 then
                second_text_y = cmd.boundingBox.y
            end
            text_count = text_count + 1
        end
        i = i + 1
    end

    if text_count < 3 then
        C.printf("FAIL: expected >=3 text commands, got %d\n", text_count)
        failed = failed + 1
    end
    if first_text_font_size ~= 17 then
        C.printf("FAIL: inherited fontSize missing on render command (got %u)\n", first_text_font_size)
        failed = failed + 1
    end
    if text_count >= 2 and not (second_text_y > first_text_y) then
        C.printf("FAIL: panel top_to_bottom layout not applied to text flow (y1=%.1f y2=%.1f)\n",
            first_text_y, second_text_y)
        failed = failed + 1
    end

    C.free(arena_mem)

    if failed == 0 then
        C.printf("test_v3_compile_resolved_regressions: PASS\n")
    else
        C.printf("test_v3_compile_resolved_regressions: FAIL (%d checks)\n", failed)
    end
    return failed
end

local rc = run_test()
if rc ~= 0 then
    error("test_v3_compile_resolved_regressions failed")
end
