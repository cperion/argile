# Argile Kernel Direction Execution Program

Status: Draft execution plan

Date: 2026-02-24

Companion document:
- `docs/argile-kernel-direction-rfc.md`

## Purpose

This document turns the kernel-first direction RFC into an implementation program:

- milestone-by-milestone execution
- ticket-level breakdowns
- file touchpoints
- dependency ordering
- acceptance criteria
- test requirements

This is the working plan for maintainers. The RFC states the direction. This document states how to ship it.

## Scope and Repositories

Argile direction work spans two codebases in practice:

1. `argile/` submodule (engine, C API, official bindings, backends, tests)
2. `argile-ui` root repo (widget toolkit, widget-layer LuaJIT wrappers, demos)

This document is stored in `argile/docs/` because the engine and C API sequencing are the critical path, but it explicitly calls out `argile-ui` tasks where they are required for proving ergonomics.

## Program Goals (Ordered)

1. Improve observability and debuggability first
2. Add overflow/scroll foundations
3. Improve binding and toolkit ergonomics
4. Add flow/wrap layout
5. Add engine-level Grid Lite

This sequence is deliberate. Grid without diagnostics and overflow would produce more powerful failures, not a better product.

## Delivery Principles

### 1. Additive over mutative API changes

Prefer adding config types and new functions over mutating the shape/semantics of existing structs like `LayoutConfig`.

### 2. Prove in bindings and demos early

Every engine feature should be exercised through:

- LuaJIT binding
- at least one backend demo
- element-box assertions where practical

### 3. Tests are part of the feature, not a later step

No milestone is complete without:

- core tests
- binding smoke path
- backend conformance/demo proof

### 4. Document the behavior contract as code ships

Update docs incrementally (API surfaces, feature semantics, caveats) to prevent design drift.

## Critical Path Overview

The program is organized into milestones M0-M4.

- M0 (visibility): unlocks faster iteration on all later milestones
- M1 (overflow/scroll): foundational for usability and later layout primitives
- M2 (ergonomics): reduces integration friction and validates API shape
- M3 (flow/wrap): intermediate layout primitive and solver extension practice
- M4 (Grid Lite): major layout feature built on prior diagnostics and overflow tooling

Parallelizable tracks:

- backend debug overlay work can run in parallel with binding exposure work
- toolkit helpers can start in `argile-ui` before engine features are finalized
- conformance scene authoring can begin early and be filled in as features land

## Workstreams

### WS-A: Core Engine + C API (`argile/`)

Primary files (expected frequent touchpoints):
- `src/config.t`
- `src/context.t`
- `src/layout.t`
- `src/init.t`
- `src/capi.t`
- `tools/build_argile.t`
- generated outputs in `build/` (for local verification)

### WS-B: Official LuaJIT Engine Binding (`argile/bindings/luajit/argile_lj`)

Primary files:
- `bindings/luajit/argile_lj/runtime.lua`
- `bindings/luajit/argile_lj/init.lua`
- `bindings/luajit/README.md`

### WS-C: Backends + Reference Demos (`argile/backends/*`)

Primary files:
- `backends/love2d/renderer.lua`
- `backends/love2d/demo_ffi/main.lua`
- `backends/sdl3/*`
- `backends/raylib/*`

### WS-D: Toolkit + Widget Ergonomics (`argile-ui` root repo)

Primary files:
- `hosts/luajit/argile_ui_lj/runtime.lua`
- `hosts/luajit/argile_ui_lj/widgets.lua`
- `platforms/love2d/luajit/demo_widgets/main.lua`
- `widgets/components/*`

### WS-E: Tests + Conformance

Primary files (likely):
- `tests/test_*.t` in `argile/`
- backend-specific demos/scenes
- new conformance scenes in `argile/examples/scenes/`

## Milestone Breakdown

## M0: Direction Reset and Tooling Visibility

Objective:

- make debugging layout issues fast and inspectable from bindings/demos
- establish documentation and roadmap alignment

Exit criteria:

- official LuaJIT binding exposes element box inspection and debug toggles
- at least one demo can visually render debug boxes or query boxes by ID
- docs point to RFC + execution program

