# Argile CAPI v2 Hard-Cut Refactor Plan (One-Go)

Status: Execution blueprint (single-pass cutover)

Date: 2026-02-28

Companion spec:
- `docs/capi-v2-hard-cut-spec.md`

## 1. Execution Stance

This is a **monolithic refactor** plan.

We are not optimizing for gradual migration, temporary compatibility layers, or dual-path code.

We are optimizing for:

1. writing the target architecture directly,
2. deleting obsolete APIs immediately,
3. landing the final v2 surface in one decisive pass.

Core rule:

- no v1 element-construction compatibility code survives the cut.

## 2. Target End State (Code, Not Transition)

At the end of this refactor, Argile has exactly one non-text element construction model in CAPI:

1. build `ElementDesc`,
2. call `OpenElementWithDesc*`,
3. call `CloseElement*`.

Everything else from v1 compose style is gone.

## 3. Final API Shape (Authoritative)

## 3.1 New Canonical Symbols

Required symbols in exported CAPI:

1. `bool OpenElementWithDescForContext(struct Context* ctx, const struct ElementDesc* desc);`
2. `bool OpenElementWithIdAndDescForContext(struct Context* ctx, struct ElementId id, const struct ElementDesc* desc);`
3. `bool OpenElementWithIdCharsAndDescForContext(struct Context* ctx, char* chars, int32_t length, const struct ElementDesc* desc);`

Retained existing symbol required by model:

1. `void CloseElementForContext(struct Context* ctx);`

## 3.2 New Descriptor Types

Target descriptor constants:

```c
typedef uint32_t ElementDescFlags;
enum {
  DESC_HAS_LAYOUT   = 1u << 0,
  DESC_HAS_SHARED   = 1u << 1,
  DESC_HAS_BORDER   = 1u << 2,
  DESC_HAS_CLIP     = 1u << 3,
  DESC_HAS_FLOATING = 1u << 4,
  DESC_HAS_ASPECT   = 1u << 5,
  DESC_HAS_IMAGE    = 1u << 6,
  DESC_HAS_CUSTOM   = 1u << 7,
  DESC_HAS_PAINT    = 1u << 8
};
```

Target descriptor struct:

```c
struct ElementDesc {
  uint32_t flags;
  struct LayoutConfig layout;
  struct SharedConfig shared;
  struct BorderConfig border;
  struct ClipConfig clip;
  struct FloatingConfig floating;
  struct AspectRatioConfig aspect;
  struct ImageConfig image;
  struct CustomConfig custom;
  struct PaintConfig paint;
};
```

## 3.3 Removed Symbols (Hard Delete)

The following families are removed from export surface:

1. `OpenElement*` (plain/id/idChars v1 forms)
2. `OpenStyledElement*`
3. `ConfigureOpenElementBox*`
4. `SetOpenElementLayoutConfig*`
5. `Attach*Config*` family
6. `AttachOverflowConfig*`
7. `ApplyOpenElementConfigs*`
8. `OpenElementWith*ConfigBundle*`

## 3.4 Version Bump

1. `ARGILE_API_VERSION` is `2`.
2. v1 clients must fail version check and migrate.

## 4. Target File-by-File Code Shape

This section defines what each key file should look like after the refactor.

## 4.1 `src/config.t`

Target additions:

1. `ui.ElementDescFlags = uint32`
2. `ui.DESC_HAS_*` constants
3. `ui.ElementDesc` struct

Target removals:

1. `ui.NodeBuildConfigBundle` (remove entirely)

Target intent:

- descriptor is the only CAPI-facing container for optional element configs.

## 4.2 `src/context.t`

Target core implementation units:

1. `Context:applyElementDesc(desc: &config.ElementDesc) : bool`
2. `Context:openElementWithDesc(hasExplicitId: bool, id: hash.ElementId, desc: &config.ElementDesc) : bool`
3. public wrappers:
   - `ui.OpenElementWithDescForContext`
   - `ui.OpenElementWithIdAndDescForContext`
   - `ui.OpenElementWithIdCharsAndDescForContext`

Target apply order (must be literal in code):

1. layout
2. shared
3. border
4. clip
5. aspect
6. image
7. custom
8. floating
9. paint

Target sketch:

```terra
terra ui.Context:applyElementDesc(desc: &config.ElementDesc) : bool
    if desc == nil then return false end
    var ok = true

    if (desc.flags and config.DESC_HAS_LAYOUT) ~= 0 then
        var openElem = self:getOpenLayoutElement()
        if openElem == nil then return false end
        openElem.layoutConfig = desc.layout
    end
    if (desc.flags and config.DESC_HAS_SHARED) ~= 0 then
        var sharedPtr = self:storeSharedConfig(desc.shared)
        if sharedPtr == nil then return false end
        var cu: config.ElementConfigUnion
        cu.shared = sharedPtr
        if self:attachElementConfig(cu, config.CONFIG_SHARED) == nil then ok = false end
    end
    -- ... repeat in fixed order for border/clip/aspect/image/custom/floating/paint ...
    return ok
end
```

Target removals from `src/context.t`:

1. `ConfigureOpenElementBox*`
2. `OpenStyledElement*`
3. `SetOpenElementLayoutConfig*` public forms (internal assignment helpers may remain if used by desc path)
4. all public `Attach*Config*`
5. `AttachOverflowConfig*`
6. `ApplyOpenElementConfigs*`
7. `OpenElementWith*ConfigBundle*`
8. v1 `OpenElement*` public entry points

