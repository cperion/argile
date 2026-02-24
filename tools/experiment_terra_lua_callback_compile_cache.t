-- Experiment: Terra -> Lua callback compile bridge with host compile cache.
--
-- Goal:
-- 1) Prove Terra can call a Lua callback to fetch a compiled Argile function pointer
-- 2) Prove cache-hit path is stable/fast enough for compile-on-change workflows
-- 3) Probe whether cache-miss compile from inside the callback works on this setup
--
-- Reading the output:
-- - "render once ..." timings include first-call warmup and are NOT steady-state cost
-- - the pointer-fetch loops are the steady-state comparison for callback overhead
-- - cache-miss callback compile is intentionally measured separately
--
-- Run from argile/:
--   TERRA_PATH="./?.t" terra tools/experiment_terra_lua_callback_compile_cache.t

local C = terralib.includecstring [[
#include <stdio.h>
#include <stdlib.h>
]]

local ui = require("src.init")
local Ast = ui.GetDslAstApi()

-- Compile APIs assign globals by name in dsl_compiler; predeclare them.
exp_callback_render_v1 = nil
exp_callback_render_v2 = nil
exp_callback_render_v3 = nil

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

local function build_simple_program()
    local b = Ast.CapiDslAstCreateBuilder()
    local p = Ast.CapiDslAstCreateProgram(b)

    local root = Ast.CapiDslAstCreateNodeElement(b)
    Ast.CapiDslAstNodeSetIdExpr(b, root, expr_str(b, "exp_root"))
    Ast.CapiDslAstNodeAddOp(b, root, "layout", op(b, "width_fixed", expr_lit(b, 120.0)))
    Ast.CapiDslAstNodeAddOp(b, root, "layout", op(b, "height_fixed", expr_lit(b, 36.0)))
    Ast.CapiDslAstNodeAddOp(b, root, "style", op(b, "bg", expr_lit(b, { r = 0.22, g = 0.42, b = 0.71, a = 1.0 })))
    Ast.CapiDslAstProgramAddBodyItem(b, p, root)

    return b, p
end

local builder, program = build_simple_program()
local host_ctx = Ast.CapiDslAstHostCreateCompilerContext()

local callback_call_count = 0

local function compile_key_and_name(mode)
    if mode == 0 then
        return "scene:v1", "exp_callback_render_v1"
    elseif mode == 1 then
        return "scene:v2", "exp_callback_render_v2"
    elseif mode == 2 then
        return "scene:v3", "exp_callback_render_v3"
    else
        return "scene:v1", "exp_callback_render_v1"
    end
end

local function fetch_render_ptr_from_lua(mode)
    callback_call_count = callback_call_count + 1
    local key, fn_name = compile_key_and_name(tonumber(mode) or 0)
    local fn = Ast.CapiDslAstHostCompileProgramRenderFunctionCached(
        host_ctx,
        key,
        builder,
        fn_name,
        program,
        function() return {} end
    )
    return fn:getpointer()
end

local FetchPtrTy = terralib.types.funcpointer({ int32 }, &opaque)
local RenderCommandArray = ui.Array(ui.RenderCommand)
local RenderFnTy = terralib.types.funcpointer({}, &RenderCommandArray)

local fetch_render_ptr_cb = terralib.cast(FetchPtrTy, fetch_render_ptr_from_lua)

terra init_ctx(ctx: &ui.Context, arena: &ui.Arena) : bool
    arena.nextAllocation = 0
    arena.capacity = 1024 * 1024
    arena.memory = [&int8](C.malloc([uint64](arena.capacity)))
    if arena.memory == nil then return false end
    return ctx:initialize(arena, 256)
end

terra free_ctx(arena: &ui.Arena)
    if arena.memory ~= nil then
        C.free(arena.memory)
        arena.memory = nil
    end
end

terra run_render_once_via_callback(fetch: FetchPtrTy, mode: int32) : int32
    var arena: ui.Arena
    var ctx: ui.Context
    if not init_ctx(&ctx, &arena) then
        C.printf("FAIL: could not initialize UI context\n")
        return 1
    end

    ui.SetCurrentContext(&ctx)
    var p = fetch(mode)
    if p == nil then
        C.printf("FAIL: callback returned nil function pointer\n")
        free_ctx(&arena)
        return 1
    end

    var render_fn = [RenderFnTy](p)
    var cmds = render_fn()
    if cmds == nil or cmds.length <= 0 then
        C.printf("FAIL: compiled render function returned no commands\n")
        free_ctx(&arena)
        return 1
    end

    free_ctx(&arena)
    return 0
end

