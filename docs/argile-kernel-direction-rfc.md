# Argile Kernel-First Direction RFC

Status: Proposed (directional)

Date: 2026-02-24

Audience: Argile maintainers, binding authors, backend authors, widget/toolkit authors

Supersedes:
- `argile/docs/design.md`
- `argile/docs/argile-multi-backend-portability-refactor-plan.md`

Implementation program:
- `argile/docs/argile-kernel-execution-program.md`

## Program Status

Active milestone:
- `M0` (Direction Reset and Tooling Visibility)

Recent progress:
- direction RFC and execution program published
- old direction docs removed
- official LuaJIT binding (`argile_lj`) now exposes `GetElementData` and debug mode toggles
- M1 overflow/scroll semantics supplement drafted (`argile/docs/overflow-scroll-semantics.md`)

Next focus:
- finish remaining M0 tasks in `argile-ui` (wrapper passthrough + demo debug overlay + docs)
- add/strengthen engine-side `GetElementData` regression coverage

## Why This RFC Exists

Argile has crossed a threshold:

- the core runtime is already strong enough to power real UI experiments
- the stable C API works as a real integration boundary
- bindings and backends are no longer hypothetical
- the current pain points are increasingly about ergonomics, observability, and layout expressiveness

This is the moment to stop optimizing for "parity with Clay" as the primary narrative and move toward a clearer identity:

Argile should be a deterministic, embeddable UI layout and interaction kernel for tool UIs, game UIs, and host-integrated runtimes, with excellent debugging and layered authoring APIs.

This RFC defines that direction and a concrete execution plan.

## Executive Summary

The next Argile direction is:

- keep the engine core small, deterministic, and backend-neutral
- treat the C API as a first-class product surface
- improve debuggability (layout inspection, overflow visibility, diagnostics)
- expand layout capabilities through extensible configs, not by overloading one `LayoutConfig`
- add practical higher-level primitives (scroll, flow/wrap, grid-lite) in a staged way
- preserve compatibility where possible and avoid ABI breakage unless justified

The most important shift is architectural:

- `argile` becomes the kernel
- `argile-ui` becomes the opinionated widget/layout convenience layer
- bindings expose both layers cleanly

## Strategic Positioning (New Narrative)

Argile is not trying to be:

- a browser CSS engine
- a React clone
- a retained-mode scene graph framework
- "just a Clay port"

Argile is trying to be:

- a predictable UI kernel with explicit state and deterministic layout
- a portable render-command emitter
- a stable ABI target for multiple languages/runtimes
- a strong foundation for toolkits (like `argile-ui`)

This makes Argile especially good for:

- in-engine tools
- editor panels and inspectors
- game HUDs and menus
- host-integrated scripting runtimes (LuaJIT, etc.)
- backend portability experiments

## What We Keep (Core Identity)

These are strengths and should remain central:

1. Data-oriented runtime and explicit frame lifecycle
2. Backend-neutral render command stream
3. Stable C API / generated FFI surfaces
4. Host-provided text measurement and rendering integration
5. Explicit IDs and deterministic interaction state
6. Headless tests and regression-focused development

## What Changes (Direction Shift)

### 1. Clay Parity Stops Being the Main Goal

Clay remains a useful inspiration and comparison point, but Argile should no longer optimize its roadmap around behavior parity narratives.

New priority order:

1. correctness and determinism
2. embeddability and ABI quality
3. debuggability and inspectability
4. practical layout capabilities for real tool UIs
5. convenience layers and polished widgets
6. parity with other libraries (only where useful)

### 2. Layout Stops Being a Single-Axis-Only Product

The current row/column axis layout is a solid primitive, but it cannot remain the only serious layout model for dashboards, inspectors, and dense admin/tool UIs.

We will keep row/column as the base primitive and add new container/item behaviors through extensible configs.

### 3. Observability Becomes a First-Class Feature

When layouts fail today, the output is visually broken but not easily introspectable from bindings and demos.

That is unacceptable for a kernel intended to be embedded by others.

Layout diagnostics and element inspection must be treated as core product capabilities.

## Pain Points Observed in Real Usage (Honest)