### M0.1 Documentation Baseline (completed in part)

Status:
- RFC published
- outdated direction docs removed

Remaining tasks:

#### K0-001: Link execution program from RFC and README

Scope:
- add explicit link to this document in `README.md` and RFC

Files:
- `README.md`
- `docs/argile-kernel-direction-rfc.md`

Acceptance:
- maintainers can discover both direction docs from repo entry points

#### K0-002: Add "Program Status" section to RFC

Scope:
- lightweight status board in RFC referencing milestone progress and current active focus

Files:
- `docs/argile-kernel-direction-rfc.md`

Acceptance:
- RFC remains authoritative for direction while deferring implementation details to this plan

### M0.2 Engine Inspection Exposure in C API (confirm and document)

Argile already exports `GetElementData` and debug mode toggles. The milestone task is to normalize usage, document semantics, and ensure bindings expose them.

#### K0-010: Document `GetElementData` behavior contract

Scope:
- define when `found` is valid
- specify frame timing expectations (post-finalize)
- specify behavior for missing IDs and invalid bounding boxes

Files:
- `docs/` (new or existing C API doc)
- optionally `src/capi.t` comments if style permits

Acceptance:
- binding authors know exactly when/why element data queries succeed

#### K0-011: Add simple engine-side test for `GetElementData`

Scope:
- create/extend test to assert known element box exists after finalize

Likely files:
- `tests/test_*.t` (new regression file preferred)

Acceptance:
- test validates `found=true` and bounding box fields are non-zero/expected within tolerance

### M0.3 LuaJIT Binding Exposure (official `argile_lj`)

#### K0-020: Expose `GetElementData` wrapper in `argile_lj`

Scope:
- add helper on runtime/client/session wrapper to query element data by element ID
- add convenience overload by string ID (optional but recommended)

Files:
- `bindings/luajit/argile_lj/runtime.lua`
- `bindings/luajit/argile_lj/init.lua` (if export surface needs wiring)

Behavior proposal:
- `ctx:get_element_data(id)` returning a Lua table
- optional `ctx:get_element_data_by_name(name)` if ID helpers exist in wrapper

Acceptance:
- LuaJIT demo code can query element boxes without raw FFI field walking

Tests:
- LuaJIT smoke example in binding docs or tiny self-test script

#### K0-021: Expose debug mode toggles in `argile_lj`

Scope:
- wrap `SetDebugModeEnabled` / `IsDebugModeEnabled`

Files:
- `bindings/luajit/argile_lj/runtime.lua`

Acceptance:
- toggling debug mode works without raw `lib.*` access

#### K0-022: Update LuaJIT binding docs with inspection examples

Files:
- `bindings/luajit/README.md`

Acceptance:
- docs contain a minimal example querying an element box after finalize

### M0.4 Widget-Layer and Demo Debug Tooling (`argile-ui`)

These tasks happen in the root `argile-ui` repo and validate the new debugging loop.

#### K0-030: Expose engine inspection helpers in `argile_ui_lj` session wrapper

Scope:
- mirror/pass through `GetElementData` helpers from engine binding layer
- avoid duplicating raw FFI logic

Files (argile-ui root):
- `hosts/luajit/argile_ui_lj/runtime.lua`

Acceptance:
- widget demos can inspect boxes via high-level session object

#### K0-031: Add demo debug overlay toggle in Love2D widget demo

Scope:
- draw outlines for selected/hovered key elements or all panels
- show IDs and bounding boxes for debugging

Files (argile-ui root):
- `platforms/love2d/luajit/demo_widgets/main.lua`

Acceptance:
- key press toggles overlay
- overlay draws at least container/panel boxes using queried element data

#### K0-032: Add "layout debug checklist" section to demo README

Files (argile-ui root):
- `platforms/love2d/luajit/demo_widgets/README.md`

Acceptance:
- contributors know how to inspect layout issues before guessing

## M1: Overflow and Scroll Foundations

Objective:

- make dense UIs usable in constrained spaces
- define overflow semantics explicitly
- establish scroll as a first-class concept

Exit criteria:

- engine supports overflow/clip/scroll semantics for containers
- bindings can set/query scroll-related state as needed
- at least one reference demo uses a real scrollable panel
- pointer hit testing respects clipping/scroll offsets

