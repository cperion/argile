local C = terralib.includecstring [[
#include <stdio.h>
#include <stdlib.h>
]]

local ui = require("src.init")
local AstCapi = require("src/capi_dsl_ast")

local function expr_lit(b, v)
    return AstCapi.CapiDslAstCreateExprLiteral(b, v)
end

local function expr_str(b, s)
    return AstCapi.CapiDslAstCreateExprString(b, s)
end

local function expr_token(b, path)
    return AstCapi.CapiDslAstCreateExprTokenRef(b, path)
end

local function op(builder, name, ...)
    local h = AstCapi.CapiDslAstCreateOp(builder, name)
    local args = {...}
    for i = 1, #args do
        AstCapi.CapiDslAstOpAddArgExpr(builder, h, args[i])
    end
    return h
end

local function build_program_with_handles()
    local b = AstCapi.CapiDslAstCreateBuilder()
    local program = AstCapi.CapiDslAstCreateProgram(b)

    local theme = AstCapi.CapiDslAstCreateTheme(b, "design")
    local token = AstCapi.CapiDslAstCreateToken(b, "color.surface")
    AstCapi.CapiDslAstTokenSetValueExpr(b, token, expr_lit(b, { r = 0.2, g = 0.3, b = 0.4, a = 1.0 }))
    AstCapi.CapiDslAstThemeAddToken(b, theme, token)
    AstCapi.CapiDslAstProgramAddDecl(b, program, theme)

    local comp = AstCapi.CapiDslAstCreateComponent(b, "Card")
    local root = AstCapi.CapiDslAstCreateNodeElement(b)
    AstCapi.CapiDslAstNodeSetIdExpr(b, root, expr_str(b, "card_root"))
    AstCapi.CapiDslAstNodeAddOp(b, root, "layout", op(b, "width_fixed", expr_lit(b, 80.0)))
    AstCapi.CapiDslAstNodeAddOp(b, root, "layout", op(b, "height_fixed", expr_lit(b, 60.0)))
    AstCapi.CapiDslAstNodeAddOp(b, root, "style", op(b, "bg", expr_token(b, "design.color.surface")))

    local slot_host = AstCapi.CapiDslAstCreateNodeElement(b)
    AstCapi.CapiDslAstNodeSetSlotName(b, slot_host, "content")
    AstCapi.CapiDslAstNodeAddOp(b, slot_host, "layout", op(b, "width_fixed", expr_lit(b, 24.0)))
    AstCapi.CapiDslAstNodeAddOp(b, slot_host, "layout", op(b, "height_fixed", expr_lit(b, 24.0)))
    AstCapi.CapiDslAstNodeAddChild(b, root, slot_host)
    AstCapi.CapiDslAstComponentSetRootNode(b, comp, root)
    AstCapi.CapiDslAstProgramAddDecl(b, program, comp)

    local invoke = AstCapi.CapiDslAstCreateInvoke(b, "Card")
    local fill = AstCapi.CapiDslAstCreateFill(b, "content")
    local child = AstCapi.CapiDslAstCreateNodeElement(b)
    AstCapi.CapiDslAstNodeSetIdExpr(b, child, expr_str(b, "filled_child"))
    AstCapi.CapiDslAstNodeAddOp(b, child, "layout", op(b, "width_fixed", expr_lit(b, 12.0)))
    AstCapi.CapiDslAstNodeAddOp(b, child, "layout", op(b, "height_fixed", expr_lit(b, 8.0)))
    AstCapi.CapiDslAstNodeAddOp(b, child, "style", op(b, "bg", expr_lit(b, { r = 0.9, g = 0.2, b = 0.1, a = 1.0 })))
    AstCapi.CapiDslAstFillAddChild(b, fill, child)
    AstCapi.CapiDslAstInvokeAddFill(b, invoke, fill)
    AstCapi.CapiDslAstProgramAddBodyItem(b, program, invoke)

    return b, program
end

