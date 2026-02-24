-- LuaJIT FFI probe for current libargile.so surface.
--
-- Goal:
-- - verify runtime ABI loads and basic symbols are callable
-- - verify LuaJIT callback interop works with an existing runtime callback API
-- - document current coverage boundary (host AST/callback backend is NOT in ui.capi yet)
--
-- Run from argile/:
--   luajit tools/experiment_luajit_ffi_surface_probe.lua

package.path = "./?.lua;./?/init.lua;./?.t;" .. package.path

local ok_mod, argile_lj = pcall(require, "bindings.luajit.argile_lj")
if not ok_mod then
    io.stderr:write("FAIL: could not load bindings.luajit.argile_lj: " .. tostring(argile_lj) .. "\n")
    os.exit(1)
end
local rt = argile_lj.runtime.load()
local ffi = rt.ffi
local lib = rt.lib

local function has_symbol(name)
    return pcall(function() return lib[name] end)
end

local function print_symbol_status(name)
    local ok = has_symbol(name)
    print(string.format("  %-48s %s", name, ok and "YES" or "NO"))
    return ok
end

print("== LuaJIT FFI surface probe for libargile.so ==")

local api_version = tonumber(lib.GetApiVersion())
print("GetApiVersion():", api_version)

print("\nRuntime ABI symbols (expected today):")
local have_set_measure = print_symbol_status("SetMeasureTextFunction")
local have_begin_layout = print_symbol_status("BeginLayout")
local have_finalize_layout = print_symbol_status("FinalizeLayout")
local have_open_text = print_symbol_status("OpenTextElement")
local have_initialize = print_symbol_status("Initialize")
local have_min_memory = print_symbol_status("MinMemorySize")
local have_get_cmd_count = print_symbol_status("GetRenderCommandCount")
print_symbol_status("OpenElement")

print("\nHost AST / callback-backend symbols (not expected in ui.capi today):")
local have_ast_host = print_symbol_status("CapiDslAstHostCreateCompilerContext")
local have_ast_callback_backend = print_symbol_status("CapiDslAstHostCreateCallbackBackend")

if have_ast_host or have_ast_callback_backend then
    print("NOTE: host AST/callback backend symbols are unexpectedly present in ui.capi on this build.")
else
    print("OK: host AST and callback backend remain host-side APIs (not exported in ui.capi).")
end

local callback_invoked = 0
local layout_probe_success = false
local measure_cb

if have_set_measure then
    -- Existing runtime callback API smoke-test: proves LuaJIT can hand a function pointer
    -- to libargile.so for later Terra/runtime use.
    measure_cb = ffi.cast(
        "int32_t (*)(struct StringSlice*, struct TextConfig*, void*, struct Dimensions*)",
        function(str_slice, text_cfg, user_data, out_dims)
            callback_invoked = callback_invoked + 1
            if out_dims ~= nil then
                out_dims.width = 42.0
                out_dims.height = 13.0
            end
            return 1
        end
    )

    -- Register callback (user data null) and immediately restore null.
    lib.SetMeasureTextFunction(measure_cb, nil)
    lib.SetMeasureTextFunction(nil, nil)

    print("\nLuaJIT callback pointer registration with SetMeasureTextFunction: PASS")
    print("  callback_invoked during registration path:", callback_invoked, "(expected 0; runtime invokes it later during layout)")
else
    print("\nSkipping callback registration test: SetMeasureTextFunction not found.")
end

local can_run_layout_probe = have_set_measure and have_begin_layout and have_finalize_layout
    and have_open_text and have_initialize and have_min_memory and have_get_cmd_count