Notes:

1. internal storage helpers like `storeBorderConfig`, `storePaintConfig`, `attachElementConfig` remain and are used by descriptor path.
2. paint copy semantics remain in `storePaintConfig`.

## 4.3 `src/init.t`

Target public forwards include descriptor APIs and exclude removed families.

Keep examples:

1. `ui.OpenElementWithDescForContext`
2. `ui.OpenElementWithIdAndDescForContext`
3. `ui.OpenElementWithIdCharsAndDescForContext`
4. `ui.CloseElementForContext`

Remove forwards for deleted v1 construction APIs.

## 4.4 `src/capi.t`

Target export table contains descriptor open APIs only for non-text construction.

Export additions:

1. `OpenElementWithDescForContext`
2. `OpenElementWithIdAndDescForContext`
3. `OpenElementWithIdCharsAndDescForContext`

Export deletions:

1. all symbol families listed in section 3.3.

## 4.5 `bindings/luajit/argile_lj/runtime.lua`

Target binding shape:

1. `mk_element_desc(opts)` helper (Lua table -> `struct ElementDesc`)
2. `open_element_desc(desc_or_opts)` method
3. optional `open_element_desc_with_id(id, desc_or_opts)`

Explicitly remove methods that map to deleted v1 symbols:

1. attach-overflow helpers built on `Attach*`
2. any open/configure/attach composition helpers

Binding usage target:

```lua
local d = ctx:mk_element_desc({
  layout = {...},
  shared = {...},
  border = {...},
})
ctx:open_element_desc(d)
lib.CloseElementForContext(ctx.ctx)
```

## 4.6 `bench/compare.lua`

Target non-text path:

1. fill reusable `struct ElementDesc[1]` buffers,
2. set flags by scenario/mode,
3. one call `OpenElementWithDescForContext`.

No use of:

1. `OpenElementForContext`
2. `ConfigureOpenElementBoxForContext`
3. `Attach*ConfigForContext`
4. bundle APIs

Text path remains explicit text-open call.

## 4.7 `tools/terra_bench_api.t`

Target Terra benchmark shim mirrors descriptor model exactly.

No compose-in-place calls in benchmark shim.

## 4.8 Tests (`tests/`)

Target tests are v2-centric.

Add dedicated tests:

1. `test_capi_element_desc.t`
2. `test_capi_element_desc_errors.t`

Delete/replace tests relying on deleted v1 element-construction symbols.

## 5. One-Go Implementation Script (Single Pass)

This is the coding order for a fast hard cut, not phased release management.

1. **Define final types first** in `src/config.t`.
2. **Implement final descriptor open path** in `src/context.t`.
3. **Delete old context entry points immediately** after descriptor path compiles.
4. **Replace public forwards/exports** in `src/init.t` and `src/capi.t`.
5. **Regenerate C API artifacts** (`make build`) so headers/ffi match v2.
6. **Migrate all in-repo callers** (bench, tools, bindings, tests) directly to descriptor API.
7. **Remove dead references and dead code** with repository-wide symbol search.
8. **Run full validation only after end-state code exists**.

This keeps coding momentum focused on the final architecture and avoids maintaining temporary green intermediate states.

## 6. Target Repository-Wide Symbol State

Final grep expectations:

Removed v1 symbols should return no active code references:

```bash
rg "OpenStyledElement|ConfigureOpenElementBox|Attach(Border|Clip|Custom|Image|Aspect|Paint|Shared|Floating)|OpenElementWithConfigBundle|ApplyOpenElementConfigs" src bindings tools bench tests
```

Descriptor symbols should exist and be used:

```bash
rg "OpenElementWithDescForContext|OpenElementWithIdAndDescForContext|OpenElementWithIdCharsAndDescForContext|ElementDesc|DESC_HAS_" src bindings tools bench tests build
```

## 7. Minimal Validation Policy (After Code, Not During)

Validation runs after the hard-cut rewrite is complete:

1. `make build`
2. `make test`
3. `make parity-quick`
4. `make bench-quick`
5. `make bench-c-heavy`

Expected benchmark parity behavior during this refactor:

1. no new mismatch categories should be introduced by API redesign,
2. existing known text mismatch may remain until dedicated text parity work is done.

## 8. Illustrated End-State Data Path

```text
Caller (C / LuaJIT / Terra)
   |
   | fill ElementDesc (flags + config payloads)
   v
OpenElementWithDescForContext
   |
   +--> open layout element node
   +--> apply descriptor fields in fixed order
   +--> attach stored configs
   +--> return bool
   v
CloseElementForContext
```

## 9. Definition of Done

The refactor is complete only when all are true:

1. `ARGILE_API_VERSION == 2`.
2. v1 construction symbol families are absent from generated `build/argile_api.h` and `build/argile_api_ffi.lua`.
3. all in-repo consumers use descriptor opens for non-text elements.
4. no compatibility wrappers for removed v1 construction APIs remain in exports.
5. docs describe descriptor-first v2 only.

## 10. Immediate Coding Target

Start directly with end-state code in this order:

1. `src/config.t`
2. `src/context.t`
3. `src/init.t`
4. `src/capi.t`
5. `bench/compare.lua`, `tools/terra_bench_api.t`, `bindings/luajit/argile_lj/runtime.lua`, tests
6. docs cleanup

No staged compatibility checkpoints.
