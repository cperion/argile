SHELL := /usr/bin/env bash

TERRA ?= terra
LUAJIT ?= luajit
CC ?= cc

.PHONY: all build build-argile build-bench build-bench-c build-parity test bench bench-quick bench-heavy bench-stress bench-c bench-c-heavy bench-c-stress parity parity-quick parity-heavy parity-stress clean

all: build

build: build-argile

build-argile:
	@mkdir -p build
	$(TERRA) tools/build_argile.t

build-bench:
	@mkdir -p build
	./tools/build_bench.sh

build-bench-c:
	@mkdir -p build
	./tools/build_bench_c.sh

build-parity:
	@mkdir -p build
	./tools/build_parity.sh

test:
	$(TERRA) tests/test_foundation.t
	$(TERRA) tests/test_layout.t
	$(TERRA) tests/test_runtime_states_integration.t
	$(TERRA) tests/test_dsl_parser.t
	$(TERRA) tests/test_dsl_compiler_program_ast.t
	$(TERRA) tests/test_capi_dsl_ast.t
	$(TERRA) tests/test_capi_dsl_host_callback_backend.t
	$(TERRA) tests/test_dsl_ast_parity.t

bench: build-bench
	$(LUAJIT) bench/compare.lua heavy

bench-quick: build-bench
	$(LUAJIT) bench/compare.lua quick

bench-heavy: build-bench
	$(LUAJIT) bench/compare.lua heavy

bench-stress: build-bench
	$(LUAJIT) bench/compare.lua stress

bench-c: build-bench-c
	./build/bench_compare_c heavy

bench-c-heavy: build-bench-c
	./build/bench_compare_c heavy

bench-c-stress: build-bench-c
	./build/bench_compare_c stress

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
