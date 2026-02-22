# Argile V2 Language + Style Refactor Plan

## Purpose

This document is the single source of truth for a major refactor of Argile's language surface and styling model.

It is written for an AI coding agent that may only consume this file before making changes.

## Refactor Policy (Important)

- This is a deliberate breaking evolution.
- Backward compatibility is **not required**.
- It is acceptable for the repo to be temporarily broken during the refactor.
- It is acceptable to remove old syntax/API first and restore functionality later.
- Final state must build and tests must pass.
- Prioritize coherence and readability over migration convenience.

## Current State Snapshot (What Exists Today)

### Core Reality

Argile already has:

- A Terra language extension (`import "src.lang.argile"`) with `argile` entrypoint.
- A strict, canonical DSL (no alias/backward-compat parser paths).
- Compile-time lowering from a Lua/Terra node table into Terra quotes (`src/builder.t`).
- A runtime/UI API and stable C-facing export table (`ui.capi`) in `src/init.t`.
- Generated binding artifacts:
  - `build/libargile.so`
  - `build/argile_api_ffi.lua`
  - `build/argile_api.h`

### Current DSL Shape (`src/lang/argile.t`)

Current syntax is already `thing(params) ... end` style:

- `argile el(...) ... end`
- `argile text(...) ... end`

Current canonical keywords:

- nodes: `el`, `text`
- config blocks: `layout`, `shared`, `border`, `clip`, `aspect`, `image`, `custom`, `floating`, `textcfg`

Current parser capabilities:

- Expression entrypoint: `local q = argile el(...) ... end`
- Statement entrypoint: `argile name = el(...) ... end`
- Local statement entrypoint: `local argile name = el(...) ... end`
- Inline expression args via `lex:luaexpr()`
- Enum-ish symbolic values (`top_to_bottom`, `center`, `capture`, etc.)

Current parser limitations (relevant for refactor):

- No `use(...)` style composition
- No style recipe layer
- No variant/state model
- No generic body control flow (`if`, `for`) inside the DSL
- Public DSL exposes engine-ish config names (`shared`, `textcfg`) instead of readable style language

### Current Builder Shape (`src/builder.t`)

`ui.compile(node)` lowers a normalized node table into runtime calls:

- opens element (`OpenElement` / `OpenElementWithId`)
- attaches configs (`SetOpenElementLayoutConfig`, `AttachSharedConfig`, `AttachBorderConfig`, etc.)
- optionally opens text (`OpenTextElementWithLength`)
- recurses children
- closes element (`CloseElement`)

Current node table keys understood by builder:

- `id`
- `layout`
- `shared`
- `border`
- `clip`
- `aspect`
- `image`
- `custom`
- `floating`
- `text`
- `textConfig`
- `children`

### Current Runtime/C API Shape (`src/init.t`, `src/context.t`)

Argile already exports a large C-callable surface (`ui.capi`) including:

- context lifecycle
- layout lifecycle
- element open/close
- config attachments
- text functions
- input/hover queries
- render command queries
- hashing/id helpers

Notable binding-focused helpers already present:

- `StringFromChars`
- `GetElementIdFromChars`
- `GetElementIdWithIndexFromChars`
- `OpenElementWithIdChars`
- `OpenTextElementWithLength`
- `SetOpenElementLayoutConfig`
- config attach helpers (`AttachSharedConfig`, `AttachBorderConfig`, etc.)

### Current Tests/Build Plumbing

- Language extension coverage exists in `tests/test_language_extension.t`
- Test suite includes it in `Makefile` target `test`
- Build script `tools/build_argile.t` generates both LuaJIT FFI and C header artifacts

## Problem Statement (Why Refactor)

Argile currently solves structure and layout well, but it does not yet provide a modern, ergonomic styling layer.

Specifically, it lacks:

- design tokens (colors, spacing, radii, typography scales)
- reusable style recipes
- variants (`tone`, `size`, `kind`, etc.)
- state styling (`hover`, `active`, `disabled`, `focus`)
- a readable styling vocabulary for day-to-day UI work
- a clear separation between public styling language and low-level engine config internals

The user goal is to take inspiration from web-stack innovations (Tailwind, Bootstrap, CSS) while keeping the target language super readable.

## High-Level Design Direction (Chosen)

### What To Build

Build a **small, readable Argile style layer** on top of the existing tree/layout DSL.

Keep most expressive power in a typed Terra style library rather than exploding the DSL with many keywords.

### What To Borrow From the Web Stack

