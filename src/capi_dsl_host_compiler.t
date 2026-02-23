local Compile = require("src/capi_dsl_compile")

local M = {}

local _next_ctx_id = 1

local ERR_NONE = 0
local ERR_INVALID_CONTEXT = 1
local ERR_INVALID_ARGUMENT = 2
local ERR_COMPILE = 3

M.CAPI_DSL_AST_HOST_COMPILER_ERR_NONE = ERR_NONE
M.CAPI_DSL_AST_HOST_COMPILER_ERR_INVALID_CONTEXT = ERR_INVALID_CONTEXT
M.CAPI_DSL_AST_HOST_COMPILER_ERR_INVALID_ARGUMENT = ERR_INVALID_ARGUMENT
M.CAPI_DSL_AST_HOST_COMPILER_ERR_COMPILE = ERR_COMPILE

local function set_last_error(ctx, code, message, api)
    if type(ctx) ~= "table" then return end
    ctx._last_host_compiler_error = {
        code = code or ERR_COMPILE,
        message = tostring(message or ""),
        api = api,
    }
end

local function clear_last_error(ctx)
    if type(ctx) ~= "table" then return end
    ctx._last_host_compiler_error = nil
end

local function check_ctx(ctx, api_name)
    if type(ctx) ~= "table" or ctx._kind ~= "CapiDslAstHostCompilerContext" then
        error("argile: invalid host compiler context")
    end
    if not ctx._alive then
        error("argile: host compiler context is destroyed")
    end
    clear_last_error(ctx)
    return ctx
end

local function normalize_cache_key(cache_key)
    local t = type(cache_key)
    if t == "string" then
        if cache_key == "" then
            error("argile: cache_key must not be empty")
        end
        return cache_key
    end
    if t == "number" or t == "boolean" then
        return tostring(cache_key)
    end
    error("argile: cache_key must be string/number/boolean")
end

local function cache_bucket(ctx, kind)
    local b = ctx._cache[kind]
    if b == nil then
        error("argile: unknown compiler cache kind '" .. tostring(kind) .. "'")
    end
    return b
end

local function cache_entry_count(bucket)
    local n = 0
    for _k, _v in pairs(bucket) do
        n = n + 1
    end
    return n
end

local function maybe_bind_global_name(name, compiled)
    if type(name) == "string" and name ~= "" then
        rawset(_G, name, compiled)
    end
end

local function try_cached(ctx, api_name, kind, cache_key, compile_call)
    check_ctx(ctx, api_name)
    local key
    local ok_key, key_or_err = pcall(normalize_cache_key, cache_key)
    if not ok_key then
        set_last_error(ctx, ERR_INVALID_ARGUMENT, key_or_err, api_name)
        return false, nil, false, key_or_err
    end
    key = key_or_err

    local bucket = cache_bucket(ctx, kind)
    local entry = bucket[key]
    if entry ~= nil then
        ctx._cache_hits = (ctx._cache_hits or 0) + 1
        if entry.global_name ~= nil then
            maybe_bind_global_name(entry.global_name, entry.value)
        end
        return true, entry.value, true, nil
    end

    local ok_compile, compiled, err = compile_call()
    if not ok_compile then
        ctx._cache_misses = (ctx._cache_misses or 0) + 1
        set_last_error(ctx, ERR_COMPILE, err, api_name)
        return false, nil, false, err
    end

    ctx._cache_misses = (ctx._cache_misses or 0) + 1
    bucket[key] = {
        value = compiled,
        global_name = (type(ctx._pending_global_name) == "string" and ctx._pending_global_name) or nil,
    }
    return true, compiled, false, nil
end

local function create_ctx(options)
    local ctx = {
        _kind = "CapiDslAstHostCompilerContext",
        _alive = true,
        _id = _next_ctx_id,
        _options = type(options) == "table" and options or {},
        _cache = {
            ["quote"] = {},
            ["function_body"] = {},
            render_function = {},
        },
        _cache_hits = 0,
        _cache_misses = 0,
        _last_host_compiler_error = nil,
    }
    _next_ctx_id = _next_ctx_id + 1
    return ctx
end

function M.CapiDslAstHostCreateCompilerContext(options)
    return create_ctx(options)
end

function M.CapiDslAstHostDestroyCompilerContext(ctx)
    check_ctx(ctx, "CapiDslAstHostDestroyCompilerContext")
    ctx._alive = false
    ctx._cache = {}
    ctx._options = nil
    return true
end

function M.CapiDslAstHostResetCompilerContext(ctx)
    check_ctx(ctx, "CapiDslAstHostResetCompilerContext")
    ctx._cache = {
        ["quote"] = {},
        ["function_body"] = {},
        render_function = {},
    }
    ctx._cache_hits = 0
    ctx._cache_misses = 0
    clear_last_error(ctx)
    return true
