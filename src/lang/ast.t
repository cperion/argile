--[[
    Argile DSL AST Types
    
    Tagged Lua tables representing DSL language constructs.
    All nodes carry source spans for error reporting.
]]

local Span = require("src/lang/argile_span")

local M = {}

-- ============================================================================
-- Helper Functions
-- ============================================================================

local function merge(t1, t2)
    local result = {}
    for k, v in pairs(t1) do
        result[k] = v
    end
    for k, v in pairs(t2) do
        result[k] = v
    end
    return result
end

-- ============================================================================
-- Base AST Node
-- ============================================================================

function M.Node(kind, span)
    return {
        _kind = kind,
        _span = span or Span.Synthetic(),
    }
end

-- ============================================================================
-- Declarations
-- ============================================================================

-- Full DSL program/module body (for non-parser frontends and canonical C API)
function M.Program(decls, body_nodes, span)
    return merge(M.Node("Program", span), {
        decls = decls or {},         -- ordered top-level declarations
        body_nodes = body_nodes or {}, -- argile body nodes/invokes/splices
    })
end

-- theme <name> ... end
function M.ThemeDecl(name, tokens, recipes, span)
    return merge(M.Node("ThemeDecl", span), {
        name = name,
        tokens = tokens or {},
        recipes = recipes or {},
    })
end

-- token <path> = <expr>
function M.TokenDecl(path, value_expr, span)
    return merge(M.Node("TokenDecl", span), {
        path = path,
        value_expr = value_expr,
    })
end

-- recipe <name>(<params>) ... end
function M.RecipeDecl(name, params, body, span)
    return merge(M.Node("RecipeDecl", span), {
        name = name,
        params = params or {},
        body = body or {},
    })
end

-- component <name>(<params>) ... end
function M.ComponentDecl(name, params, variants, root, span)
    return merge(M.Node("ComponentDecl", span), {
        name = name,
        params = params or {},
        variants = variants or {},
        root = root,
    })
end

-- variant <name> = a | b | c
function M.VariantDecl(name, values, span)
    return merge(M.Node("VariantDecl", span), {
        name = name,
        values = values or {},
    })
end

-- ============================================================================
-- Node Declarations (inside root/component)
-- ============================================================================

function M.NodeDecl(kind, span)
    return merge(M.Node("NodeDecl", span), {
        kind = kind,              -- "el" | "text"
        text_expr = nil,          -- for text nodes
        id_expr = nil,
        part_name = nil,          -- from part(...) directive
        slot_name = nil,          -- from slot(...) declaration
        has_children_marker = false,
        layout_ops = {},
        style_ops = {},
        typography_ops = {},
        paint_ops = {},
        uses = {},                -- list of use expressions
        states = {},              -- map: state_name -> StateOverlay
        children = {},
    })
end

-- State overlay: state <name> ... end
function M.StateOverlay(name, span)
    return merge(M.Node("StateOverlay", span), {
        name = name,
        style_ops = {},
        typography_ops = {},
        paint_ops = {},
    })
end

-- ============================================================================
-- Component Invocation
-- ============================================================================

-- <name>(<named_args>) ... end
function M.ComponentInvoke(name, args, span)
    return merge(M.Node("ComponentInvoke", span), {
        name = name,
        args = args or {},        -- map: arg_name -> arg_value_expr
        id_expr = nil,            -- from invocation-body id(...)
        fills = {},               -- list of FillDecl
        body_nodes = {},          -- bare nodes for children
    })
end

-- fill(<name>) ... end
function M.FillDecl(slot_name, children, span)
    return merge(M.Node("FillDecl", span), {
        slot_name = slot_name,
        children = children or {},
    })
end

-- ============================================================================
-- Expressions and Values
-- ============================================================================

-- Literal expression (bool/int/float/string/table values)
function M.LiteralExpr(value, span)
    return merge(M.Node("LiteralExpr", span), {
        value = value,
    })
end

-- token(foo.bar.baz)
function M.TokenRefExpr(path, span)
    return merge(M.Node("TokenRefExpr", span), {
        path = path or {}, -- array of path segments
    })
end

-- foo.bar.baz (runtime env / globals path lookup)
function M.PathRefExpr(path, span)
    return merge(M.Node("PathRefExpr", span), {
        path = path or {}, -- array of path segments
    })
end

-- Generic function call expression (host-side evaluable)
function M.CallExpr(callee_expr, call_style, span)
    return merge(M.Node("CallExpr", span), {
        callee_expr = callee_expr,           -- expression resolving to callable
        call_style = call_style or "positional", -- "named" | "positional"
        named_args = {},                     -- map: name -> expr (for named style)
        pos_args = {},                       -- list: expr (for positional style)
    })
end

-- Generic Lua expression fallback parsed by Terra language extension.
-- Parser/native Terra only; not portable to plain C API.
function M.LuaExpr(expr_fn, span)
    return merge(M.Node("LuaExpr", span), {
        expr_fn = expr_fn, -- function(env_table) -> value
    })
