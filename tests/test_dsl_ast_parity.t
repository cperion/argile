local C = terralib.includecstring [[
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
]]

local ui = require("src.init")
local AstApi = require("src/capi_dsl_host")
import "src/lang.argile"

terra parity_measure_text(text: &ui.StringSlice, textCfg: &ui.TextConfig, _userData: &opaque, out: &ui.Dimensions) : int32
    out.width = [float](text.length * 8)
    if textCfg ~= nil and textCfg.lineHeight > 0 then
        out.height = [float](textCfg.lineHeight)
    else
        out.height = 16.0
    end
    return 1
end

theme design
    token color.surface = { r = 0.14, g = 0.16, b = 0.20, a = 1.0 }
    token color.text = { r = 0.95, g = 0.96, b = 0.98, a = 1.0 }
    token color.accent = { r = 0.95, g = 0.62, b = 0.27, a = 1.0 }
    token color.hover = { r = 0.25, g = 0.35, b = 0.70, a = 1.0 }
    token color.selected = { r = 0.55, g = 0.35, b = 0.14, a = 1.0 }

    recipe card()
        style
            bg(token(color.surface))
        end
        paint
            fill(token(color.accent))
        end
    end

    recipe label()
        typography
            color(token(color.text))
            font_size(12)
            line_height(12)
        end
    end
end

component Badge(props)
    variant tone = primary | secondary
    root
        id(props.id)
        use(design.card())
        layout
            width_fixed(96.0)
            height_fixed(40.0)
            padding(4)
        end
        state hover
            style
                bg(token(design.color.hover))
            end
        end
        state selected
            style
                bg(token(design.color.selected))
            end
        end

        el
            part(slot_host)
            slot(content)
                text("slot-fallback")
                    use(design.label())
                end
            end
        end

        el
            part(body_host)
            children
        end
    end
end

local compiled_dsl_scene = argile
    Badge(id = "from_arg", tone = secondary)
        id("badge_root")
        fill(content)
            text("F")
                id("fill_text")
                use(design.label())
            end
        end
        text("B")
            id("body_text")
            use(design.label())
        end
    end
end

local function expr_lit(b, v) return AstApi.CapiDslAstCreateExprLiteral(b, v) end
local function expr_str(b, s) return AstApi.CapiDslAstCreateExprString(b, s) end
local function expr_symbol(b, s) return AstApi.CapiDslAstCreateExprSymbol(b, s) end
local function expr_token(b, p) return AstApi.CapiDslAstCreateExprTokenRef(b, p) end
local function expr_path(b, p) return AstApi.CapiDslAstCreateExprPathRef(b, p) end

local function op(builder, name, ...)
    local h = AstApi.CapiDslAstCreateOp(builder, name)
    local args = {...}
    for i = 1, #args do
        AstApi.CapiDslAstOpAddArgExpr(builder, h, args[i])
    end
    return h
end

local function recipe_call(builder, dotted_path)
    local path_h = AstApi.CapiDslAstCreateExprPathRef(builder, dotted_path)
    return AstApi.CapiDslAstCreateExprCall(builder, path_h, "named")
end

