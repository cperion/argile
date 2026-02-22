#!/bin/bash
# Build and run SDL3 demo for Argile (AOT executable)
# Requires: terra, SDL3, system linker toolchain

set -e

cd "$(dirname "$0")/../.."

# Build Argile first
make build

# Build native executable via Terra AOT
echo "Building SDL3 demo executable..."
terra backends/sdl3/build.t

if [[ "${ARGILE_SDL3_DEMO_BUILD_ONLY:-0}" == "1" ]]; then
	echo "Skipping run (ARGILE_SDL3_DEMO_BUILD_ONLY=1)"
	exit 0
fi

echo "Running SDL3 demo..."
./build/argile_sdl3_demo
