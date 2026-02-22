# Argile V3 Language Spec (Design-System-First)

> Draft specification for an Argile language update (V3) built on the proven V2 runtime/builder backend.

## Status

- `Draft / exploratory`
- No backward compatibility constraints on V2 semantics/APIs
- Preserve Argile language identity where it improves readability (`... end` blocks, directive-style metadata like `id(...)`)
- Primary goal: frictionless design-system authoring with clear separation of concerns and easy composition
- Implementation target (initially): `v3 AST -> v2 node tree/IR -> existing compiler/runtime`

## Why V3 Exists

Argile V2 is a strong UI construction DSL:

- clear concern separation (`layout`, `style`, `typography`, `paint`, `when`, `use`)
- proven runtime and C API
- end-to-end tests for DSL and CAPI paths

But V2 is still mostly "UI tree + styling blocks". The next problem to solve is harder:

- translating a design system into code
- encoding variants and states coherently
- composing reusable components without style drift
- keeping intent readable

V3 treats design-system concepts as first-class language concepts instead of library conventions, while keeping the Argile/V2 reading style.

## Design Goals

1. Make design intent the default reading mode.
2. Keep layout/style/paint escape hatches available and explicit.
3. Support safe composition with deterministic precedence.
4. Avoid CSS cascade, selector specificity, and stringly class APIs.
5. Keep state behavior explicit and testable.
6. Compile to a small, predictable runtime model (V2 backend in first implementation).

## Non-Goals

1. CSS compatibility (selectors, cascade, inheritance model).
2. HTML compatibility.
3. Global style rules.
4. Arbitrary dynamic metaprogramming inside every keyword (Terra already provides this outside the DSL).

## Core Ontology (First-Class Concepts)

These are language concepts, not just helper functions:

- `theme`: token namespaces and reusable semantic recipes
- `token`: named design values (color, spacing, radius, type scale, elevation)
- `component`: reusable UI definition with props, variants, parts, slots, and states
- `variant`: constrained component configuration axes (`size`, `tone`, `density`, etc.)
- `part`: named internal substructure inside a component (`root`, `label`, `icon`, etc.)
- `slot`: named caller-provided content insertion point
- `fill`: invocation-time content provided to a named slot
- `children`: default unnamed slot insertion point
- `state`: explicit overlays (`hover`, `active`, `focus`, `disabled`, `selected`)
- `layout`: spatial behavior
- `style`: semantic box appearance (background/border/shadow/etc.)
- `typography`: text appearance
- `paint`: explicit drawing primitives (shapes)
- `custom`: backend escape hatch (advanced / opaque)

## Layer Model (Separation of Concerns)

Every rendered node conceptually has these layers:

1. Structure/content (children, text)
2. Layout (`layout`)
3. Semantic appearance (`style`, `typography`)
4. Procedural visuals (`paint`)
5. State overlays (`state ...`)
6. Composition (`use`, recipe application)
7. Escape hatch (`custom`)

Hard boundaries:

- `layout` does not style.
- `style`/`typography` do not affect layout geometry.
- `paint` is visual-only in V3 initial implementation (no layout or hit-testing effects).
- `state` overlays mutate appearance/paint only (not structure) in V3 initial implementation.

## Recommended Source Model

Two layers of authoring code:

1. Design-system authoring (`theme`, `component`, `variant`, `part`)
2. Product/app usage (instantiate components, pass props/variants/content)

Low-level V2-like node declarations remain available as escape hatches within components.

## Syntax Direction (Canonical Shape)

Argile V3 keeps Lua/Terra block syntax (`... end`) and directive-style metadata (`id(...)`, etc.), and adds semantic keywords for design-system authoring.

### Top-Level Declarations (proposed)

- `theme <name> ... end`
- `component <name>(<props>) ... end`
- optional later: `mixin <name>(...) ... end`
- UI construction remains under a single `argile ... end` entrypoint, with component calls inside using Argile-native block syntax (`thing(params) ... end`)

### Inside `component`

- `variant <name> = ...`
- `state <name> ... end`
- `root ... end` (single required root part)
- `part(...)` (node metadata)
- `slot(...) ... end` (named insertion point, optional fallback content)
- `children` (default insertion point)
- `use ...`
- `layout ... end`
- `style ... end`
- `typography ... end`
- `paint ... end`
- `custom ... end`
- `id(...)`
- `text(...) ... end`
- `el ... end`

### Inside `theme`

- `token <path> = <expr>`
- `recipe <name>(<opts>) ... end`
- optional later: `alias`, `scale`, `palette`

## Canonical Example (Button)

```terra
theme app_theme
    token color.button.primary.bg = rgba(0.19, 0.37, 0.97, 1)
    token color.button.primary.bg_hover = rgba(0.15, 0.31, 0.86, 1)
    token color.button.primary.fg = rgba(1, 1, 1, 1)
    token radius.button = 8
    token spacing.button.pad_x.sm = 10
    token spacing.button.pad_x.md = 14
    token spacing.button.pad_y.sm = 6
    token spacing.button.pad_y.md = 8
    token type.button.sm.font_size = 13
    token type.button.md.font_size = 14

    recipe button(opts)
        style
            bg(token(color.button.primary.bg))
            radius(token(radius.button))
        end
        typography
            color(token(color.button.primary.fg))
        end
    end
end

component button(props)
    variant tone = primary | secondary | danger
    variant size = sm | md

    root
        id(props.id)

        layout
            width_fit()
            height_fit()
        end

        use(app_theme.button(tone = props.tone, size = props.size))

        state hover
            style
                bg(token(color.button.primary.bg_hover))
            end
        end

        text(props.label)
            part(label)
            typography
                color(token(color.button.primary.fg))
                font_size(token(type.button.md.font_size))
            end
        end
    end
end
```

Notes:

- `root` describes the component's actual rendered root node.
- `part(label)` names a sub-node for overrides/testing/introspection.
- `state hover` overlays local visual behavior.
- `variant` declarations are type-like constraints and drive recipe/branching.

## V3 Bootstrap Subset (Execution Starting Point)

This subset is not the end goal. It is the first implementation slice used to reach the full V3 target without losing semantic clarity.

Initial implementation slice:

1. `component`
2. `variant`
3. `root`
4. `part`
5. `state` (initially `hover` only, same runtime support as V2)
6. `theme`
7. `token`
8. `use`
9. `slot`, `fill`, `children`
10. existing low-level blocks (`layout`, `style`, `typography`, `paint`, `custom`)
11. `el`, `text`, `id(...)`