local function build_ast_program()
    local b = AstApi.CapiDslAstCreateBuilder()
    local program = AstApi.CapiDslAstCreateProgram(b)

    local theme_h = AstApi.CapiDslAstCreateTheme(b, "design")
    local token_defs = {
        ["color.surface"] = { r = 0.14, g = 0.16, b = 0.20, a = 1.0 },
        ["color.text"] = { r = 0.95, g = 0.96, b = 0.98, a = 1.0 },
        ["color.accent"] = { r = 0.95, g = 0.62, b = 0.27, a = 1.0 },
        ["color.hover"] = { r = 0.25, g = 0.35, b = 0.70, a = 1.0 },
        ["color.selected"] = { r = 0.55, g = 0.35, b = 0.14, a = 1.0 },
    }
    for path, value in pairs(token_defs) do
        local tok = AstApi.CapiDslAstCreateToken(b, path)
        AstApi.CapiDslAstTokenSetValueExpr(b, tok, expr_lit(b, value))
        AstApi.CapiDslAstThemeAddToken(b, theme_h, tok)
    end

    local recipe_card = AstApi.CapiDslAstCreateRecipe(b, "card")
    AstApi.CapiDslAstRecipeAddOp(b, recipe_card, "style", op(b, "bg", expr_token(b, "color.surface")))
    AstApi.CapiDslAstRecipeAddOp(b, recipe_card, "paint", op(b, "fill", expr_token(b, "color.accent")))
    AstApi.CapiDslAstThemeAddRecipe(b, theme_h, recipe_card)

    local recipe_label = AstApi.CapiDslAstCreateRecipe(b, "label")
    AstApi.CapiDslAstRecipeAddOp(b, recipe_label, "typography", op(b, "color", expr_token(b, "color.text")))
    AstApi.CapiDslAstRecipeAddOp(b, recipe_label, "typography", op(b, "font_size", expr_lit(b, 12)))
    AstApi.CapiDslAstRecipeAddOp(b, recipe_label, "typography", op(b, "line_height", expr_lit(b, 12)))
    AstApi.CapiDslAstThemeAddRecipe(b, theme_h, recipe_label)

    AstApi.CapiDslAstProgramAddDecl(b, program, theme_h)

    local comp = AstApi.CapiDslAstCreateComponent(b, "Badge")
    AstApi.CapiDslAstComponentAddParam(b, comp, "props")
    local variant = AstApi.CapiDslAstCreateVariant(b, "tone")
    AstApi.CapiDslAstVariantAddValue(b, variant, "primary")
    AstApi.CapiDslAstVariantAddValue(b, variant, "secondary")
    AstApi.CapiDslAstComponentAddVariant(b, comp, variant)

    local root = AstApi.CapiDslAstCreateNodeElement(b)
    AstApi.CapiDslAstNodeSetIdExpr(b, root, expr_path(b, "props.id"))
    AstApi.CapiDslAstNodeAddUseExpr(b, root, recipe_call(b, "design.card"))
    AstApi.CapiDslAstNodeAddOp(b, root, "layout", op(b, "width_fixed", expr_lit(b, 96.0)))
    AstApi.CapiDslAstNodeAddOp(b, root, "layout", op(b, "height_fixed", expr_lit(b, 40.0)))
    AstApi.CapiDslAstNodeAddOp(b, root, "layout", op(b, "padding", expr_lit(b, 4)))

    local st_hover = AstApi.CapiDslAstCreateStateOverlay(b, "hover")
    AstApi.CapiDslAstStateAddOp(b, st_hover, "style", op(b, "bg", expr_token(b, "design.color.hover")))
    AstApi.CapiDslAstNodeAddState(b, root, st_hover)

    local st_selected = AstApi.CapiDslAstCreateStateOverlay(b, "selected")
    AstApi.CapiDslAstStateAddOp(b, st_selected, "style", op(b, "bg", expr_token(b, "design.color.selected")))
    AstApi.CapiDslAstNodeAddState(b, root, st_selected)

    local slot_host = AstApi.CapiDslAstCreateNodeElement(b)
    AstApi.CapiDslAstNodeSetPartName(b, slot_host, "slot_host")
    AstApi.CapiDslAstNodeSetSlotName(b, slot_host, "content")
    local slot_fallback_text = AstApi.CapiDslAstCreateNodeText(b)
    AstApi.CapiDslAstNodeSetTextExpr(b, slot_fallback_text, expr_str(b, "slot-fallback"))
    AstApi.CapiDslAstNodeAddUseExpr(b, slot_fallback_text, recipe_call(b, "design.label"))
    AstApi.CapiDslAstNodeAddChild(b, slot_host, slot_fallback_text)
    AstApi.CapiDslAstNodeAddChild(b, root, slot_host)

    local body_host = AstApi.CapiDslAstCreateNodeElement(b)
    AstApi.CapiDslAstNodeSetPartName(b, body_host, "body_host")
    AstApi.CapiDslAstNodeSetChildrenMarker(b, body_host, true)
    AstApi.CapiDslAstNodeAddChild(b, root, body_host)

    AstApi.CapiDslAstComponentSetRootNode(b, comp, root)
    AstApi.CapiDslAstProgramAddDecl(b, program, comp)

    local invoke = AstApi.CapiDslAstCreateInvoke(b, "Badge")
    AstApi.CapiDslAstInvokeSetArgExpr(b, invoke, "id", expr_str(b, "from_arg"))
    AstApi.CapiDslAstInvokeSetArgExpr(b, invoke, "tone", expr_symbol(b, "secondary"))
    AstApi.CapiDslAstInvokeSetIdExpr(b, invoke, expr_str(b, "badge_root"))

    local fill = AstApi.CapiDslAstCreateFill(b, "content")
    local fill_text = AstApi.CapiDslAstCreateNodeText(b)
    AstApi.CapiDslAstNodeSetTextExpr(b, fill_text, expr_str(b, "F"))
    AstApi.CapiDslAstNodeSetIdExpr(b, fill_text, expr_str(b, "fill_text"))
    AstApi.CapiDslAstNodeAddUseExpr(b, fill_text, recipe_call(b, "design.label"))
    AstApi.CapiDslAstFillAddChild(b, fill, fill_text)
    AstApi.CapiDslAstInvokeAddFill(b, invoke, fill)

    local body_text = AstApi.CapiDslAstCreateNodeText(b)
    AstApi.CapiDslAstNodeSetTextExpr(b, body_text, expr_str(b, "B"))
    AstApi.CapiDslAstNodeSetIdExpr(b, body_text, expr_str(b, "body_text"))
    AstApi.CapiDslAstNodeAddUseExpr(b, body_text, recipe_call(b, "design.label"))
    AstApi.CapiDslAstInvokeAddBodyItem(b, invoke, body_text)

    AstApi.CapiDslAstProgramAddBodyItem(b, program, invoke)

    return b, program
