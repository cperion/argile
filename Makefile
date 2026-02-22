SHELL := /usr/bin/env bash

TERRA ?= terra
LUAJIT ?= luajit
CC ?= cc

.PHONY: all build build-argile build-bench build-parity love-demo test bench bench-quick bench-heavy bench-stress parity parity-quick parity-heavy parity-stress clean

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
	love demo/love

test:
	$(TERRA) tests/test_foundation.t
	$(TERRA) tests/test_layout.t
	$(TERRA) tests/test_builder.t
	$(TERRA) tests/test_language_extension.t
	$(TERRA) tests/test_state_requires_id.t

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