This is enough to validate the language shape and lowering model before completing the rest of the V3 target.

## Semantics

### Components

- A `component` defines a compile-time function-like UI constructor.
- Components can accept `props` (normal Lua/Terra expressions/values).
- Components must contain exactly one `root` block.
- `root` lowers to a normal V2 node tree.
- `part(...)` may appear inside `root` descendants to name nodes.
- `slot(...) ... end` and `children` declare insertion points inside the component tree.

### Variants

- `variant` declares a constrained axis of configuration.
- Values are symbolic enumerants (e.g. `primary`, `secondary`, `danger`).
- Invalid variant values should fail at compile time.
- Variants are local to the component unless explicitly forwarded.

Example:

```terra
variant tone = primary | secondary | danger
variant size = sm | md | lg
```

### Parts (`part`)

Terminology choice:

- Prefer `part` as the canonical keyword for internal structure naming.
- Keep `slot` as the canonical keyword for caller-provided content insertion.

Rules:

- `part(name)` attaches metadata to the current node.
- Sibling part names must be unique.
- Effective part identity is a hierarchical path (for example: `root.header.title`).
- Parts do not affect layout or rendering by themselves.

### Slots (`slot`, `fill`, `children`)

Slots are the external composition mechanism for component callers.

Rules:

- `slot(name) ... end` declares a named insertion point on the current node; fallback content is allowed.
- `children` declares the default unnamed insertion point.
- `fill(name) ... end` provides caller content for a named slot during component invocation.
- Bare nodes inside a component invocation body target the `children` insertion point.
- `part(...)` and `slot(...)` are distinct concepts and should not be conflated.

V3.0 recommendations:

- `fill(name)` may appear multiple times (append semantics).
- slots accept multiple nodes.
- missing fills are allowed unless a future `required` slot modifier is introduced.

### States

- `state <name> ... end` overlays appearance/paint behavior for the current node.
- V3.0 runtime target: only `hover` implemented.
- Other states may be accepted as syntax but should fail with explicit compile-time errors until runtime support exists.
- Runtime states that depend on input (`hover`, `active`, `focus`) require `id(...)` on the node.

State constraints (V3.0):

- No structural mutation inside `state` blocks (no adding/removing children).
- No `layout` mutation inside `state` blocks (initial rule; can be revisited).
- Allow `style`, `paint` (and later `typography` when implemented).

### Theme and Tokens

- `theme` defines a namespace for tokens and recipes.
- `token(path)` resolves a theme value.
- Tokens should be typed at compile time where possible (color, number, patch, etc.).
- Token names are semantic, not raw palette-only values.

Recommended token namespaces:

- `color.*`
- `spacing.*`
- `radius.*`
- `elevation.*`
- `type.*`
- `border.*`

### `use` (Composition)

`use` applies a patch/recipe to the current node or current block context.

Rules:

- `use(<expr>)` may be used at node scope (applies style/typography/paint patches as valid for node type).
- `use` inside `typography` applies only typography patch fragments.
- Invalid patch-to-context application should fail loudly.

Design intent:

- Keep composition explicit and local.
- Avoid hidden global inheritance.

## Precedence Model (Deterministic, No Cascade)

This must be explicit and stable. Recommended precedence for a node:

1. Theme defaults
2. Component base (`root` local declarations before variants/states)
3. `use` recipe base
4. Variant-derived overlays
5. State overlays (`state hover`, etc.)
6. Local low-level overrides later in source order
7. Escape-hatch overrides (`custom`) if they bypass standard rendering

Within the same layer:

- source order wins (last write wins)

Important:

- No selector specificity
- No implicit inheritance except explicitly documented node/text defaults (if any are introduced)

## Render Layering Semantics (Default)

Default node render order:

1. style background (`style.bg`, radius, etc.)
2. paint program (`paint`)
3. style border
4. content (`text`, children)
5. custom render hook (`custom`)

This mirrors current V2 paint placement and should remain stable unless explicitly versioned.

## Compilation Model

### Initial Compiler Pipeline (Recommended)

1. Parse V3 source into V3 AST
2. Resolve component declarations / theme namespaces
3. Expand component invocation into concrete node tree
4. Resolve variants, parts, tokens, and state overlays into normalized patches
5. Lower to V2 node tree/IR
6. Reuse existing V2 builder/runtime/C API

This minimizes runtime churn while enabling radical source-language redesign.

### Why Compile To V2 First

- V2 runtime and render commands are already tested end-to-end
- C API remains stable while V3 evolves
- Faster iteration on language design
- Clear place to compare semantics and debug regressions

## V3 AST (Conceptual)

This is a conceptual model for implementation planning (not final Terra data structures).

- `ThemeDecl`
  - `name`
  - `tokens[]`
  - `recipes[]`
- `TokenDecl`
  - `path`
  - `value_expr`
- `RecipeDecl`
  - `name`
  - `params`
  - `body` (patch-producing blocks)
- `ComponentDecl`
  - `name`
  - `params`
  - `variants[]`
  - `root` (`NodeDecl`)
- `VariantDecl`
  - `name`
  - `values[]`
- `NodeDecl`
  - `kind` (`el` | `text`)
  - `text_expr?`
  - `id_expr?`
  - `part_name?`
  - `slot_name?`
  - `has_children_insertion?`
  - `layout_ops[]`
  - `style_ops[]`
  - `typography_ops[]`
  - `paint_ops[]`
  - `uses[]`
  - `states[]`
  - `children[]`
- `StateOverlay`
  - `name`
  - `style_ops[]`
  - `paint_ops[]`
  - `typography_ops[]` (parsed but may be rejected in V3.0 runtime lowering)

## Error Model (Important)

Argile V3 should fail loudly and specifically. No silent no-ops.

Compile-time errors should include:

1. Unknown operation names in `layout` / `style` / `typography` / `paint`
2. Duplicate `layout` block on a node (unless merge semantics are introduced intentionally)
3. Duplicate `state <name>` block on a node
4. Missing `id(...)` for runtime input-dependent states (`hover`, later `active`, `focus`)
5. Invalid variant value
6. Invalid `use` patch for the current context
7. Unsupported state feature combinations (e.g. `hover + typography` if not implemented yet)
8. Invalid keyword placement (`part` at top-level, `variant` inside node body, etc.)
9. Invalid slot/fill usage (unknown slot, `fill(...)` outside invocation body, duplicate sibling `part(...)`)

## Suggested Keyword Set (V3.0)

