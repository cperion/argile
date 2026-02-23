local ui = require("src.init")
local Ast = ui.GetDslAstApi()

local Mini = {}

local function is_array(t)
    if type(t) ~= "table" then return false end
    local n = 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" then return false end
        if k > n then n = k end
    end
    for i = 1, n do
        if t[i] == nil then return false end
    end
    return true
end

function Mini.expr(b, v)
    if type(v) == "table" and v.__expr_handle then
        return v.__expr_handle
    end
    if type(v) == "table" and v.__symbol then
        return Ast.CapiDslAstCreateExprSymbol(b, v.__symbol)
    end
    if type(v) == "table" and v.__token then
        return Ast.CapiDslAstCreateExprTokenRef(b, v.__token)
    end
    if type(v) == "table" and v.__path then
        return Ast.CapiDslAstCreateExprPathRef(b, v.__path)
    end
    if type(v) == "table" and v.__call then
        local call_desc = v.__call
        local callee = Mini.expr(b, call_desc.callee)
        local call = Ast.CapiDslAstCreateExprCall(b, callee, call_desc.style or "named")
        if call_desc.named then
            for name, value in pairs(call_desc.named) do
                Ast.CapiDslAstExprCallAddNamedArg(b, call, name, Mini.expr(b, value))
            end
        end
        if call_desc.pos then
            for i = 1, #call_desc.pos do
                Ast.CapiDslAstExprCallAddPosArg(b, call, Mini.expr(b, call_desc.pos[i]))
            end
        end
        return call
    end
    if type(v) == "boolean" then return Ast.CapiDslAstCreateExprBool(b, v) end
    if type(v) == "number" then return Ast.CapiDslAstCreateExprLiteral(b, v) end
    if type(v) == "string" then return Ast.CapiDslAstCreateExprString(b, v) end
    if type(v) == "table" then return Ast.CapiDslAstCreateExprLiteral(b, v) end
    error("unsupported expr value: " .. tostring(v))
end

function Mini.symbol(name) return { __symbol = name } end
function Mini.token(path) return { __token = path } end
function Mini.path(path) return { __path = path } end
function Mini.call(callee, named_or_pos)
    local d = { callee = callee, style = "named" }
    if is_array(named_or_pos) then
        d.style = "positional"
        d.pos = named_or_pos
    else
        d.named = named_or_pos or {}
    end
    return { __call = d }
end

function Mini.op(name, ...)
    return { name = name, args = { ... } }
end

local function add_ops(b, add_fn, owner_h, block_kind, ops)
    for i = 1, #(ops or {}) do
        local op_desc = ops[i]
        local op_h = Ast.CapiDslAstCreateOp(b, op_desc.name)
        for j = 1, #(op_desc.args or {}) do
            Ast.CapiDslAstOpAddArgExpr(b, op_h, Mini.expr(b, op_desc.args[j]))
        end
        add_fn(b, owner_h, block_kind, op_h)
    end
end

local function build_node_like(b, item)
    if item.type == "el" or item.type == "text" then
        local n = (item.type == "el") and Ast.CapiDslAstCreateNodeElement(b) or Ast.CapiDslAstCreateNodeText(b)
        if item.id ~= nil then Ast.CapiDslAstNodeSetIdExpr(b, n, Mini.expr(b, item.id)) end
        if item.part ~= nil then Ast.CapiDslAstNodeSetPartName(b, n, item.part) end
        if item.slot ~= nil then Ast.CapiDslAstNodeSetSlotName(b, n, item.slot) end
        if item.children_marker then Ast.CapiDslAstNodeSetChildrenMarker(b, n, true) end
        if item.type == "text" and item.text ~= nil then Ast.CapiDslAstNodeSetTextExpr(b, n, Mini.expr(b, item.text)) end
        for i = 1, #(item.use or {}) do
            Ast.CapiDslAstNodeAddUseExpr(b, n, Mini.expr(b, item.use[i]))
        end
        add_ops(b, Ast.CapiDslAstNodeAddOp, n, "layout", item.layout)
        add_ops(b, Ast.CapiDslAstNodeAddOp, n, "style", item.style)
        add_ops(b, Ast.CapiDslAstNodeAddOp, n, "typography", item.typography)
        add_ops(b, Ast.CapiDslAstNodeAddOp, n, "paint", item.paint)
        for state_name, state_spec in pairs(item.states or {}) do
            local s = Ast.CapiDslAstCreateStateOverlay(b, state_name)
            add_ops(b, Ast.CapiDslAstStateAddOp, s, "style", state_spec.style)
            add_ops(b, Ast.CapiDslAstStateAddOp, s, "typography", state_spec.typography)
            add_ops(b, Ast.CapiDslAstStateAddOp, s, "paint", state_spec.paint)
            Ast.CapiDslAstNodeAddState(b, n, s)
        end
        for i = 1, #(item.children or {}) do
            Ast.CapiDslAstNodeAddChild(b, n, build_node_like(b, item.children[i]))
        end
        return n
    elseif item.type == "invoke" then
        local inv = Ast.CapiDslAstCreateInvoke(b, item.name)
        if item.id ~= nil then Ast.CapiDslAstInvokeSetIdExpr(b, inv, Mini.expr(b, item.id)) end
        for k, v in pairs(item.args or {}) do
            Ast.CapiDslAstInvokeSetArgExpr(b, inv, k, Mini.expr(b, v))
        end
        for i = 1, #(item.fills or {}) do
            local fdesc = item.fills[i]
            local f = Ast.CapiDslAstCreateFill(b, fdesc.slot)
            for j = 1, #(fdesc.children or {}) do
                Ast.CapiDslAstFillAddChild(b, f, build_node_like(b, fdesc.children[j]))
            end
            Ast.CapiDslAstInvokeAddFill(b, inv, f)
        end
        for i = 1, #(item.children or {}) do
            Ast.CapiDslAstInvokeAddBodyItem(b, inv, build_node_like(b, item.children[i]))
        end
        return inv
    else
        error("unsupported item type: " .. tostring(item.type))
    end
