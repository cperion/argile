local AST = require("src/lang/ast")
local DslCompiler = require("src/dsl_compiler")

local M = {}

local _next_builder_id = 1

local function split_dotted_path(path)
    if type(path) == "table" then
        local out = {}
        for i, part in ipairs(path) do out[i] = part end
        return out
    end
    if type(path) ~= "string" then
        error("argile: expected dotted path string or string list")
    end
    local out = {}
    for part in path:gmatch("[^%.]+") do
        out[#out + 1] = part
    end
    return out
end

local function make_pool(kind)
    return {
        kind = kind,
        slots = {},
        free = {},
        next_slot = 1,
    }
end

local function new_builder()
    local builder = {
        _kind = "CapiDslAstBuilder",
        _alive = true,
        _id = _next_builder_id,
        _pools = {
            program = make_pool("program"),
            theme = make_pool("theme"),
            token = make_pool("token"),
            recipe = make_pool("recipe"),
            component = make_pool("component"),
            variant = make_pool("variant"),
            node = make_pool("node"),
            state = make_pool("state"),
            invoke = make_pool("invoke"),
            fill = make_pool("fill"),
            expr = make_pool("expr"),
            op = make_pool("op"),
            splice = make_pool("splice"),
        },
    }
    _next_builder_id = _next_builder_id + 1
    return builder
end

local function check_builder(builder)
    if type(builder) ~= "table" or builder._kind ~= "CapiDslAstBuilder" then
        error("argile: invalid AST builder")
    end
    if not builder._alive then
        error("argile: AST builder is destroyed")
    end
end

local function make_handle(builder, pool_name, slot_idx, gen)
    return {
        _kind = "CapiDslAstHandle",
        builder_id = builder._id,
        pool = pool_name,
        slot = slot_idx,
        gen = gen,
    }
end

local function alloc(builder, pool_name, value)
    check_builder(builder)
    local pool = builder._pools[pool_name]
    if pool == nil then
        error("argile: unknown AST pool '" .. tostring(pool_name) .. "'")
    end

    local slot_idx
    if #pool.free > 0 then
        slot_idx = table.remove(pool.free)
    else
        slot_idx = pool.next_slot
        pool.next_slot = slot_idx + 1
    end

    local slot = pool.slots[slot_idx]
    local gen = (slot and slot.gen or 0) + 1
    pool.slots[slot_idx] = {
        alive = true,
        gen = gen,
        value = value,
    }
    return make_handle(builder, pool_name, slot_idx, gen)
end

local function resolve(builder, handle, expected_pool)
    check_builder(builder)
    if type(handle) ~= "table" or handle._kind ~= "CapiDslAstHandle" then
        error("argile: invalid AST handle")
    end
    if handle.builder_id ~= builder._id then
        error("argile: AST handle belongs to different builder")
    end
    if expected_pool ~= nil and handle.pool ~= expected_pool then
        error("argile: expected " .. expected_pool .. " handle, got " .. tostring(handle.pool))
    end

    local pool = builder._pools[handle.pool]
    local slot = pool and pool.slots[handle.slot] or nil
    if slot == nil or not slot.alive or slot.gen ~= handle.gen then
        error("argile: stale AST handle")
    end
    return slot.value
end

local function resolve_expr(builder, expr_handle)
    return resolve(builder, expr_handle, "expr")
end

local function resolve_op(builder, op_handle)
    return resolve(builder, op_handle, "op")
end

local function append_node_like(list, node_like)
    list[#list + 1] = node_like
end

local function assert_body_item(node)
    if AST.IsKind(node, "NodeDecl") or AST.IsKind(node, "ComponentInvoke") or AST.IsKind(node, "Splice") then
        return
    end
    error("argile: expected body item (NodeDecl/ComponentInvoke/Splice), got " .. tostring(AST.GetKind(node)))
end

local function assert_decl_item(decl)
    if AST.IsKind(decl, "ThemeDecl") or AST.IsKind(decl, "ComponentDecl") then
        return
    end
    error("argile: expected top-level declaration (ThemeDecl/ComponentDecl), got " .. tostring(AST.GetKind(decl)))
end

local function add_op_to_block_list(block_list, block_kind, op)
    if block_kind ~= "layout" and block_kind ~= "style" and block_kind ~= "typography" and block_kind ~= "paint" then
        error("argile: invalid block kind '" .. tostring(block_kind) .. "'")
    end
    local last = block_list[#block_list]
    if last ~= nil and last.kind == block_kind then
        table.insert(last.ops, op)
    else
        table.insert(block_list, { kind = block_kind, ops = { op } })
    end
end

local function node_op_target(node, block_kind)
    if block_kind == "layout" then return node.layout_ops end
    if block_kind == "style" then return node.style_ops end
    if block_kind == "typography" then return node.typography_ops end
    if block_kind == "paint" then return node.paint_ops end
    error("argile: invalid node block kind '" .. tostring(block_kind) .. "'")
end

local function state_op_target(state, block_kind)
    if block_kind == "style" then return state.style_ops end
    if block_kind == "typography" then return state.typography_ops end
    if block_kind == "paint" then return state.paint_ops end
    error("argile: state overlay only supports style/typography/paint, got '" .. tostring(block_kind) .. "'")
end

-- ============================================================================
-- Builder lifecycle
-- ============================================================================

function M.CapiDslAstCreateBuilder()
    return new_builder()
end

function M.CapiDslAstDestroyBuilder(builder)
    check_builder(builder)
    builder._alive = false
    builder._pools = {}
end

function M.CapiDslAstResetBuilder(builder)
    check_builder(builder)
    builder._pools = {
        program = make_pool("program"),
        theme = make_pool("theme"),
        token = make_pool("token"),
        recipe = make_pool("recipe"),
        component = make_pool("component"),
        variant = make_pool("variant"),
        node = make_pool("node"),
        state = make_pool("state"),
        invoke = make_pool("invoke"),
        fill = make_pool("fill"),
        expr = make_pool("expr"),
        op = make_pool("op"),
        splice = make_pool("splice"),
    }
    builder._id = _next_builder_id
    _next_builder_id = _next_builder_id + 1
    return true
end

-- ============================================================================
-- Program and declarations
-- ============================================================================

function M.CapiDslAstCreateProgram(builder)
    return alloc(builder, "program", AST.Program({}, {}))
end

function M.CapiDslAstProgramAddDecl(builder, program_h, decl_h)
    local program = resolve(builder, program_h, "program")
    local decl
    if type(decl_h) ~= "table" or decl_h.pool == nil then
        error("argile: invalid declaration handle")
    end
    if decl_h.pool == "theme" or decl_h.pool == "component" then
        decl = resolve(builder, decl_h, decl_h.pool)
    else
        error("argile: unsupported top-level declaration handle kind '" .. tostring(decl_h.pool) .. "'")
    end
    assert_decl_item(decl)
    table.insert(program.decls, decl)
    return true
end

function M.CapiDslAstProgramAddBodyItem(builder, program_h, item_h)
    local program = resolve(builder, program_h, "program")
    local item
    if item_h.pool == "node" or item_h.pool == "invoke" or item_h.pool == "splice" then
        item = resolve(builder, item_h, item_h.pool)
    else
        error("argile: unsupported body item handle kind '" .. tostring(item_h.pool) .. "'")
    end
    assert_body_item(item)
    append_node_like(program.body_nodes, item)
    return true
end

function M.CapiDslAstGetProgramAst(builder, program_h)
    return resolve(builder, program_h, "program")
end

-- ============================================================================
-- Expressions
-- ============================================================================

function M.CapiDslAstCreateExprLiteral(builder, value)
    return alloc(builder, "expr", AST.LiteralExpr(value))
end

function M.CapiDslAstCreateExprBool(builder, value)
    return alloc(builder, "expr", AST.LiteralExpr(not not value))
end

function M.CapiDslAstCreateExprInt(builder, value)
    return alloc(builder, "expr", AST.LiteralExpr(tonumber(value)))
end

function M.CapiDslAstCreateExprFloat(builder, value)
    return alloc(builder, "expr", AST.LiteralExpr(tonumber(value)))
end

function M.CapiDslAstCreateExprString(builder, value)
    if type(value) ~= "string" then
        error("argile: expected string literal")
    end
    return alloc(builder, "expr", AST.LiteralExpr(value))
end

function M.CapiDslAstCreateExprSymbol(builder, name)
    if type(name) ~= "string" then
        error("argile: expected symbol name")
    end
    return alloc(builder, "expr", AST.Symbol(name))
end

function M.CapiDslAstCreateExprTokenRef(builder, path)
    return alloc(builder, "expr", AST.TokenRefExpr(split_dotted_path(path)))
end

function M.CapiDslAstCreateExprPathRef(builder, path)
    return alloc(builder, "expr", AST.PathRefExpr(split_dotted_path(path)))
end

function M.CapiDslAstCreateExprCall(builder, callee_expr_h, call_style)
    local callee_expr = resolve_expr(builder, callee_expr_h)
    if call_style ~= nil and call_style ~= "named" and call_style ~= "positional" then
        error("argile: call_style must be 'named' or 'positional'")
    end
    return alloc(builder, "expr", AST.CallExpr(callee_expr, call_style or "positional"))
end

function M.CapiDslAstExprCallAddNamedArg(builder, call_expr_h, arg_name, arg_expr_h)
    local call = resolve_expr(builder, call_expr_h)
    if not AST.IsKind(call, "CallExpr") then
        error("argile: expected CallExpr handle")
    end
    call.call_style = "named"
    if call.named_args[arg_name] ~= nil then
        error("argile: duplicate named call arg '" .. tostring(arg_name) .. "'")
    end
    call.named_args[arg_name] = resolve_expr(builder, arg_expr_h)
    return true
end

function M.CapiDslAstExprCallAddPosArg(builder, call_expr_h, arg_expr_h)
    local call = resolve_expr(builder, call_expr_h)
    if not AST.IsKind(call, "CallExpr") then
        error("argile: expected CallExpr handle")
    end
    call.call_style = "positional"
    table.insert(call.pos_args, resolve_expr(builder, arg_expr_h))
    return true
end

-- Host-only escape hatch (not portable C ABI)
function M.CapiDslAstCreateExprLua(builder, expr_fn)
    if type(expr_fn) ~= "function" then
        error("argile: expected Lua expression function")
    end
    return alloc(builder, "expr", AST.LuaExpr(expr_fn))
end

-- ============================================================================
-- Operations
-- ============================================================================

function M.CapiDslAstCreateOp(builder, name)
    if type(name) ~= "string" then
        error("argile: expected operation name")
    end
    return alloc(builder, "op", { name = name, args = {} })
end

function M.CapiDslAstOpAddArgExpr(builder, op_h, expr_h)
    local op = resolve_op(builder, op_h)
    local expr = resolve_expr(builder, expr_h)
    table.insert(op.args, expr)
    return true
end

-- ============================================================================
-- Themes / Tokens / Recipes
-- ============================================================================

function M.CapiDslAstCreateTheme(builder, name)
    if type(name) ~= "string" then error("argile: expected theme name") end
    return alloc(builder, "theme", AST.ThemeDecl(name, {}, {}))
end

function M.CapiDslAstCreateToken(builder, dotted_path)
    if type(dotted_path) ~= "string" then error("argile: expected token dotted path") end
    return alloc(builder, "token", AST.TokenDecl(dotted_path, nil))
end

function M.CapiDslAstTokenSetValueExpr(builder, token_h, expr_h)
    local token = resolve(builder, token_h, "token")
    token.value_expr = resolve_expr(builder, expr_h)
    return true
end

function M.CapiDslAstThemeAddToken(builder, theme_h, token_h)
    local theme = resolve(builder, theme_h, "theme")
    local token = resolve(builder, token_h, "token")
    theme.tokens[token.path] = token
    return true
end

function M.CapiDslAstCreateRecipe(builder, name)
    if type(name) ~= "string" then error("argile: expected recipe name") end
    return alloc(builder, "recipe", AST.RecipeDecl(name, {}, {}))
end

function M.CapiDslAstRecipeAddParam(builder, recipe_h, param_name)
    local recipe = resolve(builder, recipe_h, "recipe")
    table.insert(recipe.params, param_name)
    return true
end

function M.CapiDslAstRecipeAddOp(builder, recipe_h, block_kind, op_h)
    local recipe = resolve(builder, recipe_h, "recipe")
    local op = resolve_op(builder, op_h)
    add_op_to_block_list(recipe.body, block_kind, op)
    return true
end

function M.CapiDslAstThemeAddRecipe(builder, theme_h, recipe_h)
    local theme = resolve(builder, theme_h, "theme")
    local recipe = resolve(builder, recipe_h, "recipe")
    theme.recipes[recipe.name] = recipe
    return true
end

-- ============================================================================
-- Components / Variants
-- ============================================================================

function M.CapiDslAstCreateComponent(builder, name)
    if type(name) ~= "string" then error("argile: expected component name") end
    return alloc(builder, "component", AST.ComponentDecl(name, {}, {}, nil))
end

function M.CapiDslAstComponentAddParam(builder, component_h, param_name)
    local component = resolve(builder, component_h, "component")
    table.insert(component.params, param_name)
    return true
end

function M.CapiDslAstCreateVariant(builder, name)
    if type(name) ~= "string" then error("argile: expected variant name") end
    return alloc(builder, "variant", AST.VariantDecl(name, {}))
end

function M.CapiDslAstVariantAddValue(builder, variant_h, value)
    local variant = resolve(builder, variant_h, "variant")
    if AST.IsKind(value, "Symbol") then
        value = value.name
    end
    if type(value) ~= "string" then
        error("argile: variant values must be strings/symbol names")
    end
    table.insert(variant.values, value)
    return true
end

function M.CapiDslAstComponentAddVariant(builder, component_h, variant_h)
    local component = resolve(builder, component_h, "component")
    local variant = resolve(builder, variant_h, "variant")
    component.variants[variant.name] = variant
    return true
end

function M.CapiDslAstComponentSetRootNode(builder, component_h, node_h)
    local component = resolve(builder, component_h, "component")
    local node = resolve(builder, node_h, "node")
    if not AST.IsKind(node, "NodeDecl") then
        error("argile: component root must be NodeDecl")
    end
    component.root = node
    return true
end

-- ============================================================================
-- Nodes / State overlays
-- ============================================================================

function M.CapiDslAstCreateNodeElement(builder)
    return alloc(builder, "node", AST.NodeDecl("el"))
end

function M.CapiDslAstCreateNodeText(builder)
    return alloc(builder, "node", AST.NodeDecl("text"))
end

function M.CapiDslAstNodeSetTextExpr(builder, node_h, expr_h)
    local node = resolve(builder, node_h, "node")
    if node.kind ~= "text" then
        error("argile: text expression can only be set on text nodes")
    end
    node.text_expr = resolve_expr(builder, expr_h)
    return true
end

function M.CapiDslAstNodeSetIdExpr(builder, node_h, expr_h)
    local node = resolve(builder, node_h, "node")
    node.id_expr = resolve_expr(builder, expr_h)
    return true
end

function M.CapiDslAstNodeSetPartName(builder, node_h, part_name)
    local node = resolve(builder, node_h, "node")
    node.part_name = part_name
    return true
end

function M.CapiDslAstNodeSetSlotName(builder, node_h, slot_name)
    local node = resolve(builder, node_h, "node")
    node.slot_name = slot_name
    return true
end

function M.CapiDslAstNodeSetChildrenMarker(builder, node_h, enabled)
    local node = resolve(builder, node_h, "node")
    node.has_children_marker = not not enabled
    return true
end

function M.CapiDslAstNodeAddChild(builder, node_h, item_h)
    local node = resolve(builder, node_h, "node")
    local item
    if item_h.pool == "node" or item_h.pool == "invoke" or item_h.pool == "splice" then
        item = resolve(builder, item_h, item_h.pool)
    else
        error("argile: unsupported child handle kind '" .. tostring(item_h.pool) .. "'")
    end
    assert_body_item(item)
    table.insert(node.children, item)
    return true
end

function M.CapiDslAstNodeAddOp(builder, node_h, block_kind, op_h)
    local node = resolve(builder, node_h, "node")
    local op = resolve_op(builder, op_h)
    local target = node_op_target(node, block_kind)
    table.insert(target, op)
    return true
end

function M.CapiDslAstNodeAddUseExpr(builder, node_h, expr_h)
    local node = resolve(builder, node_h, "node")
    local expr = resolve_expr(builder, expr_h)
    table.insert(node.uses, expr)
    return true
end

function M.CapiDslAstCreateStateOverlay(builder, state_name)
    if type(state_name) ~= "string" then
        error("argile: expected state name")
    end
    return alloc(builder, "state", AST.StateOverlay(state_name))
end

function M.CapiDslAstNodeAddState(builder, node_h, state_h)
    local node = resolve(builder, node_h, "node")
    local state = resolve(builder, state_h, "state")
    if node.states[state.name] ~= nil then
        error("argile: duplicate state overlay '" .. tostring(state.name) .. "'")
    end
    node.states[state.name] = state
    return true
end

function M.CapiDslAstStateAddOp(builder, state_h, block_kind, op_h)
    local state = resolve(builder, state_h, "state")
    local op = resolve_op(builder, op_h)
    local target = state_op_target(state, block_kind)
    table.insert(target, op)
    return true
end

-- ============================================================================
-- Invokes / Fills / Splices
-- ============================================================================

function M.CapiDslAstCreateInvoke(builder, component_name)
    if type(component_name) ~= "string" then
        error("argile: expected component invoke name")
    end
    return alloc(builder, "invoke", AST.ComponentInvoke(component_name, {}))
end

function M.CapiDslAstInvokeSetArgExpr(builder, invoke_h, arg_name, expr_h)
    local invoke = resolve(builder, invoke_h, "invoke")
    if invoke.args[arg_name] ~= nil then
        error("argile: duplicate invoke arg '" .. tostring(arg_name) .. "'")
    end
    invoke.args[arg_name] = resolve_expr(builder, expr_h)
    return true
end

function M.CapiDslAstInvokeSetIdExpr(builder, invoke_h, expr_h)
    local invoke = resolve(builder, invoke_h, "invoke")
    invoke.id_expr = resolve_expr(builder, expr_h)
    return true
end

function M.CapiDslAstInvokeAddFill(builder, invoke_h, fill_h)
    local invoke = resolve(builder, invoke_h, "invoke")
    local fill = resolve(builder, fill_h, "fill")
    table.insert(invoke.fills, fill)
    return true
end

function M.CapiDslAstInvokeAddBodyItem(builder, invoke_h, item_h)
    local invoke = resolve(builder, invoke_h, "invoke")
    local item
    if item_h.pool == "node" or item_h.pool == "invoke" or item_h.pool == "splice" then
        item = resolve(builder, item_h, item_h.pool)
    else
        error("argile: unsupported invocation body handle kind '" .. tostring(item_h.pool) .. "'")
    end
    assert_body_item(item)
    append_node_like(invoke.body_nodes, item)
    return true
end

function M.CapiDslAstCreateFill(builder, slot_name)
    if type(slot_name) ~= "string" then error("argile: expected fill slot name") end
    return alloc(builder, "fill", AST.FillDecl(slot_name, {}))
end

function M.CapiDslAstFillAddChild(builder, fill_h, item_h)
    local fill = resolve(builder, fill_h, "fill")
    local item
    if item_h.pool == "node" or item_h.pool == "invoke" or item_h.pool == "splice" then
        item = resolve(builder, item_h, item_h.pool)
    else
        error("argile: unsupported fill child handle kind '" .. tostring(item_h.pool) .. "'")
    end
    assert_body_item(item)
    table.insert(fill.children, item)
    return true
end

function M.CapiDslAstCreateSplice(builder, expr_fn)
    if type(expr_fn) ~= "function" then
        error("argile: expected splice expr function")
    end
    return alloc(builder, "splice", AST.Splice(expr_fn))
end

-- ============================================================================
-- Host-side compile entrypoints (canonical compiler path)
-- ============================================================================

function M.CapiDslAstCompileProgramQuote(builder, program_h, env_fn, registry)
    local program = resolve(builder, program_h, "program")
    return DslCompiler.compileAstProgram(program, env_fn, registry)
end

function M.CapiDslAstCompileProgramFunction(builder, name, program_h, env_fn, registry)
    local program = resolve(builder, program_h, "program")
    return DslCompiler.compileAstProgramFunction(name, program, env_fn, registry)
end

function M.CapiDslAstCompileProgramRenderFunction(builder, name, program_h, env_fn, registry)
    local program = resolve(builder, program_h, "program")
    return DslCompiler.compileAstProgramRenderFunction(name, program, env_fn, registry)
end

function M.CapiDslAstDebugProgram(builder, program_h)
    local program = resolve(builder, program_h, "program")
    return AST.Debug(program)
end

return M