- CSS: design tokens, pseudo-state concepts, composable styling concepts
- Tailwind: composability and predictable naming/scales
- Bootstrap: opinionated recipes/components and consistent defaults

### What To Explicitly Avoid

- CSS cascade and selector specificity
- Global selectors
- Stringly-typed class soup as the main API
- Huge keyword surface in the language extension

## Target End State (V2)

Argile V2 should have four layers:

1. **Argile Core DSL**
   - structure and layout
   - minimal, readable syntax

2. **Argile Style System**
   - tokens
   - style patches
   - recipes/variants/state patches
   - deterministic merge rules

3. **Argile Paint Layer**
   - declarative shape/paint primitives attached to elements
   - theme/token-aware drawing commands
   - visual only (does not affect layout)

4. **Argile Kit (optional but recommended)**
   - default theme
   - opinionated component recipes (`button`, `card`, `panel`, etc.)

## Canonical V2 Public Language Surface (Proposed)

### Keep

- `argile`
- `el(...)`
- `text(...)`
- `layout ... end`

### Add (Public Styling Surface)

- `use(...)`
  - Applies a style patch or recipe result.
  - Intended primary reuse/composition mechanism.

- `style ... end`
  - Readable high-level visual styling block.
  - Maps to low-level configs (`shared`, `border`, parts of `textConfig`, etc.) during lowering.

- `typography ... end`
  - Text-focused styling block (readable replacement for `textcfg`).
  - Valid in `text` nodes only (and optionally in `el` nodes if inheritance is implemented later).

- `paint ... end`
  - Declarative custom shape/paint block for element-local drawing.
  - Separate from `style` and separate from opaque `custom` renderer escape hatch.

- `when <state> ... end` (Phase 5)
  - State-specific styling (`hover`, `active`, `disabled`, `focus`, optionally `selected`).
  - Compiles into conditional style/paint application (details below).

### Remove From Public DSL (Move to Lowering Internals)

These engine-ish blocks should no longer be part of the normal public Argile language surface:

- `shared`
- `textcfg`
- `border` (as a separate block; fold common border styling into `style`)
- `clip`
- `aspect`
- `image`
- `custom`
- `floating`

Notes:

- These concepts still exist in the engine and builder internals.
- `custom` remains the advanced opaque renderer escape hatch; `paint` is the readable declarative drawing layer.
- Advanced escape hatches can be reintroduced later as `native <kind> ... end` if truly needed.
- Initial V2 should optimize for readability and coherent styling, not full internal surface exposure.

## Canonical V2 Syntax Examples (Target)

### Example: Readable Styled Button

```terra
local ds = require("src/style/default_theme")

local save_button = argile el("save_button")
    use(ds.button { tone = primary, size = md })

    style
        bg(ds.colors.primary_500)
        radius(ds.radii.md)
        border_color(ds.colors.primary_700)
        border_width(1)
    end

    when hover
        style
            bg(ds.colors.primary_600)
        end
    end

    text("Save")
        use(ds.text.button)
        typography
            align(center)
        end
    end
end
```

### Example: Panel With Layout + Tokens

```terra
local ds = require("src/style/default_theme")

local panel = argile el("panel")
    layout
        width_grow
        height_grow
        dir(top_to_bottom)
        padding(ds.space.lg)
        gap(ds.space.md)
    end

    use(ds.panel { tone = surface })

    text("Settings")
        use(ds.text.title)
    end

    el("body")
        layout
            width_grow
            height_grow
        end
        use(ds.panel_body)
    end
end
```

### Example: Paint Layer (Custom Shapes, Readable)

```terra
local ds = require("src/style/default_theme")

local badge = argile el("badge")
    layout
        width_fixed(120)
        height_fixed(40)
    end

    style
        bg(ds.colors.surface_100)
        radius(ds.radii.md)
        border_color(ds.colors.border_muted)
        border_width(1)
    end

    paint
        fill(ds.colors.primary_500)
        round_rect(6, 6, 12, 12, 6)

        stroke(ds.colors.primary_700, 1)
        line(24, 20, 108, 20)
    end

    text("New")
        use(ds.text.badge)
    end
end
```

## Style + Paint System Architecture (V2)

### Core Types (New Modules)

Add new modules under `src/style/`:

- `src/style/core.t`
- `src/style/tokens.t` (optional split)
- `src/style/default_theme.t`
- `src/style/recipes.t` (optional split)

Add new module(s) under `src/paint/` (or `src/style/paint.t` if you prefer one namespace):

- `src/paint/core.t`
- `src/paint/defaults.t` (optional)