end

function M.CapiDslAstHostClearCompileCache(ctx)
    check_ctx(ctx, "CapiDslAstHostClearCompileCache")
    ctx._cache["quote"] = {}
    ctx._cache["function_body"] = {}
    ctx._cache.render_function = {}
    return true
end

function M.CapiDslAstHostInvalidateCompileCacheKey(ctx, cache_key)
    check_ctx(ctx, "CapiDslAstHostInvalidateCompileCacheKey")
    local key = normalize_cache_key(cache_key)
    ctx._cache["quote"][key] = nil
    ctx._cache["function_body"][key] = nil
    ctx._cache.render_function[key] = nil
    return true
end

function M.CapiDslAstHostGetCompileCacheStats(ctx)
    check_ctx(ctx, "CapiDslAstHostGetCompileCacheStats")
    local quote_entries = cache_entry_count(ctx._cache["quote"])
    local fn_entries = cache_entry_count(ctx._cache["function_body"])
    local render_entries = cache_entry_count(ctx._cache.render_function)
    return {
        hits = ctx._cache_hits or 0,
        misses = ctx._cache_misses or 0,
        quote_entries = quote_entries,
        function_entries = fn_entries,
        render_function_entries = render_entries,
        total_entries = quote_entries + fn_entries + render_entries,
    }
end

function M.CapiDslAstHostClearLastCompilerContextError(ctx)
    clear_last_error(ctx)
    return true
end

function M.CapiDslAstHostGetLastCompilerContextError(ctx)
    local err = type(ctx) == "table" and ctx._last_host_compiler_error or nil
    if err == nil then
        return { code = ERR_NONE, message = "", api = nil }
    end
    return {
        code = err.code or ERR_COMPILE,
        message = err.message or "",
        api = err.api,
    }
end

function M.CapiDslAstHostTryCompileProgramQuoteCached(ctx, cache_key, builder, program_h, env_fn, registry)
    return try_cached(ctx, "CapiDslAstHostTryCompileProgramQuoteCached", "quote", cache_key, function()
        return Compile.CapiDslAstTryCompileProgramQuote(builder, program_h, env_fn, registry)
    end)
end

function M.CapiDslAstHostCompileProgramQuoteCached(ctx, cache_key, builder, program_h, env_fn, registry)
    local ok, compiled, hit, err = M.CapiDslAstHostTryCompileProgramQuoteCached(ctx, cache_key, builder, program_h, env_fn, registry)
    if not ok then error(err) end
    return compiled, hit
end

function M.CapiDslAstHostTryCompileProgramFunctionCached(ctx, cache_key, builder, name, program_h, env_fn, registry)
    ctx._pending_global_name = name
    local ok, compiled, hit, err = try_cached(ctx, "CapiDslAstHostTryCompileProgramFunctionCached", "function_body", cache_key, function()
        return Compile.CapiDslAstTryCompileProgramFunction(builder, name, program_h, env_fn, registry)
    end)
    ctx._pending_global_name = nil
    if ok and type(name) == "string" and name ~= "" then
        maybe_bind_global_name(name, compiled)
    end
    return ok, compiled, hit, err
end

function M.CapiDslAstHostCompileProgramFunctionCached(ctx, cache_key, builder, name, program_h, env_fn, registry)
    local ok, compiled, hit, err = M.CapiDslAstHostTryCompileProgramFunctionCached(ctx, cache_key, builder, name, program_h, env_fn, registry)
    if not ok then error(err) end
    return compiled, hit
end

function M.CapiDslAstHostTryCompileProgramRenderFunctionCached(ctx, cache_key, builder, name, program_h, env_fn, registry)
    ctx._pending_global_name = name
    local ok, compiled, hit, err = try_cached(ctx, "CapiDslAstHostTryCompileProgramRenderFunctionCached", "render_function", cache_key, function()
        return Compile.CapiDslAstTryCompileProgramRenderFunction(builder, name, program_h, env_fn, registry)
    end)
    ctx._pending_global_name = nil
    if ok and type(name) == "string" and name ~= "" then
        maybe_bind_global_name(name, compiled)
    end
    return ok, compiled, hit, err
end

function M.CapiDslAstHostCompileProgramRenderFunctionCached(ctx, cache_key, builder, name, program_h, env_fn, registry)
    local ok, compiled, hit, err = M.CapiDslAstHostTryCompileProgramRenderFunctionCached(ctx, cache_key, builder, name, program_h, env_fn, registry)
    if not ok then error(err) end
    return compiled, hit
end

return M