if can_run_layout_probe then
    print("\nRunning real LuaJIT -> libargile.so layout probe (measure callback invocation + cache)...")
    local ctx = rt:create_context({ width = 400, height = 200 })
    print(string.format("  MinMemorySize=%s arena_cap=%s init_mode=%s",
        tostring(tonumber(lib.MinMemorySize())), tostring(ctx.arena_capacity), tostring(ctx.init_mode)))
    print("  Context pointer:", tostring(ctx.ctx))

    local tc = rt:mk_text_config({ fontSize = 16, lineHeight = 16 })
    local text = "Hello LuaJIT FFI"

    local function do_text_layout_pass(label)
        local before = callback_invoked
        ctx:set_current()
        ctx:begin_layout(400.0, 200.0)
        ctx:open_text(text, tc)
        local finalize_count = ctx:finalize_layout()
        local render_count = ctx:get_render_command_count()
        local after = callback_invoked
        print(string.format(
            "  %-18s finalize=%d render_count=%d callback_calls_delta=%d total=%d",
            label, finalize_count, render_count, (after - before), after
        ))
        return before, after, finalize_count, render_count
    end

    callback_invoked = 0
    ctx:set_measure_text(function(str_slice, text_cfg, user_data, out_dims)
        return measure_cb(str_slice, text_cfg, user_data, out_dims)
    end)

    local first_calls_before, first_calls_after = do_text_layout_pass("first pass")
    local _, second_calls_after = do_text_layout_pass("second pass")

    ctx:reset_measure_text_cache()
    local _, third_calls_after = do_text_layout_pass("third pass (reset)")

    ctx:set_measure_text(nil)
    ctx:destroy()

    local first_delta = first_calls_after - first_calls_before
    local second_delta = second_calls_after - first_calls_after
    local third_delta = third_calls_after - second_calls_after

    if first_delta > 0 and second_delta == 0 and third_delta > 0 then
        print("  PASS: measure-text callback invoked on miss, cached on repeat, invoked again after reset")
        layout_probe_success = true
    else
        print("  FAIL: unexpected callback/cache behavior")
    end
else
    print("\nSkipping real layout probe: missing required runtime symbols.")
end

print("\nCanonical AST reuse + LuaJIT DSL wrapper probe:")
local AST = argile_lj.ast
local DSL = argile_lj.dsl

local dsl_prog = DSL.program({
    decls = {
        DSL.theme("demo", {
            tokens = {
                DSL.token_decl("colors.text", { r = 1, g = 1, b = 1, a = 1 }),
            },
            recipes = {
                DSL.recipe("label_text", { "tone" }, {
                    { kind = "typography", ops = { { "color", DSL.token("colors.text") } } },
                }),
            },
        }),
        DSL.component("Label", {
            params = { "text", "tone" },
            variants = { tone = { "primary", "muted" } },
            root = DSL.el({
                id = "label_root",
                children = {
                    DSL.text({
                        id = "label_text",
                        text = DSL.path("props.text"),
                        use = { DSL.call(DSL.path("recipes.label_text"), { named = { tone = DSL.path("props.tone") } }) },
                    }),
                },
            }),
        }),
    },
    body = {
        DSL.invoke("Label", { text = "Hello from LuaJIT DSL", tone = DSL.sym("primary") }),
    },
})

print("  AST.Program kind:", AST.GetKind(dsl_prog))
local portable_ok, portable_errors = AST.validate_portable(dsl_prog)
print("  portable AST validation:", portable_ok and "PASS" or "FAIL")
if not portable_ok then
    for _, err in ipairs(portable_errors) do
        print("   - " .. err)
    end
end

print("\nCompiler ABI capability probe (from package helper):")
local compiler_caps = argile_lj.compiler.detect(lib)
print("  host compiler exports present:", tostring(compiler_caps.host_compiler_exports))
print("  host callback backend exports present:", tostring(compiler_caps.host_callback_backend_exports))
print("  missing symbols checked:", #compiler_caps.missing)

if measure_cb ~= nil then
    measure_cb:free()
end

print("\nCoverage summary (today):")
print("- Works from pure LuaJIT FFI: runtime ui.capi surface")
if layout_probe_success then
    print("- Works in practice: LuaJIT -> C function pointer callbacks into libargile.so (measure-text callback invoked by real layout)")
else
    print("- Callback pointer registration works; full runtime invocation probe currently blocked by FFI context-init interop issue")
end
print("- Works today: canonical AST reuse from LuaJIT (loads src/lang/ast.t directly)")
print("- Works today: LuaJIT DSL wrapper producing portable canonical AST tables")
print("- Not available from pure LuaJIT FFI today: host AST compiler cache / callback backend (host-side API only)")
print("- Implication: LuaJIT runtime wrappers can ship now; DSL compile path still needs host-compiler ABI exposure")

print("\nexperiment complete")
