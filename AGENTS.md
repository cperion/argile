# Repository Guidelines

## Project Structure & Module Organization
This repository ports `ref/clay.h` into the Argile Terra-native `ui` library and maintains parity-focused tests and benchmarks.
- `src/`: Terra implementation modules (`arena`, `array`, `config`, `layout`, `context`, `init`).
- `tests/`: Terra test suites (`test_foundation.t`, `test_layout.t`).
- `bench/`: LuaJIT benchmark runner and docs.
- `tools/`: build scripts and benchmark backends (`build_argile.t`, `build_bench.sh`, `build_terra.t`, `terra_bench_api.t`, `clay_bench.c`, `ffi_gen.t`).
- `docs/design.md`, `docs/ai-guide.md`, `docs/terra/*`: architectural and Terra-language references.
- `ref/clay.h`: authoritative Clay behavior reference.

## Build, Test, and Development Commands
Use these commands as the default workflow:
- `terra tests/test_foundation.t`: core type/array/hash/config/context checks.
- `terra tests/test_layout.t`: layout pipeline, render commands, and advanced feature checks.
- `./tools/build_argile.t`: compiles the Argile shared library (`build/libargile.so`) and generates `build/argile_api_ffi.lua`.
- `make build`: runs `tools/build_argile.t`, ensuring `build/libargile.so` + `build/argile_api_ffi.lua` are regenerated.
- `luajit bench/compare.lua quick|heavy|stress`: run Clay-vs-Argile benchmark suites and print final comparison table.
- `rg "pattern" src tests tools`: fast codebase search.

## Coding Style & Naming Conventions
- Keep Terra API under `ui` namespace; do not leak `Clay_`/`CLAY__` into new Terra-facing APIs.
- Preserve Clay behavior exactly when porting algorithms; adapt syntax only.
- Prefer data-oriented flat arrays and arena allocation.
- Use `while` loops for flow that would otherwise depend on `continue`.
- Validate Terra semantics against `docs/terra/api.md` before introducing advanced metaprogramming or ABI changes.

## Testing & Benchmarking Guidelines
- Add regression tests for every layout/math/hash bug fix.
- When adding benchmark scenarios, implement the same scenario in both backends:
  - Terra: `tools/terra_bench_api.t`
  - Clay: `tools/clay_bench.c`
- Keep exported benchmark function signatures identical across both libraries.
- Treat benchmark checksums as backend-internal consistency checks; compare performance metrics in the final table.

## Commit & PR Guidelines
- Commit format: `type(scope): imperative summary`.
- Keep commits focused (feature, fix, or benchmark change; avoid mixed refactors).
- PRs should include: intent, changed files, validation commands run, and benchmark profile used when performance-relevant.
