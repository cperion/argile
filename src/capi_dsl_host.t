local Ast = require("src/capi_dsl_ast")
local Compile = require("src/capi_dsl_compile")

local M = {}

local BUILDER_ERR_NONE = 0
local BUILDER_ERR_CALL = 1

M.CAPI_DSL_AST_BUILDER_ERR_NONE = BUILDER_ERR_NONE
M.CAPI_DSL_AST_BUILDER_ERR_CALL = BUILDER_ERR_CALL

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

local function set_last_builder_error(builder, code, message, api_name)
    if type(builder) ~= "table" then return end
    builder._last_builder_error = {
        code = code or BUILDER_ERR_CALL,
        message = tostring(message or ""),
        api = api_name,
    }
end

local function clear_last_builder_error(builder)
    if type(builder) ~= "table" then return end
    builder._last_builder_error = nil
end

function M.CapiDslAstClearLastBuilderError(builder)
    clear_last_builder_error(builder)
    return true
end

function M.CapiDslAstGetLastBuilderError(builder)
    local err = type(builder) == "table" and builder._last_builder_error or nil
    if err == nil then
        return { code = BUILDER_ERR_NONE, message = "", api = nil }
    end
    return {
        code = err.code or BUILDER_ERR_CALL,
        message = err.message or "",
        api = err.api,
    }
end

function M.CapiDslAstTryCall(builder, api_name, ...)
    if type(api_name) ~= "string" then
        set_last_builder_error(builder, BUILDER_ERR_CALL, "api_name must be string", nil)
        return false, nil, "api_name must be string"
    end
    local fn = M[api_name]
    if type(fn) ~= "function" then
        local msg = "unknown AST host API function '" .. tostring(api_name) .. "'"
        set_last_builder_error(builder, BUILDER_ERR_CALL, msg, api_name)
        return false, nil, msg
    end
    clear_last_builder_error(builder)
    local packed = { ... }
    packed.n = select("#", ...)
    local ok, r1, r2, r3, r4, r5 = pcall(function()
        return fn(unpack(packed, 1, packed.n))
    end)
    if not ok then
        set_last_builder_error(builder, BUILDER_ERR_CALL, r1, api_name)
        return false, nil, r1
    end
    return true, r1, r2, r3, r4, r5
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