### M1 Design Decision Package (must land before coding)

#### K1-000: Overflow/scroll semantics RFC supplement

Scope:
- define per-axis overflow policies
- define interaction model ownership (engine vs host) for wheel and drag scrolling
- define clipping/render command implications
- define hit-testing semantics under scroll offsets

Files:
- `docs/` (new supplement doc, suggested: `docs/overflow-scroll-semantics.md`)

Acceptance:
- maintainers can implement without semantic ambiguity

Required decisions:
- whether scroll is represented as element config + runtime state
- whether scroll offset is author-supplied, engine-managed, or hybrid
- whether `auto` overflow mode is in scope for M1 or deferred

### M1 Core Data Model and C API

#### K1-010: Add overflow/scroll config structs and enum values

Scope:
- add additive config types and enums
- avoid changing `LayoutConfig` shape

Likely files:
- `src/config.t`
- `src/init.t`
- `src/capi.t`

Proposed additions (illustrative):
- `OverflowMode` enum (`VISIBLE`, `CLIP`, `SCROLL`, maybe `AUTO`)
- `OverflowConfig` (x/y mode)
- `ScrollConfig` (initial policy / behavior flags if needed)
- `CONFIG_OVERFLOW`
- `CONFIG_SCROLL` (or a single combined config if simpler)

Acceptance:
- config types are defined and exported through `ui.capi`
- generated headers/FFI include new enums/structs

#### K1-011: Add attach functions for overflow/scroll configs

Scope:
- C API wrappers and core attach path wiring

Likely files:
- `src/context.t`
- `src/capi.t`

Acceptance:
- additive `AttachOverflowConfig*` / `AttachScrollConfig*` (names TBD) available

#### K1-012: Add runtime getters/setters for scroll state (if engine-managed)

Scope:
- set/get scroll offsets by element ID
- bounded/clamped behavior defined

Likely files:
- `src/context.t`
- `src/capi.t`

Acceptance:
- host can drive or inspect scroll offsets through the stable API

Note:
- If M1 adopts host-managed offsets only, this ticket becomes "element config + clip offset wiring" and state APIs may be reduced.

### M1 Layout Solver + Render Pipeline Integration

#### K1-020: Compute content extents vs viewport extents for overflow containers

Scope:
- record content size and visible viewport size for containers
- derive overflow on x/y axes

Likely files:
- `src/context.t`
- `src/layout.t` (if layout helpers are split there)

Acceptance:
- engine can determine if/where overflow occurs without backend help

#### K1-021: Apply clip regions for overflow clip/scroll containers

Scope:
- clip command generation and nesting behavior
- interaction with existing clip config/floating content

Likely files:
- `src/context.t`

Acceptance:
- nested clipped containers generate correct scissor command sequences

Tests:
- nested clip container render-command order checks

#### K1-022: Apply child offset transforms for scroll containers

Scope:
- offset child layout/render positions by scroll offset
- ensure element bounding boxes reflect final on-screen positions consistently

Likely files:
- `src/context.t`

Acceptance:
- scrolled content renders and hit-tests at the expected positions

#### K1-023: Hit-testing and pointer-over behavior with clipping and scroll

Scope:
- pointer queries respect clipped visibility
- off-viewport content does not receive hover/active

Likely files:
- `src/context.t` hit testing path

Acceptance:
- interactions only apply to visible scrolled/clipped portions

### M1 Diagnostics and Introspection

#### K1-030: Expose overflow extents in element data or debug-only API

Scope:
- optional extension to `ElementData` or separate debug query API

Decision:
- avoid mutating `ElementData` if ABI risk is high; use additive debug API if needed

Acceptance:
- maintainers can inspect overflow amount for debugging

#### K1-031: Debug warnings for over-constrained/overflowing containers (debug mode)

Scope:
- optional warnings gated by debug mode

Acceptance:
- debug builds can surface useful diagnostics without breaking release behavior

### M1 Official LuaJIT Binding and Backend Integration

#### K1-040: Expose overflow/scroll attach APIs in `argile_lj`