end

local ast_builder, ast_program = build_ast_program()
local compiled_ast_scene = AstApi.CapiDslAstCompileProgramQuote(ast_builder, ast_program, function() return {} end)

terra init_ctx(ctx: &ui.Context, arena: &ui.Arena) : bool
    arena.nextAllocation = 0
    arena.capacity = 4 * 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))
    if arena.memory == nil then return false end
    return ctx:initialize(arena, 512)
end

terra free_ctx(arena: &ui.Arena)
    if arena.memory ~= nil then
        C.free(arena.memory)
        arena.memory = nil
    end
end

terra color_equal(a: ui.Color, b: ui.Color) : bool
    return ui.FloatEqual(a.r, b.r) and ui.FloatEqual(a.g, b.g) and ui.FloatEqual(a.b, b.b) and ui.FloatEqual(a.a, b.a)
end

terra bbox_equal(a: ui.BoundingBox, b: ui.BoundingBox) : bool
    return ui.FloatEqual(a.x, b.x) and ui.FloatEqual(a.y, b.y) and ui.FloatEqual(a.width, b.width) and ui.FloatEqual(a.height, b.height)
end

terra text_slice_equal(a: ui.StringSlice, b: ui.StringSlice) : bool
    if a.length ~= b.length then return false end
    if a.length == 0 then return true end
    if a.chars == nil or b.chars == nil then return false end
    return C.memcmp(a.chars, b.chars, [uint64](a.length)) == 0
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
    if not bbox_equal(a.boundingBox, b.boundingBox) then return false end
    if a.commandType == ui.RENDER_RECTANGLE then
        return color_equal(a.renderData.rectangle.backgroundColor, b.renderData.rectangle.backgroundColor)
    elseif a.commandType == ui.RENDER_TEXT then
        return text_slice_equal(a.renderData.text.stringContents, b.renderData.text.stringContents) and
               color_equal(a.renderData.text.textColor, b.renderData.text.textColor) and
               a.renderData.text.fontId == b.renderData.text.fontId and
               a.renderData.text.fontSize == b.renderData.text.fontSize and
               a.renderData.text.lineHeight == b.renderData.text.lineHeight and
               a.renderData.text.letterSpacing == b.renderData.text.letterSpacing
    elseif a.commandType == ui.RENDER_PAINT then
        return paint_ops_equal(a.renderData.paint.ops, a.renderData.paint.count, b.renderData.paint.ops, b.renderData.paint.count)
    end
    return true
end

terra render_scene(ctx: &ui.Context, use_ast: bool, w: float, h: float) : int32
    ui.SetCurrentContext(ctx)
    ui.BeginLayoutForContext(ctx, w, h)
    if use_ast then
        [compiled_ast_scene]
    else
        [compiled_dsl_scene]
    end
    return ui.FinalizeLayoutForContext(ctx)
end