Keep it small and high-signal:

- `theme`
- `token`
- `recipe`
- `component`
- `variant`
- `root`
- `part`
- `slot`
- `fill`
- `children`
- `state`
- `use`
- `el`
- `text`
- `id`
- `layout`
- `style`
- `typography`
- `paint`
- `custom`

Avoid adding aliases initially. Add aliases only after real usage proves a need.

## Detailed Example 1: Button

```terra
component button(props)
    variant tone = primary | secondary | danger
    variant size = sm | md | lg

    root
        id(props.id)
        use(ds.button(tone = props.tone, size = props.size))

        state hover
            style
                bg(token(color.button.hover_bg))
            end
        end

        text(props.label)
            part(label)
            use(ds.button_label(size = props.size))
        end
    end
end
```

## Detailed Example 2: Card

```terra
component card(props)
    variant tone = surface | elevated | outlined

    root
        id(props.id)
        use(ds.card(tone = props.tone))

        layout
            width_grow()
            dir(top_to_bottom)
            gap(token(spacing.card.gap))
            padding(token(spacing.card.padding))
        end

        el
            part(header)
            use(ds.card_header())
            slot(header)
                text(props.title)
                    part(title)
                    use(ds.card_title())
                end
            end
        end

        el
            part(body)
            use(ds.card_body())
            children
        end

        el
            part(footer)
            use(ds.card_footer())
            slot(footer)
            end
        end
    end
end
```

Note:

- This example shows `part(...)` as node metadata and `slot(...)` / `children` as insertion points.
- Invocation-time content is provided via `fill(...)` (see decision section below).

## Detailed Example 3: Input (with Deferred States)

```terra
component input(props)
    variant size = sm | md | lg
    variant tone = default | danger

    root
        id(props.id)
        use(ds.input(size = props.size, tone = props.tone))

        -- V3.0 runtime may reject focus/active until implemented
        state hover
            style
                border_color(token(color.input.border.hover))
            end
        end

        text(props.value)
            part(value)
            use(ds.input_value(size = props.size))
        end
    end
end
```

## V3 Syntax Decisions (Locked)

1. Component invocation syntax (Argile-native, no curlys)
- Use a single explicit `argile ... end` entrypoint as the parser boundary.
- Inside that entrypoint, invoke components with block syntax: `thing(params) ... end`
- `id(...)` remains a body directive, not a call parameter.

Example:

```terra
argile
    button(label = "Save", tone = primary, size = md)
        id("save_button")
    end
end
```

2. `part` semantics and placement
- `part(...)` is node metadata for internal component anatomy.
- Use node-body metadata placement (same style as `id(...)`).
- Sibling `part(...)` names must be unique; effective identity is hierarchical path.

3. Caller-provided content insertion
- `slot(name) ... end` declares a named insertion point (fallback content allowed).
- `children` declares the default unnamed insertion point.
- `fill(name) ... end` provides invocation-time content for a named slot.
- Bare nodes inside an invocation body target `children`.

Example:

```terra
argile
    card()
        id("settings_card")

        fill(header)
            text("Settings")
        end

        text("General")
        text("Notifications")

        fill(footer)
            button(label = "Save", tone = primary)
                id("save")
            end
        end
    end
end
```

4. Recipe definition syntax inside `theme`
- Patch blocks vs function-like Terra returning patch objects

Recommendation:

- Support both eventually, but implement Terra function recipes first if parser scope gets too large.

## Locked Implementation Decisions (Authoritative)

This section answers the implementation questions raised during V3 planning. These decisions are the authoritative execution constraints for parser/lowering/runtime work.

### 1. Declaration Scope (`component`, `theme`)

- `component` and `theme` are **module-scoped lexical declarations**.
- They are not global singletons as a language semantic.
- Cross-file visibility uses normal Lua/Terra module exports/imports.
- An internal registry table may exist in implementation, but only as a scoped compiler structure.

Example:

```terra
-- buttons.t
component button(props)
    root
        id(props.id)
        text(props.label)
            part(label)
        end
    end
end

return { button = button }
```

```terra
-- screen.t
local ds = require("design_system.buttons")
local button = ds.button

argile
    button(label = "Save", tone = primary, size = md)
        id("save_button")
    end
end
```

### 2. Parsing Strategy (One Pass + Eager Registration)

- Use **one parse pass**.
- Register `theme` / `component` declarations eagerly as they are parsed.
- Use **builder-time semantic evaluation and lowering** later (when `env_fn` is available).
- Do not implement a full lexical two-pass parser unless a real need emerges.
- Forward references are not required in the first implementation.

### 3. V3 AST Representation

- V3 uses an **explicit AST**.
- AST nodes are **Lua tables with tags** (not Terra structs).
- AST stores parser closures / expression thunks where needed (consistent with current Argile parser patterns).
- Terra types/quotes remain in the compile stage after lowering to V2 node trees.

### 4. Lowering Timing (Critical)

- Lowering happens **inside the builder function** (the closure returned by the parser), not as a pure parse-time transform.
- Reason: V3 expressions (`id(...)`, props, token args, recipe args, etc.) depend on the same `env_fn` evaluation model used by current Argile parsing.

Required flow:

```text
argile source
 -> parser (V3 AST + expression closures)
 -> builder(env_fn)
 -> evaluate expressions
 -> lower V3 AST to V2 node tree
 -> ui.compile(v2_node)
 -> Terra quote
```

### 5. V3 State Keyword (`state`, not `when`)

- V3 keyword is **`state`**.
- `when` is not part of V3 syntax.
- V2 raw mode may still use `when`, but V3 does not alias both.

Example:

```terra
state hover
    style
        bg(token(app_theme.color.button.primary.bg_hover))
    end
end
```

### 6. Component Invocation vs Reserved Keyword Collisions

- Reserved keywords/directives cannot be used as component names.
- Component declaration with a reserved name is a compile-time declaration error.
- Parser dispatch inside `argile ... end` is:
  1. reserved keyword/directive
  2. `identifier(` => component invocation
  3. otherwise error
- No-arg component invocation must use `name()`.

### 7. Component Invocation Arguments (Named-Only)

- V3 component invocations are **named-args only**.
- This is a hard rule for V3 component calls.
- Positional args remain valid for low-level V2 constructs (for example `text("...")` and style ops).

Example:

```terra
button(label = "Save", tone = primary, size = md)
    id("save_button")
end
```

### 8. Slot/Fallback/Fill Semantics

