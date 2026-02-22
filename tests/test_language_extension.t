local C = terralib.includecstring[[
    #include <stdio.h>
    #include <stdlib.h>
]]

local ui = require("src.builder")
local ds = require("src/style/default_theme")
import "src/lang.argile"

local compiled_expr = argile el
    id("lang_expr_root")
    layout
        width_fixed(640.0)
        height_fixed(480.0)
        dir(top_to_bottom)
    end
    style
        bg(ds.colors.surface_800)
    end
    el
        id("lang_expr_child")
        layout
            width_fixed(120.0)
            height_fixed(32.0)
        end
        style
            bg(ds.colors.primary_500)
        end
    end
end

local dsl_root_id = "lang_dsl_root"
local dsl_text = "dsl text node"
local compiled_dsl = argile el
    id(dsl_root_id)
    layout
        width_fixed(520.0)
        height_fixed(300.0)
        dir(top_to_bottom)
        padding(10)
        gap(6)
    end
    use(ds.panel())
    text(dsl_text)
        use(ds.text.body())
        typography
            align(center)
        end
    end
    el
        id("lang_dsl_child")
        layout
            width_grow
            height_fixed(40)
        end
    end
end

local compiled_dsl_end = argile el
    id("lang_dsl_end_root")
    layout
        width_fixed(360.0)
        height_fixed(220.0)
        dir(top_to_bottom)
        padding(8)
        gap(4)
    end
    use(ds.panel())
    text("dsl end style")
        use(ds.text.muted())
        typography
            align(left)
        end
    end
    el
        id("lang_dsl_end_child")
        layout
            width_grow
            height_fixed(24.0)
        end
    end
end

argile compiled_stmt = el
    id("lang_stmt_root")
    layout
        width_fixed(320.0)
        height_fixed(120.0)
    end
    style
        bg(ds.colors.surface_600)
    end
end

argile compiled_stmt_dsl = el
    id("lang_stmt_dsl_root")
    layout
        width_fixed(280.0)
        height_fixed(90.0)
        padding(6)
    end
    use(ds.panel())
    text("statement dsl")
end

do
    local argile compiled_local = el
        id("lang_local_root")
        layout
            width_fixed(240.0)
            height_fixed(100.0)
        end
        style
            bg(ds.colors.primary_700)
        end
    end
    _G.__compiled_local_layout = compiled_local
end

do
    local argile compiled_local_dsl = el
        id("lang_local_dsl_root")
        layout
            width_fixed(220.0)
            height_fixed(70.0)
        end
        use(ds.panel())
        text("local statement dsl")
    end
    _G.__compiled_local_dsl_layout = compiled_local_dsl
end

local compiled_button = argile el
    id("test_button")
    use(ds.button({ tone = "primary", size = "md" }))
    text("Click Me")
        use(ds.text.button())
    end
end

local compiled_with_state = argile el
    id("stateful_element")
    use(ds.button({ tone = "primary" }))
    when hover
        style
            bg(ds.colors.primary_600)
        end
    end
    text("Hover Me")
        use(ds.text.button())
    end
end

local compiled_with_paint = argile el
    id("painted_element")
    layout
        width_fixed(100.0)
        height_fixed(100.0)
    end
    style
        bg(ds.colors.surface_800)
        radius(8.0)
    end
    paint
        fill(ds.colors.primary_500)
        round_rect(10, 10, 80, 80, 8)
        stroke(ds.colors.primary_700, 2)
        line(10, 50, 90, 50)
    end
end

local compiled_hover_style = argile el
    id("hover_style_test")
    layout
        width_fixed(80.0)
        height_fixed(40.0)
    end
    style
        bg(ds.colors.surface_600)
    end
    when hover
        style
            bg(ds.colors.primary_500)
        end
    end
end

local compiled_hover_paint = argile el
    id("hover_paint_test")
    layout
        width_fixed(60.0)
        height_fixed(60.0)
    end
    style
        bg(ds.colors.surface_700)
    end
    paint
        fill(ds.colors.surface_500)
    end
    when hover
        paint
            fill(ds.colors.primary_400)
        end
    end
end

local compiled_text_with_body_id = argile text("Hoverable Label")
    id("hoverable_text")
    style
        bg(ds.colors.surface_700)
    end
    when hover
        style
            bg(ds.colors.primary_500)
        end
    end
    typography
        color(ds.colors.white)
    end
end

if not terralib.isquote(compiled_expr) then
    error("argile expression form did not produce a Terra quote")
