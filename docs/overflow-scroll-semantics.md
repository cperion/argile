# Argile Overflow and Scroll Semantics (M1 Supplement)

Status: Draft proposal for M1 implementation

Date: 2026-02-24

Related:
- `docs/argile-kernel-direction-rfc.md`
- `docs/argile-kernel-execution-program.md` (K1-000)

## Purpose

This document defines the behavior contract for overflow and scroll support in Argile.

It is intended to remove ambiguity before engine implementation work starts.

The goal is not a CSS clone. The goal is deterministic, testable container overflow behavior suitable for tool UIs and game UIs.

## Design Goals

1. Explicit per-axis overflow behavior
2. Deterministic clipping and hit testing
3. Additive API design (avoid `LayoutConfig` ABI churn)
4. Backend-neutral semantics
5. Simple enough to implement and bind in M1

## Non-Goals (M1)

1. CSS parity (`overflow: auto` heuristics, scrollbars, browser behavior parity)
2. Momentum/kinetic scrolling
3. Platform-native scrollbar rendering
4. Virtualized lists
5. Nested scrolling gesture arbitration beyond simple deterministic rules

## Terms

### Container viewport

The visible content area of a container after layout, padding, and clipping policy are applied.

This is the rectangular region that may clip children.

### Content extent

The total laid-out size of the container's children before clipping/scroll offset is applied.

### Overflow amount

The positive difference between content extent and viewport extent along an axis.

### Scroll offset

The content translation applied along an axis for a scrollable container.

Convention (proposed):
- positive `scrollY` moves content upward (reveals lower content)
- positive `scrollX` moves content leftward (reveals content to the right)

Internally, this means child rendering/hit-testing uses a negative transform by the scroll offset.

## Proposed Feature Surface (M1)

Use additive element configs (container-level), not `LayoutConfig` changes.

### Overflow Modes (per axis)

Proposed enum:

- `OVERFLOW_VISIBLE`
- `OVERFLOW_CLIP`
- `OVERFLOW_SCROLL`
- `OVERFLOW_AUTO` (defer if implementation complexity is high)

M1 recommendation:
- ship `VISIBLE`, `CLIP`, `SCROLL`
- defer `AUTO` unless it is near-zero cost

### Container Config (proposed shape)

One additive container config is sufficient for M1:

- `OverflowConfig`
  - `xMode`
  - `yMode`

Optional separate config if needed by implementation:

- `ScrollConfig`
  - behavior flags (future)
  - initial offsets (optional)

M1 recommendation:
- start with `OverflowConfig`
- manage scroll offsets through runtime state APIs instead of a static config field

## Scroll Ownership Model (M1 Recommendation)

Use a hybrid model:

1. Engine stores and clamps scroll offsets (runtime state)
2. Host/application supplies input deltas (wheel, drag, keyboard) and calls setter APIs
3. Engine applies offsets to rendering, clipping, and hit testing

Why:

- deterministic and inspectable in engine state
- backend-neutral (no direct wheel semantics in core)
- easy to bind
- avoids embedding gesture policy into the engine too early

## Container Behavior by Overflow Mode

Semantics are per-axis and combined independently.

### `VISIBLE`

- No clipping on that axis due to overflow policy
- Children can render outside the viewport on that axis
- Hit testing is not clipped by overflow policy on that axis (but may still be clipped by parent clip regions)
- Scroll offset for that axis is ignored and treated as `0`

### `CLIP`

- Content is clipped to viewport on that axis
- No scrolling is applied on that axis
- Hit testing is clipped to visible region on that axis
- Scroll offset for that axis is ignored and treated as `0`

### `SCROLL`

- Content is clipped to viewport on that axis
- Scroll offset is applied and clamped to valid bounds
- Hit testing uses scrolled positions and clipping
- If content extent <= viewport extent, overflow is zero and scroll offset clamps to `0`

### `AUTO` (if later added)

Proposed future semantics:
- behaves as `VISIBLE` or `CLIP`/`SCROLL` depending on overflow presence
- exact behavior should be specified later and should not block M1

## Scroll Offset Semantics

### Coordinate space

Scroll offsets are stored in container-local content coordinates.

They do not modify layout tree structure. They modify child render/hit-test positions relative to the container viewport.

### Clamping

For a scrollable axis:

- `maxScroll = max(0, contentExtent - viewportExtent)`
- `scrollOffset = clamp(scrollOffset, 0, maxScroll)`

If overflow mode is not `SCROLL`, engine should clamp effective offset to `0` on that axis.

### Layout timing

Scroll offset clamping must occur after content extents and viewport extents are known for the frame.

Implications:

- host may set an offset before layout/finalize
- engine may clamp it during finalize
- host can query final clamped values after finalize (recommended API)

## Clipping Semantics

### Clip region generation

For axes in `CLIP` or `SCROLL`, the container contributes a clip/scissor region aligned to its viewport.

Clip regions compose through intersection with parent clip regions.

### Nested clipping

Nested containers intersect clip regions in declaration/layout order.

Backends should receive render commands that make clip nesting explicit (existing scissor start/end command pattern remains valid).

