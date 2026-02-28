# Argile CAPI v2 Hard-Cut Specification

Status: Draft (design-phase target)

Authors: Argile maintainers

Date: 2026-02-28

Audience: engine maintainers, binding authors, benchmark harness maintainers, platform integration maintainers

## 1. Purpose

This document defines the **CAPI v2 hard-cut target** for Argile element construction.

The primary goal is to replace the current multi-call composition model:

- `OpenElement*`
- `ConfigureOpenElementBox*`
- `Attach*Config*`
- `OpenElementWithConfigBundle*`

with a **single canonical fast path** that expresses an element in one descriptor.

## 2. Scope

In scope:

1. Element construction API redesign for non-text elements.
2. ABI contract for descriptor-driven opening.
3. Removal list for v1 element-construction APIs.
4. Semantics (ordering, defaults, ownership, error rules).
5. Validation requirements.

Out of scope:

1. DSL parser/compiler behavior redesign.
2. Render command format redesign.
3. Scroll solver redesign.
4. Widget-layer UX design.

## 3. Design Principles

1. One obvious high-performance path for FFI callers.
2. No compatibility shim in v2: removed symbols are removed.
3. Stable C ABI with explicit presence flags.
4. Deterministic config application order.
5. No hidden dynamic allocation requirements for caller-owned descriptor memory.

## 4. Versioning and Compatibility Policy

1. `ARGILE_API_VERSION` MUST be bumped from `1` to `2`.
2. CAPI symbol set in v2 is authoritative. Removed v1 symbols are not exported.
3. Bindings must hard-fail on v1/v2 mismatch using `GetApiVersion()`.
4. No compatibility wrappers are retained in engine exports.

## 5. v2 Canonical Element Construction Model

### 5.1 Core Idea

All non-text element construction uses one call:

- `OpenElementWithDescForContext(struct Context*, const struct ElementDesc*)`

Optional ID variants exist, but they still consume the same descriptor.

### 5.2 Canonical Calls

Required element-open calls:

1. `bool OpenElementWithDescForContext(struct Context* ctx, const struct ElementDesc* desc);`
2. `bool OpenElementWithIdAndDescForContext(struct Context* ctx, struct ElementId id, const struct ElementDesc* desc);`
3. `bool OpenElementWithIdCharsAndDescForContext(struct Context* ctx, char* chars, int32_t length, const struct ElementDesc* desc);`
4. `void CloseElementForContext(struct Context* ctx);`

Convenience non-context wrappers MAY exist in Terra/Lua wrappers, but **not as independent CAPI behavior variants**.

## 6. New Types

### 6.1 Presence Flags

`ElementDesc` uses a bitmask to specify which optional config blocks are active.

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

### 6.2 Descriptor Struct

`ElementDesc` is POD and passed by pointer.

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

Notes:

1. Fields are always physically present for ABI stability.
2. `flags` controls which fields are semantically read.
3. `DESC_HAS_LAYOUT` and `DESC_HAS_SHARED` are recommended in all box-like nodes.

### 6.3 Optional Helper Initializer (Non-ABI)

C headers MAY include an inline helper:

```c
static inline struct ElementDesc ElementDesc_Default(void) {
  struct ElementDesc d;
  memset(&d, 0, sizeof(d));
  return d;
}
```

This helper is optional and non-normative for ABI.

## 7. Semantics

### 7.1 Preconditions

`OpenElementWithDesc*` requires:

1. `ctx != NULL`
2. Between `BeginLayoutForContext` and `FinalizeLayoutForContext`.
3. Element stack not overflowed.
4. `desc != NULL`

Violation returns `false` and follows normal engine error reporting policy.

### 7.2 Defaulting Behavior

If a flag is absent:

1. That config is not attached.
2. Previous open element state is not reused.
3. No implicit attachment occurs except engine defaults required for validity.

Mandatory validity rules:

1. If `DESC_HAS_LAYOUT` is absent, engine applies default FIT layout equivalent to text-free open semantics.
2. If `DESC_HAS_SHARED` is absent, no shared visual config is attached.

### 7.3 Config Application Order (Normative)

For deterministic behavior, when `OpenElementWithDesc*` executes, config application order MUST be:

1. Layout
2. Shared
3. Border
4. Clip
5. Aspect
6. Image
7. Custom
8. Floating
9. Paint