- `slot(name) ... end` declares a named insertion point with optional fallback content.
- If any `fill(name)` is supplied by the caller, the slot fallback content is **replaced**.
- There is no implicit merge mode in V3 core semantics.

### 9. Multiple `fill(name)` Blocks

- Multiple `fill(name)` blocks are allowed.
- Their contents append in source order to form the final slot content.
- Fallback content is still replaced entirely once any fill is present.

### 10. Variant Value Representation

- Bare variant values (`primary`, `md`) are parsed as **Argile symbols** (tagged AST symbol nodes).
- Variant membership validation happens during semantic/lowering validation.
- Lowering may normalize valid variant values to interned strings for downstream use.

### 11. `id(...)` Precedence and Override Semantics

- Invocation-body `id(...)` overrides component-template root `id(...)`.
- Override replaces the template root `id_expr` structurally.
- `id(...)` may be an expression (not literal-only), subject to normal Argile/V2 id validity rules.
- Duplicate invocation `id(...)` is an error.

Example:

```terra
component chip(props)
    root
        id(props.default_id)
        text(props.label)
    end
end

argile
    chip(label = "CPU")
        id("chip_cpu") -- overrides template root id expression
    end
end
```

### 12. Theme Model (Multiple Themes, No Ambient Singleton)

- Multiple themes are allowed.
- There is no ambient singleton theme in V3 core semantics.
- Theme selection is explicit via recipe/theme references and explicit token paths.

Recommended explicit style:

```terra
use(app_theme.button(tone = props.tone, size = props.size))

state hover
    style
        bg(token(app_theme.color.button.primary.bg_hover))
    end
end
```

### 13. Token Evaluation Timing

- `token(...)` resolves at **compile-time / lowering-time**, not runtime.
- Runtime theme switching is out of scope for the initial V3 target.
- Token errors (unknown path, wrong type) must be compile-time errors.

### 14. `part(...)` Metadata Usage and Persistence

- `part(...)` is not test-only metadata.
- It is future-facing metadata for:
  - diagnostics/debugging
  - introspection
  - future override APIs
- `part(...)` metadata must survive lowering to the V2 node tree.

Recommended lowered metadata fields (prefixed to avoid collisions):

- `_argile_v3_part_name`
- `_argile_v3_part_path` (optional early, recommended)
- `_argile_v3_component`

### 15. Error Location Tracking (Mandatory)

- AST nodes and key directives should carry source span information.
- At minimum: line + local token context.
- Preferred: file + line + column, if practical with Terra lexer access.
- Parser, semantic, and lowering errors should include source context and nearest component name when available.

### 16. `root` Block Semantics (Clarified)

- `root ... end` is the component's **implicit root element node block**.
- It is not a wrapper that contains multiple top-level sibling nodes.
- A component must declare exactly one `root`.
- `root` uses node-body grammar (`id`, `layout`, `style`, `typography`, `paint`, `state`, `slot`, `children`, `el`, `text`, etc.).

Example:

```terra
component button(props)
    root
        id(props.id)
        use(ds.button(tone = props.tone, size = props.size))

        text(props.label)
            part(label)
        end
    end
end
```

### 17. Nested Slot / Fill Scoping

- Each component invocation creates its own fill scope.
- `fill(name)` only targets slots in the **immediately invoked component instance**.
- Nested component slots are filled inside the nested invocation body.
- No path-based slot targeting in the initial V3 target (`fill(header.icon)` can be considered later if needed).

Example:

```terra
argile
    card()
        id("settings")

        fill(header)
            toolbar()
                fill(actions)
                    button(label = "Add")
                        id("add_btn")
                    end
                end
            end
        end
    end
end
```

## V3 Parser Implementation Checklist (Same-Doc Execution Guide)

This checklist is the parser/AST execution target for V3. It starts with the bootstrap subset and then expands to the full target. It is intentionally concrete so an AI coding agent can execute against it directly.

### Scope For Parser Phase 1 (Bootstrap)

Implement parsing for:

- top-level `theme <name> ... end`
- top-level `component <name>(<params>) ... end`
- `variant <name> = a | b | c`
- `root ... end`
- node declarations: `el ... end`, `text(<expr>) ... end`
- node metadata directives: `id(...)`, `part(...)`
- component composition directives: `slot(name) ... end`, `children`
- invocation-time content directives: `fill(name) ... end`
- node blocks reused from V2: `layout`, `style`, `typography`, `paint`, `custom`, `state`, `use(...)`

Phase 1 may defer:

- `mixin`
- advanced recipe block syntax if Terra-function recipes are used first
- slot modifiers (`required`, `single`, typed slots)
- `active` / `focus` / `disabled` / `selected` runtime support wiring (parser syntax may still be accepted)

### Parser Boundary (Locked)

- Use a single explicit `argile ... end` entrypoint for V3 invocation parsing.
- Parse component declarations and theme declarations in the same language extension surface (either same entrypoint or declaration entrypoints, but keep one parser module).
- Inside `argile ... end`, parser dispatch order is:
  1. reserved keywords/directives (`el`, `text`, `state`, `slot`, `fill`, etc.)
  2. `identifier(` => V3 component invocation
  3. otherwise error

### Lexical / Token Expectations

The parser should explicitly recognize and reserve these V3 keywords (in addition to V2 keywords already used by Argile):

- `theme`
- `component`
- `variant`
- `root`
- `part`
- `slot`
- `fill`
- `children`
- `state`
- `token`
- `recipe`

Identifier categories to distinguish in parser logic:

- declaration names (`theme`, `component`, `recipe`)
- symbolic variant values (`primary`, `md`, etc.)
- node/directive names (`el`, `text`, `id`, `part`, `slot`, `fill`, `children`)
- operation names inside `layout` / `style` / `typography` / `paint`

### AST Additions Required (Phase 1 Minimum)

Add or extend AST nodes to represent:

- `ThemeDecl`
  - `name`
  - `token_decls[]`
  - `recipe_decls[]` (or Terra-function references if recipe parsing is deferred)
- `ComponentDecl`
  - `name`
  - `params`
  - `variants[]`
  - `root`
- `VariantDecl`
  - `name`
  - `values[]` (symbol list)
- `ComponentInvoke`
  - `name`
  - `args` (named and/or positional, depending parser choice)
  - `id_expr?` (resolved from body directive)
  - `fills[]`
  - `body_nodes[]` (default children content before lowering)
- `FillDecl`
  - `slot_name`
  - `children[]`
- `NodeDecl` extensions
  - `part_name?`
  - `slot_name?` (for `slot(name)`)
  - `has_children_insertion?`

