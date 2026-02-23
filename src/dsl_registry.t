local AST = require("src/lang/ast")
local style = require("src/style/core")

local M = {}

function M.Create()
    return {
        components = {},
        themes = {},
    }
end

function M.Clear(registry)
    registry.components = {}
    registry.themes = {}
end

function M.NormalizeRuntimeValue(value)
    if AST.IsKind(value, "Symbol") then
        return value.name
    end
    return value
end

local function eval_ops_list(ops, env_fn)
    local out = {}
    if not ops then return out end
    for _, op in ipairs(ops) do
        local args = {}
        for i, arg_expr in ipairs(op.args or {}) do
            args[i] = M.NormalizeRuntimeValue(AST.EvalExpr(arg_expr, env_fn))
        end
        out[#out + 1] = { name = op.name, args = args }
    end
    return out
end

local function set_nested_path(root, dotted_path, value)
    local cursor = root
    local parts = {}
    for part in dotted_path:gmatch("[^%.]+") do
        parts[#parts + 1] = part
    end
    for i = 1, #parts - 1 do
        local key = parts[i]
        local nextv = cursor[key]
        if type(nextv) ~= "table" or nextv._argile_dsl_kind then
            nextv = {}
            cursor[key] = nextv
        end
        cursor = nextv
    end
    cursor[parts[#parts]] = value
end

function M.BuildThemeValue(decl, decl_env)
    local theme = {
        _argile_dsl_kind = "theme",
        _argile_dsl_theme_name = decl.name,
        _argile_dsl_theme_decl = decl,
    }

    decl_env = decl_env or {}
    local decl_env_fn = function() return decl_env end
    for _, token_decl in pairs(decl.tokens or {}) do
        local value = M.NormalizeRuntimeValue(AST.EvalExpr(token_decl.value_expr, decl_env_fn))
        set_nested_path(theme, token_decl.path, value)
    end

    local function make_recipe_env_fn(opts)
        return function()
            local env = {}
            for k, v in pairs(decl_env) do
                env[k] = v
            end
            env.opts = opts or {}
            for k, v in pairs(theme) do
                if type(k) == "string" and k:sub(1, 10) ~= "_argile_dsl_" then
                    env[k] = v
                end
            end
            return env
        end
    end

    for recipe_name, recipe_decl in pairs(decl.recipes or {}) do
        theme[recipe_name] = function(opts)
            opts = opts or {}
            local env_fn = make_recipe_env_fn(opts)
            local patch = style.StylePatch:new()
            for _, block in ipairs(recipe_decl.body or {}) do
                local ops = eval_ops_list(block.ops, env_fn)
                if block.kind == "style" then
                    patch = style.apply_style_ops(patch, ops)
                elseif block.kind == "typography" then
                    patch = style.apply_typography_ops(patch, ops)
                elseif block.kind == "paint" then
                    patch = style.apply_paint_ops(patch, ops)
                elseif block.kind == "layout" then
                    patch = style.apply_layout_ops(patch, ops)
                else
                    error("argile: unknown recipe block kind '" .. tostring(block.kind) .. "'")
                end
            end
            return patch
        end
    end

    return theme
end

function M.BuildComponentHandle(decl, decl_env)
    decl._argile_dsl_decl_env = decl_env or {}
    return {
        _argile_dsl_kind = "component",
        _argile_dsl_component_name = decl.name,
        decl = decl,
    }
end

return M