These were surfaced while fixing the LuaJIT Love2D widget demo:

### A. Too Much Manual Pixel Accounting

Simple responsive changes required manual subtraction of:

- container padding
- child gaps
- sibling widths
- wrap widths

This made it easy to create mistakes in demo code and hard to reason about failures.

This is partly normal for a low-level engine, but the ergonomics around it are currently too thin.

### B. Layout API Is Powerful but Narrowly Expressed

Current `LayoutConfig` is intentionally compact (sizing, padding, gap, alignment, direction), which is good, but:

- it does not model overflow behavior
- it does not model scroll behavior
- it does not model wrapping/flow behavior
- it does not model grid containers/items

As a result, higher-level users reimplement layout policy in application code.

### C. Wrapper Ergonomics Lag Behind Core Capability

The engine supports more than the widget-layer helpers expose. Common examples include:

- percent sizing ergonomics
- generic min/max sizing construction helpers
- debug inspection access (`GetElementData`)

Bindings need to expose the kernel well, not just a handpicked subset.

### D. Debugging Layout from Bindings Is Too Hard

The engine tracks element boxes and exposes element data, but the LuaJIT wrapper layers do not surface it today.

This made screenshot-driven debugging slower than necessary and encouraged guessing instead of inspection.

### E. Overflow and Scrolling Are Not a First-Class Authoring Experience

When content exceeds vertical space in a real UI panel, authors immediately need:

- clipping policy
- overflow visibility
- scroll state/input
- ergonomic panel abstractions

Without that, demos degrade poorly and app authors manually hide content.

## Product Architecture (Target)

Argile should be explicitly layered:

### Layer 1: `argile-core` (engine kernel)

Responsibilities:

- layout solving
- interaction state and hit testing
- render command generation
- context lifecycle
- debug/inspection data
- stable C ABI

Non-responsibilities:

- themed widgets
- opinionated components
- backend-specific rendering
- app-level responsive conventions

### Layer 2: `argile-ui` (toolkit + ergonomics)

Responsibilities:

- widgets and themes
- layout convenience APIs (panel, split, grid-lite wrappers)
- scroll containers
- responsive helpers
- common composition patterns for dashboards/forms

Non-responsibilities:

- replacing core layout solver
- duplicating engine FFI loaders in bindings

### Layer 3: Bindings (LuaJIT and future bindings)

Responsibilities:

- faithful core API exposure
- safe and ergonomic host-language wrappers
- low-friction access to diagnostics and element inspection
- interop patterns for host text measurement/rendering

### Layer 4: Backends (Love2D, SDL3, raylib, others)

Responsibilities:

- drawing render commands
- text metrics callback integration
- input translation
- optional debug overlays/inspectors

## Layout Evolution Plan

### Guiding Rule

Do not turn `LayoutConfig` into a dumping ground.

Instead, add layout features as explicit element configs/attachments where possible. This preserves clarity and reduces ABI churn risk.

### Current Baseline (Keep)

Row/column axis layout remains the foundational primitive:

- left-to-right
- top-to-bottom
- sizing (fit/grow/percent/fixed)
- padding
- gap
- child alignment

### Phase 1 Additions (High Leverage)

1. Overflow policy per axis
- `visible`
- `clip`
- `scroll`
- `auto` (optional later)

2. Scroll state support
- per-element scroll offset
- pointer wheel / drag support hooks (host-driven)
- scroll bounds derived from content vs viewport

3. Layout diagnostics
- overflow extents
- clipped content indication
- optional debug warnings in debug mode

4. Binding exposure of element inspection
- `GetElementData`
- debug mode toggles
- optional helper APIs to query `boundingBox` by string ID

### Phase 2 Additions (Practical Layout Power)

1. Flow / wrap layout (`row_wrap`)
- wrapping children across lines
- line gap support
- item alignment within line

2. Split helpers (widget layer first)
- horizontal/vertical split panels
- resizable split behavior in toolkit

3. Responsive convenience primitives in `argile-ui`
- width breakpoints
- stack/swap row->col helpers
- safe wrap-width helpers for text

### Phase 3 Additions (Engine-Level Grid Lite)

Add a minimal grid that solves real tool UI needs without imitating CSS Grid complexity.