### StylePatch (Typed, Mergeable)

Create a typed Terra/Lua-side style patch schema that can be merged and later lowered into the existing builder node shape.

Minimum fields for V2:

- `layout` (optional subset; recipe defaults only)
- `shared` (background color, corner radius, userData)
- `border`
- `textConfig`
- `clip` (optional advanced path, not public DSL initially)
- `aspect` (optional advanced path)
- `image` (optional advanced path)
- `custom` (optional advanced path)
- `floating` (optional advanced path)
- `states`
  - keyed patches: `hover`, `active`, `disabled`, `focus`, `selected` (optional)

Each sub-config should be patch-like (partial), not “all fields required”.

### PaintProgram / PaintPatch (Typed, Ordered)

Paint should not be encoded as opaque `customData` by default.

Define a typed, ordered paint representation attached to a node, for example:

- `paintOps` (ordered list)
- `paintStateOps` (optional per-state overlay lists)

Suggested op categories:

- stateful paint parameters:
  - `fill(color)`
  - `stroke(color, width)`
- shape primitives:
  - `rect(x, y, w, h)`
  - `round_rect(x, y, w, h, r)` (or `radii(...)` later)
  - `circle(cx, cy, r)`
  - `line(x1, y1, x2, y2)`
- local transforms/helpers (optional V2.1):
  - `translate(x, y)`
  - `inset(p)` / `inset4(...)`

Initial V2 rule:

- Paint is visual-only and does not affect layout, intrinsic sizing, or hit testing.

### Recipe Model

A recipe is a function that returns a `StylePatch`.

Canonical shape:

- `recipe()` returns base patch
- `recipe(params)` returns base + variant-selected patch

Examples:

- `ds.button { tone = primary, size = md }`
- `ds.text.body`
- `ds.text.button`

Paint recipes are optional in V2.0, but the style recipe model should not block them later.

### Tokens

Tokens should be plain Terra/Lua tables with stable names and predictable scales.

Minimum token categories:

- `colors`
- `space`
- `radii`
- `font_sizes`
- `line_heights`
- `font_ids` (if relevant)

Naming guidance:

- Prefer semantic + scale names:
  - `primary_500`, `surface_100`, `fg_muted`
  - `xs`, `sm`, `md`, `lg`, `xl`

## Merge Semantics (Must Be Explicit)

### Deterministic Precedence (Canonical)

Apply style sources in this order:

1. Theme defaults (if any)
2. Recipe base (`use(...)`)
3. Recipe variants (`use(recipe { ... })`)
4. State patch (from `when ...`) when active
5. Local `style ... end`
6. Local `typography ... end`
7. Explicit `layout ... end` block (layout always wins over recipe layout defaults)

`last write wins` within the same target field.

Apply paint sources in this order:

1. Recipe/base paint ops (if any)
2. State paint ops (from `when ...`) when active
3. Local `paint ... end`

Paint ops are ordered and appended (not field-merged), except state overlays may intentionally override stateful parameters (`fill`, `stroke`) for subsequent shapes.

### Config Block Merge Behavior

If multiple `use(...)`, `style`, `typography`, or `paint` blocks appear, they compose in source order.

This is intentional and should be supported directly (no silent overwrite of whole blocks).

## Normalized AST / Lowering Pipeline (Refactor Target)

### New Recommended Pipeline

Refactor toward a staged pipeline instead of parsing directly into the final builder node shape.

1. **Parse DSL** (`src/lang/argile.t`)
   - Produce a normalized Argile AST (V2 AST), not final builder node tables.

2. **Resolve Styles**
   - Evaluate `use(...)` and style blocks into merged `StylePatch` values.
   - Resolve state patches and local overrides.

3. **Resolve Paint**
   - Evaluate `paint` blocks and any recipe-provided paint ops into an ordered paint program.
   - Resolve state paint overlays.

4. **Lower to Builder Node / Renderable Node**
   - Convert resolved styles into existing low-level fields (`shared`, `border`, `textConfig`, etc.).
   - Attach resolved paint program in a dedicated field (new V2 field, e.g. `paint`).
   - Preserve `layout`, `text`, `children`, `id`.

5. **Compile**
   - Call existing `ui.compile(node)` (or a lightly refactored equivalent).

### Why This Matters

- keeps parser simpler
- isolates style logic from Terra lexing logic
- makes testing style merge behavior easier
- preserves existing runtime lowering model

## Language Grammar Plan (V2)

### Parser Strategy

Keep the current Terra language extension entrypoint (`argile`) and parser architecture in `src/lang/argile.t`.

