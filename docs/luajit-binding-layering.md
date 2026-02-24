# LuaJIT Binding Layering and Compatibility Policy

This document defines how official LuaJIT bindings are split across `argile` (engine) and downstream projects (such as `argile-ui`) while staying compatible.

The goal is to avoid two incompatible FFI stacks for the same engine ABI.

## Scope

This policy covers:

- the official engine-level LuaJIT binding in `argile` (`argile_lj`)
- downstream LuaJIT bindings that add higher-level APIs (widgets, themes, app DSLs)
- compatibility requirements between the two layers
- packaging/re-export patterns

This policy does not define widget APIs themselves.

## Ownership Model

### `argile` Owns the Engine Binding

`argile` is the canonical home for:

- `ui.capi` FFI loading and runtime wrappers
- ABI version checks and feature detection
- canonical AST reuse / AST helpers for LuaJIT
- engine-level DSL/AST wrapper helpers
- engine/backend reference demos (for example LÖVE FFI)

Current reference package:

- `bindings/luajit/argile_lj/`

### `argile-ui` (and other downstream projects) Own Higher-Level Bindings

Downstream projects should add higher-level bindings on top of the engine binding, for example:

- widgets
- themes and design-system helpers
- app-level DSL sugar
- framework integration convenience wrappers

They should not fork or duplicate the engine FFI runtime layer unless there is a documented technical blocker.

## Layering Rule (Hard Requirement)

Official downstream LuaJIT bindings must be layered on top of `argile_lj`.

That means:

- no duplicate `ffi.cdef` of `argile_api_ffi.lua` in downstream bindings
- no separate raw `ffi.load("libargile.so")` path inside downstream bindings (except explicit advanced escape hatches)
- no second runtime context type incompatible with `argile_lj.runtime`

The engine binding is the foundation; downstream bindings extend it.

## Recommended Package Shape

### Engine Layer (in `argile`)

- `bindings.luajit.argile_lj.runtime`
- `bindings.luajit.argile_lj.ast`
- `bindings.luajit.argile_lj.dsl`
- `bindings.luajit.argile_lj.compiler`

### Widget/App Layer (in downstream projects, e.g. `argile-ui`)

Recommended names:

- `hosts.luajit.argile_ui_lj.init`
- `hosts.luajit.argile_ui_lj.widgets`
- `hosts.luajit.argile_ui_lj.theme`
- `hosts.luajit.argile_ui_lj.dsl` (optional)

The widget layer should either:

- accept an `argile_lj` runtime client/context injected by the user, or
- lazily create and cache one by calling `require("bindings.luajit.argile_lj")`

## Compatibility Contract (What Must Match)

### 1. FFI Loader and Library Handle

Both layers must operate on the same loaded Argile library and FFI definitions.

Required behavior:

- one `ffi.cdef` source for Argile ABI (`build/argile_api_ffi.lua`)
- one library handle for `libargile.so` per process (or an explicit shared loader object)
- downstream bindings should reuse `argile_lj.runtime.load(...)`

Why:

- avoids subtle type identity mismatches
- avoids duplicated symbol probing / capability drift
- keeps ABI version checks centralized

### 2. Runtime Context Object Shape

Downstream widget bindings must accept and use the same context objects produced by `argile_lj.runtime`.

At minimum, downstream code should treat these fields/methods as the stable contract:

- `runtime_ctx.lib`
- `runtime_ctx.ffi`
- `runtime_ctx.ctx`
- `runtime_ctx:set_current()`
- `runtime_ctx:set_measure_text(fn [, user_data])`
- `runtime_ctx:destroy()`

If downstream code wraps the context, it should preserve access to the underlying `runtime_ctx`.

### 3. ABI Version and Capability Checks

Engine ABI checks belong in `argile_lj`, not duplicated in each downstream binding.

Downstream bindings should reuse:

- `GetApiVersion()` vs `ARGILE_API_VERSION`
- engine/compiler capability detection helpers (for example `argile_lj.compiler.detect(...)`)

Do not add a second incompatible version-gating scheme.

### 4. String and ID Semantics