Reason: preserves established behavior expectations from existing bundle application order in `src/context.t`.

### 7.4 Paint Ownership Rules

When `DESC_HAS_PAINT` is set:

1. `paint.ops` may point to caller memory.
2. Engine copies paint ops into context-managed storage during call.
3. Caller memory only needs to remain valid for the duration of the call.
4. On capacity failure, call returns `false` and standard error path is used.

### 7.5 ID Behavior

- `OpenElementWithDescForContext` uses engine automatic ID generation.
- `OpenElementWithIdAndDescForContext` uses caller-specified `ElementId`.
- `OpenElementWithIdCharsAndDescForContext` hashes chars exactly like current `GetElementIdFromChars` path.

### 7.6 Culling, Debug, and Scroll Semantics

Descriptor API does not change:

1. Global/per-context culling settings.
2. Debug mode toggles.
3. Scroll container behavior.
4. `UpdateScrollContainers*` contract.

## 8. Removed v1 Symbols (Hard-Cut)

The following symbol families are removed from v2 exports:

### 8.1 Open/Configure/Attach Composition APIs

1. `OpenElement`, `OpenElementForContext`
2. `OpenElementWithId`, `OpenElementWithIdForContext`
3. `OpenElementWithIdChars`, `OpenElementWithIdCharsForContext`
4. `OpenStyledElement`, `OpenStyledElementForContext`
5. `ConfigureOpenElementBox`, `ConfigureOpenElementBoxForContext`
6. `SetOpenElementLayoutConfig`, `SetOpenElementLayoutConfigForContext`
7. `AttachSharedConfig`, `AttachSharedConfigForContext`
8. `AttachBorderConfig`, `AttachBorderConfigForContext`
9. `AttachClipConfig`, `AttachClipConfigForContext`
10. `AttachOverflowConfig`, `AttachOverflowConfigForContext`
11. `AttachFloatingConfig`, `AttachFloatingConfigForContext`
12. `AttachAspectRatioConfig`, `AttachAspectRatioConfigForContext`
13. `AttachImageConfig`, `AttachImageConfigForContext`
14. `AttachCustomConfig`, `AttachCustomConfigForContext`
15. `AttachPaintConfig`, `AttachPaintConfigForContext`

### 8.2 Bundle APIs

1. `ApplyOpenElementConfigs`, `ApplyOpenElementConfigsForContext`
2. `OpenElementWithConfigBundle`, `OpenElementWithConfigBundleForContext`
3. `OpenElementWithIdAndConfigBundle`, `OpenElementWithIdAndConfigBundleForContext`
4. `OpenElementWithIdCharsAndConfigBundle`, `OpenElementWithIdCharsAndConfigBundleForContext`

## 9. APIs Explicitly Retained in v2

Retained as-is unless separately redesigned:

1. Frame lifecycle: `BeginLayout*`, `FinalizeLayout*`
2. Text opening: `OpenTextElementWithLengthForContext` and ID variants
3. Close operation: `CloseElementForContext`
4. Render fetch APIs
5. Input/interaction APIs
6. Hash/ID APIs
7. Context/arena initialization APIs

## 10. Error Model

`OpenElementWithDesc*` returns `false` for any failure.

Failure causes include:

1. null context
2. null descriptor
3. capacity exceeded
4. unbalanced layout lifecycle misuse
5. invalid paint payload (count > 0 and ops == NULL)

Engine MUST continue to use existing `SetErrorHandler` callback surface for error details.

## 11. Performance Contract

v2 descriptor path is designed to reduce per-element FFI boundary crossings.

Expected wins:

1. benchmark hot loops (especially config churn) move from N attach calls to one open call.
2. lower boundary overhead for LuaJIT and other FFI runtimes.
3. reduced opportunities for accidental slow-path composition.

Non-goal: changing internal layout solver complexity in this refactor.

## 12. Threading and Reentrancy

Unchanged from v1:

1. Contexts are not internally synchronized.
2. One context should be mutated by one thread at a time.
3. CAPI calls are reentrant only where existing engine behavior is reentrant.

## 13. Descriptor Usage Examples

### 13.1 C Example: Basic Panel