end

-- Symbol for variant values (primary, md, etc.)
function M.Symbol(name, span)
    return merge(M.Node("Symbol", span), {
        name = name,
    })
end

-- Splice: [expression] escape in argile body — injects a pre-built V2 subtree
function M.Splice(expr_fn, span)
    return merge(M.Node("Splice", span), {
        expr_fn = expr_fn,       -- function(env_fn) -> V2 node or list of V2 nodes
    })
end

-- ============================================================================
-- Expression Evaluation Helpers (shared by parser helpers/compiler)
-- ============================================================================

local function env_table_from_fn(env_fn)
    if env_fn == nil then return nil end
    return env_fn()
end

local function normalize_eval_value(v)
    if M.IsKind(v, "Symbol") then
        return v.name
    end
    return v
end

local function resolve_dotted_path(path, env_fn, span, kind_label)
    local env = env_table_from_fn(env_fn)
    local target = env and env[path[1]] or nil
    if target == nil then
        target = rawget(_G, path[1])
    end

    for i = 2, #path do
        if target == nil then break end
        target = target[path[i]]
    end

    if target == nil then
        local dotted = table.concat(path or {}, ".")
        local prefix = kind_label or "path"
        if span and span.file then
            error(prefix .. " '" .. dotted .. "' is nil")
        else
            error(prefix .. " '" .. dotted .. "' is nil")
        end
    end
    return target
end

-- Evaluate an AST expression (or legacy callable value) against an env_fn.
-- Supports a transition period where parser-produced AST may still contain
-- callables in some fields (e.g. use expressions) while the canonical AST
-- representation is made explicit.
function M.EvalExpr(expr, env_fn)
    if expr == nil then return nil end

    if type(expr) == "function" then
        return expr(env_fn)
    end

    if not M.IsKind(expr, "LiteralExpr")
        and not M.IsKind(expr, "TokenRefExpr")
        and not M.IsKind(expr, "PathRefExpr")
        and not M.IsKind(expr, "CallExpr")
        and not M.IsKind(expr, "LuaExpr")
        and not M.IsKind(expr, "Symbol") then
        return expr
    end

    if M.IsKind(expr, "LiteralExpr") then
        return expr.value
    elseif M.IsKind(expr, "TokenRefExpr") then
        return resolve_dotted_path(expr.path, env_fn, expr._span, "token path")
    elseif M.IsKind(expr, "PathRefExpr") then
        return resolve_dotted_path(expr.path, env_fn, expr._span, "path")
    elseif M.IsKind(expr, "CallExpr") then
        local target = M.EvalExpr(expr.callee_expr, env_fn)
        if type(target) ~= "function" then
            error("call target is not callable")
        end
        if expr.call_style == "named" then
            local opts = {}
            for name, arg_expr in pairs(expr.named_args or {}) do
                opts[name] = normalize_eval_value(M.EvalExpr(arg_expr, env_fn))
            end
            return target(opts)
        else
            local args = {}
            for i, arg_expr in ipairs(expr.pos_args or {}) do
                args[i] = normalize_eval_value(M.EvalExpr(arg_expr, env_fn))
            end
            return target(unpack(args))
        end
    elseif M.IsKind(expr, "LuaExpr") then
        local env = env_table_from_fn(env_fn) or {}
        return expr.expr_fn(env)
    elseif M.IsKind(expr, "Symbol") then
        return expr
    end

    return expr
end

-- ============================================================================
-- Validation Helpers
-- ============================================================================

-- Check if a node is of a specific kind
function M.IsKind(node, kind)
    return type(node) == "table" and node._kind == kind
end

-- Get node kind as string
function M.GetKind(node)
    return node and node._kind or "nil"
end

-- Format node for debugging
function M.Debug(node, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    
    if type(node) ~= "table" then
        return prefix .. tostring(node)
    end
    
    if not node._kind then
        return prefix .. "<not an AST node>"
    end
    
    local lines = {prefix .. node._kind .. " {"}
    
    for k, v in pairs(node) do
        if k:sub(1, 1) ~= "_" then  -- skip internal fields
            if type(v) == "table" then
                if v._kind then
                    table.insert(lines, prefix .. "  " .. k .. " =")
                    table.insert(lines, M.Debug(v, indent + 2))
                elseif #v > 0 then
                    table.insert(lines, prefix .. "  " .. k .. " = [")
                    for i, item in ipairs(v) do
                        if type(item) == "table" and item._kind then
                            table.insert(lines, M.Debug(item, indent + 3))
                        else
                            table.insert(lines, prefix .. "    " .. tostring(item))
                        end
                    end
                    table.insert(lines, prefix .. "  ]")
                end
            else
                table.insert(lines, prefix .. "  " .. k .. " = " .. tostring(v))
            end
        end
    end
    
    table.insert(lines, prefix .. "}")
    return table.concat(lines, "\n")
end

return M