local function build_program_with_recipe_use()
    local b = AstCapi.CapiDslAstCreateBuilder()
    local program = AstCapi.CapiDslAstCreateProgram(b)

    local theme = AstCapi.CapiDslAstCreateTheme(b, "design")
    local token = AstCapi.CapiDslAstCreateToken(b, "color.surface")
    AstCapi.CapiDslAstTokenSetValueExpr(b, token, expr_lit(b, { r = 0.12, g = 0.55, b = 0.22, a = 1.0 }))
    AstCapi.CapiDslAstThemeAddToken(b, theme, token)

    local recipe = AstCapi.CapiDslAstCreateRecipe(b, "surface_card")
    AstCapi.CapiDslAstRecipeAddOp(b, recipe, "style", op(b, "bg", expr_token(b, "color.surface")))
    AstCapi.CapiDslAstThemeAddRecipe(b, theme, recipe)
    AstCapi.CapiDslAstProgramAddDecl(b, program, theme)

    local node = AstCapi.CapiDslAstCreateNodeElement(b)
    AstCapi.CapiDslAstNodeSetIdExpr(b, node, expr_str(b, "recipe_probe"))
    AstCapi.CapiDslAstNodeAddOp(b, node, "layout", op(b, "width_fixed", expr_lit(b, 32.0)))
    AstCapi.CapiDslAstNodeAddOp(b, node, "layout", op(b, "height_fixed", expr_lit(b, 20.0)))

    local recipe_path = AstCapi.CapiDslAstCreateExprPathRef(b, "design.surface_card")
    local recipe_call = AstCapi.CapiDslAstCreateExprCall(b, recipe_path, "named")
    AstCapi.CapiDslAstNodeAddUseExpr(b, node, recipe_call)
    AstCapi.CapiDslAstProgramAddBodyItem(b, program, node)

    return b, program
end

local function build_program_with_variant_invoke(symbol_name)
    local b = AstCapi.CapiDslAstCreateBuilder()
    local program = AstCapi.CapiDslAstCreateProgram(b)

    local comp = AstCapi.CapiDslAstCreateComponent(b, "Badge")
    AstCapi.CapiDslAstComponentAddParam(b, comp, "props")

    local variant = AstCapi.CapiDslAstCreateVariant(b, "tone")
    AstCapi.CapiDslAstVariantAddValue(b, variant, "primary")
    AstCapi.CapiDslAstVariantAddValue(b, variant, "secondary")
    AstCapi.CapiDslAstComponentAddVariant(b, comp, variant)

    local root = AstCapi.CapiDslAstCreateNodeElement(b)
    AstCapi.CapiDslAstNodeSetIdExpr(b, root, expr_str(b, "badge_variant_root"))
    AstCapi.CapiDslAstNodeAddOp(b, root, "layout", op(b, "width_fixed", expr_lit(b, 20.0)))
    AstCapi.CapiDslAstNodeAddOp(b, root, "layout", op(b, "height_fixed", expr_lit(b, 10.0)))
    AstCapi.CapiDslAstComponentSetRootNode(b, comp, root)
    AstCapi.CapiDslAstProgramAddDecl(b, program, comp)

    local invoke = AstCapi.CapiDslAstCreateInvoke(b, "Badge")
    AstCapi.CapiDslAstInvokeSetArgExpr(b, invoke, "tone", AstCapi.CapiDslAstCreateExprSymbol(b, symbol_name))
    AstCapi.CapiDslAstProgramAddBodyItem(b, program, invoke)

    return b, program
end

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

