# Benchmark Harness

LuaJIT-driven comparison suite for Clay vs Argile using raw runtime APIs (no scenario wrapper exports).

## What It Benchmarks

The runner executes equivalent workloads on both backends:

- Flat layout: many fixed children
- Deep layout: nested tree expansion (`depth x branch`)
- Text-heavy feeds
- Mixed dashboard UI (text + image/custom + borders)
- Clipped scrolling list containers
- Mixed config churn (border/image/custom/aspect ratio)

Each scenario reports:

- `ms/frame`
- `FPS`
- speedup (`Clay_time / Argile_time`)
- backend checksums (frame command totals)

A final table and summary are printed at the end (average + geometric mean speedup, best/worst scenario).

## Build

```bash
./tools/build_bench.sh
```

Build outputs:

- `build/libargile.so`
- `build/argile_api_ffi.lua`
- `build/libclay.so`
- `build/libargile_runtime.so`

`bench/compare.lua` drives:

- Argile through the runtime C API (`ui.capi`, `*ForContext` entry points, including `OpenElementWithConfigBundleForContext` in hot paths)
- Clay through canonical `clay.h` APIs (`Clay_*` + macro-required internal `Clay__*` functions)

## Run

```bash
luajit bench/compare.lua quick
luajit bench/compare.lua heavy
luajit bench/compare.lua stress
```

Profiles:

- `quick`: fast validation loop
- `heavy`: default comprehensive run
- `stress`: larger arena + heavier workloads

### Strict Fairness

Fair mode is always enabled in `bench/compare.lua`:
- Clay culling is hard-disabled
- Argile culling is hard-disabled
- an untimed LuaJIT preheat pass runs once per backend/function-signature before measured iterations
- each scenario runs multiple samples with alternating backend order and median selection
- LuaJIT GC is collected/stopped during timed loops and restarted afterward
- Argile text measure uses a native C callback (`libargile_runtime.so`) to match Clay's native callback path
- the run fails if any scenario checksum differs (`strict parity`)
