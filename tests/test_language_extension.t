local C = terralib.includecstring[[
    #include <stdio.h>
    #include <stdlib.h>
]]

local ui = require("src.builder")
import "src.lang.argile"

local compiled_expr = argile el("lang_expr_root")
    layout
        width_fixed(640.0)
        height_fixed(480.0)
        dir(top_to_bottom)
    end
    shared
        color(0.15, 0.2, 0.3, 1.0)
    end
    el("lang_expr_child")
        layout
            width_fixed(120.0)
            height_fixed(32.0)
        end
        shared
            color(0.7, 0.2, 0.1, 1.0)
        end
    end
end

local dsl_root_id = "lang_dsl_root"
local dsl_text = "dsl text node"
local dsl_border_width = 2
local compiled_dsl = argile el(dsl_root_id)
    layout
        width_fixed(520.0)
        height_fixed(300.0)
        dir(top_to_bottom)
        padding(10)
        gap(6)
    end
    shared
        color(0.08, 0.12, 0.2, 1.0)
        radius(5.0)
    end
    border
        color(0.9, 0.3, 0.2, 1.0)
        width(dsl_border_width)
    end
    clip
        horizontal(true)
        vertical(true)
        offset(1.0, 2.0)
    end
    aspect
        ratio(1.6)
    end
    floating
        offset(2.0, 3.0)
        expand(0.0, 0.0)
        parent_id(0)
        z_index(1)
        element_attach(center_top)
        parent_attach(center_top)
        pointer_capture(capture)
        attach_to(parent)
        clip_to(attached_parent)
    end
    text(dsl_text)
        textcfg
            color(1.0, 1.0, 1.0, 1.0)
            font_size(15)
            line_height(18)
            wrap(words)
            align(center)
        end
    end
    el("lang_dsl_child")
        layout
            width_grow
            height_fixed(40)
        end
        custom
            data(nil)
        end
        image
            data(nil)
        end
    end
end

local compiled_dsl_end = argile el("lang_dsl_end_root")
    layout
        width_fixed(360.0)
        height_fixed(220.0)
        dir(top_to_bottom)
        padding(8)
        gap(4)
    end
    shared
        color(0.11, 0.16, 0.24, 1.0)
        radius(4.0)
    end
    border
        color(0.95, 0.7, 0.2, 1.0)
        width(1)
    end
    text("dsl end style")
        textcfg
            color(1.0, 1.0, 0.9, 1.0)
            font_size(13)
            line_height(16)
            wrap(words)
            align(left)
        end
    end
    el("lang_dsl_end_child")
        layout
            width_grow
            height_fixed(24.0)
        end
        custom
            data(nil)
        end
    end
end

argile compiled_stmt = el("lang_stmt_root")
    layout
        width_fixed(320.0)
        height_fixed(120.0)
    end
    shared
        color(0.3, 0.35, 0.4, 1.0)
    end
end

argile compiled_stmt_dsl = el("lang_stmt_dsl_root")
    layout
        width_fixed(280.0)
        height_fixed(90.0)
        padding(6)
    end
    shared
        color(0.25, 0.35, 0.45, 1.0)
    end
    text("statement dsl")
end

do
    local argile compiled_local = el("lang_local_root")
        layout
            width_fixed(240.0)
            height_fixed(100.0)
        end
        shared
            color(0.4, 0.2, 0.55, 1.0)
        end
    end
    _G.__compiled_local_layout = compiled_local
end

do
    local argile compiled_local_dsl = el("lang_local_dsl_root")
        layout
            width_fixed(220.0)
            height_fixed(70.0)
        end
        shared
            color(0.2, 0.2, 0.2, 1.0)
        end
        text("local statement dsl")
    end
    _G.__compiled_local_dsl_layout = compiled_local_dsl
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
