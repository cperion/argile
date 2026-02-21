#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p build

echo "[1/2] Building Argile parity library + FFI cdefs"
terra tools/build_parity_terra.t

echo "[2/2] Building Clay parity library"
cc -O3 -fPIC -shared tools/clay_parity.c -o build/libclay_parity.so

echo "Done"
echo "  - build/libargile_parity.so"
echo "  - build/libclay_parity.so"
echo "  - build/argile_parity_api.lua"