#### Grid Lite Goals

- deterministic
- embeddable
- easy to bind
- simple solver
- sufficient for dashboards and inspectors

#### Grid Lite Non-Goals (initially)

- CSS track sizing parity
- named areas
- `minmax()` grammar
- `fr` semantics
- full implicit grid behavior parity with browsers

## Proposed Grid Lite API Shape (Engine)

Use element configs, not `LayoutConfig` mutation.

### New Container Config

`CONFIG_GRID_CONTAINER`

Proposed fields (illustrative):

- `columns : uint16`
- `columnGap : uint16`
- `rowGap : uint16`
- `autoFlow : uint8` (start with row flow only)
- `paddingBehavior :` reuse container `LayoutConfig.padding` (no duplication)

Future-compatible fields (can be reserved or added later):

- column sizing mode
- row sizing mode
- dense placement flag

### New Item Config

`CONFIG_GRID_ITEM`

Proposed fields:

- `col : int16` (`-1` = auto)
- `row : int16` (`-1` = auto)
- `colSpan : uint16` (default `1`)
- `rowSpan : uint16` (default `1`)

Optional future fields:

- per-item alignment overrides
- clipping/overflow hints

### Placement Model (Initial)

1. Container declares fixed `columns`
2. Children are processed in declaration order
3. If item has explicit `(row, col)`, place there if valid
4. Else place in next available cells (row-major)
5. Apply spans
6. Compute row heights from tallest participating items
7. Position children and generate bounding boxes

This gives immediate value while staying deterministic and implementation-friendly.

## ABI and Compatibility Strategy

This is critical.

### Rule 1: Avoid Breaking `struct LayoutConfig`

`LayoutConfig` is already exposed in generated headers/FFI and used by bindings. Changing its shape is high-risk.

Preferred strategy:

- add new config structs and attach APIs
- extend enum values carefully
- add new functions rather than mutate semantics of old ones

### Rule 2: Version the API Intentionally

Keep `ARGILE_API_VERSION` meaningful.

When adding new config types/functions:

- increment API version when binary compatibility changes
- preserve old paths when behavior can remain valid
- provide compatibility docs and migration notes

### Rule 3: Bindings Must Fail Clearly on Mismatch

Bindings should check API version and feature availability where practical.

Examples:

- `has_symbol` checks (already used in some wrappers)
- feature probes for new config attach functions

## Diagnostics and Inspector Roadmap

This is one of the strongest opportunities for differentiation.

### Engine-Level Diagnostics (Debug Mode)

Add or standardize:

- overflow detection per element
- clipped content extents
- warnings for impossible/over-constrained conditions
- layout pass counters and timings (optional debug stats)

### Binding-Level Inspector Helpers

Expose in official bindings:

- `get_element_data(id_name)` -> `{ found, x, y, width, height }`
- debug mode enable/disable
- optional `dump_layout_boxes()` helpers (binding-side convenience)

### Backend Debug Overlay (Optional but Valuable)

Reference backends can provide:

- box outlines by element ID
- clip region visualization
- hover target overlay
- scroll viewport/content extents

This should be a backend helper, not core engine logic.

## Binding Direction (LuaJIT First)

The LuaJIT path is currently the fastest integration feedback loop and should be treated as the proving ground for engine ergonomics.

### Short-Term Binding Improvements

1. Expose `GetElementData` in `argile_lj`
2. Expose debug mode toggles (`SetDebugModeEnabled`, `IsDebugModeEnabled`)
3. Add sizing helpers:
- `mk_sizing_percent(w_percent, h_percent)`
- generic axis builder helpers
4. Add higher-level helper wrappers in `argile_ui_lj`:
- `scroll_panel`
- `split`
- `row_wrap` or `grid_lite` (toolkit-level first)

### Binding Policy

Bindings should layer on top of official engine bindings where possible (already the intended policy for `argile-ui` LuaJIT wrappers).

Do not duplicate raw FFI loaders across toolkit layers.

## Backend Direction

Backends remain thin adapters.

Priority is consistency and debuggability, not visual identity parity.

### Backend Expectations

