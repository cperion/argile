#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p build
CC_BIN="${CC:-cc}"

echo "[1/3] Building Argile benchmark library + FFI cdefs"
terra tools/build_terra.t

echo "[2/3] Building Clay benchmark library"
"$CC_BIN" -O3 -fPIC -shared tools/clay_bench.c -o build/libclay_bench.so

echo "[3/3] Building pure-C benchmark runner"
"$CC_BIN" -O3 -std=c11 tools/bench_compare_c.c -o build/bench_compare_c -ldl -lm

echo "Done"
echo "  - build/libargile_bench.so"
echo "  - build/libclay_bench.so"
echo "  - build/argile_bench_api.lua"
echo "  - build/bench_compare_c"