Refactor parser internals to support:

- node body entries:
  - `layout`
  - `use`
  - `style`
  - `typography`
  - `paint`
  - `when`
  - child nodes `el`, `text`

### `use(...)`

Syntax:

- `use(expr)`

Semantics:

- `expr` evaluates to a `StylePatch` (or recipe result convertible to one)
- merged into current node accumulated style

### `style ... end`

Syntax:

- block of styling ops

Initial V2 ops (supported, readable, mappable to current runtime):

- `bg(...)` -> shared background color
- `radius(...)`
- `radius4(...)`
- `border_width(...)`
- `border_width4(...)`
- `border_between_children(...)`
- `border_color(...)`
- `user_data(...)` (maps to shared.userData)

Optional V2.1 ops (only if engine support exists or `custom` mapping is clearly defined):

- `opacity(...)`
- `shadow(...)`
- `outline(...)`

### `typography ... end`

Syntax:

- block of text ops

Initial V2 ops (maps to current `textConfig`):

- `color(...)`
- `font_id(...)`
- `font_size(...)`
- `letter_spacing(...)`
- `line_height(...)`
- `wrap(...)`
- `align(...)`
- `user_data(...)`

### `paint ... end`

Syntax:

- block of paint ops

Initial V2 ops (small, readable primitive set):

- `fill(...)`
- `stroke(color, width)`
- `rect(x, y, w, h)`
- `round_rect(x, y, w, h, r)`
- `circle(cx, cy, r)`
- `line(x1, y1, x2, y2)`

Coordinate semantics (V2 default):

- coordinates are local to the element box (content-box refinement can be added later)
- shapes do not affect layout
- hit testing remains element box-based

### `when <state> ... end`

Syntax:

- `when hover ... end`
- `when active ... end`
- `when disabled ... end`
- `when focus ... end`

Semantics (V2 first implementation):

- `when` stores style and/or paint overlays under `node.states[state]`
- state application occurs during lowering/compile, not during parsing

Implementation constraint:

- Runtime-evaluated interactive states (`hover`, `active`, `focus`) require a stable element id.
- If such a state is declared on a node without `id`, error at compile-time with a clear message.

Default simplification for first pass:

- Implement `disabled` as a purely declarative state (controlled by recipe or explicit boolean later)
- Implement `hover` first
- Defer `active`/`focus` if runtime hooks are unclear

## Runtime State Styling Strategy (Important)

There are two valid approaches. Choose **Approach A** first.

### Approach A (Recommended First): Compile-Time State Slots + Runtime Conditional Attach

- Parser/lowering stores normal style patch + paint ops + per-state overlays on the node.
- `ui.compile(node)` emits runtime conditional branches for state overlays when possible.
- `hover` uses existing runtime hover query helpers and element id.

Pros:

- readable DSL
- no new runtime style engine required
- minimal architecture change

Cons:

- requires careful compile ordering
- state support depends on runtime query availability

### Approach B (Deferred): Full Runtime Style Resolver

- compile nodes with style descriptors
- runtime resolves all states dynamically

Do not start here unless A proves impossible.

## Paint Runtime Strategy (Important)

`custom` remains an opaque renderer escape hatch and should not be the default implementation model for user-authored paint DSL.

There are two valid implementation approaches. Choose **Paint Approach A** first.

### Paint Approach A (Recommended First): New Native Paint Render Commands

- Add paint op storage and one or more new render command types for primitive drawing (or a compact paint-list command).
- Builder/lowering emits these commands from `node.paint`.
- Renderer consumes typed paint commands directly.

Pros:

- typed and inspectable
- no opaque pointer protocol
- clean separation between `paint` and `custom`

Cons:

- requires runtime/render-command struct changes
- parity/benchmark tools may need updates if they inspect command counts/types

### Paint Approach B (Interim): Lower `paint` to `RENDER_CUSTOM` Payload

- DSL remains `paint ... end`, but lowering packs paint ops into a custom payload and emits `RENDER_CUSTOM`.

Pros:

- can ship quickly
- fewer core runtime changes initially

Cons:

- opaque payload undermines debuggability and cross-language rendering
- blurs distinction with user `custom` escape hatch

Use only as a temporary stepping stone if runtime changes block progress.

## C API Rework Plan (Binding-Friendly, V2)

This refactor is primarily about language/styling, but C ABI cleanup should be done in the same window because breaking changes are allowed.

### ABI Principles

- `ForContext` functions are canonical
- non-`ForContext` wrappers are convenience only
- all string inputs should have explicit `(ptr, len)` forms in exported ABI
- versioned ABI must remain discoverable