AST invariants to enforce early:

- `component` has exactly one `root`
- `variant` names unique per component
- `part(...)` sibling uniqueness (at least local sibling check in parser or early validation pass)
- no duplicate `layout` block per node
- no duplicate `state <name>` block per node

### Parser Functions To Add / Refactor (Suggested Breakdown)

The exact function names can differ, but the parser implementation should be split roughly this way:

1. Top-level declaration parsing
- `parse_v3_theme_decl(...)`
- `parse_v3_component_decl(...)`
- `parse_v3_variant_decl(...)`

2. V3 component root/body parsing
- `parse_v3_root_block(...)`
- `parse_v3_component_body_stmt(...)`

3. V3 invocation parsing inside `argile ... end`
- `parse_v3_component_invoke(...)`
- `parse_v3_invoke_body_item(...)` (handles `id`, `fill`, bare nodes for `children`)

4. Node metadata / composition directives
- `parse_part_directive(...)`
- `parse_slot_decl(...)`
- `parse_fill_decl(...)`
- `parse_children_insertion(...)`

5. Reuse/adapt V2 node parsers
- `parse_v2_element_builder` / `parse_v2_text_builder` (or equivalents)
- V2 block parsers for `layout/style/typography/paint/custom/state/use`

### Parsing Rules (Behavioral)

#### `component`

- Must appear at declaration scope.
- Accepts Terra-style params in parentheses (stored as parser closures/expressions, same pattern as current Argile parser where applicable).
- Body may contain:
  - `variant ...`
  - exactly one `root ... end`
- Any other statement at component top-level is a compile-time parse error.

#### `root`

- Must appear exactly once inside `component`.
- Is the component's implicit root element node block.
- Uses node-body grammar directly (`id`, `layout`, `style`, `typography`, `paint`, `state`, `slot`, `children`, `el`, `text`, etc.).
- Lowers directly to the component’s rendered root node.

#### `part(...)`

- Valid only inside node bodies (`el` / `text` descendants, including root node).
- Attaches metadata to current node.
- Duplicate `part(...)` on the same node is an error.

#### `slot(name) ... end`

- Valid only inside component definitions (not invocation bodies).
- Valid only inside node bodies.
- Declares named insertion point on current node.
- Fallback content (nested nodes/text) is allowed.
- Duplicate `slot(name)` on same node is an error.

#### `children`

- Valid only inside component definitions, inside node bodies.
- Declares default unnamed insertion point.
- At most one `children` insertion marker per node.
- `children` is a directive/marker, not a block.

#### `fill(name) ... end`

- Valid only inside component invocation bodies.
- Not valid inside component declarations.
- Body may contain nodes and nested component invocations.
- Multiple `fill(name)` occurrences are allowed and append in source order.

#### Bare nodes inside invocation body

- Bare `el`, `text`, or component invocations inside a component invocation body target the default `children` insertion point.
- If the callee component has no `children` insertion point, lowering should fail with a clear compile-time error.

### Invocation Syntax Rules (No Curlys)

Canonical invocation form:

```terra
argile
    button(label = "Save", tone = primary, size = md)
        id("save_button")
        fill(icon)
            icon_check()
        end
    end
end
```

Parser rule (locked):

- named args only for V3 component invocations

Rationale:

- keeps component APIs self-documenting and stable
- avoids positional drift in semantic component APIs

### Error Cases The Parser Must Produce (Phase 1+)

Add parser/validation tests for these exact classes:

1. `component` without `root`
2. duplicate `root` in a component
3. `variant` outside `component`
4. `part(...)` outside node body
5. `slot(...)` outside component declaration
6. `fill(...)` inside component declaration
7. `children` outside component declaration node body
8. duplicate `part(...)` on same node
9. duplicate `slot(name)` on same node
10. duplicate `children` marker on same node
11. duplicate `layout` block (existing V2 rule; ensure V3 path preserves it)
12. duplicate `state <name>` block (existing V2 rule; ensure V3 path preserves it)
13. unknown op inside `layout` / `style` / `typography` / `paint` through V3 parse path

### Parser -> Lowering Contract (Phase 1 Handoff)

The parser phase-1 work is complete when it can hand off enough information to a lowering pass to do the following deterministically:

- instantiate component root tree
- inject named fills into `slot(name)` in source order
- inject bare invocation-body nodes into `children`
- preserve `id(...)` and `part(...)` metadata
- preserve `state`/`layout`/`style`/`typography`/`paint` blocks unchanged for downstream V2 lowering

Do not implement runtime semantics in parser code. Lowering occurs later inside the builder function after expression evaluation via `env_fn`.

### File-Level Implementation Notes (Argile Codebase)

Likely primary files for parser phase work:

- `src/lang/argile.t`
  - new V3 parse functions and AST nodes
  - keyword dispatch updates
  - V3 entrypoint integration
- `tests/`
  - parser fixture tests (new V3-focused file)
  - lowering tests (V3 to V2 node-tree normalization)
  - runtime integration tests after lowering exists

Keep V2 parser behavior intact while V3 parser is introduced.

### Suggested Commit Plan (Parser Phase)

1. `feat(v3-parser): add AST types and keyword scaffolding`
2. `feat(v3-parser): parse component/root/variant declarations`
3. `feat(v3-parser): parse part/slot/children/fill directives`
4. `test(v3-parser): add syntax and error fixture coverage`
5. `feat(v3-lower): inject slot/fill/children into v2 node tree`
6. `test(v3): add end-to-end component lowering integration tests`

## V3 Lowering Implementation Checklist (V3 AST -> V2 Node Tree)

This checklist defines the lowering path from V3 component syntax to the existing V2 node tree/IR model. It starts with bootstrap lowering and extends to full-target semantics.

### Scope For Lowering Phase 1 (Bootstrap)

Implement lowering for:

- component invocation expansion (`ComponentInvoke` -> instantiated root node tree)
- named slot injection (`fill(name)` -> `slot(name)`)
- default content injection (bare invocation-body nodes -> `children`)
- metadata propagation (`id(...)`, `part(...)`)
- variant value validation (shape/allowed symbols)
- preservation of V2-native blocks (`layout`, `style`, `typography`, `paint`, `state`, `use`, `custom`)

Phase 1 may defer:

- theme/token/recipe evaluation if parser phase uses placeholder recipe refs
- cross-component slot forwarding
- part-path-based override APIs
- runtime support for states beyond current V2 behavior