Files:
- `bindings/luajit/argile_lj/runtime.lua`

Acceptance:
- LuaJIT host code can declare overflow/scroll behavior without raw FFI

#### K1-041: Love2D demo integration for scroll panel (engine demo)

Files:
- `backends/love2d/demo_ffi/main.lua`
- optionally `backends/love2d/renderer.lua` (if scissor issues are found)

Acceptance:
- demo contains a real scrollable area
- scissor clipping is visually correct

#### K1-042: Backend conformance scene for clipping/scroll

Scope:
- deterministic scene covering nested clipping and scroll offsets

Likely files:
- `examples/scenes/*`
- backend demos that invoke the scene

Acceptance:
- same semantic results across at least Love2D and one native backend

### M1 `argile-ui` Toolkit Adoption (root repo)

#### K1-050: Add widget-level `scroll_panel` helper

Files (argile-ui root):
- `hosts/luajit/argile_ui_lj/widgets.lua`

Acceptance:
- toolkit users can create scrollable panels without manual clip wiring

#### K1-051: Migrate Love2D widget demo to `scroll_panel` where needed

Files (argile-ui root):
- `platforms/love2d/luajit/demo_widgets/main.lua`

Acceptance:
- small-height windows remain usable without hiding large UI sections

## M2: Ergonomics Pass (Bindings + Toolkit)

Objective:

- reduce manual layout math in day-to-day authoring
- expose more core capability safely through wrappers

Exit criteria:

- percent sizing and generic sizing helpers exist in bindings
- widget layer has convenience primitives that reduce width bookkeeping
- demos become simpler or at least more declarative

### M2 Core/Binding API Surface Improvements

#### K2-010: Add generic sizing helper constructors in `argile_lj`

Scope:
- `mk_sizing_percent`
- optional axis-level builder (`mk_sizing_axis`)
- optional generic `mk_sizing(opts)` wrapper

Files:
- `bindings/luajit/argile_lj/runtime.lua`

Acceptance:
- percent/min/max sizing no longer requires raw struct construction in user code

#### K2-011: Expose convenience wrappers for element box query by name

Scope:
- string ID lookup + `GetElementData` in one call

Files:
- `bindings/luajit/argile_lj/runtime.lua`
- `hosts/luajit/argile_ui_lj/runtime.lua` (forwarder)

Acceptance:
- demo/debug code avoids repeated ID conversion boilerplate

#### K2-012: Add examples to binding docs for percent sizing and inspection

Files:
- `bindings/luajit/README.md`
- optionally `docs/luajit-binding-layering.md`

Acceptance:
- documented path for responsive sizing and layout debugging

### M2 Toolkit Layout Convenience (`argile-ui`)

#### K2-020: Add split helpers (`h_split`, `v_split` or single `split`)

Scope:
- common two-pane layouts without manual width arithmetic

Files (argile-ui root):
- `hosts/luajit/argile_ui_lj/widgets.lua`

Acceptance:
- demo panes can be authored via split helper instead of custom width math

#### K2-021: Add responsive stack helper

Scope:
- helper that switches row/col based on width threshold

Files (argile-ui root):
- `hosts/luajit/argile_ui_lj/widgets.lua`

Acceptance:
- common row->col fallback logic is centralized

#### K2-022: Text wrap ergonomics helper

Scope:
- reduce manual `wrap_width = panel_w - padding - ...` repetition
- possible helper on `label()`/`panel()` for "fill-width wrapped text"

Files (argile-ui root):
- `hosts/luajit/argile_ui_lj/widgets.lua`

Acceptance:
- widget demos visibly reduce repeated wrap-width arithmetic

#### K2-023: Refactor widget demo to use new helpers

Files (argile-ui root):
- `platforms/love2d/luajit/demo_widgets/main.lua`

Acceptance:
- demo code becomes simpler and more declarative than current patched version

### M2 Engine Diagnostics Quality Pass

#### K2-030: Add stable debug overlay helper example in Love backend

Scope:
- reusable helper in backend code or demo utility

Files:
- `backends/love2d/renderer.lua` or `backends/love2d/demo_ffi/main.lua`

Acceptance:
- maintainers can inspect boxes/clips quickly during future feature work

