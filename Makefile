SHELL := /usr/bin/env bash

TERRA ?= terra
LUAJIT ?= luajit
CC ?= cc

.PHONY: all build build-argile build-bench build-parity love-demo love-demo-portable raylib-demo sdl3-demo test bench bench-quick bench-heavy bench-stress parity parity-quick parity-heavy parity-stress clean

all: build

build: build-argile

build-argile:
	@mkdir -p build
	$(TERRA) tools/build_argile.t

build-bench:
	@mkdir -p build
	./tools/build_bench.sh

build-parity:
	@mkdir -p build
	./tools/build_parity.sh

love-demo: build
	love backends/love2d/demo_ffi

love-demo-portable: build
	love backends/love2d/demo

raylib-demo: build
	@echo "Note: Raylib demo may crash on Wayland (GLFW limitation). Use X11 or see backends/raylib/README.md"
	./backends/raylib/build.sh

sdl3-demo: build
	@echo "SDL3 demo with native Wayland support"
	./backends/sdl3/build.sh

test:
	$(TERRA) tests/test_foundation.t
	$(TERRA) tests/test_layout.t
	$(TERRA) tests/test_builder.t
	$(TERRA) tests/test_language_extension.t
	$(TERRA) tests/test_state_requires_id.t
	$(TERRA) tests/test_runtime_states_integration.t
	$(TERRA) tests/test_integration_v2.t
	$(TERRA) tests/test_v3_parser.t
	$(TERRA) tests/test_v3_integration_basic.t
	$(TERRA) tests/test_v3_render_integration.t

bench: build-bench
	$(LUAJIT) bench/compare.lua heavy

bench-quick: build-bench
	$(LUAJIT) bench/compare.lua quick

bench-heavy: build-bench
	$(LUAJIT) bench/compare.lua heavy

bench-stress: build-bench
	$(LUAJIT) bench/compare.lua stress

parity: build-parity
	$(LUAJIT) parity/compare_layouts.lua heavy

parity-quick: build-parity
	$(LUAJIT) parity/compare_layouts.lua quick

parity-heavy: build-parity
	$(LUAJIT) parity/compare_layouts.lua heavy

parity-stress: build-parity
	$(LUAJIT) parity/compare_layouts.lua stress

clean:
	rm -rf build