terra compare_context_commands(a: &ui.Context, b: &ui.Context, label: &int8) : int32
    if a.renderCommands.length ~= b.renderCommands.length then
        C.printf("FAIL: %s: render command count mismatch (%d vs %d)\n", label, a.renderCommands.length, b.renderCommands.length)
        return 1
    end
    var i: int32 = 0
    while i < a.renderCommands.length do
        var ca = ui.GetRenderCommandAtForContext(a, i)
        var cb = ui.GetRenderCommandAtForContext(b, i)
        if not command_equal(ca, cb) then
            C.printf("FAIL: %s: command mismatch at %d (type %d vs %d, id %u vs %u)\n", label, i, ca.commandType, cb.commandType, ca.id, cb.id)
            return 1
        end
        i = i + 1
    end
    return 0
end

terra compare_element_data_ids(a: &ui.Context, b: &ui.Context, label: &int8) : int32
    var failed: int32 = 0
    var root_id = ui.GetElementIdFromChars("badge_root", 9)
    var fill_id = ui.GetElementIdFromChars("fill_text", 8)
    var body_id = ui.GetElementIdFromChars("body_text", 8)
    var i: int32 = 0
    while i < 3 do
        var id = root_id
        var name: &int8 = "badge_root"
        if i == 1 then
            id = fill_id
            name = "fill_text"
        elseif i == 2 then
            id = body_id
            name = "body_text"
        end

        ui.SetCurrentContext(a)
        var da = ui.GetElementData(id)
        ui.SetCurrentContext(b)
        var db = ui.GetElementData(id)
        if da.found ~= db.found then
            C.printf("FAIL: %s: element data presence mismatch for %s (dsl=%d ast=%d)\n", label, name, da.found, db.found)
            failed = failed + 1
        elseif da.found and not bbox_equal(da.boundingBox, db.boundingBox) then
            C.printf("FAIL: %s: element data bbox mismatch for %s\n", label, name)
            failed = failed + 1
        end
        i = i + 1
    end

    return failed
end

terra run_frame_pair(pointer_inside: bool, selected: bool, label: &int8) : int32
    var failed: int32 = 0
    var arena_a: ui.Arena
    var arena_b: ui.Arena
    var ctx_a: ui.Context
    var ctx_b: ui.Context

    if not init_ctx(&ctx_a, &arena_a) or not init_ctx(&ctx_b, &arena_b) then
        C.printf("FAIL: %s: could not init contexts\n", label)
        free_ctx(&arena_a)
        free_ctx(&arena_b)
        return 1
    end

    ui.SetMeasureTextFunction(parity_measure_text, nil)
    ui.ResetMeasureTextCache()

    var ptr = ui.Vector2 { x = 10.0, y = 10.0 }
    var out = ui.Vector2 { x = 1000.0, y = 1000.0 }
    var curptr = out
    if pointer_inside then
        curptr = ptr
    end
    var root_id = ui.GetElementIdFromChars("badge_root", 9)

    ui.SetCurrentContext(&ctx_a)
    ui.SetPointerStateForContext(&ctx_a, curptr, false)
    ui.SetElementSelectedForContext(&ctx_a, root_id, selected)
    if render_scene(&ctx_a, false, 240.0, 120.0) <= 0 then
        C.printf("FAIL: %s: DSL scene emitted no commands\n", label)
        failed = failed + 1
    end

    ui.SetCurrentContext(&ctx_b)
    ui.SetPointerStateForContext(&ctx_b, curptr, false)
    ui.SetElementSelectedForContext(&ctx_b, root_id, selected)
    if render_scene(&ctx_b, true, 240.0, 120.0) <= 0 then
        C.printf("FAIL: %s: AST scene emitted no commands\n", label)
        failed = failed + 1
    end

    if failed == 0 then
        failed = failed + compare_context_commands(&ctx_a, &ctx_b, label)
        failed = failed + compare_element_data_ids(&ctx_a, &ctx_b, label)
    end

    free_ctx(&arena_a)
    free_ctx(&arena_b)
    return failed
end

terra run_test() : int32
    var failed: int32 = 0
    failed = failed + run_frame_pair(false, false, "base")
    failed = failed + run_frame_pair(true, false, "hover")
    failed = failed + run_frame_pair(false, true, "selected")
    if failed == 0 then
        C.printf("test_dsl_ast_parity: PASS\n")
    end
    return failed
end

local rc = run_test()
if rc ~= 0 then
    error("test_dsl_ast_parity failed")
end