### ABI Actions

1. Keep `ui.capi` as stable export list, but reorganize sections logically.
2. Ensure any new helper exposed to bindings has:
   - `ForContext` version
   - non-context convenience wrapper (optional)
3. Keep `GetApiVersion` and `ARGILE_API_VERSION` authoritative.
4. Regenerate `build/argile_api.h` and `build/argile_api_ffi.lua` after any export changes.
5. If style- or paint-related runtime helpers are added, place them in clearly named sections (do not mix into core layout calls arbitrarily).

### What Not To Do (For Now)

- Do not expose the full style recipe system as C ABI in the first pass.
- Keep style recipes/theme definitions Terra-side until the model stabilizes.
- Do not expose the `paint` DSL itself through the C ABI in the first pass.
- If native paint render commands are added, expose only the resulting render command data/types, not Terra-side recipe/parser abstractions.

## Implementation Plan (Execution Order)

The sequence below is designed for a hard refactor where temporary breakage is acceptable.

### Phase 0: Baseline and Branch Safety (Short)

Goal:

- Establish a clear starting point before destructive edits.

Tasks:

- Verify repo is clean.
- Run baseline checks:
  - `make test`
  - `make build`
- Record current DSL examples from `tests/test_language_extension.t`.

Deliverable:

- No code changes required; baseline confidence only.

### Phase 1: Introduce Style Core (No Parser Changes Yet)

Goal:

- Create a style system implementation independent from the language parser.

Files to add:

- `src/style/core.t`
- `src/style/default_theme.t`
- `tests/test_style_core.t`

Tasks:

1. Define `StylePatch` schema (Lua/Terra tables; partial fields supported).
2. Implement merge helpers:
   - `merge_patch(a, b)`
   - `merge_patch_list(...)`
   - deep merge only for known config subtrees
3. Implement mapping helpers:
   - `style_ops -> shared/border/textConfig patch`
4. Create minimal default tokens:
   - colors, spacing, radii, typography scale
5. Create first recipes:
   - `panel`
   - `button`
   - `text.body`
   - `text.button`
6. Add tests for merge precedence and recipe outputs.

Acceptance:

- Style patches can be created and merged without involving `argile` parser.
- Tests pass for merge semantics.
- Core patch shapes and merge semantics are consistent with `## Argile Language Principles` (especially separation of concerns and composition rules).

### Phase 2: Refactor Builder Input Model (Support Resolved Styles)

Goal:

- Teach builder/lowering to consume a style-resolved (and paint-ready) node without exposing low-level blocks in the DSL.

Files to change:

- `src/builder.t`
- possibly `src/init.t` only if helper exports are needed

Tasks:

1. Add a normalization step (inside `src/builder.t` or a new module) that converts:
   - `stylePatch` + `typographyPatch` + `layout`
   - into builder node fields: `shared`, `border`, `textConfig`, etc.
2. Define a builder-facing `paint` field on the normalized node (can be unused until paint parser/lowering lands).
3. Preserve existing `ui.compile(node)` output behavior for low-level node fields.
4. Add a new entry helper if useful:
   - `ui.compileResolved(node)` or `ui.resolveAndCompile(node)`
5. Keep text node + children behavior intact.

Acceptance:

- A manually constructed V2-style node (without parser changes yet) can compile and render.
- Normalization/lowering preserves the concern boundaries defined in `## Argile Language Principles` (style vs typography vs paint).

### Phase 3: Rewrite `argile` Parser to V2 Public DSL

Goal:

- Replace public DSL surface with `use/style/typography` syntax and wire in `paint` parsing.

Files to change:

- `src/lang/argile.t`
- `tests/test_language_extension.t`

Tasks:

1. Remove public parsing paths for old engine-ish blocks:
   - `shared`, `textcfg`, `border`, `clip`, `aspect`, `image`, `custom`, `floating`
2. Add parsing for:
   - `use(expr)`
   - `style ... end`
   - `typography ... end`
   - `paint ... end` (AST only if runtime paint is deferred one phase)
3. Parse node bodies into a V2 AST (not directly final builder node table).
4. Add style resolution step invocation before compilation.
5. Keep entrypoint forms:
   - expression
   - statement
   - localstatement
6. Preserve `... end` block syntax and readability.

Acceptance:

- `argile` DSL examples using `use/style/typography` (and optionally `paint`) produce Terra quotes.
- Old DSL syntax is no longer accepted (by design).
- Parser surface and AST shapes conform to `## Argile Language Principles` (no mixed-concern keywords, clear concern boundaries).