```c
struct ElementDesc d = {0};
d.flags = DESC_HAS_LAYOUT | DESC_HAS_SHARED | DESC_HAS_BORDER;

d.layout.sizing.width.type = SIZING_FIXED;
d.layout.sizing.width.size.min = 360;
d.layout.sizing.width.size.max = 360;
d.layout.sizing.height.type = SIZING_FIXED;
d.layout.sizing.height.size.min = 320;
d.layout.sizing.height.size.max = 320;
d.layout.layoutDirection = TOP_TO_BOTTOM;
d.layout.padding.left = d.layout.padding.right = 8;
d.layout.padding.top = d.layout.padding.bottom = 8;
d.layout.childGap = 4;
d.layout.childAlignment.x = ALIGN_X_LEFT;
d.layout.childAlignment.y = ALIGN_Y_TOP;

d.shared.backgroundColor = (struct Color){25,35,50,255};
d.shared.cornerRadius = (struct CornerRadius){0,0,0,0};
d.shared.userData = NULL;

d.border.color = (struct Color){60,70,90,255};
d.border.width = (struct BorderWidth){1,1,1,1,0};

OpenElementWithDescForContext(ctx, &d);
/* children... */
CloseElementForContext(ctx);
```

### 13.2 C Example: Config-Churn Node

```c
struct ElementDesc d = {0};
d.flags = DESC_HAS_LAYOUT | DESC_HAS_SHARED;

if (mode == 0) { d.flags |= DESC_HAS_BORDER; }
if (mode == 1) { d.flags |= DESC_HAS_CUSTOM; }
if (mode == 2) { d.flags |= DESC_HAS_IMAGE; }
if (mode == 3) { d.flags |= DESC_HAS_ASPECT; }

OpenElementWithDescForContext(ctx, &d);
CloseElementForContext(ctx);
```

### 13.3 LuaJIT FFI Pattern

```lua
local d = ffi.new("struct ElementDesc")
d.flags = bit.bor(lib.DESC_HAS_LAYOUT, lib.DESC_HAS_SHARED)
-- fill d.layout and d.shared once, mutate only changed fields in loop
lib.OpenElementWithDescForContext(ctx, d)
lib.CloseElementForContext(ctx)
```

## 14. Required Export Surface Updates

The following generated artifacts MUST include v2 symbols/types and omit removed v1 symbols:

1. `build/argile_api.h`
2. `build/argile_api_ffi.lua`

Generation path remains:

- `tools/build_argile.t` -> `src/capi.t` exports and type traversal.

## 15. Test Requirements (Spec-Level)

Minimum mandatory tests for v2:

1. `OpenElementWithDescForContext` opens, configures, and closes correctly.
2. ID variants match `GetElementIdFromChars` semantics.
3. Missing flags do not attach unintended configs.
4. Paint ops copy semantics validated.
5. Capacity failure path returns `false` and reports error.
6. Existing parity tests run with updated API call sites.

## 16. Illustrated Model

### 16.1 v1 vs v2 Call Shape

```text
v1 (multi-call per element)
---------------------------
OpenElement
  -> ConfigureOpenElementBox
  -> AttachBorder?
  -> AttachClip?
  -> AttachCustom?
  -> AttachImage?
  -> AttachAspect?
CloseElement

v2 (single descriptor open)
---------------------------
OpenElementWithDesc(desc{layout,shared,optional configs...})
CloseElement
```

### 16.2 Data Flow

```text
Caller stack/local ElementDesc
         |
         v
OpenElementWithDescForContext
         |
         +--> open element frame node
         +--> apply layout
         +--> store/attach optional configs in deterministic order
         +--> return bool
```

## 17. Acceptance Criteria

This spec is considered implemented when:

1. CAPI v2 symbols compile and export correctly.
2. All in-repo callers use descriptor path for non-text opens.
3. Removed v1 symbols are absent from generated headers/ffi.
4. Bench and parity tools run on v2 surface.
5. Known non-related parity issues (e.g. existing text mismatch) remain isolated and explicit.

## 18. Open Questions (To Resolve Before Implementation Freeze)

1. Should `DESC_HAS_LAYOUT` be mandatory-hard-fail, or default-fit fallback? (current draft: fallback)
2. Should overflow convenience be represented directly in descriptor or remain wrapper-only? (current draft: wrapper-only)
3. Should text receive a parallel descriptor in v2.1 (`TextDesc`), or stay current shape? (current draft: stay current)

## 19. Change Log

- 2026-02-28: Initial hard-cut v2 draft authored.