### Lowering Input / Output Contract

Input:

- V3 AST with parsed declarations (`ThemeDecl`, `ComponentDecl`) and invocation tree (`ComponentInvoke`, `NodeDecl`, `FillDecl`)

Output:

- V2-compatible node tree (same shape currently accepted by builder/runtime)
- with all component/slot/fill abstractions removed
- preserving only V2-relevant data plus optional metadata fields that V2 builder already tolerates/uses

The lowering output should be directly consumable by the existing V2 compile path (`ui.compile` or an equivalent normalized builder entry) during builder execution.

### Deterministic Lowering Order (Must Be Fixed)

For each `ComponentInvoke`, lower in this order:

1. Resolve component declaration by name (module-scoped lexical registry)
2. Validate invocation arguments (names present, duplicates, unknown names)
3. Validate variant values (allowed symbol set)
4. Clone the component `root` node tree AST (deep clone)
5. Apply invocation body directives to cloned root:
   - `id(...)` to root node metadata
   - collect named fills
   - collect default children content
6. Resolve `slot(name)` insertions with named fills
7. Resolve `children` insertion with default body nodes
8. Lower nested component invocations recursively
9. Emit V2 node tree

This order avoids ambiguous precedence and makes test outputs stable.

### Component Invocation Semantics (Phase 1)

Canonical invocation:

```terra
argile
    button(label = "Save", tone = primary, size = md)
        id("save_button")
    end
end
```

Rules:

- Invocation args are configuration/props.
- `id(...)` in invocation body targets the component `root`.
- Invocation body may contain:
  - `id(...)` (at most one)
  - `fill(name) ... end`
  - bare nodes (`el`, `text`, nested component invocations) for default `children`
- Any other directive at invocation scope is a compile-time error in the current implementation phase.

### Slot Resolution Semantics (Phase 1)

#### Named slots: `slot(name) ... end`

- `slot(name)` declares an insertion point on a node in the component template.
- Fallback content is the content inside the `slot(name) ... end` block.
- All `fill(name)` bodies from the invocation are appended in source order.
- If no `fill(name)` is provided, fallback content is used.
- If a `fill(name)` is provided and fallback content exists, fallback content is replaced (not merged) unless a future explicit merge mode is added.

Phase-1 rule:

- `fill(name)` replaces fallback content entirely for that slot.

This is simpler and more predictable for the bootstrap lowering phase.

#### Default slot: `children`

- `children` marks a default unnamed insertion point on a node.
- Bare nodes in the invocation body are inserted at that point in source order.
- If no bare nodes are provided, nothing is inserted (no implicit fallback for `children` marker itself).

#### Missing insertion points

- Named `fill(name)` with no matching `slot(name)` in the component is a compile-time lowering error.
- Bare invocation-body nodes with no `children` marker in the component is a compile-time lowering error.

### `part(...)` Propagation Semantics

`part(...)` is structural metadata and must survive lowering.

Phase-1 behavior:

- Propagate `part_name` onto the lowered V2 node (extra metadata field if needed).
- Do not let `part(...)` affect render/layout behavior.
- Preserve enough structure so future diagnostics/override APIs can refer to part paths.

Optional early-phase metadata:

- `part_path` computed during lowering (for debug/testing), if easy to implement.
- If not implemented initially, retain local `part_name` and compute paths in a separate pass later.

### `id(...)` Resolution Semantics

There are two sources of root identity in V3:

1. `id(...)` inside component `root` template
2. `id(...)` inside invocation body

Precedence (locked):

- invocation `id(...)` overrides template root `id(...)`

Rationale:

- caller identity is usually instance-specific
- component template id can be a fallback/default if present

Constraints:

- At most one invocation `id(...)`
- duplicate `id(...)` directives in invocation body are a lowering-time validation error (or parser error if easier)

### Variant Validation (Phase 1+)

Validate variant values during lowering (or an early semantic pass before lowering):

- unknown variant name in invocation args -> error
- duplicate variant arg -> error
- invalid symbolic value for declared variant -> error

If non-variant props are allowed in the same argument list:

- only error on unknown names after combining declared variants + declared component params

### Preservation of V2 Blocks / Semantics

Lowering must preserve V2 semantics already implemented and tested:

- `layout` block contents/order
- `style` block contents/order
- `typography` block contents/order
- `paint` block contents/order
- `state` overlays and current runtime support/limitations
- `use(...)` nodes/patch references (until theme resolution phase)

Do not reinterpret V2 operations during initial lowering.

### Lowering Error Cases (Must Be Explicit)

Add lowering tests for these classes:

1. unknown component invocation (`buttonx(...)`)
2. duplicate invocation `id(...)`
3. named `fill(name)` with no matching `slot(name)` in component
4. bare invocation-body nodes but no `children` marker in component
5. duplicate variant arg in invocation
6. invalid variant value symbol
7. unknown arg name (neither variant nor declared prop, if prop validation is implemented)
8. duplicate slot declaration names in component template after parser/validation (defensive check)

### Lowering Test Fixtures (Phase 1 Minimum)

Add dedicated V3 lowering fixtures/tests that assert produced V2 node-tree shapes for:

1. `button`
- invocation id overrides template id
- no fills
- simple variant args present in lowered metadata/context

2. `card`
- `fill(header)` replaces header slot fallback
- bare text nodes go to `children`
- `fill(footer)` injects footer content

3. Error fixtures
- missing `children`
- unknown slot fill
- invalid variant

Prefer structural assertions on normalized node trees before runtime render-command assertions.

### Suggested Lowering Function Breakdown

Suggested functions (names can differ):

- `resolve_v3_component(name, scope)`
- `validate_v3_invoke_args(invoke, component_decl)`
- `clone_v3_node_tree(node)`
- `lower_v3_component_invoke(invoke, env)`
- `apply_v3_invoke_body_to_root(root_node, invoke_body)`
- `inject_v3_named_fills(root_node, fills)`
- `inject_v3_default_children(root_node, body_nodes)`
- `lower_v3_node(node, env)` (recursively lowers nested component invocations to V2 nodes)
- `validate_v3_slot_resolution(root_node, fills, body_nodes)`

### File-Level Implementation Notes (Argile Codebase)

Likely initial locations:

- `src/lang/argile.t`
  - parser + AST + builder-time lowering entrypoint (initial implementation)
- optional later split:
  - `src/lang/argile_v3_lowering.t` for maintainability once implementation stabilizes
- tests:
  - new `tests/test_v3_parser.t`
  - new `tests/test_v3_lowering.t`
  - later `tests/test_v3_integration.t`

