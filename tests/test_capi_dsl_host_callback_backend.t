local C = terralib.includecstring [[
#include <stdio.h>
#include <stdlib.h>
]]

local ui = require("src.init")
local Ast = ui.GetDslAstApi()

cb_backend_render_v0 = nil
cb_backend_render_v1 = nil

do
    if not Ast.CapiDslAstHasFeature(Ast.CAPI_DSL_AST_FEATURE_CALLBACK_BACKEND) then
        error("expected CALLBACK_BACKEND feature flag")
    end
end

local function expr_lit(b, v)
    return Ast.CapiDslAstCreateExprLiteral(b, v)
end

local function expr_str(b, s)
    return Ast.CapiDslAstCreateExprString(b, s)
end

local function op(builder, name, ...)
    local h = Ast.CapiDslAstCreateOp(builder, name)
    local args = { ... }
    for i = 1, #args do
        Ast.CapiDslAstOpAddArgExpr(builder, h, args[i])
    end
    return h
end

local function build_program()
    local b = Ast.CapiDslAstCreateBuilder()
    local p = Ast.CapiDslAstCreateProgram(b)

    local node = Ast.CapiDslAstCreateNodeElement(b)
    Ast.CapiDslAstNodeSetIdExpr(b, node, expr_str(b, "cb_backend_root"))
    Ast.CapiDslAstNodeAddOp(b, node, "layout", op(b, "width_fixed", expr_lit(b, 64.0)))
    Ast.CapiDslAstNodeAddOp(b, node, "layout", op(b, "height_fixed", expr_lit(b, 24.0)))
    Ast.CapiDslAstNodeAddOp(b, node, "style", op(b, "bg", expr_lit(b, { r = 0.3, g = 0.2, b = 0.7, a = 1.0 })))
    Ast.CapiDslAstProgramAddBodyItem(b, p, node)

    return b, p
end

local builder, program = build_program()
local host_ctx = Ast.CapiDslAstHostCreateCompilerContext()
local backend = Ast.CapiDslAstHostCreateCallbackBackend(host_ctx, builder, program, function() return {} end)

Ast.CapiDslAstHostCallbackSetRenderRoute(backend, 0, "cb:scene:v0", "cb_backend_render_v0")
Ast.CapiDslAstHostCallbackSetRenderRoute(backend, 1, "cb:scene:v1", "cb_backend_render_v1")

do
    local route0 = Ast.CapiDslAstHostCallbackGetRenderRoute(backend, 0)
    if type(route0) ~= "table" or route0.cache_key ~= "cb:scene:v0" or route0.global_name ~= "cb_backend_render_v0" then
        error("expected callback route metadata for mode 0")
    end
    local route_missing = Ast.CapiDslAstHostCallbackGetRenderRoute(backend, 99)
    if route_missing ~= nil then
        error("expected missing callback route to return nil")
    end
end

local ptr0 = Ast.CapiDslAstHostCallbackFetchRenderFunctionPointer(backend, 0)
if ptr0 == nil then
    error("expected direct callback-backend fetch pointer for mode 0")
end

local ok_ptr0, ptr0_again, err_ptr0 = Ast.CapiDslAstHostCallbackTryFetchRenderFunctionPointer(backend, 0)
if not ok_ptr0 or ptr0_again == nil or err_ptr0 ~= nil then
    error("expected callback-backend try fetch to succeed for mode 0")
end
if ptr0_again ~= ptr0 then
    error("expected callback-backend cached fetch pointer stability")
end

do
    local stats = Ast.CapiDslAstHostGetCompileCacheStats(host_ctx)
    if stats.render_function_entries < 1 then
        error("expected host compile cache render entries after callback backend fetch")
    end
    if stats.hits < 1 then
        error("expected at least one host compile cache hit after repeated callback backend fetch")
    end
end

local cb_ptr = Ast.CapiDslAstHostCallbackGetFetchRenderFunctionPointerCallback(backend)
if cb_ptr == nil then
    error("expected callback function pointer")
end
local cb_ptr_again = Ast.CapiDslAstHostCallbackGetFetchRenderFunctionPointerCallback(backend)
if cb_ptr_again ~= cb_ptr then
    error("expected stable callback function pointer object")
end

local FetchTy = Ast.CAPI_DSL_AST_HOST_CALLBACK_FETCH_RENDER_PTR_TYPE

terra callback_fetch_twice(fetch: FetchTy, mode: int32) : int32
    var p0 = fetch(mode)
    var p1 = fetch(mode)
    if p0 == nil or p1 == nil then
        return 1000000
    end
    if p0 ~= p1 then
        return 1
    end
    return 0
end

local terra_rc0 = callback_fetch_twice(cb_ptr, 0)
if terra_rc0 ~= 0 then
    error("expected Terra callback fetch pointer stability for mode 0")
end

local terra_rc1 = callback_fetch_twice(cb_ptr, 1)
if terra_rc1 ~= 0 then
    error("expected Terra callback fetch pointer stability for mode 1")
end

do
    local ok_missing, missing_ptr, missing_err = Ast.CapiDslAstHostCallbackTryFetchRenderFunctionPointer(backend, 42)
    if ok_missing or missing_ptr ~= nil then
        error("expected missing route fetch to fail")
    end
    if type(missing_err) ~= "string" or not missing_err:find("no callback compile route", 1, true) then
        error("expected missing route error message")
    end
    local diag = Ast.CapiDslAstHostCallbackGetLastError(backend)
    if diag.code ~= Ast.CAPI_DSL_AST_HOST_CALLBACK_ERR_MISSING_ROUTE then
        error("expected callback backend missing-route diagnostic code")
    end
    if diag.mode ~= 42 then
        error("expected callback backend missing-route diagnostic mode")
    end
end

do
    local ok_bad_mode, _, bad_mode_err = Ast.CapiDslAstHostCallbackTryFetchRenderFunctionPointer(backend, "bad")
    if ok_bad_mode then
        error("expected bad mode to fail")
    end
    if type(bad_mode_err) ~= "string" or not bad_mode_err:find("mode must be number", 1, true) then
        error("expected bad mode diagnostic message")
    end
end

do
    local cb_stats = Ast.CapiDslAstHostCallbackGetStats(backend)
    if cb_stats.fetch_count < 4 then
        error("expected callback backend fetch count to increase")
    end
    if cb_stats.callback_ptr_create_count ~= 1 then
        error("expected callback pointer to be created exactly once")
    end
    if cb_stats.route_count ~= 2 then
        error("expected callback backend route count")
    end
end

Ast.CapiDslAstHostDestroyCallbackBackend(backend)

do
    local ok_destroyed_direct = pcall(function()
        Ast.CapiDslAstHostCallbackGetStats(backend)
    end)
    if ok_destroyed_direct then
        error("expected destroyed callback backend direct API call to fail")
    end
end

terra callback_fetch_after_destroy(fetch: FetchTy) : bool
    var p = fetch(0)
    return p == nil
end

if not callback_fetch_after_destroy(cb_ptr) then
    error("expected callback pointer to return nil after backend destroy")
end

do
    local diag = Ast.CapiDslAstHostCallbackGetLastError(backend)
    if diag.code ~= Ast.CAPI_DSL_AST_HOST_CALLBACK_ERR_INVALID_BACKEND then
        error("expected destroyed callback backend diagnostic code")
    end
end

Ast.CapiDslAstHostDestroyCompilerContext(host_ctx)
Ast.CapiDslAstDestroyBuilder(builder)

C.printf("test_capi_dsl_host_callback_backend: PASS\n")
