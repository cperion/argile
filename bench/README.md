# Benchmark Harness

Comprehensive LuaJIT-driven comparison suite for `clay.h` vs Argile.

## What It Benchmarks

The runner executes realistic and stress workloads on both backends through the same C ABI:

- Flat layout: many fixed children
- Deep layout: nested tree expansion (`depth x branch`)
- Text-heavy feeds
- Mixed dashboard UI (text + image/custom + borders)
- Clipped scrolling list containers
- Mixed config churn (border/image/custom/aspect ratio)

Each scenario reports:

- `ms/frame`
- `FPS`
- speedup (`Clay_time / Terra_time`)
- backend checksums (frame command totals)

A final table and summary are printed at the end (average + geometric mean speedup, best/worst scenario).

## Build

```bash
./tools/build_bench.sh
```

Build outputs:

- `build/libargile_bench.so`
- `build/libclay_bench.so`
- `build/argile_bench_api.lua`

`build/argile_bench_api.lua` is generated automatically by `tools/build_terra.t` by inspecting the final Argile exported API table (`tools/terra_bench_api.t` -> `api.exports`).

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

## API Contract

Both libs export identical benchmark functions:

- `bench_init(width, height, max_elements, arena_bytes)`
- `bench_shutdown()`
- `bench_frame_fixed_children(child_count)`
- `bench_frame_nested(depth, branch)`
- `bench_frame_text_rows(row_count)`
- `bench_frame_dashboard(panel_count, widgets_per_panel)`
- `bench_frame_clip_lists(list_count, rows_per_list)`
- `bench_frame_stress_mixed(element_count)`