### Phase 4: Add Paint Layer (Readable Shape/Draw Layer)

Goal:

- Introduce declarative custom visuals while keeping layout and styling readable.

Files to change:

- `src/lang/argile.t`
- `src/builder.t`
- `src/context.t` (if native paint commands are added)
- `src/config.t` (if new render command types/data are added)
- `src/init.t` (exports/types if needed)
- `tests/test_language_extension.t`
- add `tests/test_paint_layer.t` if needed

Tasks:

1. Add `paint ... end` parser support and AST storage (`node.paint` or equivalent).
2. Implement paint op parsing for initial primitive set.
3. Implement paint lowering:
   - Preferred: native paint render command(s)
   - Interim: `RENDER_CUSTOM` payload (only if necessary)
4. Define and document paint render order relative to background/border/text/custom.
5. Add tests for:
   - parse success
   - runtime command generation
   - coexistence with `style` and `text`

Acceptance:

- A node with `paint ... end` produces render output and remains layout-neutral.
- `paint` behavior remains consistent with `## Argile Language Principles` (visual-only, no layout/hit-testing side effects in V2).

### Phase 5: Add `when` State Styling (Readable State Layer)

Goal:

- Introduce web-inspired pseudo-state styling without CSS selectors.

Files to change:

- `src/lang/argile.t`
- `src/builder.t`
- `tests/test_language_extension.t`
- add `tests/test_style_states.t` if needed

Tasks:

1. Add `when <state> ... end` parser support.
2. Restrict initial content of `when` to styling constructs:
   - `use(...)`
   - `style ... end`
   - `typography ... end` (for text nodes)
   - `paint ... end`
3. Store state patches on node AST.
4. Lower `hover` state into runtime conditional style/paint application.
5. Emit compile-time error if `hover` state is used on node without id.
6. Add tests for:
   - parse success
   - parse errors on missing id
   - quote generation

Acceptance:

- `when hover` works on id-bearing nodes and changes emitted styling conditionally.
- `when` remains an overlay mechanism (no structural mutation), consistent with `## Argile Language Principles`.

### Phase 6: Optional Ergonomic Enhancements (Only After Core Is Stable)

Goal:

- Improve readability without bloating grammar.

Candidate enhancements:

- `do` keyword support after node calls (`el(id) do ... end`) if parser complexity is acceptable
- body control flow (`if`, `for`) in node bodies
- `id(...)` op inside `el` body for future extensibility
- `native <kind> ... end` escape hatch for advanced low-level configs

Rules:

- Only implement if core style layer is already coherent and tested.
- Avoid adding aliases/shorthands that fragment vocabulary.

### Phase 7: C API Cleanup (During Same Breaking Window)

Goal:

- Use the refactor window to improve ABI coherence for bindings.

Files to change:

- `src/init.t`
- `src/context.t`
- `tools/build_argile.t`
- `tests/test_language_extension.t` (and/or dedicated C API tests)

Tasks:

1. Reorganize `ui.capi` export ordering by domain:
   - context/init
   - layout/frame
   - element construction
   - text
   - input/state
   - render output
   - hashing/id
2. Audit string-taking functions and prefer explicit `(ptr, len)` exported variants.
3. Keep `GetApiVersion` and generated header/FFI artifacts verified.
4. Ensure any new exports are present in both generated bindings.

Acceptance:

- `make build` produces a coherent `build/argile_api.h` and `build/argile_api_ffi.lua`.
- ABI changes do not leak Terra-side recipe/style abstractions in ways that violate the separation goals in `## Argile Language Principles`.

### Phase 8: Tests, Examples, and Documentation Finalization

Goal:

- Make the refactor usable and maintainable.

Files to add/change:

- `tests/test_style_core.t`
- `tests/test_paint_layer.t` (if created)
- `tests/test_style_states.t` (if created)
- `tests/test_language_extension.t`
- `Makefile`
- optional docs/examples under `docs/` and `demo/`

Tasks:

1. Replace old DSL examples in tests with V2 syntax.
2. Add style recipe and merge tests.
3. Add at least one full integration test:
   - `argile el(...) use(...) style ... text(...) ...`
4. Verify generated C header still parses in C compiler sanity check (if a test hook exists; otherwise manual command in validation section).
5. Document the new public DSL and style philosophy.

Acceptance:

- Final tests pass.
- V2 syntax is demonstrated in tests.
- Build artifacts regenerate successfully.
- Examples/tests visibly reflect the concern separation and composition model from `## Argile Language Principles`.

