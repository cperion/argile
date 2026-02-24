local HostCompiler = require("src/capi_dsl_host_compiler")

local M = {}

local _next_backend_id = 1

local ERR_NONE = 0
local ERR_INVALID_BACKEND = 1
local ERR_INVALID_ARGUMENT = 2
local ERR_COMPILE = 3
local ERR_MISSING_ROUTE = 4

M.CAPI_DSL_AST_HOST_CALLBACK_ERR_NONE = ERR_NONE
M.CAPI_DSL_AST_HOST_CALLBACK_ERR_INVALID_BACKEND = ERR_INVALID_BACKEND
M.CAPI_DSL_AST_HOST_CALLBACK_ERR_INVALID_ARGUMENT = ERR_INVALID_ARGUMENT
M.CAPI_DSL_AST_HOST_CALLBACK_ERR_COMPILE = ERR_COMPILE
M.CAPI_DSL_AST_HOST_CALLBACK_ERR_MISSING_ROUTE = ERR_MISSING_ROUTE

local FetchRenderPtrCallbackTy = terralib.types.funcpointer({ int32 }, &opaque)
M.CAPI_DSL_AST_HOST_CALLBACK_FETCH_RENDER_PTR_TYPE = FetchRenderPtrCallbackTy

local function clear_last_error(backend)
    if type(backend) == "table" then
        backend._last_callback_error = nil
    end
end

local function set_last_error(backend, code, message, api, mode)
    if type(backend) ~= "table" then return end
    backend._last_callback_error = {
        code = code or ERR_COMPILE,
        message = tostring(message or ""),
        api = api,
        mode = mode,
    }
end

local function check_backend(backend, api_name)
    if type(backend) ~= "table" or backend._kind ~= "CapiDslAstHostCallbackBackend" then
        error("argile: invalid host callback backend")
    end
    if not backend._alive then
        error("argile: host callback backend is destroyed")
    end
    if api_name ~= nil then
        clear_last_error(backend)
    end
    return backend
end

local function normalize_mode(mode)
    if type(mode) ~= "number" then
        error("argile: mode must be number")
    end
    mode = math.floor(mode)
    if mode < -2147483648 or mode > 2147483647 then
        error("argile: mode out of int32 range")
    end
    return mode
end

local function normalize_name(name)
    if name == nil then
        return nil
    end
    if type(name) ~= "string" then
        error("argile: route global name must be string or nil")
    end
    if name == "" then
        return nil
    end
    return name
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

local function route_key_for(mode)
    return tostring(mode)
end

local function get_route(backend, mode)
    return backend._routes[route_key_for(mode)]
end

local function fetch_render_ptr_internal(backend, mode, api_name)
    if type(backend) ~= "table" or not backend._alive then
        local msg = "argile: host callback backend is destroyed"
        set_last_error(backend, ERR_INVALID_BACKEND, msg, api_name, mode)
        return nil, msg
    end
    local route = get_route(backend, mode)
    if route == nil then
        local msg = "argile: no callback compile route configured for mode " .. tostring(mode)
        set_last_error(backend, ERR_MISSING_ROUTE, msg, api_name, mode)
        return nil, msg
    end

    local ok, fn_or_nil, _hit, err = HostCompiler.CapiDslAstHostTryCompileProgramRenderFunctionCached(
        backend.host_ctx,
        route.cache_key,
        backend.builder,
        route.global_name,
        backend.program_h,
        backend.env_fn,
        backend.registry
    )

    if not ok then
        local host_diag = HostCompiler.CapiDslAstHostGetLastCompilerContextError(backend.host_ctx)
        local msg = err or (type(host_diag) == "table" and host_diag.message) or "compile failed"
        set_last_error(backend, ERR_COMPILE, msg, api_name, mode)
        return nil, msg
    end

    if fn_or_nil == nil or terralib.type(fn_or_nil) ~= "terrafunction" then
        local msg = "argile: callback backend expected Terra render function from host compiler cache"
        set_last_error(backend, ERR_COMPILE, msg, api_name, mode)
        return nil, msg
    end

    backend._fetch_count = (backend._fetch_count or 0) + 1
    return fn_or_nil:getpointer(), nil
end

local function create_callback_lua_fn(backend)
    return function(mode)
        if type(backend) ~= "table" or backend._kind ~= "CapiDslAstHostCallbackBackend" or not backend._alive then
            set_last_error(backend, ERR_INVALID_BACKEND, "argile: host callback backend is destroyed", "CapiDslAstHostCallbackFetchRenderFunctionPointer", mode)
            return nil
        end
        local ok_mode, nmode = pcall(normalize_mode, tonumber(mode) or mode)
        if not ok_mode then
            set_last_error(backend, ERR_INVALID_ARGUMENT, nmode, "CapiDslAstHostCallbackFetchRenderFunctionPointer", mode)
            return nil
        end
        local ptr = fetch_render_ptr_internal(backend, nmode, "CapiDslAstHostCallbackFetchRenderFunctionPointer")
        return ptr
    end
end

