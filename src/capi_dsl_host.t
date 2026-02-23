local Ast = require("src/capi_dsl_ast")
local Compile = require("src/capi_dsl_compile")

local M = {}

M.CAPI_DSL_AST_FEATURE_CORE = 1
M.CAPI_DSL_AST_FEATURE_EXPRS = 2
M.CAPI_DSL_AST_FEATURE_COMPONENTS = 4
M.CAPI_DSL_AST_FEATURE_THEMES = 8
M.CAPI_DSL_AST_FEATURE_RECIPES = 16
M.CAPI_DSL_AST_FEATURE_COMPILE = 32
M.CAPI_DSL_AST_FEATURE_SOURCE_META = 64
M.CAPI_DSL_AST_FEATURE_DIAGNOSTICS = 128

function M.CapiDslAstGetFeatureFlags()
    return M.CAPI_DSL_AST_FEATURE_CORE
        + M.CAPI_DSL_AST_FEATURE_EXPRS
        + M.CAPI_DSL_AST_FEATURE_COMPONENTS
        + M.CAPI_DSL_AST_FEATURE_THEMES
        + M.CAPI_DSL_AST_FEATURE_RECIPES
        + M.CAPI_DSL_AST_FEATURE_COMPILE
        + M.CAPI_DSL_AST_FEATURE_SOURCE_META
        + M.CAPI_DSL_AST_FEATURE_DIAGNOSTICS
end

function M.CapiDslAstHasFeature(flag)
    local flags = M.CapiDslAstGetFeatureFlags()
    flag = tonumber(flag) or 0
    return flag ~= 0 and (flags % (flag * 2)) >= flag
end

for k, v in pairs(Ast) do
    if M[k] ~= nil then
        error("argile: duplicate host AST API symbol '" .. tostring(k) .. "'")
    end
    M[k] = v
end

for k, v in pairs(Compile) do
    if M[k] ~= nil then
        error("argile: duplicate host AST compile API symbol '" .. tostring(k) .. "'")
    end
    M[k] = v
end

return M
