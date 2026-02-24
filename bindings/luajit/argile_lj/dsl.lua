local A = require("bindings.luajit.argile_lj.ast")

local M = {}

local function split_path(path)
    if type(path) == "table" then return path end
    local out = {}
    for seg in tostring(path):gmatch("[^%.]+") do
        out[#out + 1] = seg
    end
    return out
end

local function is_ast(v)
    return type(v) == "table" and v._kind ~= nil
end

local function expr(v)
    if v == nil then return nil end
    if is_ast(v) then return v end
    return A.LiteralExpr(v)
end

local function op_list(ops)
    if not ops then return {} end
    local out = {}
    for _, op in ipairs(ops) do
        if op.name then
            local args = {}
            for i, a in ipairs(op.args or {}) do args[i] = expr(a) end
            out[#out + 1] = { name = op.name, args = args }
        elseif op[1] then
            local args = {}
            for i = 2, #op do args[#args + 1] = expr(op[i]) end
            out[#out + 1] = { name = op[1], args = args }
        end
    end
    return out
end

function M.literal(v) return A.LiteralExpr(v) end
function M.sym(name) return A.Symbol(name) end
function M.token(path) return A.TokenRefExpr(split_path(path)) end
function M.path(path) return A.PathRefExpr(split_path(path)) end

function M.call(callee, args)
    local c = A.CallExpr(expr(callee), (args and args.named) and "named" or "positional")
    if args and args.named then
        c.named_args = {}
        for k, v in pairs(args.named) do c.named_args[k] = expr(v) end
    else
        c.pos_args = {}
        for i, v in ipairs(args or {}) do c.pos_args[i] = expr(v) end
    end
    return c
end

function M.use(v)
    return expr(v)
end

function M.state(name, spec)
    spec = spec or {}
    local s = A.StateOverlay(name)
    s.style_ops = op_list(spec.style)
    s.typography_ops = op_list(spec.typography)
    s.paint_ops = op_list(spec.paint)
    return s
end

local function node_common(n, spec)
    spec = spec or {}
    n.id_expr = expr(spec.id)
    n.part_name = spec.part
    n.slot_name = spec.slot
    n.has_children_marker = not not spec.children_marker
    n.layout_ops = op_list(spec.layout)
    n.style_ops = op_list(spec.style)
    n.typography_ops = op_list(spec.typography)
    n.paint_ops = op_list(spec.paint)
    n.uses = {}
    for _, u in ipairs(spec.use or spec.uses or {}) do
        n.uses[#n.uses + 1] = expr(u)
    end
    if spec.states then
        if #spec.states > 0 then
            for _, st in ipairs(spec.states) do
                n.states[st.name] = st
            end
        else
            for name, st_spec in pairs(spec.states) do
                local st = M.state(name, st_spec)
                n.states[name] = st
            end
        end
    end
    n.children = spec.children or {}
    return n
end

function M.el(spec)
    return node_common(A.NodeDecl("el"), spec)
end

function M.text(content_or_spec, maybe_spec)
    local spec
    if type(content_or_spec) == "table" and not is_ast(content_or_spec) then
        spec = content_or_spec
    else
        spec = maybe_spec or {}
        spec.text = content_or_spec
    end
    local n = node_common(A.NodeDecl("text"), spec)
    n.text_expr = expr(spec.text or "")
    return n
end

function M.fill(slot_name, children)
    return A.FillDecl(slot_name, children or {})
end

function M.invoke(name, args, spec)
    local inv = A.ComponentInvoke(name, {})
    for k, v in pairs(args or {}) do
        inv.args[k] = expr(v)
    end
    spec = spec or {}
    inv.id_expr = expr(spec.id)
    inv.fills = spec.fills or {}
    inv.body_nodes = spec.children or spec.body_nodes or {}
    return inv
end

function M.variant(name, values)
    local out = {}
    for i, v in ipairs(values or {}) do
        out[i] = is_ast(v) and v or M.sym(v)
    end
    return A.VariantDecl(name, out)
end

function M.component(name, spec)
    spec = spec or {}
    local variants = {}
    if spec.variants then
        if #spec.variants > 0 then
            variants = spec.variants
        else
            for vname, vals in pairs(spec.variants) do
                variants[#variants + 1] = M.variant(vname, vals)
            end
        end
    end
    return A.ComponentDecl(name, spec.params or {}, variants, spec.root)
end

function M.token_decl(path, value)
    return A.TokenDecl(type(path) == "string" and path or table.concat(path, "."), expr(value))
end

function M.recipe(name, params, body)
    return A.RecipeDecl(name, params or {}, body or {})
end

function M.theme(name, spec)
    spec = spec or {}
    return A.ThemeDecl(name, spec.tokens or {}, spec.recipes or {})
end

function M.program(spec)
    spec = spec or {}
    return A.Program(spec.decls or {}, spec.body or spec.body_nodes or {})
end

-- Small no-parens friendly helpers
M.id = expr
M.children = function(nodes) return nodes or {} end

return M