### Suggested Commit Plan (Lowering Phase)

1. `feat(v3-lower): add component lookup and invoke validation`
2. `feat(v3-lower): implement slot/fill/children injection`
3. `feat(v3-lower): preserve id/part metadata and recurse nested invokes`
4. `test(v3-lower): add slot and variant error coverage`
5. `test(v3): add runtime integration for button/card fixtures`

## Implementation Plan (V3 Full-Target Delivery)

This plan is not optimized for minimum risk. It is optimized for reaching the intended V3 language: design-system-first, Argile-native syntax, and end-to-end correctness on the existing backend.

### Phase 0: Spec Freeze (Language + Semantics)

Goals:

- Freeze V3 syntax decisions in this doc (already mostly done)
- Freeze precedence model, slot/fill semantics, and state boundaries
- Freeze error model expectations (no silent no-ops)

Required outputs:

- this spec updated and internally consistent
- parser checklist + lowering checklist + full-target milestones aligned

Acceptance criteria:

- `button`, `card`, `input` examples all use the same canonical syntax style
- `part` / `slot` / `fill` / `children` semantics are unambiguous
- no contradictory "prototype-only" wording in semantic sections

### Phase 1: Parser + AST (Bootstrap Coverage)

Goals:

- Implement V3 declaration and invocation parsing in `src/lang/argile.t`
- Produce stable V3 AST for `theme`, `component`, `variant`, `root`, `part`, `slot`, `fill`, `children`
- Reuse V2 node/body parsers where possible

Scope:

- Follows `## V3 Parser Implementation Checklist`

Acceptance criteria:

- Parser fixtures for `button`, `card`, `input` pass
- Negative parser tests for all listed error classes pass
- V2 parser behavior remains intact

### Phase 2: Lowering (Component Expansion + Slot Resolution)

Goals:

- Lower V3 component invocations into V2-compatible node trees
- Implement deterministic `slot` / `fill` / `children` injection semantics
- Preserve `id(...)` / `part(...)` metadata
- Validate variants and invocation args

Scope:

- Follows `## V3 Lowering Implementation Checklist`

Acceptance criteria:

- Structural lowering tests pass for `button`, `card`, `input`
- Error tests pass for missing `children`, unknown `slot` fill, invalid variants
- Lowered trees are accepted by existing V2 compile path

### Phase 3: Theme / Token / Recipe Semantics (Full V3 Core)

Goals:

- Implement `theme` declaration storage/lookup
- Implement `token(...)` resolution with clear typing/errors
- Implement `recipe` semantics and `use(...)` application in V3 component context
- Validate patch-to-context application (`style` vs `typography` vs `paint`)

Decisions to enforce:

- no silent patch field drops
- deterministic recipe/variant/state/local override precedence
- explicit compile-time errors for invalid token paths and wrong token types

Acceptance criteria:

- `button`, `card`, `input` examples can resolve tokens/recipes end-to-end
- theme recipe usage compiles through V2 backend and emits expected render commands
- negative tests cover invalid token path/type and invalid `use(...)` application

### Phase 4: Full State Surface (V3 Semantics + V2 Runtime Bridging)

Goals:

- Expand runtime state support beyond current V2 `hover` where intended (`active`, `focus`, `disabled`, `selected`)
- Define and implement support matrix by node/block type
- Implement or explicitly reject `typography` state overlays with documented behavior

Important:

- `state` remains overlay-only (no structural mutation)
- `paint` remains visual-only
- runtime-input-dependent states require `id(...)`

Acceptance criteria:

- state support matrix documented in code/tests/docs
- runtime integration tests validate state command output changes across frames
- unsupported combinations fail with explicit compile-time errors

### Phase 5: Component Composition Ergonomics (Full Target)

Goals:

- Finalize component invocation argument model (named args, validation, defaults)
- Finalize slot ergonomics (fallback replacement semantics, repeated fills append semantics)
- Add any essential syntax refinements proven necessary by real component authoring (not speculative aliases)

Possible additions (only if justified by examples/tests):

- prop defaults in `component` declarations
- required slots
- slot arity constraints
- component-local helper declarations

Acceptance criteria:

- `button`, `card`, `input` plus at least 2 more complex components remain readable
- no syntax addition violates the separation model
- parser/lowering complexity remains manageable and tested

### Phase 6: Full End-to-End Integration and Correctness Suite

Goals:

- Prove V3 works end-to-end, not just parses/lowers
- Validate behavior correctness, not only output parity

Required test coverage:

- V3 component -> render commands integration tests
- correctness assertions on command order/payloads/geometry/colors/text/paint
- multi-frame runtime state behavior tests
- negative integration tests for language/semantic/runtime errors

Relationship to existing tests:

- keep V2 DSL/CAPI integration tests as backend proof
- add V3 integration tests as front-end proof

Acceptance criteria:

- `make test` includes V3 parser/lowering/integration suites
- `make build` remains green
- generated artifacts remain valid (`build/libargile.so`, `build/argile_api_ffi.lua`, `build/argile_api.h`)

### Phase 7: Docs / Reference / Examples (Public-Facing V3)

Goals:

- Produce V3 syntax reference aligned with implementation
- Document state support matrix and deferred features (if any remain)
- Provide canonical design-system examples and equivalent V2 expansions for transparency

Required docs:

- V3 syntax reference
- V3 semantics/precedence reference
- V3 component authoring guide (tokens/recipes/slots/states)

Acceptance criteria:

- all code examples in docs are implementation-valid
- docs reflect actual parser/runtime behavior (no speculative syntax in reference docs)

### Phase 8: Backend Review (Optional, After V3 Semantics Are Proven)

Goals:

- Re-evaluate whether V2 backend structures need changes to better support V3 semantics/perf
- Only now consider runtime/builder refactors informed by real V3 usage

Examples:

- native support for part-path metadata
- optimized slot-expanded node caching
- improved state overlay representation

Acceptance criteria:

- any backend changes preserve V3 and V2 correctness suites
- runtime changes are driven by measured complexity/perf, not speculation

## Testing Strategy (V3)

Required test layers:

1. Parser fixtures (AST shape / parse errors)
2. Lowering tests (`v3 -> v2 node tree`)
3. Runtime integration tests (`v3 -> render commands`)
4. Negative tests (unknown ops, invalid variants, missing ids, unsupported states)

Priority invariants:

