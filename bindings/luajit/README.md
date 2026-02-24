# LuaJIT Reference Integration (`argile_lj`)

This directory contains the official LuaJIT reference integration for Argile.

Current goals:
- Prove the runtime `ui.capi` FFI surface works well from pure LuaJIT
- Reuse the canonical Argile AST definitions from `src/lang/ast.t`
- Provide a LuaJIT-native DSL wrapper (table/metatable style) that builds canonical AST tables
- Keep the compiler boundary explicit (`ui.capi` runtime-only today; host compiler APIs are not exported yet)

## Binding Layering Policy (Engine vs Widget Bindings)

`argile_lj` is the canonical engine-level LuaJIT binding. Higher-level bindings (for example `argile-ui` widget bindings) should layer on top of it, not fork the FFI runtime loader.

See:

- `docs/luajit-binding-layering.md`

This defines the compatibility contract for:

- shared `ffi.cdef` / `ffi.load`
- runtime context object reuse
- string and ID lifetime semantics
- callback GC safety
- version/capability checks

## Modules

- `bindings.luajit.argile_lj.runtime`
  - Loads `build/argile_api_ffi.lua` and `build/libargile.so`
  - Provides context creation helpers and runtime callback registration
  - Includes a LuaJIT-friendly fallback context init path (`InitializeContext`) if needed

- `bindings.luajit.argile_lj.ast`
  - Reuses the canonical AST module (`src/lang/ast.t`) directly
  - Adds `validate_portable(program)` to flag host-only nodes (`LuaExpr`, `Splice`)

- `bindings.luajit.argile_lj.dsl`
  - LuaJIT-native AST builders over the canonical AST
  - Focused on semantic parity (not Terra parser syntax parity)

- `bindings.luajit.argile_lj.compiler`
  - Detects whether host compiler/callback backend exports are present in the loaded `.so`
  - Explicitly reports the current runtime-only boundary

## What Works Today (Pure LuaJIT FFI)

- Runtime `ui.capi` usage (`BeginLayout`, `FinalizeLayout`, `OpenTextElement*`, render command inspection)
- Runtime callback interop (`SetMeasureTextFunction*`) including callback invocation during real layout
- Text measurement cache behavior (callback miss/hit/reset) via FFI
- Layout inspection helpers (`GetElementData`) and debug mode toggles through the runtime wrapper
- Canonical AST reuse and LuaJIT AST/DSL construction (host-language frontend side)
- LÖVE2D reference integration through the official binding (`argile-ui/platforms/love2d/luajit/demo_ffi`)

## What Is Not Available From `ui.capi` Today

- `CapiDslAstHost*` compiler context/cache APIs
- `CapiDslAstHostCallback*` callback backend helper APIs

Those APIs are host-side Terra/Lua integration surfaces and are not exported in the runtime `ui.capi` shared-library ABI yet.

## Probe / Example

Run the current probe:

```sh
cd argile
luajit tools/experiment_luajit_ffi_surface_probe.lua
```

The probe now validates:
- runtime symbol availability
- real callback invocation during layout
- text measurement cache behavior
- canonical AST reuse from LuaJIT
- LuaJIT DSL wrapper -> portable AST validation
- host compiler export detection (expected missing in `ui.capi`)

## Layout Inspection Example

After a frame is finalized, you can inspect computed element boxes from LuaJIT:

```lua
local argile_lj = require("bindings.luajit.argile_lj")
local runtime = argile_lj.runtime.load({
    ffi_def_path = "build/argile_api_ffi.lua",
    lib_path = "build/libargile.so",
})

local ctx = runtime:create_context({ width = 800, height = 600 })

-- Optional: enable engine debug diagnostics (if present in this build)
runtime:set_debug_mode_enabled(true)

ctx:set_current()
-- ... build and finalize a frame here ...
-- ctx:begin_layout(...)
-- ...
-- ctx:finalize_layout()

local root_box = ctx:get_element_data("root")
if root_box.found then
    print("root:", root_box.x, root_box.y, root_box.width, root_box.height)
end
```

Notes:
- `ctx:get_element_data(...)` sets the context current before querying `GetElementData(...)` because the C API lookup is current-context based.
- The helper accepts either an `ElementId` cdata value or a string element name.