### Floating children

M1 rule:
- floating children remain subject to the container's clip policy if they are logically clipped to that container
- existing floating/clip config semantics take precedence where already defined

If current engine semantics are more nuanced, the implementation should document the exact interaction and keep it deterministic.

## Hit Testing and Interaction Semantics

### Pointer visibility rule

A child element cannot receive hover/active interaction if the pointer lies outside the effective clipped visible region for all active clip ancestors.

This applies to:
- `PointerOver`
- active press/hold state transitions
- click release detection

### Scrolled content rule

Hit testing uses the same effective transformed positions as rendering:

- content offset by scroll state
- clipped by viewport and ancestor clips

No duplicate coordinate system should exist between render and hit-test paths.

### Offscreen content

Off-viewport content in a scrolled container must not receive hover/click unless the visible clipped portion under the pointer intersects the element.

## Render Command and Backend Contract

Overflow/scroll semantics remain backend-neutral. Backends are responsible for faithful execution of render commands.

### Core responsibilities

- compute viewport clip regions
- apply scroll offsets to child positions
- emit scissor/clip commands consistently
- preserve correct command ordering

### Backend responsibilities

- correctly intersect and apply scissor regions
- render with no extra layout policy
- avoid backend-specific clipping behavior leaks

### Debug implication

Backend debug overlays should be able to display:
- container viewport rect
- content extents (optional)
- active clip rect
- scroll offset

This is backend tooling, not a core requirement for M1.

## Inspection and Diagnostics Contract

### Element bounding boxes (`GetElementData`)

M1 recommendation:
- `GetElementData` returns the final on-screen bounding box used for rendering/hit testing in the current frame

This keeps debugging straightforward.

If the engine currently stores pre-scroll logical boxes for some elements, implementation should either:
- normalize to final visual boxes, or
- add a separate debug query for logical vs visual boxes

Do not leave this ambiguous.

### Overflow diagnostics (debug mode)

M1 should expose at least one way to inspect overflow:

Options:
1. extend `ElementData` (ABI risk)
2. add a separate debug query API (preferred if additive)
3. debug-mode warning logs only (minimum viable)

Recommendation:
- additive debug query API if practical
- otherwise debug warnings in M1 and richer inspection in M2

### Debug warnings (recommended)

Emit debug-mode warnings for:

- scroll offset set on non-scroll axis (informational)
- invalid overflow config values
- impossible clip/scroll combinations (if any)
- internal layout inconsistencies

Warnings must not change release semantics.

## Proposed Runtime APIs (Illustrative, M1)

Final names may differ. This section defines capability, not exact symbol spelling.

### Config attachment

- `AttachOverflowConfig(...)`
- `AttachOverflowConfigForContext(...)`

### Scroll state (if engine-managed as recommended)

- `SetElementScrollOffset(id, x, y)` or axis-specific setters
- `GetElementScrollOffset(id)` / `GetElementScrollInfo(id)`

Recommended query shape (conceptual):
- current clamped offset
- max scroll extents
- viewport extents
- content extents (optional in M1)

If full scroll info is too much for M1, at least support:
- set offset
- get clamped offset

## Backward Compatibility and ABI Strategy

### Hard rule

Do not mutate `LayoutConfig` for M1 overflow/scroll.

Use additive configs and functions so existing bindings and demos remain valid.

### API versioning

If new exported types/functions are added:
- update API versioning as required by current policy
- document added symbols in release notes/docs

## Test Matrix (Required for M1)

M1 should ship with tests covering:

1. Visible overflow (no clip)
2. Clip-only overflow
3. Scroll-only per axis (x and y)
4. Nested clip + scroll containers
5. Hit testing on clipped edges
6. Hit testing on scrolled content
7. Scroll offset clamping when content shrinks/grows between frames
8. Render command scissor ordering for nested overflow containers

Recommended additions:

- a conformance scene for nested clipping and scrolling
- backend smoke validation on Love2D plus one native backend

## Deferred Topics (Explicitly)

These should not block M1:

- visual scrollbars as core engine primitives
- scroll snapping
- momentum/inertia
- keyboard focus-driven auto-scroll behavior
- nested scroll propagation heuristics
- accessibility semantics for scroll containers

## Open Questions (Resolve Before Implementation Starts)

1. Should `OVERFLOW_AUTO` ship in M1 or defer?
2. Do we expose scroll extents in `ElementData` or a separate debug query API?
3. Are scroll offsets represented as floats or integer pixels in public API?
4. Do we want one combined overflow+scroll config or separate configs?
5. What is the warning/reporting channel for debug-mode diagnostics?

## Recommended M1 Decisions (to unblock execution)

If the team wants to move immediately, use these defaults:

1. Ship `VISIBLE`, `CLIP`, `SCROLL`; defer `AUTO`
2. Use additive `OverflowConfig` + runtime scroll state APIs
3. Engine stores/clamps offsets; host supplies deltas and calls setters
4. `GetElementData` should represent final visual boxes
5. Add debug warnings now; richer overflow inspection can follow if needed

These defaults maximize progress while preserving the kernel-first design constraints.
