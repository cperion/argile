#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p build

echo "[1/2] Building Argile benchmark library + FFI cdefs"
terra tools/build_terra.t

echo "[2/2] Building Clay benchmark library"
cc -O3 -fPIC -shared tools/clay_bench.c -o build/libclay_bench.so

echo "Done"
echo "  - build/libargile_bench.so"
echo "  - build/libclay_bench.so"
echo "  - build/argile_bench_api.lua"