end
if not terralib.isquote(compiled_dsl) then
    error("argile DSL form did not produce a Terra quote")
end
if not terralib.isquote(compiled_dsl_end) then
    error("argile end-style DSL form did not produce a Terra quote")
end
if not terralib.isquote(compiled_stmt) then
    error("argile statement form did not produce a Terra quote")
end
if not terralib.isquote(compiled_stmt_dsl) then
    error("argile statement DSL form did not produce a Terra quote")
end
if not terralib.isquote(_G.__compiled_local_layout) then
    error("argile local statement form did not produce a Terra quote")
end
if not terralib.isquote(_G.__compiled_local_dsl_layout) then
    error("argile local statement DSL form did not produce a Terra quote")
end
if not terralib.isquote(compiled_button) then
    error("argile button with recipe did not produce a Terra quote")
end
if not terralib.isquote(compiled_with_state) then
    error("argile stateful element did not produce a Terra quote")
end
if not terralib.isquote(compiled_with_paint) then
    error("argile element with paint did not produce a Terra quote")
end
if not terralib.isquote(compiled_hover_style) then
    error("argile hover style element did not produce a Terra quote")
end
if not terralib.isquote(compiled_hover_paint) then
    error("argile hover paint element did not produce a Terra quote")
end
if not terralib.isquote(compiled_text_with_body_id) then
    error("argile text node with body id did not produce a Terra quote")
end