terra callback_fetch_loop(fetch: FetchPtrTy, mode: int32, iters: int32) : int32
    var first = fetch(mode)
    var mismatches: int32 = 0
    var nils: int32 = 0
    if first == nil then nils = nils + 1 end
    var i: int32 = 0
    while i < iters do
        var p = fetch(mode)
        if p == nil then
            nils = nils + 1
        elseif p ~= first then
            mismatches = mismatches + 1
        end
        i = i + 1
    end
    return mismatches + (nils * 1000000)
end

local function print_stats(label)
    local s = Ast.CapiDslAstHostGetCompileCacheStats(host_ctx)
    print(string.format(
        "%s stats: hits=%d misses=%d quote=%d fn=%d render=%d total=%d callback_calls=%d",
        label,
        s.hits, s.misses,
        s.quote_entries, s.function_entries, s.render_function_entries, s.total_entries,
        callback_call_count
    ))
end

local function time_call(label, fn)
    local t0 = os.clock()
    local ok, a, b, c = pcall(fn)
    local dt = (os.clock() - t0) * 1000.0
    if ok then
        print(string.format("%s: %.3f ms", label, dt))
        return true, dt, a, b, c
    end
    print(string.format("%s: FAIL after %.3f ms -> %s", label, dt, tostring(a)))
    return false, dt, a
end

print("== Terra->Lua callback compile/cache experiment ==")
print_stats("initial")

local ok_warm, _, warm_fn, warm_hit = time_call("warm compile (Lua host API)", function()
    return Ast.CapiDslAstHostCompileProgramRenderFunctionCached(
        host_ctx,
        "scene:v1",
        builder,
        "exp_callback_render_v1",
        program,
        function() return {} end
    )
end)
if not ok_warm then error("warm compile failed") end
print("warm compile cache hit? ", warm_hit)
print_stats("after warm")

local ok_warm_v2, _, warm_fn_v2, warm_hit_v2 = time_call("warm compile v2 (Lua host API)", function()
    return Ast.CapiDslAstHostCompileProgramRenderFunctionCached(
        host_ctx,
        "scene:v2",
        builder,
        "exp_callback_render_v2",
        program,
        function() return {} end
    )
end)
if not ok_warm_v2 then error("warm compile v2 failed") end
print("warm compile v2 cache hit? ", warm_hit_v2)
print_stats("after warm v2")

local warm_ptr_v1 = warm_fn:getpointer()
local warm_ptr_v2 = warm_fn_v2:getpointer()

terra fetch_render_ptr_from_terra(mode: int32) : &opaque
    if mode == 1 then
        return [&opaque]([warm_ptr_v2])
    end
    return [&opaque]([warm_ptr_v1])
end

local fetch_render_ptr_from_terra_ptr = fetch_render_ptr_from_terra:getpointer()

terra terra_fetch_loop_direct(iters: int32, mode: int32) : int32
    var first = fetch_render_ptr_from_terra(mode)
    var mismatches: int32 = 0
    var nils: int32 = 0
    if first == nil then nils = nils + 1 end
    var i: int32 = 0
    while i < iters do
        var p = fetch_render_ptr_from_terra(mode)
        if p == nil then
            nils = nils + 1
        elseif p ~= first then
            mismatches = mismatches + 1
        end
        i = i + 1
    end
    return mismatches + (nils * 1000000)
end

terra terra_fetch_loop_fnptr(iters: int32, mode: int32) : int32
    var fetch = [FetchPtrTy]([fetch_render_ptr_from_terra_ptr])
    var first = fetch(mode)
    var mismatches: int32 = 0
    var nils: int32 = 0
    if first == nil then nils = nils + 1 end
    var i: int32 = 0
    while i < iters do
        var p = fetch(mode)
        if p == nil then
            nils = nils + 1
        elseif p ~= first then
            mismatches = mismatches + 1
        end
        i = i + 1
    end
    return mismatches + (nils * 1000000)
end

terra direct_const_ptr_loop(iters: int32) : int32
    var first = [&opaque]([warm_ptr_v1])
    var mismatches: int32 = 0
    var nils: int32 = 0
    if first == nil then nils = nils + 1 end
    var i: int32 = 0
    while i < iters do
        var p = [&opaque]([warm_ptr_v1])
        if p == nil then
            nils = nils + 1
        elseif p ~= first then
            mismatches = mismatches + 1
        end
        i = i + 1
    end
    return mismatches + (nils * 1000000)
end

terra run_render_once_direct(ptr: &opaque) : int32
    var arena: ui.Arena
    var ctx: ui.Context
    if not init_ctx(&ctx, &arena) then
        C.printf("FAIL: could not initialize UI context (direct)\n")
        return 1
    end
    if ptr == nil then
        C.printf("FAIL: direct path got nil function pointer\n")
        free_ctx(&arena)
        return 1
    end
    ui.SetCurrentContext(&ctx)
    var render_fn = [RenderFnTy](ptr)
    var cmds = render_fn()
    if cmds == nil or cmds.length <= 0 then
        C.printf("FAIL: direct compiled render function returned no commands\n")
        free_ctx(&arena)
        return 1
    end
    free_ctx(&arena)
    return 0