- No silent no-ops
- Deterministic precedence
- Separation of concerns preserved
- Render layering unchanged unless explicitly versioned
- State support matrix matches documented behavior exactly

## Relationship To V2 (Operationally)

- V2 remains the low-level API and backend target.
- V3 is an Argile language update for design-system authoring.
- V3 should preserve Argile's reading style (block syntax + directive-style metadata) while adding semantic constructs.
- V2 can continue to exist as "raw mode" for advanced/engine-level usage.

## Final Target (Explicit Ship Criteria)

Argile V3 is complete when it is a **design-system-first Argile language update** with **Argile-native syntax** (`thing(params) ... end`, `id(...)`) that compiles to the existing V2 backend (initially) and is proven correct end-to-end by integration tests.

### What V3 Must Express

V3 must support, as first-class language concepts:

1. `theme`, `token`, `recipe`
2. `component`, `variant`
3. `part(...)` (internal structure metadata)
4. `slot(...)`, `fill(...)`, `children` (caller composition)
5. `layout`, `style`, `typography`, `paint`, `custom`
6. `state` overlays with an explicit support matrix
7. deterministic precedence and loud errors (no silent no-ops)

### Canonical V3 Syntax (Target)

```terra
theme app_theme
    token color.button.primary.bg = rgba(0.19, 0.37, 0.97, 1)
    token color.button.primary.bg_hover = rgba(0.15, 0.31, 0.86, 1)
    token color.button.primary.fg = rgba(1, 1, 1, 1)
    token radius.button = 8
    token spacing.button.pad_x.md = 14
    token spacing.button.pad_y.md = 8
    token type.button.md.font_size = 14

    recipe button(opts)
        style
            bg(token(color.button.primary.bg))
            radius(token(radius.button))
        end
        typography
            color(token(color.button.primary.fg))
            font_size(token(type.button.md.font_size))
        end
    end
end

component button(props)
    variant tone = primary | secondary | danger
    variant size = sm | md | lg

    root
        id(props.id)

        layout
            width_fit()
            height_fit()
            padding_x(token(spacing.button.pad_x.md))
            padding_y(token(spacing.button.pad_y.md))
        end

        use(app_theme.button(tone = props.tone, size = props.size))

        state hover
            style
                bg(token(color.button.primary.bg_hover))
            end
        end

        text(props.label)
            part(label)
            typography
                color(token(color.button.primary.fg))
            end
        end
    end
end
```

### Composition Model (Slots / Fills / Children)

Component declaration:

```terra
component card(props)
    variant tone = surface | elevated | outlined

    root
        id(props.id)
        use(ds.card(tone = props.tone))

        el
            part(header)
            slot(header)
                text(props.title)
                    part(title)
                    use(ds.card_title())
                end
            end
        end

        el
            part(body)
            children
        end

        el
            part(footer)
            slot(footer)
            end
        end
    end
end
```

Invocation:

```terra
argile
    card(tone = surface)
        id("settings_card")

        fill(header)
            text("Settings")
        end

        text("General")
        text("Notifications")

        fill(footer)
            button(label = "Save", tone = primary, size = md)
                id("save_button")
            end
        end
    end
end
```

### Required Semantics (Must Be True)

1. `part(...)` is internal structure metadata only
2. `slot(...)` / `children` are insertion points
3. `fill(...)` provides caller content
4. invocation `id(...)` overrides component-template root id (if both exist)
5. `state` is overlay-only (no structural mutation)
6. `paint` is visual-only (no layout/hit-testing side effects)
7. unknown ops and invalid compositions fail loudly

### Required Precedence (Deterministic)

For any node, precedence must be:

1. theme defaults
2. component base
3. recipe base (`use(...)`)
4. variant overlays
5. state overlays
6. local overrides (later source order wins)
7. `custom` escape-hatch behavior (if used)

No selector specificity. No implicit cascade.

### Required Backend Architecture (Initial)

```text
V3 source
 -> V3 parser / AST
 -> V3 lowering (component / slot / fill / variant / state resolution)
 -> V2 node tree / IR
 -> existing V2 builder / runtime
 -> render commands
```

### Definition Of Done (Specific)

V3 is "done" when all of the following are true:

1. Parser + AST:
   - `theme`, `token`, `recipe`, `component`, `variant`, `root`, `part`, `slot`, `fill`, `children`, `state` parse correctly
   - parser errors are explicit for invalid placement/duplicates/unknown constructs
2. Lowering:
   - component invocation expands deterministically to V2-compatible node trees
   - slot/fill/default-children injection behavior is deterministic and tested
   - `id(...)` and `part(...)` metadata survives lowering
3. Semantics:
   - tokens/recipes/`use(...)` resolve with explicit typing and errors
   - precedence rules are implemented exactly as documented
   - state support matrix is implemented and documented (unsupported combinations error explicitly)
4. Runtime correctness:
   - `button`, `card`, `input` render correctly end-to-end (`v3 -> render commands`)
   - integration tests assert geometry/colors/text/paint payloads and command order
   - multi-frame state behavior is tested (not just single-frame snapshots)
5. Quality gates:
   - no silent no-ops in `layout` / `style` / `typography` / `paint` / `use` / `state`
   - `make test` passes with V3 parser/lowering/integration suites included
   - `make build` passes and generated artifacts remain valid (`build/libargile.so`, `build/argile_api_ffi.lua`, `build/argile_api.h`)
6. Documentation:
   - V3 docs/examples are implementation-valid
   - reference docs reflect the actual support matrix and error behavior

### Required Test Style (Correctness, Not Just Matching)

V3 integration tests must assert correctness, not only parity/equivalence.

```terra
local compiled = argile
    button(label = "Save", tone = primary, size = md)
        id("save_button")
    end
end

ui.BeginLayout(...)
compiled()
ui.EndLayout()

local cmds = ui.GetRenderCommands(...)

-- Assert actual correctness, not only "same as another path"
assert(has_rect_with_color(cmds, rgba(0.19, 0.37, 0.97, 1)))
assert(has_text(cmds, "Save"))
assert_command_order(cmds, ui.RENDER_COMMAND_TYPE_RECTANGLE, ui.RENDER_COMMAND_TYPE_TEXT)
```

## Summary (Decision)

Argile V3 should be:

- a design-system-first language
- compiled to the proven V2 backend initially
- explicit about precedence and states
- small in keyword count but rich in semantic composition

The best next step is to validate this spec by writing the same `button`, `card`, and `input` three times:

1. as V3 examples (this doc)
2. as equivalent V2 expansions
3. as render-command expectations in tests
