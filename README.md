# Argile

Argile is a Terra-native immediate-mode UI layout library with behavior parity goals against `clay.h`.

The repository includes:
- core Terra runtime (`src/`)
- parity and regression tests (`tests/`)
- LuaJIT benchmark suite against Clay (`bench/`)
- a Love2D demo that consumes `libargile.so` through FFI (`demo/love/`)

## Requirements

- Terra
- LuaJIT (for benchmarks/demo)
- C toolchain (`cc`) for Clay benchmark backend
- Love2D (optional, for `make love-demo`)

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

## Love2D Demo

```bash
make love-demo
```

The demo uses the main Argile library (`libargile.so`) and stable FFI API (`argile_api_ffi.lua`), not a special demo backend.

## API Surface

- Full Terra surface: `require("src.init")` returns `ui` (includes internals and helpers for Terra-side use).
- Stable C/FFI surface: `ui.capi` is the exported ABI used by `tools/build_argile.t`.
- API version guard: use `GetApiVersion()` and `ARGILE_API_VERSION` to verify compatibility at runtime.
- Multicontext support: `*ForContext` functions allow explicit context routing without relying on global current context.

## Repository Map

- `src/context.t`: layout engine, render command generation, interaction, and stable runtime API wrappers.
- `src/builder.t`: compile-time Lua table to Terra AST builder (`ui.compile`).
- `tools/build_argile.t`: builds shared library and generates LuaJIT `ffi.cdef`.
- `tools/build_bench.sh`: builds benchmark backends.
- `tools/build_parity.sh`: builds parity backends and generated parity FFI cdefs.