- render-command fidelity
- correct clipping/scissoring
- text measure callback correctness
- input state translation correctness
- debug overlay support (optional, recommended)

### Backend Validation

Add small conformance scenes focused on:

- clipping
- nested overflow/scroll
- text wrap
- paint ops
- hover/active/focus state behavior
- grid-lite placement (once implemented)

## Documentation Direction

Argile docs should separate:

1. product direction / RFCs
2. stable API references
3. language specs
4. backend integration guides
5. binding guides

This RFC replaces older documents that assumed:

- parity-driven framing as the primary goal
- a narrower backend-portability refactor as the central roadmap

Those topics still matter, but they are now subordinate to the kernel-first direction.

## Proposed Roadmap (Milestones)

### Milestone 0: Direction Reset and Tooling Visibility

Goals:

- publish this RFC
- expose element inspection + debug toggles in bindings
- add minimal layout debug helpers in reference demos

Success criteria:

- maintainers can inspect computed element boxes from LuaJIT
- demo layout debugging no longer depends on screenshots alone

### Milestone 1: Overflow and Scroll Foundations

Goals:

- define overflow/scroll config model
- implement clipping/scroll viewport semantics in core
- provide widget-layer `scroll_panel`

Success criteria:

- dense panels can remain usable on small windows
- no ad hoc demo-only content hiding required for basic panel overflow

### Milestone 2: Ergonomics Pass (Bindings + Toolkit)

Goals:

- percent sizing and min/max helper APIs in bindings
- widget-level split and responsive helpers
- improved text-wrap ergonomics in toolkit helpers

Success criteria:

- common dashboard layouts need less manual width math
- demos become simpler, not more complex

### Milestone 3: Flow / Wrap Layout

Goals:

- implement row-wrap/flow container (engine or toolkit first based on findings)
- add tests and demo coverage

Success criteria:

- card galleries / tag clouds / wrap rows work without manual row splitting

### Milestone 4: Grid Lite (Engine-Level)

Goals:

- `CONFIG_GRID_CONTAINER`
- `CONFIG_GRID_ITEM`
- deterministic placement and sizing
- C API + binding support + tests + demo scene

Success criteria:

- practical dashboards and inspectors can be authored without manual column math
- layout behavior is inspectable and testable

## Testing and Validation Strategy

Every major layout feature should ship with:

1. core unit/regression tests
2. render-command conformance scenes
3. binding smoke tests (LuaJIT at minimum)
4. at least one backend demo exercising the feature
5. layout inspection assertions where possible (element box checks)

For new layout primitives (scroll, flow, grid-lite), tests should cover:

- nested containers
- clipping interactions
- fixed/fit/grow/percent sizing combinations
- text elements
- paint/border/shared config interactions
- pointer hit-testing with clipping

## Risks and Mitigations

### Risk: Feature Creep Toward CSS Clone Complexity

Mitigation:

- explicitly scope "lite" features
- solve tool UI needs first
- avoid spec parity ambitions

### Risk: ABI Churn Breaking Bindings

Mitigation:

- prefer additive config types/functions
- avoid `LayoutConfig` shape changes
- keep version checks and feature probes

### Risk: Debug Features Slow Release Builds

Mitigation:

- gate diagnostics behind debug mode
- keep expensive checks optional

### Risk: Toolkit Diverges from Core Semantics

Mitigation:

- use toolkit helpers as proving ground
- promote features to core only after patterns stabilize

## Immediate Action Items (Next Steps)

1. Expose `GetElementData` and debug mode toggles in official LuaJIT bindings
2. Add percent sizing helpers and generic sizing builders in binding wrappers
3. Add `scroll_panel` to `argile-ui` widget layer
4. Draft `Grid Lite` config structs and attachment APIs (C API + Terra)
5. Create a grid/overflow conformance demo scene
6. Add a debug overlay helper for at least one backend (Love2D first is fine)

## Final Statement

Argile should not become "more complicated CSS."

Argile should become a better kernel:

- deterministic
- inspectable
- portable
- binding-friendly
- strong enough to support opinionated toolkits

If this RFC is followed, Argile will move from "promising layout engine inspired by Clay" to "serious embeddable UI kernel with a clear product identity."