end

local ok_probe, _, probe_rc = time_call("render once via Terra->Lua callback (cache hit)", function()
    return run_render_once_via_callback(fetch_render_ptr_cb, 0)
end)
if not ok_probe or probe_rc ~= 0 then
    error("callback render probe failed")
end
print_stats("after callback render probe")

local ok_probe_direct, _, probe_direct_rc = time_call("render once via pure Terra direct pointer", function()
    return run_render_once_direct(warm_ptr_v1)
end)
if not ok_probe_direct or probe_direct_rc ~= 0 then
    error("direct render probe failed")
end

local loops = 2000
local ok_loop, dt_loop_cb, loop_result = time_call("callback fetch loop (" .. tostring(loops) .. " cache hits)", function()
    return callback_fetch_loop(fetch_render_ptr_cb, 0, loops)
end)
if not ok_loop then
    error("callback fetch loop failed")
end
local mismatches = loop_result % 1000000
local nils = math.floor(loop_result / 1000000)
print(string.format("callback fetch loop result: mismatches=%d nils=%d", mismatches, nils))
print_stats("after hit loop")

local ok_loop_terra, dt_loop_terra, loop_result_terra = time_call("pure Terra fetch loop (" .. tostring(loops) .. " direct fn hits)", function()
    return terra_fetch_loop_direct(loops, 0)
end)
if not ok_loop_terra then
    error("pure Terra fetch loop failed")
end
local mismatches_terra = loop_result_terra % 1000000
local nils_terra = math.floor(loop_result_terra / 1000000)
print(string.format("pure Terra fetch loop result: mismatches=%d nils=%d", mismatches_terra, nils_terra))

local ok_loop_terra_fp, dt_loop_terra_fp, loop_result_terra_fp = time_call("pure Terra fetch loop (" .. tostring(loops) .. " fnptr hits)", function()
    return terra_fetch_loop_fnptr(loops, 0)
end)
if not ok_loop_terra_fp then
    error("pure Terra fnptr fetch loop failed")
end
local mismatches_terra_fp = loop_result_terra_fp % 1000000
local nils_terra_fp = math.floor(loop_result_terra_fp / 1000000)
print(string.format("pure Terra fnptr fetch loop result: mismatches=%d nils=%d", mismatches_terra_fp, nils_terra_fp))

local ok_loop_const, dt_loop_const, loop_result_const = time_call("pure Terra constant pointer loop (" .. tostring(loops) .. ")", function()
    return direct_const_ptr_loop(loops)
end)
if not ok_loop_const then
    error("pure Terra const pointer loop failed")
end
local mismatches_const = loop_result_const % 1000000
local nils_const = math.floor(loop_result_const / 1000000)
print(string.format("pure Terra const pointer loop result: mismatches=%d nils=%d", mismatches_const, nils_const))

if dt_loop_cb and dt_loop_terra and dt_loop_const and dt_loop_terra > 0 and dt_loop_const > 0 then
    print(string.format(
        "relative overhead: callback-hit vs Terra-direct = %.2fx ; callback-hit vs const = %.2fx ; Terra-direct vs const = %.2fx",
        dt_loop_cb / dt_loop_terra,
        dt_loop_cb / dt_loop_const,
        dt_loop_terra / dt_loop_const
    ))
end
if dt_loop_cb and dt_loop_terra_fp and dt_loop_terra_fp > 0 then
    print(string.format(
        "relative overhead (callback-hit vs Terra-fnptr): %.2fx",
        dt_loop_cb / dt_loop_terra_fp
    ))
end

-- Optional probe: trigger a cache miss compile inside the callback (mode=2, uncached key).
local ok_miss, _, miss_rc = time_call("compile miss via Terra->Lua callback (mode=2)", function()
    return run_render_once_via_callback(fetch_render_ptr_cb, 2)
end)
if ok_miss then
    print("cache-miss compile from callback succeeded, rc=", miss_rc)
else
    local diag = Ast.CapiDslAstHostGetLastCompilerContextError(host_ctx)
    if type(diag) == "table" and diag.message and diag.message ~= "" then
        print("host compiler context last error:", diag.message)
    end
    print("NOTE: cache-miss compile from inside callback may not be supported in this runtime setup.")
end
print_stats("final")

Ast.CapiDslAstDestroyBuilder(builder)
Ast.CapiDslAstHostDestroyCompilerContext(host_ctx)

print("experiment complete")