#### K2-031: Document layout debugging workflow

Files:
- `docs/ai-guide.md` or new maintainer-focused debug doc

Acceptance:
- reproducible workflow for diagnosing clipping/overflow/hit-test issues

## M3: Flow / Wrap Layout

Objective:

- provide a practical layout primitive for wrapping rows of items without full grid complexity

Exit criteria:

- flow/wrap layout available (engine or officially blessed toolkit-level implementation)
- tests cover wrapping, clipping, and sizing interactions
- at least one demo scene uses it for real content

### M3 Design Decision Package

#### K3-000: Decide engine-level vs toolkit-level first implementation

Options:
- engine first (better fidelity, more work now)
- toolkit first (faster proof, may expose solver limitations)

Recommendation:
- prototype toolkit behavior if possible, but implement engine support if wrapping semantics require solver-level knowledge (likely)

Files:
- `docs/` design note

Acceptance:
- chosen path and semantics documented before implementation

#### K3-001: Flow layout semantics spec

Define:
- line breaking rules
- line gap and item gap
- fit/grow/fixed sizing interactions
- cross-axis alignment
- behavior under clipping and scroll

Acceptance:
- implementation can be tested against written expectations

### M3 Engine Implementation (if engine-level)

#### K3-010: Add flow/wrap container config type(s)

Scope:
- additive config enum + struct(s)

Likely files:
- `src/config.t`
- `src/init.t`
- `src/capi.t`

Acceptance:
- C API exposes flow/wrap config attach path

#### K3-011: Flow line-packing algorithm in layout solver

Scope:
- row wrapping into multiple lines
- line metrics accumulation
- child positioning

Likely files:
- `src/context.t`
- `src/layout.t`

Acceptance:
- deterministic wrapping based on available width and child sizes

#### K3-012: Flow render/hit-test correctness under clipping/scroll

Scope:
- ensure no regressions from M1

Acceptance:
- wrapped items clip and interact correctly in overflow containers

### M3 Toolkit and Demo Adoption

#### K3-020: Add `row_wrap` helper in `argile-ui`

Files (argile-ui root):
- `hosts/luajit/argile_ui_lj/widgets.lua`

Acceptance:
- toolkit exposes wrap container ergonomically

#### K3-021: Convert one demo section to wrap layout

Candidate uses:
- badge rows
- stat cards
- action tiles

Files:
- `platforms/love2d/luajit/demo_widgets/main.lua` (argile-ui root)
- optionally `backends/love2d/demo_ffi/main.lua` (engine demo)

Acceptance:
- demo showcases wrap behavior at multiple widths

### M3 Tests and Conformance

#### K3-030: Add flow-wrap regression tests

Coverage:
- line breaks
- child gap/line gap
- fixed/grow interactions
- clipped container

Files:
- `tests/test_*.t`

Acceptance:
- deterministic expected boxes for known scene

#### K3-031: Add conformance scene for wrap layout

Files:
- `examples/scenes/*`

Acceptance:
- backends render semantically equivalent wrap placement

## M4: Grid Lite (Engine-Level)

Objective:

- implement a minimal, practical grid for dashboards and inspectors

Exit criteria:

- grid container/item configs shipped in C API
- solver places and sizes items deterministically with spans
- bindings and demos can author grid layouts
- tests cover placement, spans, clipping, and interaction semantics

### M4 Design Package (must be explicit before code)

#### K4-000: Grid Lite semantics spec

Must define:
- placement order
- explicit vs auto placement precedence
- invalid placement behavior (clamp/error/debug warning)
- span collision behavior
- row height computation rules
- interaction with overflow/scroll/clipping
- interaction with fit/grow/percent/fixed child sizing

Files:
- `docs/` (suggested: `docs/grid-lite-semantics.md`)

Acceptance:
- semantics are testable and unambiguous

#### K4-001: ABI strategy memo for grid configs

Scope:
- lock additive config approach
- document versioning impact
- define generated FFI/header expectations

Files:
- `docs/` or section in grid spec

Acceptance:
- no surprise ABI churn during implementation

### M4 Core Data Model and C API