This is a critical compatibility area.

Rules:

- downstream bindings should reuse engine-provided string/ID helpers whenever possible
- ownership/lifetime of Lua strings passed through FFI must be documented and preserved across both layers
- IDs should be created through shared helpers (`GetElementId`, cached ID helpers) to avoid inconsistent hashing paths

Important practical note:

- Lua strings passed by pointer must stay alive for as long as Argile may read them (layout + render command consumption + callbacks such as text measurement)
- downstream wrappers must not hide this lifetime issue with unsafe defaults

When in doubt:

- pin frame strings for the duration of the frame, or
- copy strings into owned buffers for longer-lived usage

### 5. Callback Registration and GC Safety

LuaJIT callback pointers (`ffi.cast`) must be retained strongly to avoid GC invalidation.

Engine layer should provide the canonical pattern for:

- measure-text callback registration
- callback lifetime retention
- reset/unregister behavior

Downstream bindings must reuse that pattern instead of creating divergent callback lifetimes.

### 6. Error and Diagnostic Model

Downstream bindings should not invent a conflicting low-level error model.

Prefer:

- surfacing engine errors/capabilities directly
- adding higher-level context (widget/theme names) on top

Keep low-level runtime/FFI failure messages traceable to `argile_lj`.

## Merge Strategy (How To “Merge” Without Forking)

The preferred approach is compositional merge:

- `argile-ui` LuaJIT bindings re-export `argile_lj`
- add widget APIs on top
- expose a single top-level package for users if desired

Example shape:

```lua
-- argile-ui side
local M = {}
M.argile = require("bindings.luajit.argile_lj")
M.widgets = require("hosts.luajit.argile_ui_lj.widgets")
M.theme = require("hosts.luajit.argile_ui_lj.theme")
return M
```

This gives users a unified experience without duplicating the engine FFI core.

## What “Merged Together” Should Not Mean

Avoid:

- copy/pasting `argile_lj.runtime` into downstream repos
- re-declaring Argile FFI types/constants in a second place
- making widget bindings depend on undocumented internals of `argile_lj`
- patching engine-level lifetime semantics differently in multiple bindings

These cause drift and hard-to-debug FFI bugs.

## Extension Points for Downstream Bindings

Downstream LuaJIT bindings are encouraged to add:

- widget composition APIs
- theme token adapters
- design-system facades
- higher-level scene authorship helpers
- widget-specific diagnostics / devtools

As long as they preserve the compatibility contract above.

## Versioning and Release Coordination

When releasing official LuaJIT bindings across `argile` and `argile-ui`:

- treat `argile_lj` as the ABI-facing base dependency
- document the minimum supported `argile_lj` version/commit in `argile-ui`
- keep compatibility changes explicit in changelogs (string ownership, context object changes, callback API changes)

If the engine binding contract changes, downstream bindings must be updated in lockstep or feature-gated.

## Testing Strategy

### Engine (`argile`)

`argile` should continue to own:

- runtime FFI probes
- backend reference demos
- ABI/capability detection checks
- AST/DSL portability probes for LuaJIT

### Downstream (`argile-ui`)

`argile-ui` should add:

- widget binding smoke tests using `argile_lj.runtime`
- compatibility tests that instantiate widgets against a real `argile_lj` context
- tests that verify no duplicate FFI loader is created when a runtime client is injected

## Immediate Implementation Guidance

Before building official `argile-ui` LuaJIT bindings:

1. Depend on `bindings.luajit.argile_lj` instead of creating a new raw FFI loader.
2. Define the `argile_ui_lj` context acceptance pattern (`runtime_client` and/or `runtime_ctx` injection).
3. Reuse engine string/ID helpers or wrap them without changing ownership semantics.
4. Document the required `argile_lj` APIs consumed by the widget layer.
5. Add a smoke demo that uses `argile_ui_lj` and proves it runs on top of the same `argile_lj` runtime context.

## Related Documents

- `bindings/luajit/README.md`
- `docs/capi-dsl-ast-bindings.md`
- `docs/capi-dsl-ast-canonical-architecture.md`

