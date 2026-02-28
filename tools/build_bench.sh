#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p build
CC_BIN="${CC:-cc}"

echo "[1/3] Building Argile runtime library + FFI cdefs"
terra tools/build_argile.t

echo "[2/3] Building Clay runtime library"
"$CC_BIN" -O3 -fPIC -shared tools/clay_runtime.c -o build/libclay.so

echo "[3/3] Building Argile benchmark runtime helpers"
"$CC_BIN" -O3 -fPIC -shared tools/argile_runtime.c -o build/libargile_runtime.so

echo "Done"
echo "  - build/libargile.so"
echo "  - build/libclay.so"
echo "  - build/libargile_runtime.so"
echo "  - build/argile_api_ffi.lua"
