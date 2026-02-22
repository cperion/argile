#!/bin/bash
# Build and run raylib demo for Argile (AOT executable)
# Requires: terra, raylib, system linker toolchain

set -e

cd "$(dirname "$0")/../.."

# Build Argile first
make build

# Build native executable via Terra AOT to avoid Terra JIT + Mesa LLVM collisions
echo "Building raylib demo executable..."
terra backends/raylib/build.t

if [[ "${ARGILE_RAYLIB_DEMO_BUILD_ONLY:-0}" == "1" ]]; then
  echo "Skipping run (ARGILE_RAYLIB_DEMO_BUILD_ONLY=1)"
  exit 0
fi

echo "Running raylib demo..."
./build/argile_raylib_demo