end

function Mini.build_program(spec)
    local b = Ast.CapiDslAstCreateBuilder()
    local program = Ast.CapiDslAstCreateProgram(b)

    for _, theme_spec in ipairs(spec.themes or {}) do
        local theme_h = Ast.CapiDslAstCreateTheme(b, theme_spec.name)
        for path, value in pairs(theme_spec.tokens or {}) do
            local tok = Ast.CapiDslAstCreateToken(b, path)
            Ast.CapiDslAstTokenSetValueExpr(b, tok, Mini.expr(b, value))
            Ast.CapiDslAstThemeAddToken(b, theme_h, tok)
        end
        for _, recipe_spec in ipairs(theme_spec.recipes or {}) do
            local recipe_h = Ast.CapiDslAstCreateRecipe(b, recipe_spec.name)
            for _, param in ipairs(recipe_spec.params or {}) do
                Ast.CapiDslAstRecipeAddParam(b, recipe_h, param)
            end
            add_ops(b, Ast.CapiDslAstRecipeAddOp, recipe_h, "style", recipe_spec.style)
            add_ops(b, Ast.CapiDslAstRecipeAddOp, recipe_h, "typography", recipe_spec.typography)
            add_ops(b, Ast.CapiDslAstRecipeAddOp, recipe_h, "paint", recipe_spec.paint)
            Ast.CapiDslAstThemeAddRecipe(b, theme_h, recipe_h)
        end
        Ast.CapiDslAstProgramAddDecl(b, program, theme_h)
    end

    for _, comp_spec in ipairs(spec.components or {}) do
        local comp_h = Ast.CapiDslAstCreateComponent(b, comp_spec.name)
        for _, p in ipairs(comp_spec.params or {}) do
            Ast.CapiDslAstComponentAddParam(b, comp_h, p)
        end
        for _, v in ipairs(comp_spec.variants or {}) do
            local vh = Ast.CapiDslAstCreateVariant(b, v.name)
            for _, vv in ipairs(v.values or {}) do
                Ast.CapiDslAstVariantAddValue(b, vh, vv)
            end
            Ast.CapiDslAstComponentAddVariant(b, comp_h, vh)
        end
        Ast.CapiDslAstComponentSetRootNode(b, comp_h, build_node_like(b, comp_spec.root))
        Ast.CapiDslAstProgramAddDecl(b, program, comp_h)
    end

    for i = 1, #(spec.body or {}) do
        Ast.CapiDslAstProgramAddBodyItem(b, program, build_node_like(b, spec.body[i]))
    end

    return b, program
end

-- Demo program built from plain Lua tables.
local demo_spec = {
    themes = {
        {
            name = "design",
            tokens = {
                ["color.surface"] = { r = 0.12, g = 0.14, b = 0.18, a = 1.0 },
                ["color.text"] = { r = 0.95, g = 0.96, b = 0.98, a = 1.0 },
            },
            recipes = {
                {
                    name = "card",
                    style = { Mini.op("bg", Mini.token("color.surface")) },
                },
                {
                    name = "label",
                    typography = {
                        Mini.op("color", Mini.token("color.text")),
                        Mini.op("font_size", 12),
                        Mini.op("line_height", 12),
                    },
                },
            },
        },
    },
    components = {
        {
            name = "Badge",
            params = { "props" },
            variants = {
                { name = "tone", values = { "primary", "secondary" } },
            },
            root = {
                type = "el",
                id = Mini.path("props.id"),
                use = { Mini.call(Mini.path("design.card"), {}) },
                layout = {
                    Mini.op("width_fixed", 96.0),
                    Mini.op("height_fixed", 40.0),
                    Mini.op("padding", 4),
                },
                children = {
                    {
                        type = "el",
                        slot = "content",
                        children = {
                            { type = "text", text = "fallback", use = { Mini.call(Mini.path("design.label"), {}) } },
                        },
                    },
                    { type = "el", children_marker = true },
                },
            },
        },
    },
    body = {
        {
            type = "invoke",
            name = "Badge",
            id = "badge_root",
            args = { id = "from_wrapper", tone = Mini.symbol("secondary") },
            fills = {
                { slot = "content", children = {
                    { type = "text", id = "fill_text", text = "F", use = { Mini.call(Mini.path("design.label"), {}) } },
                }},
            },
            children = {
                { type = "text", id = "body_text", text = "B", use = { Mini.call(Mini.path("design.label"), {}) } },
            },
        },
    },
}

local builder, program = Mini.build_program(demo_spec)
print("=== Host AST Wrapper Demo: Program AST ===")
print(Ast.CapiDslAstDebugProgram(builder, program))

local compiled = Ast.CapiDslAstCompileProgramQuote(builder, program, function() return {} end)
print("=== Host AST Wrapper Demo: Compiled Quote ===")
print(tostring(compiled))