## File-by-File Refactor Guide (Concrete)

### `src/lang/argile.t`

Current role:

- Terra language extension parser + direct node builder construction.

Target role:

- Terra language extension parser producing V2 AST builders.
- Supports `use/style/typography/paint/when` and child nodes.
- Keeps only readable public surface.

Key changes:

- Replace config-block parsing dispatch with V2 blocks.
- Add style op parsing tables.
- Add paint op parsing tables.
- Add state block parsing.
- Call style resolution before `ui.compile(...)`.

### `src/builder.t`

Current role:

- compiles low-level node tables to Terra quote runtime calls.

Target role:

- retain low-level compile path
- add normalization/resolution entry for V2 node structures
- add paint-program lowering support
- compile state-conditioned styling (at least hover) if included in V2

Key rule:

- Preserve low-level runtime call ordering correctness (`OpenElement`, attach configs, `OpenTextElement`, children, `CloseElement`).

### `src/init.t`

Current role:

- assembles `ui` table and `ui.capi`.

Target role:

- same, but with cleaner export grouping/order and any helper additions required by refactor.

### `src/context.t`

Current role:

- runtime implementation and C-callable functions.

Target role:

- mostly stable runtime core
- only change if state styling, paint render commands, or new helper functions require runtime support

### `tools/build_argile.t`

Current role:

- builds shared library and generates FFI/C headers.

Target role:

- unchanged architecture, but must reflect any updated `ui.capi` exports/types.

### `tests/test_language_extension.t`

Current role:

- validates parser forms and runtime command generation for current DSL.

Target role:

- validates V2 syntax and style-layer integration
- no need to preserve old syntax tests

## Testing and Validation Plan (Final Checkpoint)

Run at the end of the refactor:

- `make test`
- `make build`
- `terra tests/test_language_extension.t`
- `terra tests/test_style_core.t` (if not already included in `make test`)
- `terra tests/test_paint_layer.t` (if not already included in `make test`)

Optional but recommended:

- C header sanity compile:
  - `printf '#include "build/argile_api.h"\nint main(){return 0;}\n' | cc -x c - -fsyntax-only -I.`

## Non-Goals (For This Refactor)

- CSS selector engine
- CSS parser
- Full Tailwind-compatible utility grammar
- Full component framework with slots/templating
- Full vector/path engine or SVG parser
- Cross-language exposure of the style recipe system (defer until Terra-side style model stabilizes)

## Open Design Decisions (Defaults Chosen Here)

These are intentionally resolved in this plan so the agent can proceed without asking.

1. Public styling keyword should be `style` (not `visual`).
2. Public text styling keyword should be `typography` (replaces `textcfg` in DSL).
3. Reuse mechanism should be `use(expr)`.
4. State styling keyword should be `when`.
5. Paint keyword should be `paint` (not `draw`).
6. Public DSL should remove engine-internal config blocks for normal use.
7. Style recipes/themes live in Terra modules, not in the DSL.
8. Final V2 syntax readability is more important than preserving old examples.

## Argile Language Principles (Design Guardrails)

This section defines the conceptual model of the language so future additions can be judged against clear boundaries.

### Node Ontology (What An Argile Node Is)

Every node should be understood as a composition of distinct concerns, in this order:

1. **Structure / Content**
   - node kind (`el`, `text`)
   - `id`
   - `children`
   - text content (for `text`)
2. **Layout**
   - size, flow, alignment, spacing
   - purely spatial concerns
3. **Semantic Appearance**
   - themeable box/text appearance (`style`, `typography`)
   - token/recipe-driven
4. **Procedural Visuals**
   - explicit geometry drawing (`paint`)
   - shape primitives and paint parameters
5. **State Overlays**
   - conditional overrides (`when hover`, etc.)
   - overlays style and/or paint, not structure
6. **Composition / Reuse**
   - `use(...)` applies recipes/patches
   - deterministic merging in source order
7. **Escape Hatches (Advanced)**
   - `custom` / future `native` paths
   - for renderer-specific or unsupported features

Rule:

- A new feature should fit one of these concerns.
- If it spans multiple concerns, prefer splitting it instead of inventing a mixed keyword.

### Separation of Concerns (Hard Boundaries)

#### `layout`

- Owns only spatial concerns (size, position flow, padding, gap, alignment).
- Must not encode color, border, typography, or drawing primitives.

#### `style`