local function ensure_callback_ptr(backend)
    if backend._fetch_render_ptr_callback_ptr ~= nil then
        return backend._fetch_render_ptr_callback_ptr
    end
    backend._fetch_render_ptr_callback_lua = create_callback_lua_fn(backend)
    backend._fetch_render_ptr_callback_ptr = terralib.cast(
        FetchRenderPtrCallbackTy,
        backend._fetch_render_ptr_callback_lua
    )
    backend._callback_ptr_create_count = (backend._callback_ptr_create_count or 0) + 1
    return backend._fetch_render_ptr_callback_ptr
end

function M.CapiDslAstHostCreateCallbackBackend(host_ctx, builder, program_h, env_fn, registry, options)
    if type(host_ctx) ~= "table" or host_ctx._kind ~= "CapiDslAstHostCompilerContext" then
        error("argile: invalid host compiler context for callback backend")
    end
    local backend = {
        _kind = "CapiDslAstHostCallbackBackend",
        _alive = true,
        _id = _next_backend_id,
        host_ctx = host_ctx,
        builder = builder,
        program_h = program_h,
        env_fn = env_fn,
        registry = registry,
        _routes = {},
        _fetch_count = 0,
        _callback_ptr_create_count = 0,
        _last_callback_error = nil,
    }
    _next_backend_id = _next_backend_id + 1

    if type(options) == "table" then
        if type(options.default_route) == "table" then
            local r = options.default_route
            M.CapiDslAstHostCallbackSetRenderRoute(backend, 0, r.cache_key, r.global_name)
        end
        if type(options.routes) == "table" then
            for mode, route in pairs(options.routes) do
                if type(route) == "table" then
                    M.CapiDslAstHostCallbackSetRenderRoute(backend, mode, route.cache_key, route.global_name)
                end
            end
        end
    end

    return backend
end

function M.CapiDslAstHostDestroyCallbackBackend(backend)
    check_backend(backend, nil)
    backend._alive = false
    backend._routes = {}
    backend._fetch_render_ptr_callback_lua = nil
    backend._fetch_render_ptr_callback_ptr = nil
    return true
end

function M.CapiDslAstHostCallbackClearLastError(backend)
    check_backend(backend, nil)
    clear_last_error(backend)
    return true
end

function M.CapiDslAstHostCallbackGetLastError(backend)
    local err = type(backend) == "table" and backend._last_callback_error or nil
    if err == nil then
        return { code = ERR_NONE, message = "", api = nil, mode = nil }
    end
    return {
        code = err.code or ERR_COMPILE,
        message = err.message or "",
        api = err.api,
        mode = err.mode,
    }
end

function M.CapiDslAstHostCallbackSetRenderRoute(backend, mode, cache_key, global_name)
    check_backend(backend, "CapiDslAstHostCallbackSetRenderRoute")
    mode = normalize_mode(mode)
    cache_key = normalize_cache_key(cache_key)
    backend._routes[route_key_for(mode)] = {
        mode = mode,
        cache_key = cache_key,
        global_name = normalize_name(global_name),
    }
    return true
end

function M.CapiDslAstHostCallbackGetRenderRoute(backend, mode)
    check_backend(backend, "CapiDslAstHostCallbackGetRenderRoute")
    mode = normalize_mode(mode)
    local route = get_route(backend, mode)
    if route == nil then return nil end
    return {
        mode = route.mode,
        cache_key = route.cache_key,
        global_name = route.global_name,
    }
end

function M.CapiDslAstHostCallbackFetchRenderFunctionPointer(backend, mode)
    check_backend(backend, "CapiDslAstHostCallbackFetchRenderFunctionPointer")
    mode = normalize_mode(mode)
    local ptr, err = fetch_render_ptr_internal(backend, mode, "CapiDslAstHostCallbackFetchRenderFunctionPointer")
    if ptr == nil then
        error(err)
    end
    return ptr
end

function M.CapiDslAstHostCallbackTryFetchRenderFunctionPointer(backend, mode)
    check_backend(backend, "CapiDslAstHostCallbackTryFetchRenderFunctionPointer")
    local ok_mode, nmode = pcall(normalize_mode, mode)
    if not ok_mode then
        set_last_error(backend, ERR_INVALID_ARGUMENT, nmode, "CapiDslAstHostCallbackTryFetchRenderFunctionPointer", mode)
        return false, nil, nmode
    end
    local ptr, err = fetch_render_ptr_internal(backend, nmode, "CapiDslAstHostCallbackTryFetchRenderFunctionPointer")
    if ptr == nil then
        return false, nil, err
    end
    return true, ptr, nil
end

function M.CapiDslAstHostCallbackGetFetchRenderFunctionPointerCallback(backend)
    check_backend(backend, "CapiDslAstHostCallbackGetFetchRenderFunctionPointerCallback")
    return ensure_callback_ptr(backend)
end

function M.CapiDslAstHostCallbackGetStats(backend)
    check_backend(backend, "CapiDslAstHostCallbackGetStats")
    return {
        fetch_count = backend._fetch_count or 0,
        callback_ptr_create_count = backend._callback_ptr_create_count or 0,
        route_count = (function()
            local n = 0
            for _k, _v in pairs(backend._routes) do n = n + 1 end
            return n
        end)(),
    }
end

return M
