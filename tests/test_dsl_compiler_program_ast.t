local C = terralib.includecstring [[
#include <stdio.h>
#include <stdlib.h>
]]

local ui = require("src.init")
local AST = require("src/lang/ast")
local DslCompiler = require("src/dsl_compiler")

local function lit(v)
    return AST.LiteralExpr(v)
end

local function op(name, ...)
    local args = terralib.newlist({...})
    local out = {}
    for i = 1, #args do out[i] = args[i] end
    return { name = name, args = out }
end

local function color(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1.0 }
end

local function build_program_ast()
    local token_surface = AST.TokenDecl("color.surface", lit(color(0.2, 0.3, 0.4, 1.0)))
    local theme = AST.ThemeDecl("design", { ["color.surface"] = token_surface }, {})

    local slot_host = AST.NodeDecl("el")
    slot_host.slot_name = "content"
    slot_host.layout_ops = {
        op("width_fixed", lit(24.0)),
        op("height_fixed", lit(24.0)),
    }

    local root = AST.NodeDecl("el")
    root.id_expr = lit("card_root")
    root.layout_ops = {
        op("width_fixed", lit(80.0)),
        op("height_fixed", lit(60.0)),
    }
    root.style_ops = {
        op("bg", AST.TokenRefExpr({"design", "color", "surface"})),
    }
    root.children = { slot_host }

    local component = AST.ComponentDecl("Card", {}, {}, root)

    local filled_child = AST.NodeDecl("el")
    filled_child.id_expr = lit("filled_child")
    filled_child.layout_ops = {
        op("width_fixed", lit(12.0)),
        op("height_fixed", lit(8.0)),
    }
    filled_child.style_ops = {
        op("bg", lit(color(0.9, 0.2, 0.1, 1.0))),
    }

    local fill = AST.FillDecl("content", { filled_child })
    local invoke = AST.ComponentInvoke("Card", {})
    invoke.fills = { fill }

    return AST.Program({ theme, component }, { invoke })
end

local compiled_program_body = DslCompiler.compileAstProgram(build_program_ast(), function()
    return {}
end)

terra init_ctx(ctx: &ui.Context, arena: &ui.Arena) : bool
    arena.nextAllocation = 0
    arena.capacity = 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))
    if arena.memory == nil then return false end
    return ctx:initialize(arena, 256)
end

terra free_ctx(arena: &ui.Arena)
    if arena.memory ~= nil then
        C.free(arena.memory)
        arena.memory = nil
    end
end

terra color_eq(a: ui.Color, b: ui.Color) : bool
    return ui.FloatEqual(a.r, b.r) and ui.FloatEqual(a.g, b.g) and ui.FloatEqual(a.b, b.b) and ui.FloatEqual(a.a, b.a)
end

terra find_rect(ctx: &ui.Context, id: ui.ElementId, out_cmd: &ui.RenderCommand) : bool
    var i: int32 = 0
    while i < ctx.renderCommands.length do
        var cmd = ui.GetRenderCommandAtForContext(ctx, i)
        if cmd.commandType == ui.RENDER_RECTANGLE and cmd.id == id.id then
            @out_cmd = cmd
            return true
        end
        i = i + 1
    end
    return false
end

terra dump_commands(ctx: &ui.Context)
    var i: int32 = 0
    while i < ctx.renderCommands.length do
        var cmd = ui.GetRenderCommandAtForContext(ctx, i)
        C.printf("cmd[%d] type=%d id=%u bbox=(%.1f %.1f %.1f %.1f)\n",
            i, cmd.commandType, cmd.id,
            cmd.boundingBox.x, cmd.boundingBox.y, cmd.boundingBox.width, cmd.boundingBox.height)
        i = i + 1
    end
end

terra run_test() : int32
    var failed: int32 = 0
    var arena: ui.Arena
    var ctx: ui.Context
    if not init_ctx(&ctx, &arena) then
        C.printf("FAIL: could not init context\n")
        return 1
    end

    ui.SetCurrentContext(&ctx)
    ui.BeginLayoutForContext(&ctx, 300.0, 200.0)
    [compiled_program_body]
    var cmd_count = ui.FinalizeLayoutForContext(&ctx)
    if cmd_count <= 0 then
        C.printf("FAIL: compileAstProgram emitted no commands\n")
        free_ctx(&arena)
        return 1
    end

    var root_id = ui.GetElementIdFromChars("card_root", 9)
    var child_id = ui.GetElementIdFromChars("filled_child", 12)
    var root_cmd: ui.RenderCommand
    var child_cmd: ui.RenderCommand
    if not find_rect(&ctx, root_id, &root_cmd) then
        C.printf("FAIL: root rect not found\n")
        dump_commands(&ctx)
        failed = failed + 1
    end
    if not find_rect(&ctx, child_id, &child_cmd) then
        C.printf("FAIL: filled child rect not found\n")
        dump_commands(&ctx)
        failed = failed + 1
    end

    if failed == 0 then
        var expected_root = ui.Color { r = 0.2, g = 0.3, b = 0.4, a = 1.0 }
        var expected_child = ui.Color { r = 0.9, g = 0.2, b = 0.1, a = 1.0 }
        if not color_eq(root_cmd.renderData.rectangle.backgroundColor, expected_root) then
            C.printf("FAIL: root token-resolved bg color mismatch\n")
            failed = failed + 1
        end
        if not color_eq(child_cmd.renderData.rectangle.backgroundColor, expected_child) then
            C.printf("FAIL: fill child bg color mismatch\n")
            failed = failed + 1
        end
    end

    free_ctx(&arena)
    if failed == 0 then
        C.printf("test_dsl_compiler_program_ast: PASS\n")
    end
    return failed
end

local rc = run_test()
if rc ~= 0 then
    error("test_dsl_compiler_program_ast failed")
end