- Owns semantic box appearance and theme-friendly visuals.
- Examples: background, radius, border settings, semantic box appearance.
- Should remain declarative and token/recipe-friendly.
- Must not contain arbitrary geometry/path commands.

#### `typography`

- Owns text appearance only.
- Maps to text rendering configuration (`textConfig` internally).
- Valid primarily on `text` nodes in V2.

#### `paint`

- Owns explicit shape drawing within a node.
- Visual only: does not affect layout, intrinsic measurement, or hit testing in V2.
- Can consume tokens, but should not replace semantic `style`.

#### `custom` (advanced internal/escape hatch)

- Opaque renderer extension hook.
- Not part of the primary visual language.
- Use when Argile cannot represent the rendering behavior via `style` or `paint`.

Boundary test:

- If a feature describes "what this UI should look like" in a themeable, reusable way, it likely belongs in `style` / `typography`.
- If it describes exact geometry or draw operations, it belongs in `paint`.
- If it requires backend-specific opaque data/protocols, it belongs in `custom`.

### Composition Principles (`use(...)`)

`use(...)` is the primary composition primitive and should remain simple, explicit, and type-checked.

Rules:

- `use(expr)` accepts a recipe result or patch object.
- A patch may include any node-level concerns except structure/content:
  - style patch
  - typography patch
  - paint ops
  - layout defaults (optional; explicit local `layout` still wins)
  - state overlays
- `use(...)` must not create or mutate children.
- `use(...)` must not implicitly assign ids.
- Multiple `use(...)` calls compose in source order.
- Invalid patch content should fail loudly during lowering (clear error messages).

Typing guidance:

- Prefer normalized patch objects with known top-level keys.
- Reject unknown top-level keys by default (or gate them behind an explicit advanced mode).
- Keep patch objects data-like and side-effect free.

### State Model Principles (`when`)

States are overlays, not alternate trees.

Rules:

- `when` may override style and paint (and typography on `text` nodes).
- `when` should not add/remove children in V2.
- `when` should not mutate layout in V2 (defer until there is a strong use case).
- Runtime-dependent states (`hover`, `active`, `focus`) require stable ids.
- Compile-time errors for invalid state usage are preferred over silent no-op behavior.

Precedence:

- Base recipe/style/paint resolve first.
- State overlays apply next when active.
- Local blocks after `when` still follow source-order semantics (document exact parser/lowering order and keep it deterministic).

### Render Layering Principles (Must Be Explicit)

Argile must define rendering order as part of the language contract.

V2 default layering (recommended):

1. element background / border (`style` lowered to native configs)
2. `paint` primitives (node-local declarative drawing)
3. text/content render commands generated by children and `text` nodes
4. `custom` escape-hatch render output (advanced; if present)

Notes:

- Exact integration with child rendering depends on runtime command emission order; preserve deterministic behavior.
- If future use cases require it, add explicit paint sublayers (`paint_under`, `paint_over`) later instead of changing base semantics silently.

### Coordinate and Interaction Principles For `paint`

V2 defaults:

- Paint coordinates are local to the element box.
- Paint does not affect layout, clipping bounds, or hit testing shape.
- Clipping remains controlled by layout/clip systems, not by paint geometry.

Reason:

- This keeps the language readable and the implementation tractable while layout remains the core solved problem.

### Language Surface Growth Rule

New syntax should only be added if it improves one of:

- readability
- composition
- determinism
- separation of concerns

Avoid adding syntax that only shortens names or duplicates existing capabilities.

Default preference:

- add power in Terra recipe/style modules first
- add DSL keywords only when they materially improve readability or correctness

## Suggested First Commit Breakdown (If Agent Chooses Incremental Commits)

1. `feat(style): add style patch core and default theme skeleton`
2. `refactor(builder): add style resolution to low-level node lowering`
3. `refactor(lang): replace public dsl blocks with use/style/typography`
4. `feat(lang): add paint layer primitives and render lowering`
5. `feat(lang): add state styling with when hover`
6. `refactor(api): reorganize capi exports and regenerate headers`
7. `test(argile): replace language-extension fixtures with v2 style syntax`

## Execution Notes For AI Agent

- Prefer deleting obsolete parser branches instead of preserving both old and new syntax.
- Keep the runtime engine stable unless a feature truly requires runtime changes.
- Implement style merge logic in a dedicated module before touching parser complexity.
- Keep `paint` separate from `style`; do not collapse shape drawing into style ops.
- Use tests as executable examples of the intended V2 language.
- If state styling runtime semantics become unclear, ship V2 with `use/style/typography` first and add `when` in the next phase rather than blocking the whole refactor.