local builder, program = build_program_with_handles()
local compiled_quote = AstCapi.CapiDslAstCompileProgramQuote(builder, program, function() return {} end)
local recipe_builder, recipe_program = build_program_with_recipe_use()
local compiled_recipe_quote = AstCapi.CapiDslAstCompileProgramQuote(recipe_builder, recipe_program, function() return {} end)

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
    [compiled_quote]
    var count = ui.FinalizeLayoutForContext(&ctx)
    if count <= 0 then
        C.printf("FAIL: no render commands emitted\n")
        free_ctx(&arena)
        return 1
    end

    var root_id = ui.GetElementIdFromChars("card_root", 9)
    var child_id = ui.GetElementIdFromChars("filled_child", 12)
    var root_cmd: ui.RenderCommand
    var child_cmd: ui.RenderCommand

    if not find_rect(&ctx, root_id, &root_cmd) then
        C.printf("FAIL: root rect not found\n")
        failed = failed + 1
    end
    if not find_rect(&ctx, child_id, &child_cmd) then
        C.printf("FAIL: child rect not found\n")
        failed = failed + 1
    end

    if failed == 0 then
        var expected_root = ui.Color { r = 0.2, g = 0.3, b = 0.4, a = 1.0 }
        var expected_child = ui.Color { r = 0.9, g = 0.2, b = 0.1, a = 1.0 }
        if not color_eq(root_cmd.renderData.rectangle.backgroundColor, expected_root) then
            C.printf("FAIL: root color mismatch\n")
            failed = failed + 1
        end
        if not color_eq(child_cmd.renderData.rectangle.backgroundColor, expected_child) then
            C.printf("FAIL: child color mismatch\n")
            failed = failed + 1
        end
    end

    free_ctx(&arena)
    if failed == 0 then
        C.printf("test_capi_dsl_ast: PASS\n")
    end
    return failed
end

terra run_recipe_use_test() : int32
    var failed: int32 = 0
    var arena: ui.Arena
    var ctx: ui.Context
    if not init_ctx(&ctx, &arena) then
        C.printf("FAIL: could not init context for recipe use test\n")
        return 1
    end

    ui.SetCurrentContext(&ctx)
    ui.BeginLayoutForContext(&ctx, 200.0, 120.0)
    [compiled_recipe_quote]
    var count = ui.FinalizeLayoutForContext(&ctx)
    if count <= 0 then
        C.printf("FAIL: recipe use test emitted no commands\n")
        free_ctx(&arena)
        return 1
    end

    var probe_id = ui.GetElementIdFromChars("recipe_probe", 12)
    var cmd: ui.RenderCommand
    if not find_rect(&ctx, probe_id, &cmd) then
        C.printf("FAIL: recipe probe rect not found\n")
        failed = failed + 1
    else
        var expected = ui.Color { r = 0.12, g = 0.55, b = 0.22, a = 1.0 }
        if not color_eq(cmd.renderData.rectangle.backgroundColor, expected) then
            C.printf("FAIL: recipe use color mismatch\n")
            failed = failed + 1
        end
    end

    free_ctx(&arena)
    if failed == 0 then
        C.printf("test_capi_dsl_ast_recipe_use: PASS\n")
    end
    return failed
end

local rc = run_test()
if rc ~= 0 then
    error("test_capi_dsl_ast failed")
end

local rc_recipe = run_recipe_use_test()
if rc_recipe ~= 0 then
    error("test_capi_dsl_ast recipe use failed")
end

do
    local ok = pcall(function()
        AstCapi.CapiDslAstDestroyBuilder(builder)
        AstCapi.CapiDslAstGetProgramAst(builder, program)
    end)
    if ok then
        error("expected stale handle / destroyed builder error")
    end
end

do
    local ok = pcall(function()
        AstCapi.CapiDslAstDestroyBuilder(recipe_builder)
        AstCapi.CapiDslAstDebugProgram(recipe_builder, recipe_program)
    end)
    if ok then
        error("expected destroyed builder failure for recipe builder")
    end
end

do
    local ok_valid = pcall(function()
        local b, p = build_program_with_variant_invoke("primary")
        AstCapi.CapiDslAstCompileProgramQuote(b, p, function() return {} end)
        AstCapi.CapiDslAstDestroyBuilder(b)
    end)
    if not ok_valid then
        error("expected valid variant invoke to compile")
    end
end

do
    local ok_invalid, err_invalid = pcall(function()
        local b, p = build_program_with_variant_invoke("danger")
        AstCapi.CapiDslAstCompileProgramQuote(b, p, function() return {} end)
    end)
    if ok_invalid then
        error("expected invalid variant invoke to fail compilation")
    end
    if type(err_invalid) ~= "string" or not err_invalid:find("invalid variant value", 1, true) then
        error("expected invalid variant diagnostic, got: " .. tostring(err_invalid))
    end
end
