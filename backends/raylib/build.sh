#!/bin/bash
# Build and run raylib demo for Argile
# Requires: terra, raylib

set -e

cd "$(dirname "$0")/../.."

# Build Argile first
make build

# Run the Terra demo
echo "Running raylib demo..."
terra backends/raylib/demo/main.t
