# Argile DSL Callback-Compile Backend Evaluation (Terra -> Lua, Cached)

## Purpose

This document records the benchmark experiment and architecture tradeoffs for a **cached callback-based compile backend**:

- Terra runtime code calls a Lua callback (via `terralib.cast`)
- the Lua callback fetches or compiles a cached Argile DSL render function through the canonical host AST/compiler path
- the callback returns a native function pointer
- Terra runtime code calls that function pointer

This is a **transitional backend strategy** for shipping DSL compilation support in bindings without waiting for a pure-Terra runtime lowering path.

It is not the long-term canonical runtime compiler architecture, but it is a practical and measured option.

## Why This Exists

Argile currently has:

- a canonical host-side DSL compiler (`dsl_compiler`, Lua/Terra metaprogramming)
- a runtime shared-library ABI (`ui.capi`, Terra exports)

`ui.capi` cannot directly export/call the host compiler path (`terralib.saveobj` export boundary). The callback backend is a pragmatic bridge when:

- compilation is infrequent
- compiled artifacts are cached
- runtime execution remains native

## Experiment

Reference experiment tool:

- `argile/tools/experiment_terra_lua_callback_compile_cache.t`

Run command (from `argile/`):

```bash
TERRA_PATH="./?.t" terra tools/experiment_terra_lua_callback_compile_cache.t
```

## What The Experiment Measures

The experiment measures four paths in the same process:

1. Host compile (Lua/Terra canonical path) cache miss
2. Terra -> Lua callback -> cached function pointer fetch (cache hit)
3. Pure Terra equivalent pointer fetch loops (direct function and function-pointer forms)
4. Real cache-miss compile from inside the callback path

It also validates:

- pointer stability on cache hits
- no nil pointers on valid paths
- actual UI render output execution via returned function pointers

## Example Results (One Machine / One Run)

Observed on the developer machine during the recorded run:

- warm compile (host API, miss): ~2.05 ms
- warm compile v2 (host API, miss): ~1.69 ms
- render once via Terra->Lua callback (cache hit): ~54.56 ms
- render once via pure Terra direct pointer: ~3.70 ms

Steady-state pointer fetch loop (`2000` iterations):

- callback cache hits: ~6.23 ms
- pure Terra direct function fetch: ~3.99 ms
- pure Terra function-pointer fetch: ~4.62 ms
- pure Terra constant pointer loop: ~1.42 ms

Relative overhead from that run:

- callback-hit vs pure Terra direct: ~1.56x
- callback-hit vs pure Terra fnptr: ~1.35x
- callback-hit vs constant-pointer baseline: ~4.38x

Cache-miss compile from inside callback (uncached key):

- succeeded
- ~6.58 ms in the experiment scene

## How To Interpret These Numbers

### First-Call Numbers Are Not Steady-State

The "render once via callback" timing includes one-time runtime warmup/JIT effects and should not be used as the steady-state overhead number.

The loop timings are the useful comparison for ongoing behavior.

### The Callback Bridge Is Slower, But Not Catastrophically So

For pointer fetch on cache hits, the callback path was roughly:

- `1.3x - 1.6x` slower than pure-Terra pointer-provider paths in this experiment

That is acceptable when:

- callback fetch is not in the hottest per-element inner loops, or
- the callback is used primarily for compile-on-change orchestration, not per-frame recompilation

### Cache-Miss Compile Cost Can Be Tolerable If It Is Rare

The experiment's cache-miss compile from inside callback succeeded in a few milliseconds for a small scene.

This supports the strategy:

- compile on startup/change
- cache aggressively
- keep runtime execution on compiled functions

## Architectural Tradeoffs

## Option A: Cached Callback Backend (This Document)

Shape:

- runtime Terra code calls Lua callback
- callback uses canonical host compiler cache
- callback returns compiled function pointer

Pros:

- uses canonical compiler semantics today
- no duplicate semantic engine
- shippable without waiting for pure-Terra lowering
- works with immediate-mode UI if compile is cached
- can support hot reload and dynamic authoring workflows

Cons:

- runtime callback overhead vs pure Terra path
- more complex error/reentrancy handling than direct runtime APIs
- still crosses Lua/Terra boundary
- not suitable as a "compile every frame" design

## Option B: Pure Terra Runtime Lowering (Long-Term)

Shape:

- portable AST/IR -> pure Terra lowering/runtime compile
- no Lua callbacks in runtime compile path

Pros:

- cleaner runtime architecture
- better long-term performance ceiling
- simpler runtime deployment contract for non-Terra bindings

Cons:

- larger implementation project
- requires porting/extracting semantic lowering out of host Lua/Terra compiler path

## Recommendation (Current Project State)

Use the cached callback backend as a **supported transitional backend** while:

- keeping canonical semantics in the host compiler
- preserving the AST-first architecture
- continuing to evaluate/plan pure-Terra lowering for long-term runtime compile

## Guardrails (Non-Negotiable)

To keep the callback backend from becoming a maintenance trap:

- no duplicate semantics in the callback backend
- callback backend must compile/fetch through canonical host compiler APIs
- compile must be cached by stable keys
- no per-frame recompilation in normal operation
- runtime UI keeps the previous compiled artifact active until replacement compile succeeds
- compile errors surface diagnostics without breaking the live frame loop

## Cache Policy Guidance

Recommended cache key inputs:

- canonical AST hash (or source hash if AST is deterministically derived)
- compile options
- environment signature
- Argile/compiler version
- runtime ABI version if artifact depends on it

Recommended invalidation triggers:

- source/AST changes
- theme/token/recipe inputs that affect compile-time behavior
- feature-flag/ABI changes
- compiler option changes

## Threading / Reentrancy Notes

Callback compilation crosses runtime and host execution domains. Use one of:

- one compiler context per thread
- or a shared compiler context with explicit serialization/locking

Do not assume the host compiler state is reentrant by default.

## How To Present This To Library Users

The callback backend should be presented honestly and clearly:

### What To Promise

- canonical Argile semantics (same host compiler)
- cached compilation support
- no required per-frame recompilation
- runtime execution remains compiled/native

### What Not To Promise

- "pure runtime compiler" (it is a host callback backend)
- zero-overhead compilation
- support for every host-only construct in plain runtime-only deployments

### Suggested User-Facing Wording

Suggested wording for bindings documentation:

- "Argile supports cached host-compiled DSL execution. Compilation occurs on load/change and compiled UI functions are reused during frame execution."
- "Runtime-only deployments can use `ui.capi` without DSL compilation."
- "A callback-based compile backend is available for host-integrated environments and is intended for cached compile workflows, not per-frame compilation."

## Integration Plan Implications

This experiment supports the decision to:

- keep `ui.capi` runtime ABI low-level and stable
- implement language shims (LuaJIT/Rust/etc.) on top of low-level APIs
- use host compiler contexts + cache for DSL compilation in integrated environments

It does **not** remove the value of a future pure-Terra lowering path if runtime AST compilation in `ui.capi` becomes a product requirement.

## Related References

- `argile/docs/capi-dsl-ast-canonical-architecture.md`
- `argile/docs/capi-dsl-ast-bindings.md`
- `argile/tools/experiment_terra_lua_callback_compile_cache.t`
