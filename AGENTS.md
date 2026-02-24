# Repository Guidelines

## Project Structure & Module Organization
Argile ports `ref/clay.h` into a Terra-native UI library with parity tests and LuaJIT benchmarks.
- `src/`: runtime modules, canonical DSL parser/compiler/AST, C API exports, and host-side AST/compiler integration APIs.
- `tests/`: foundation, layout, compiler/AST, and regression coverage.
- `bench/`: Clay-vs-Argile benchmark harness.
- `bindings/`: official language bindings (LuaJIT reference integration lives in `bindings/luajit/`).
- `render/`: backend-neutral render-command dispatch helpers used by downstream platform integrations.
- `tools/`: build scripts (`build_argile.t`, `build_bench.sh`, `build_terra.t`) and benchmark backends.
- `docs/`: architecture, bindings, design notes, and Terra references (`docs/terra/*`).
- `ref/clay.h`: source-of-truth behavior reference.

## Build, Test, and Development Commands
Default workflow:
- `make build`: build `build/libargile.so` and regenerate `build/argile_api_ffi.lua`.
- `make test`: run all Terra tests.
- `make build-bench`: build Argile and Clay benchmark libraries.
- `make bench`, `make bench-quick`, `make bench-stress`: run benchmark profiles.
- `make build-parity`: build Argile/Clay parity libraries + FFI bindings.
- `make parity`, `make parity-quick`, `make parity-stress`: run tolerance-based layout parity checks.
- Platform demos now live in the sibling `argile-ui` repository (`platforms/*`).
- `luajit tools/experiment_luajit_ffi_surface_probe.lua`: probe official LuaJIT runtime/AST DSL integration against `libargile.so`.
- `rg "pattern" src tests tools`: fast code search.

## Coding Style & Naming Conventions
- Keep Terra API under `ui` namespace; do not leak `Clay_`/`CLAY__` into new Terra-facing APIs.
- Preserve Clay behavior exactly when porting algorithms; adapt syntax only.
- Prefer data-oriented arrays and arena allocation.
- Use `while` loops for control flow that would otherwise require `continue`.
- Use `ui.capi` for stable C/FFI exports; keep internal helpers on full `ui` only.
- Validate Terra semantics with `docs/terra/api.md` before ABI or metaprogramming changes.
- Official LuaJIT engine bindings live in `bindings/luajit/argile_lj`; downstream widget bindings should layer on top (see `docs/luajit-binding-layering.md`).

## Testing & Benchmarking Guidelines
- Add regression tests for every layout/math/hash bug fix.
- Keep benchmark scenarios equivalent in both backends:
  - Argile: `tools/terra_bench_api.t`
  - Clay: `tools/clay_bench.c`
- Keep parity scenarios equivalent in both backends:
  - Argile: `tools/terra_parity_api.t`
  - Clay: `tools/clay_parity.c`
- Keep exported benchmark function signatures identical across both libraries.
- Treat benchmark checksums as backend-internal consistency checks; compare performance metrics in the final table.
- For FFI-facing changes, rebuild (`make build`) and sanity-check generated signatures in `build/argile_api_ffi.lua`.

## Commit & PR Guidelines
- Commit format: `type(scope): imperative summary`.
- Keep commits focused (feature, fix, or benchmark change; avoid mixed refactors).
- PRs should include: intent, changed files, validation commands run, and benchmark profile used when performance-relevant.
