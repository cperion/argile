SHELL := /usr/bin/env bash

TERRA ?= terra
LUAJIT ?= luajit
CC ?= cc

.PHONY: all build build-argile build-bench love-demo test bench bench-quick bench-heavy bench-stress clean

all: build

build: build-argile

build-argile:
	@mkdir -p build
	$(TERRA) tools/build_argile.t

build-bench:
	@mkdir -p build
	./tools/build_bench.sh

love-demo: build
	love demo/love

test:
	$(TERRA) tests/test_foundation.t
	$(TERRA) tests/test_layout.t
	$(TERRA) tests/test_builder.t

bench: build-bench
	$(LUAJIT) bench/compare.lua heavy

bench-quick: build-bench
	$(LUAJIT) bench/compare.lua quick

bench-heavy: build-bench
	$(LUAJIT) bench/compare.lua heavy

bench-stress: build-bench
	$(LUAJIT) bench/compare.lua stress

clean:
	rm -rf build
