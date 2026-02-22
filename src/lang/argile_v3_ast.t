--[[
    Argile V3 AST Types
    
    Tagged Lua tables representing V3 language constructs.
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
-- Symbols and Values
-- ============================================================================

-- Symbol for variant values (primary, md, etc.)
function M.Symbol(name, span)
    return merge(M.Node("Symbol", span), {
        name = name,
    })
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
