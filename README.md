# Argile

Argile is a Terra-native immediate-mode UI layout library and embeddable UI kernel.

Direction note:
- The current strategic direction and roadmap are documented in `docs/argile-kernel-direction-rfc.md`.
- The implementation breakdown and milestone/ticket execution plan are documented in `docs/argile-kernel-execution-program.md`.
- Clay remains an important inspiration/reference point, but Argile is now explicitly positioned as a kernel-first engine with layered toolkits and bindings.

The repository includes:
- core Terra runtime (`src/`)
- canonical DSL parser/compiler/AST and host-side AST/compiler APIs (`src/lang/*`, `src/dsl_*`, `src/capi_dsl_*`)
- parity and regression tests (`tests/`)
- official language bindings (LuaJIT reference integration in `bindings/luajit/`)
- backend-neutral render command dispatch support (`render/`)
- LuaJIT benchmark suite against Clay (`bench/`)

## Requirements

- Terra
- LuaJIT (for benchmarks/demo)
- C toolchain (`cc`) for Clay benchmark backend
- Platform demos/integrations now live in the sibling `argile-ui` repository (optional runtime deps vary by platform)

## Quick Start

```bash
make build
make test
```

Build output:
- `build/libargile.so`
- `build/argile_api_ffi.lua`

## Benchmarks

```bash
make build-bench
make bench-quick
make bench
make bench-stress
```

This compares `build/libargile_bench.so` vs `build/libclay_bench.so` and prints a final performance table.

## Layout Parity Harness

```bash
make build-parity
make parity-quick
make parity
make parity-stress
```

This compares per-element layout boxes (by ID) between `build/libargile_parity.so` and `build/libclay_parity.so` using tolerance-based geometry checks, then prints a full scenario comparison table and mismatch diagnostics.

## Platform Demos (Moved to `argile-ui`)

```bash
cd ../argile-ui
make demo-love-platform-ffi
```

Platform integrations and demos (LÖVE2D, SDL3, raylib, widget-layer examples) now live in `argile-ui/platforms/*` so Argile stays focused on portable render commands and the engine C API.

## API Surface

- Full Terra surface: `require("src.init")` returns `ui` (includes internals and helpers for Terra-side use).
- Stable C/FFI surface: `ui.capi` is the exported ABI used by `tools/build_argile.t`.
- API version guard: use `GetApiVersion()` and `ARGILE_API_VERSION` to verify compatibility at runtime.
- Multicontext support: `*ForContext` functions allow explicit context routing without relying on global current context.

## Repository Map

- `src/context.t`: layout engine, render command generation, interaction, and stable runtime API wrappers.
- `src/dsl_compiler.t`: canonical Argile DSL compiler (host-side Lua/Terra metaprogramming path).
- `src/lang/argile.t`, `src/lang/ast.t`: canonical parser and AST definitions.
- `src/capi_dsl_ast.t`, `src/capi_dsl_compile.t`, `src/capi_dsl_host*.t`: host-side AST/compiler APIs for bindings/tooling.
- `bindings/luajit/`: official LuaJIT runtime + AST/DSL reference integration.
- `render/dispatcher.lua`: backend-neutral render-command dispatcher helper used by platform sinks.
- `tools/build_argile.t`: builds shared library and generates LuaJIT `ffi.cdef`.
- `tools/build_bench.sh`: builds benchmark backends.
- `tools/build_parity.sh`: builds parity backends and generated parity FFI cdefs.