#### K4-010: Add `CONFIG_GRID_CONTAINER` and `CONFIG_GRID_ITEM`

Scope:
- new enum values and config structs

Likely files:
- `src/config.t`
- `src/init.t`
- `src/capi.t`

Proposed structs (example names):
- `GridContainerConfig`
- `GridItemConfig`

Acceptance:
- generated API artifacts include grid config types

#### K4-011: Add grid attach APIs

Scope:
- attach functions for open element / current context

Likely files:
- `src/context.t`
- `src/capi.t`

Acceptance:
- engine users can declare grid container and per-item configs via stable API

#### K4-012: Optional feature probe/version helpers (if needed)

Scope:
- binding-friendly detection of grid support

Acceptance:
- bindings can fail gracefully on older libs

### M4 Grid Solver Implementation

#### K4-020: Placement map and occupancy tracking

Scope:
- row-major occupancy structure
- placement of explicit and auto items
- span reservation

Likely files:
- `src/context.t`
- `src/layout.t`

Acceptance:
- deterministic cell allocation for test scenes

#### K4-021: Track sizing and row height calculation

Initial scope:
- fixed column count
- equal-width columns (recommended M4 baseline)
- row heights from max item height in row/span contribution

Acceptance:
- stable sizing without CSS-like track complexity

#### K4-022: Child positioning and bounding boxes

Scope:
- compute final child positions from grid cell geometry
- preserve element box validity for diagnostics and hit testing

Acceptance:
- `GetElementData` reports correct grid item boxes

#### K4-023: Clipping/overflow/scroll interactions with grid

Scope:
- grid inside scroll panels
- scroll panels inside grid cells
- clip nesting correctness

Acceptance:
- no hit-test/render regressions under nested layouts

#### K4-024: Debug diagnostics for invalid grid declarations

Examples:
- zero columns
- out-of-range explicit cell indices
- non-positive spans
- impossible spans (overflow beyond columns)

Acceptance:
- clear debug-mode warnings (and deterministic fallback behavior)

### M4 Official LuaJIT Binding and Toolkit Exposure

#### K4-030: Expose grid configs in `argile_lj`

Scope:
- config constructors and attach wrappers

Files:
- `bindings/luajit/argile_lj/runtime.lua`

Acceptance:
- LuaJIT engine demo can author grid directly

#### K4-031: Add `grid_lite` helper in `argile_ui_lj`

Scope:
- ergonomic widget-level grid container and item span helpers

Files (argile-ui root):
- `hosts/luajit/argile_ui_lj/widgets.lua`

Acceptance:
- dashboard-like demo layouts no longer require manual width splitting

#### K4-032: Convert widget demo layout sections to grid

Candidates:
- stats row / cards
- bottom split actions/tasks
- diagnostics panel stack (if desired)

Files (argile-ui root):
- `platforms/love2d/luajit/demo_widgets/main.lua`

Acceptance:
- demo remains readable at varying window sizes with less custom breakpoint math

### M4 Tests and Conformance

#### K4-040: Core grid regression test suite

Coverage:
- auto placement
- explicit placement
- spans
- collisions
- out-of-range values
- nested grid
- grid inside scroll/clip

Files:
- `tests/test_*.t`

Acceptance:
- deterministic box outputs, no crashes, clear debug fallbacks

#### K4-041: Backend conformance scene for grid

Scope:
- grid visual + interaction scene for Love2D and at least one native backend

Files:
- `examples/scenes/*`
- backend demos

Acceptance:
- semantic parity across backends in layout and pointer behavior

## Cross-Cutting Program Tasks (Run Across Milestones)

### X1: API Versioning and Migration Notes

For every milestone introducing new API:

- record `ARGILE_API_VERSION` changes
- document added enums/structs/functions
- note binding compatibility expectations

Files:
- `README.md`
- generated headers/FFI comments (if present)
- milestone-specific docs

### X2: Generated Artifact Verification

After C API changes:

- run core build to regenerate `build/argile_api_ffi.lua` and headers
- verify bindings still load

Commands (typical):
- `make build`
- targeted LuaJIT demo smoke tests

### X3: Reference Demo Maintenance

Keep at least one engine-level and one toolkit-level demo current:

- `argile/backends/love2d/demo_ffi/` (engine integration reference)
- `argile-ui/platforms/love2d/luajit/demo_widgets/` (toolkit ergonomics proving ground)

### X4: Regression Capture Discipline

For every bug fixed during this program:

- add a regression test if it affects layout/hit testing/render command semantics
- add a small demo repro only if the test alone is insufficient

## Suggested Issue / Ticket Template

Use this for each implementation ticket above.

### Ticket Template

ID:
- e.g. `K1-021`

Title:

Problem:

Scope:

Out of scope:

Touched files:

C API impact:
- none / additive / breaking

Binding impact:
- none / `argile_lj` / `argile_ui_lj` / other

Backend impact:
- none / Love2D / SDL3 / raylib

Tests:
- unit/regression
- conformance/demo

Acceptance criteria:

Risks / follow-ups:

## Suggested Implementation Sequence (Practical)

This is the recommended order inside the program. Individual tickets can move if blocked.

### Sequence A (start immediately)

1. K0-010, K0-011 (document and test `GetElementData`)
2. K0-020, K0-021, K0-022 (expose in `argile_lj`)
3. K0-030, K0-031 (surface in `argile-ui` demo tooling)

Outcome:
- faster feedback loop before touching solver logic

### Sequence B (scroll foundations)

1. K1-000 (overflow/scroll semantics doc)
2. K1-010, K1-011 (configs + attach APIs)
3. K1-020..K1-023 (solver/render/hit-test integration)
4. K1-040..K1-042 (bindings + demos + conformance)
5. K1-050..K1-051 (`argile-ui` scroll_panel adoption)

Outcome:
- constrained-window usability improves dramatically

### Sequence C (ergonomics before bigger layout features)

1. K2-010..K2-012 (binding sizing + docs)
2. K2-020..K2-023 (`argile-ui` helpers + demo simplification)
3. K2-030..K2-031 (debug workflow polish)

Outcome:
- reduced manual layout math and easier future demos

### Sequence D (flow/wrap)

1. K3-000, K3-001 (spec)
2. K3-010..K3-012 (engine implementation) or toolkit prototype first
3. K3-020..K3-021 (toolkit + demos)
4. K3-030..K3-031 (tests + conformance)

Outcome:
- practical wrap layouts available without grid

### Sequence E (Grid Lite)

1. K4-000, K4-001 (spec + ABI memo)
2. K4-010..K4-012 (API and config surface)
3. K4-020..K4-024 (solver + diagnostics)
4. K4-030..K4-032 (bindings + toolkit + demo conversion)
5. K4-040..K4-041 (tests + conformance)

Outcome:
- grid-capable kernel with deterministic semantics and good diagnostics

## Acceptance Checklist (Program-Level)

The program is considered successful when all of the following are true:

1. Maintainers can inspect element boxes from official bindings without raw FFI
2. Constrained layouts remain usable via overflow/scroll behavior
3. Common responsive layouts in `argile-ui` need substantially less manual width math
4. Flow/wrap or equivalent wrap behavior is available and tested
5. Grid Lite supports real dashboard/inspector layouts with spans
6. Grid/scroll/clip semantics are covered by regression tests and conformance demos
7. The engine remains backend-neutral and the C API remains coherent

## Open Questions to Resolve Early

These should be answered before deep implementation on M1/M4:

1. Scroll ownership model:
- engine-managed interaction, host-managed offset, or hybrid?

2. Overflow diagnostics surface:
- extend `ElementData` vs separate debug query API?

3. Flow layout placement semantics:
- new config type vs mode on existing layout?

4. Grid column sizing baseline:
- equal-width columns only for M4, or fixed per-column widths in M4?

5. Debug warnings channel:
- existing error reporting path vs separate debug log callback?

## Maintainer Notes (Working Style)

To keep momentum and reduce regressions:

- land small vertical slices
- prefer feature flags / debug-mode gates for diagnostics
- keep demo changes paired with tests when behavior semantics change
- validate bindings immediately after C API changes
- avoid "big bang" solver rewrites unless a milestone explicitly requires it

This program is intentionally ambitious, but it is staged so that each milestone delivers standalone value.