terra run_language_extension_test() : int32
    var failed = int32(0)

    var arena: ui.Arena
    arena.nextAllocation = 0
    arena.capacity = 4 * 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))
    if arena.memory == nil then
        C.printf("FAIL: malloc failed\n")
        return 1
    end

    var ctx: ui.Context
    ui.SetCurrentContext(&ctx)
    if not ctx:initialize(&arena, 512) then
        C.printf("FAIL: context initialization failed\n")
        C.free(arena.memory)
        return 1
    end

    ui.BeginLayout(640.0, 480.0)
    [compiled_expr]
    var cmd_count_expr = ui.FinalizeLayout()
    if cmd_count_expr <= 0 then
        C.printf("FAIL: expression form generated no commands\n")
        failed = failed + 1
    end

    ui.BeginLayout(640.0, 480.0)
    [compiled_dsl]
    var cmd_count_dsl = ui.FinalizeLayout()
    if cmd_count_dsl <= 0 then
        C.printf("FAIL: DSL form generated no commands\n")
        failed = failed + 1
    end

    ui.BeginLayout(640.0, 480.0)
    [compiled_dsl_end]
    var cmd_count_dsl_end = ui.FinalizeLayout()
    if cmd_count_dsl_end <= 0 then
        C.printf("FAIL: end-style DSL form generated no commands\n")
        failed = failed + 1
    end

    ui.BeginLayout(640.0, 480.0)
    [compiled_stmt]
    var cmd_count_stmt = ui.FinalizeLayout()
    if cmd_count_stmt <= 0 then
        C.printf("FAIL: statement form generated no commands\n")
        failed = failed + 1
    end

    ui.BeginLayout(640.0, 480.0)
    [compiled_stmt_dsl]
    var cmd_count_stmt_dsl = ui.FinalizeLayout()
    if cmd_count_stmt_dsl <= 0 then
        C.printf("FAIL: statement DSL form generated no commands\n")
        failed = failed + 1
    end

    ui.BeginLayout(640.0, 480.0)
    [_G.__compiled_local_layout]
    var cmd_count_local = ui.FinalizeLayout()
    if cmd_count_local <= 0 then
        C.printf("FAIL: local statement form generated no commands\n")
        failed = failed + 1
    end

    ui.BeginLayout(640.0, 480.0)
    [_G.__compiled_local_dsl_layout]
    var cmd_count_local_dsl = ui.FinalizeLayout()
    if cmd_count_local_dsl <= 0 then
        C.printf("FAIL: local statement DSL form generated no commands\n")
        failed = failed + 1
    end

    ui.BeginLayout(640.0, 480.0)
    [compiled_button]
    var cmd_count_button = ui.FinalizeLayout()
    if cmd_count_button <= 0 then
        C.printf("FAIL: button with recipe generated no commands\n")
        failed = failed + 1
    end

    ui.BeginLayout(640.0, 480.0)
    [compiled_with_state]
    var cmd_count_state = ui.FinalizeLayout()
    if cmd_count_state <= 0 then
        C.printf("FAIL: stateful element generated no commands\n")
        failed = failed + 1
    end

    ui.BeginLayout(640.0, 480.0)
    [compiled_with_paint]
    var cmd_count_paint = ui.FinalizeLayout()
    if cmd_count_paint <= 0 then
        C.printf("FAIL: element with paint generated no commands\n")
        failed = failed + 1
    else
        var found_paint = false
        var found_rect = false
        var paint_index: int32 = -1
        var rect_index: int32 = -1
        var i: int32 = 0
        while i < cmd_count_paint do
            var cmd = ui.GetRenderCommandAt(i)
            if cmd.commandType == ui.RENDER_RECTANGLE then
                found_rect = true
                rect_index = i
            end
            if cmd.commandType == ui.RENDER_PAINT then
                found_paint = true
                paint_index = i
                if cmd.renderData.paint.count ~= 4 then
                    C.printf("FAIL: paint command count expected 4, got %d\n", [int32](cmd.renderData.paint.count))
                    failed = failed + 1
                elseif cmd.renderData.paint.ops == nil then
                    C.printf("FAIL: paint ops pointer is nil\n")
                    failed = failed + 1
                else
                    var op0 = cmd.renderData.paint.ops[0]
                    var op1 = cmd.renderData.paint.ops[1]
                    var op2 = cmd.renderData.paint.ops[2]
                    var op3 = cmd.renderData.paint.ops[3]
                    if op0.kind ~= ui.PAINT_OP_FILL then
                        C.printf("FAIL: paint op0 kind expected FILL, got %d\n", [int32](op0.kind))
                        failed = failed + 1
                    end
                    if op1.kind ~= ui.PAINT_OP_ROUND_RECT then
                        C.printf("FAIL: paint op1 kind expected ROUND_RECT, got %d\n", [int32](op1.kind))
                        failed = failed + 1
                    end
                    if not ui.FloatEqual(op1.x, 10.0) or not ui.FloatEqual(op1.y, 10.0) or
                       not ui.FloatEqual(op1.w, 80.0) or not ui.FloatEqual(op1.h, 80.0) then
                        C.printf("FAIL: round_rect geometry mismatch (%.1f, %.1f, %.1f, %.1f)\n", op1.x, op1.y, op1.w, op1.h)
                        failed = failed + 1
                    end
                    if op2.kind ~= ui.PAINT_OP_STROKE or op2.width ~= 2 then
                        C.printf("FAIL: paint op2 stroke mismatch kind=%d width=%d\n", [int32](op2.kind), [int32](op2.width))
                        failed = failed + 1
                    end
                    if op3.kind ~= ui.PAINT_OP_LINE then
                        C.printf("FAIL: paint op3 kind expected LINE, got %d\n", [int32](op3.kind))
                        failed = failed + 1
                    end
                    if not ui.FloatEqual(op3.x, 10.0) or not ui.FloatEqual(op3.y, 50.0) or
                       not ui.FloatEqual(op3.x2, 90.0) or not ui.FloatEqual(op3.y2, 50.0) then
                        C.printf("FAIL: line geometry mismatch (%.1f, %.1f -> %.1f, %.1f)\n", op3.x, op3.y, op3.x2, op3.y2)
                        failed = failed + 1
                    end
                end
            end
            i = i + 1
        end
        if not found_paint then
            C.printf("FAIL: no RENDER_PAINT command found\n")
            failed = failed + 1
        end
        if not found_rect then
            C.printf("FAIL: painted element did not emit rectangle background command\n")
            failed = failed + 1
        elseif paint_index <= rect_index then
            C.printf("FAIL: paint command should be emitted after rectangle (paint=%d rect=%d)\n", paint_index, rect_index)
            failed = failed + 1
        end
    end

    -- Test hover style: verify compilation and command generation
    -- Note: Full hover behavior testing requires multi-frame simulation
    -- Here we just verify the element compiles and generates commands
    ui.BeginLayout(640.0, 480.0)
    [compiled_hover_style]
    var hover_style_cmds = ui.FinalizeLayout()
    if hover_style_cmds <= 0 then
        C.printf("FAIL: hover style element generated no commands\n")
        failed = failed + 1
    else
        var found_rect = false
        var i: int32 = 0
        while i < hover_style_cmds do
            var cmd = ui.GetRenderCommandAt(i)
            if cmd.commandType == ui.RENDER_RECTANGLE then
                found_rect = true
            end
            i = i + 1
        end
        if not found_rect then
            C.printf("FAIL: hover style element no rectangle found\n")
            failed = failed + 1
        end
    end

    -- Test hover paint: verify compilation and command generation
    ui.BeginLayout(640.0, 480.0)
    [compiled_hover_paint]
    var hover_paint_cmds = ui.FinalizeLayout()
    if hover_paint_cmds <= 0 then
        C.printf("FAIL: hover paint element generated no commands\n")
        failed = failed + 1
    else
        var found_paint = false
        var i: int32 = 0
        while i < hover_paint_cmds do
            var cmd = ui.GetRenderCommandAt(i)
            if cmd.commandType == ui.RENDER_PAINT then
                found_paint = true
            end
            i = i + 1
        end
        if not found_paint then
            C.printf("FAIL: hover paint element no paint command found\n")
            failed = failed + 1
        end
    end

    ui.BeginLayout(640.0, 480.0)
    [compiled_text_with_body_id]
    var text_with_body_id_cmds = ui.FinalizeLayout()
    if text_with_body_id_cmds <= 0 then
        C.printf("FAIL: text node with body id generated no commands\n")
        failed = failed + 1
    end

    var id_from_chars = ui.GetElementIdFromChars("id_test", 7)
    var id_from_string = ui.GetElementId(ui.StringFromChars("id_test", 7))
    if id_from_chars.id ~= id_from_string.id then
        C.printf("FAIL: GetElementIdFromChars mismatch\n")
        failed = failed + 1
    end

    ui.BeginLayout(640.0, 480.0)
    ui.OpenElementWithIdChars("capi_root", 9)

    var lc: ui.LayoutConfig
    lc.sizing.width.type = ui.SIZING_FIXED
    lc.sizing.width.size.min = 300.0
    lc.sizing.width.size.max = 300.0
    lc.sizing.width.percent = 0
    lc.sizing.height.type = ui.SIZING_FIXED
    lc.sizing.height.size.min = 80.0
    lc.sizing.height.size.max = 80.0
    lc.sizing.height.percent = 0
    lc.padding.left = 4
    lc.padding.right = 4
    lc.padding.top = 4
    lc.padding.bottom = 4
    lc.childGap = 2
    lc.childAlignment.x = ui.ALIGN_X_LEFT
    lc.childAlignment.y = ui.ALIGN_Y_TOP
    lc.layoutDirection = ui.LEFT_TO_RIGHT

    if not ui.SetOpenElementLayoutConfig(lc) then
        C.printf("FAIL: SetOpenElementLayoutConfig failed\n")
        failed = failed + 1
    end

    var shared: ui.SharedConfig
    shared.backgroundColor.r = 0.2
    shared.backgroundColor.g = 0.4
    shared.backgroundColor.b = 0.6
    shared.backgroundColor.a = 1.0
    shared.cornerRadius.topLeft = 6.0
    shared.cornerRadius.topRight = 6.0
    shared.cornerRadius.bottomLeft = 6.0
    shared.cornerRadius.bottomRight = 6.0
    shared.userData = nil

    if not ui.AttachSharedConfig(shared) then
        C.printf("FAIL: AttachSharedConfig failed\n")
        failed = failed + 1
    end

    var border: ui.BorderConfig
    border.color.r = 1.0
    border.color.g = 1.0
    border.color.b = 1.0
    border.color.a = 1.0
    border.width.left = 1
    border.width.right = 1
    border.width.top = 1
    border.width.bottom = 1
    border.width.betweenChildren = 0
    if not ui.AttachBorderConfig(border) then
        C.printf("FAIL: AttachBorderConfig failed\n")
        failed = failed + 1
    end

    var text_cfg: ui.TextConfig
    text_cfg.userData = nil
    text_cfg.textColor.r = 1.0
    text_cfg.textColor.g = 1.0
    text_cfg.textColor.b = 1.0
    text_cfg.textColor.a = 1.0
    text_cfg.fontId = 0
    text_cfg.fontSize = 14
    text_cfg.letterSpacing = 0
    text_cfg.lineHeight = 14
    text_cfg.wrapMode = ui.TEXT_WRAP_WORDS
    text_cfg.textAlignment = ui.TEXT_ALIGN_LEFT
    ui.OpenTextElementWithLength("hello bindings", 14, &text_cfg)

    ui.CloseElement()
    var cmd_count_capi = ui.FinalizeLayout()
    if cmd_count_capi <= 0 then
        C.printf("FAIL: C helper API generated no commands\n")
        failed = failed + 1
    end

    C.free(arena.memory)
    return failed
end

local rc = run_language_extension_test()
if rc == 0 then
    print("test_language_extension: PASS")
else
    print("test_language_extension: FAIL (" .. tostring(rc) .. " checks)")
end
os.exit(rc)
