# Canonical Argile DSL AST C API Architecture and Implementation Plan

## Status

- Proposed architecture and implementation plan
- Intended to guide the next C API effort after the rename cleanup pass
- This document defines the full target surface and migration path
- Reoriented after confirming `terralib.saveobj` export constraints:
  - shared-library `ui.capi` can export Terra functions only
  - the current Lua/Terra metaprogramming compiler cannot be exported directly

## Why This Exists

The goal of the Argile C API is not to expose a separate "C-friendly subset" of the DSL.
The goal is to let non-Terra users access the full Argile feature set by constructing Argile AST directly through a stable handle-based C API, and then compile through the same canonical pipeline used by the DSL parser.

This document exists to lock that architecture in place and prevent:

- duplicate semantic implementations
- partial feature subsets becoming accidental public contracts
- prototype implementations drifting from the real DSL
- ambiguous "minimal phase" scopes that produce half-integrated work

## Problem Statement

We need an Argile-facing API architecture that enables bindings users (LuaJIT, Rust, Python, etc.) to:

- build Argile programs (themes, components, nodes, invokes, fills, states, recipes)
- build Argile expressions (literals, symbols, refs, token refs, recipe calls, etc.)
- compile those ASTs through the canonical Argile compiler when running in a host Lua/Terra environment
- consume Argile runtime/layout/render APIs through a stable shared-library C ABI (`ui.capi`)
- obtain the same behavior as parser-produced Argile DSL for equivalent input

No API layer is allowed to implement its own separate semantic engine or emitter.

## Architectural Decision (Core Rule)

The canonical architecture is:

- Parser DSL -> Argile AST
- C API AST builder -> Argile AST
- Native Terra programmatic API (optional) -> Argile AST (or canonical semantic IR derived from AST)
- Canonical compiler -> semantics/lowering -> backend/runtime emission

There must be one semantic compiler path.

### Execution-Phase Constraint (Critical)

Argile currently has two execution phases:

- Host-side Lua/Terra metaprogramming phase (parser, AST construction, quote generation, compiler logic)
- Runtime/shared-library phase (`saveobj` exports through `ui.capi`)

`terralib.saveobj` can export Terra functions, but not plain Lua functions. Therefore:

- the current host-side `dsl_compiler` cannot be directly exported through `ui.capi`
- a shared-library runtime C ABI cannot directly call the current Lua compiler path

This is a phase boundary, not a semantic boundary.

The architecture must preserve one semantic source of truth while acknowledging that host-side compile and runtime shared-library bindings are different surfaces today.

### Explicitly Rejected Architecture

The following is not acceptable as the long-term implementation:

- C API AST-like builder -> separate CAPI semantic interpreter/emitter
- parser DSL -> different semantic compiler

That architecture duplicates semantics and causes drift.

## Scope (Full Target Surface)

This document covers the complete target for Argile DSL-facing APIs across both execution phases:

- full AST construction API (host-side and/or exportable data-builder forms)
- compile entrypoints for AST (host-side canonical compiler now, runtime ABI later if compiler lowering becomes Terra-exportable)
- diagnostics and validation
- feature parity expectations vs parser DSL
- testing and conformance strategy
- migration and rollout plan

This document does not define runtime rendering internals (`context.t`, layout algorithms) except where C API integration touches them through canonical compiler outputs.

## Current Codebase Reference (Renamed Canonical Paths)

This architecture is written against the renamed canonical DSL paths:

- parser: `argile/src/lang/argile.t`
- AST types: `argile/src/lang/ast.t`
- compiler: `argile/src/dsl_compiler.t`
- C API export aggregator: `argile/src/capi.t`
- C API export table assembly: `argile/src/capi_dsl_exports.t` (if retained / expanded)

These names are canonical. Version-specific naming should not be reintroduced for the current DSL path.

## Goals

### Primary Goals

- Full Argile DSL feature access for non-Terra users
- Handle-based, stable C ABI suitable for FFI bindings
- Single canonical semantic/compiler path
- Parser and C API parity on behavior for equivalent AST
- Good diagnostics for malformed AST and compile failures

### Secondary Goals

- Ergonomic wrappers can be built in host languages on top of the low-level C API
- Native Terra programmatic API can share the same AST/compile path
- Future multi-backend work remains compatible because semantics stay centralized

## Non-Goals

- Recreating parser syntax as a C string API
- Exposing Lua tables directly as C ABI
- Supporting arbitrary Lua closures through C ABI
- Building a separate CAPI-only semantic interpreter/emitter
- Hiding all AST details behind a high-level "convenience-only" API

## Design Principles

### 1. Canonical Semantics First

All language semantics live in one place. If a feature is hard to expose in C API, extend the AST or compiler input contract, not a side implementation.

### 2. AST Is the Contract

Bindings users do not need the parser. They need the AST and compiler entrypoint.

### 3. Handle-Based C API

C API object construction must use typed opaque handles with validation:

- stale handle detection
- owner/context checks
- predictable lifetime
- no raw pointer ownership across FFI

### 4. Data-Oriented, Not Closure-Centric

AST and compile entrypoints must be expressible without requiring Lua closures for core semantics.

### 5. Full-Surface Planning

Implementation can be phased, but the architecture and acceptance criteria must cover the full target surface from the start.

### 6. Phase-Correct APIs

Do not plan features for the wrong execution phase:

- Host-side AST + compiler APIs may rely on Lua/Terra metaprogramming
- Shared-library `ui.capi` exports must be Terra functions / exportable structs only

If a capability is not currently implementable in shared-library ABI form, document it as host-only or future-runtime work instead of building a duplicate semantic path.

## API Surfaces (Reoriented)

The project should explicitly maintain two API surfaces that share the same AST and semantics.

### A. Host-Side DSL AST + Compiler API (Lua/Terra)

Purpose:

- full Argile language tooling
- AST construction
- canonical compilation through `dsl_compiler`
- testing, codegen, authoring tools, embedded host integrations

Properties:

- may use Lua tables / metaprogramming
- may call parser/compiler modules directly
- not a `saveobj`-exported shared-library ABI

### B. Runtime Shared-Library C ABI (`ui.capi`)

Purpose:

- runtime layout/render/input APIs for all languages
- stable exported structs/constants/functions
- optional AST data builder/storage API if implemented in Terra-exportable form

Properties:

- Terra-exported functions only
- no direct calls into plain Lua compiler functions
- no duplicate DSL semantics

### Long-Term Convergence Goal

If the project later needs runtime shared-library AST compilation for non-Terra hosts, the semantic lowering/compiler path must be moved (or duplicated at the backend level only) into Terra-exportable/runtime-compatible code while keeping semantics shared.

## Canonical Pipeline (Target State)

### High-Level Flow

1. Input frontend creates Argile AST:
   - parser (`lang/argile.t`)
   - host-side AST API (`CapiDslAst*` host surface and/or Terra builders)
   - runtime ABI AST builder/storage API (optional/future, Terra-exportable subset or full builder)
   - optional native Terra builder
2. Canonical compiler validates and resolves AST semantics (host-side today)
3. Compiler lowers into runtime/backend operations
4. Runtime executes layout/render pipeline via `ui.capi` or direct Terra calls

### Key Requirement

The semantic resolution step (components, variants, state overlays, `use(...)`, fills/slots, tokens, recipes) must be shared across all frontends.

Backend differences are acceptable. Semantic differences are not.

### Present Capability vs Future Capability

Present:

- Host-side AST -> canonical compiler -> Terra quote/runtime emission
- Runtime `ui.capi` -> runtime engine APIs (layout/render/input)

Future (optional, if needed):

- Runtime `ui.capi` AST -> canonical semantics in Terra-exportable/runtime form -> runtime emission

## AST as the C API Target

## AST Role

`argile/src/lang/ast.t` defines the language constructs. The C API should expose constructors and mutators for the same constructs (or a canonicalized AST schema derived from them if parser-only fields exist).

## AST Node Families (Current and Target)

### Top-Level Declarations

- `ThemeDecl`
- `TokenDecl`
- `RecipeDecl`
- `ComponentDecl`
- `VariantDecl`

### Body / Node Constructs

- `NodeDecl` (`el`, `text`)
- `StateOverlay`
- `ComponentInvoke`
- `FillDecl`

### Values / Expressions (Current AST + required expansion)

Current AST already includes:

- `Symbol`
- `Splice` (Terra/Lua-specific escape hatch)

Required for full C API parity (canonical AST expansion if not present yet):

- literal expressions (bool, int, float, string, color-like structured literals if represented as expressions)
- token reference expressions
- parameter / invoke-arg references
- recipe call expressions
- possibly field/path reference expressions
- optional unary/binary expressions if DSL semantics require them

## AST C ABI Suitability Requirements

If `ast.t` contains parser-only or Lua-only constructs, define a canonical AST schema that:

- preserves DSL semantics
- is constructible through C API
- is accepted by the canonical compiler
- clearly separates Terra/Lua-only extensions (for parser/native Terra only)

Examples of likely special handling:

- `Splice(expr_fn)` is Terra/Lua-specific and cannot be represented in plain C ABI
- direct Lua function values in recipe/use expressions need AST-level recipe call descriptors instead

## C API Surface Design (AST Builder)

## API Scope

The public AST-facing API should expose:

- builder/context lifecycle
- AST object creation and destruction
- object graph wiring (append children, set roots, attach declarations)
- typed expression construction
- compile entrypoints (host-side today, runtime ABI later only if compiler path becomes Terra-exportable)
- validation and diagnostics

It must not expose parser internals.

Note:

- Host-side AST APIs may internally use Lua tables while presenting a structured interface.
- Shared-library ABI APIs must use exportable Terra structs/opaque handles and cannot expose Lua tables.

## Handle Model

### Typed Handles (Opaque)

Proposed handle families:

- `CapiDslAstBuilderHandle`
- `CapiDslAstProgramHandle`
- `CapiDslAstDeclHandle` (optional common declaration handle)
- `CapiDslAstThemeHandle`
- `CapiDslAstTokenHandle`
- `CapiDslAstRecipeHandle`
- `CapiDslAstComponentHandle`
- `CapiDslAstVariantHandle`
- `CapiDslAstNodeHandle`
- `CapiDslAstStateHandle`
- `CapiDslAstInvokeHandle`
- `CapiDslAstFillHandle`
- `CapiDslAstExprHandle`
- `CapiDslAstParamHandle` (optional if params/args are separate objects)

Whether declaration-specific handles are split or unified is an implementation choice. Typed handles are preferred for binding safety.

### Handle Semantics

Handles are:

- opaque values (index + generation recommended)
- scoped to a builder context
- invalid after explicit destroy or builder destroy
- checked on every API call

Required validation:

- stale handle detection (generation mismatch)
- owner check (handle belongs to the active builder/context provided)
- kind check (handle type matches expected object family)

## Memory Ownership Model

### Ownership

- Builder context owns all AST object storage for objects created under it
- Builder context owns copied strings (or interned strings) used by AST
- Destroying builder context invalidates all handles it issued

### Rationale

- Safe across FFI boundaries
- No dangling raw pointers
- Predictable cleanup
- Simple bindings integration

### Allocation Strategy

Acceptable implementations:

- arena + typed slot arrays + generation counters
- pooled arrays with free lists + generation counters

Avoid:

- exposing raw pointers to AST internals
- per-object malloc ownership pushed to bindings user

## C API Construction Model

## Builder Context Lifecycle

Required API families:

- create builder context
- destroy builder context
- reset builder context (optional, explicit semantics)
- query last error / diagnostics

Builder context should be explicit, not global singleton state.

## Program Construction

Program-level API must support:

- create program
- add top-level declarations and root body items
- set compile options / environment hooks (if any are expressible through C API)
- finalize/validate program structure before compile (optional explicit call, but diagnostics must exist either way)

## Declarations and Nodes

API must support creating and wiring all DSL constructs:

- themes with tokens and recipes
- components with params/variants/root
- variant value lists
- `el` and `text` nodes
- `state` overlays on nodes
- component invokes with named args
- fills and invoke body children
- `slot` declarations and `children` marker on nodes
- `id`, `part`, and other directives

## Expressions

Expressions are first-class AST objects in the C API.

The C API must not require per-feature ad-hoc setters for semantics that are fundamentally expression-driven.

### Required Expression Kinds

- `nil` / absent (represented by not setting a field)
- bool literal
- int literal
- float literal
- string literal
- symbol literal (for variants and symbolic DSL values)
- token reference
- parameter reference / invoke arg reference
- recipe call
- field/path reference (if distinct from arg ref)
- structured literal / object-like values (if needed for config-friendly AST)

### Expression Attachment Points

The C API must allow expressions to be attached wherever DSL supports values, including:

- text content (`text(...)`)
- `id(...)`
- component invoke args
- token declarations
- recipe call args
- operation arguments in `layout/style/typography/paint`
- state overlay operation args

## AST Mutation and Validation Rules

The C API should enforce or diagnose the same structural rules the parser enforces, including (examples):

- duplicate `id(...)` on same node
- duplicate `part(...)` on same node
- duplicate slot declaration on same node
- slot + children marker conflict
- duplicate `children` marker
- duplicate state name on same node
- duplicate variant name in component
- duplicate root block in component
- duplicate invoke arg name
- duplicate invocation `id(...)`

Validation can happen:

- eagerly on mutation calls
- or during explicit/finalize/compile validation

But diagnostics should be deterministic and comparable to parser behavior.

## Compiler Integration (Canonical Path)

## Required Compiler Contract

The compiler must accept AST produced outside the parser.

This may require refactoring `argile/src/dsl_compiler.t` so that:

- parser AST and C API AST share the same accepted schema
- parser-specific conveniences/closures are normalized before semantic compile
- compile entrypoints are callable without parser-only context

## Compile Entry Points (C API / Host API)

Required capability (project-wide):

- compile AST program/body into canonical executable/entry representation

Possible exposed forms (implementation choice):

- host-side compile to Terra quote / Terra function
- host-side compile-and-bind helper for tools/tests
- future runtime ABI compile to runtime executable plan (only after Terra-exportable semantic lowering exists)

What matters:

- all routes use the same canonical semantic lowering

### Immediate Constraint

The current `dsl_compiler` is host-side Lua/Terra metaprogramming code and cannot be called through shared-library `ui.capi` directly.

Therefore, `CapiDslAstCompile*` in the near term should be implemented as host-side API entrypoints (Lua/Terra environment), not as `saveobj` shared-library exports.

## No Separate Semantic Path

The C API compile implementation must not:

- reimplement slots/fills logic
- reimplement variant resolution
- reimplement state precedence
- reimplement `use(...)` recipe semantics

If a feature is unsupported by C API compile path, the compiler path itself is incomplete and must be fixed centrally.

## Features and Parity Requirements

## Full Parity Target Matrix (Semantic Features)

The following features are in scope for parity between parser DSL and C API AST.

### Core Nodes and Structure

- `el`
- `text`
- nested nodes
- component invocation
- invoke body children
- `fill(...)`
- slot declaration on component template nodes
- `children` marker insertion
- `part(...)`
- `id(...)`

### Config and Styling DSL Blocks

- `layout`
- `style`
- `typography`
- `paint`
- `use(...)` (recipe/pattern application)

### Runtime States

- `state hover`
- `state active`
- `state focus`
- `state selected`
- `state disabled`
- merge order / precedence parity

### Components and Variants

- component params
- variant declarations and allowed values
- invoke arg passing and lookup
- variant-driven template behavior
- invocation `id(...)` overrides

### Themes / Tokens / Recipes

- theme declarations
- token declarations (paths and values)
- recipe declarations
- recipe invocation via `use(...)`
- token and recipe resolution semantics parity

### Expressions

- literals and symbols
- token refs
- arg/param refs
- recipe call args
- operation arguments with expression resolution
- state-overlay operation arguments with expression resolution

## Terra/Lua-Only Extensions (Documented Boundary)

If parser/native Terra supports constructs that depend on Lua/Terra closures (for example `Splice` or arbitrary closure-backed `use(...)` paths), they must be explicitly classified:

- parser/Terra-only extension
- not part of portable C API AST parity

This boundary must be documented, not left implicit.

If practical, provide AST-native equivalents for common use cases (recipe call descriptors, explicit patch AST nodes).

## Recipes and Themes (Detailed Strategy)

## Problem

DSL may use Lua values and callables at parse/compile time. C API cannot depend on Lua closure semantics.

## Canonical Strategy

Represent portable semantics in AST:

- `ThemeDecl` and `TokenDecl` as data declarations
- `RecipeDecl` as AST declaration (if recipe body is DSL-structured)
- `RecipeCallExpr` / `UseExpr` as AST call/reference

The compiler resolves AST recipe calls and token refs using canonical rules.

## Optional Extensions (Not Core Requirement)

Host integrations may later add:

- recipe registry callbacks (C function pointers or host-registered adapters)
- external token providers

These extensions must plug into the canonical compile pipeline, not bypass it.

## Diagnostics and Error Model

## C API Error Categories

Builder/API-level errors:

- invalid handle
- stale handle
- wrong handle kind
- wrong owner/builder
- invalid enum/value kind
- duplicate field / duplicate declaration entry
- structural constraint violations
- capacity/allocation failure

Compile-time errors:

- unknown component
- unknown variant value
- bad arg type or unresolved ref
- missing slot/fill target mismatch
- invalid `use(...)` target / recipe
- token resolution failure
- semantic merge/validation failures

## Error Reporting Requirements

The C API must provide:

- stable error codes
- human-readable message retrieval
- object/path context (component, node, field) where possible
- optional span/source metadata hooks if caller attaches them

Parser and CAPI compile errors should share code families where practical.

## Source Location / Spans

The parser naturally has spans. C API-built AST may not.

The C API should support optional source metadata attachment:

- file/module name string
- line/column range
- arbitrary user tag

This is important for bindings that implement their own DSL/parser.

## Threading and Reentrancy

## Requirements

- Builder contexts must be explicit and independent
- No hidden global mutable state in AST construction path
- Concurrent builders should be possible unless a documented runtime/compiler lock exists

## Compiler/Reentrancy Notes

If `dsl_compiler.t` currently relies on shared module state (registries, parse-time globals), refactor it so AST compile entrypoints are explicit about compiler environment and registry inputs.

Concurrency support can be phased, but non-reentrant global singleton design should not be baked into the AST C API.

## ABI Stability and Versioning

## API Namespacing

Use a distinct family for DSL AST C API:

- `CapiDslAst*` for AST builder/compile API

Keep runtime core APIs in their existing generic `ui.capi` export family.

## Feature Flags

Add explicit feature flags/capability queries for AST C API coverage, for example:

- `CAPI_FEATURE_DSL_AST_CORE`
- `CAPI_FEATURE_DSL_AST_EXPRS`
- `CAPI_FEATURE_DSL_AST_COMPONENTS`
- `CAPI_FEATURE_DSL_AST_THEMES`
- `CAPI_FEATURE_DSL_AST_RECIPES`
- `CAPI_FEATURE_DSL_AST_COMPILE`

Feature flags must describe real exported capabilities, not internal implementation staging names.

## Module Layout (Target Internal Organization)

The internal split should reflect responsibilities, even if implemented incrementally:

- `argile/src/lang/ast.t`
  - canonical AST definitions (or a renamed/normalized canonical AST module)
- `argile/src/lang/argile.t`
  - parser -> AST
- `argile/src/dsl_compiler.t`
  - canonical semantic compile path (may delegate to submodules later)
- `argile/src/capi_dsl_ast.t`
  - C API AST builder handles and object construction
- `argile/src/capi_dsl_compile.t`
  - C API compile entrypoints that call canonical compiler
- `argile/src/capi_dsl_exports.t`
  - DSL/AST C API export list assembly
- `argile/src/capi.t`
  - aggregate all export domains

Optional later split if compiler grows:

- `argile/src/dsl_semantics.t`
- `argile/src/dsl_backend_terra_quote.t`
- `argile/src/dsl_backend_runtime.t`

The critical rule is that semantics are shared.

## Implementation Plan (Full-Scope, No Ambiguous "Minimal" Boundary)

This plan is phased for execution order, but each phase is defined against the full target architecture. "Minimal" is not used as a completion criterion. Each phase has explicit deliverables and stop gates.

## Phase 0 - Architectural Lock-In and Constraints

### Deliverables

- This document committed in `argile/docs/`
- Explicit engineering rule in team notes / ADR:
  - no separate CAPI semantic/emitter path
- Decision on canonical AST schema ownership:
  - existing `ast.t` as canonical, or
  - parser AST + canonical normalized AST layer

### Outputs

- agreed architecture
- agreed boundaries (portable AST vs Terra/Lua-only extensions)
- accepted naming (`CapiDslAst*`)

### Stop Gate

No C API AST implementation starts until the above is accepted.

## Phase 1 - Full AST Schema Audit and Canonicalization

### Goal

Produce a complete canonical AST schema that the parser and C API can both generate, including all DSL constructs required for parity.

### Work Items

- Audit `argile/src/lang/ast.t` node-by-node
- Classify fields:
  - portable (CAPI-safe)
  - parser-only
  - Terra/Lua-only
- Identify missing expression node types for full parity
- Specify canonical representations for:
  - token refs
  - recipe calls
  - param/arg refs
  - any structured values
- Specify optional source metadata attachment contract

### Deliverables

- canonical AST schema section in this doc (or companion schema doc if too long)
- updated `ast.t` plan (and implementation diff if done in this phase)
- list of Terra/Lua-only extensions that remain non-portable

### Stop Gate

Schema fully covers the full DSL surface (including themes/recipes/components/variants/states/uses), with no TODO holes for core semantics.

## Phase 2 - Compiler Input Refactor to Canonical AST Contract

### Goal

Make `argile/src/dsl_compiler.t` compile from a canonical AST contract independent of parser-only behavior.

### Work Items

- Identify parser assumptions currently embedded in compiler input handling
- Refactor compile entrypoints to accept canonical AST structures directly
- Normalize parser output in `argile/src/lang/argile.t` if needed before compilation
- Eliminate or isolate parser-only constructs before semantic compile
- Ensure component/variant/theme/recipe/state semantics remain unchanged

### Deliverables

- compiler accepts canonical AST input from non-parser caller
- parser uses the same compile entrypoint after parse
- regression tests proving parser behavior preserved

### Stop Gate

A manually constructed Lua AST (without parser) can be compiled through the canonical compiler path for at least one scene covering components, states, and fills.

## Phase 3 - Host-Side AST Builder Core (Handles, Program, Nodes, Expressions)

### Goal

Expose a handle-based AST builder API for constructing canonical AST programs and expressions, without adding any duplicate semantics.

This phase can be implemented as a host-side API first (Lua/Terra environment) to validate the full AST contract and semantics path before any shared-library ABI constraints are imposed.

### Work Items

- Implement builder context and handle storage with generation checks
- Implement object creation for:
  - program
  - node (`el`, `text`)
  - invoke
  - fill
  - state overlay
  - component declaration
  - variant declaration
  - theme / token / recipe declarations
  - expressions
- Implement graph wiring APIs:
  - append child
  - set component root
  - add fill
  - add state
  - add declarations to program/theme/component
- Implement setters/mutators for node directives:
  - `id`, `part`, `slot`, `children`
- Implement expression attachment to all relevant AST fields and operation arguments
- Implement string storage/copy semantics in builder context

### Deliverables

- `capi_dsl_ast` (or `dsl_ast_builder`) module with typed handles and constructors
- host-side tests proving AST graph/lifecycle correctness
- if exportable Terra structs/functions are used from the start, generated header/FFI exports can also be added here
- AST builder unit tests (handles, invalidation, graph constraints)

### Stop Gate

AST builder can construct a non-trivial AST covering:

- theme + token + recipe declaration
- component with variants and root node
- invoke with fills and state overlays
- expression-based arguments in style/typography/paint/layout operations

No compile path required yet to pass this gate, but AST structure must be complete and validated.

## Phase 4 - Host-Side AST Compile Entry (Canonical Compiler Only)

### Goal

Compile AST-builder-produced ASTs through the canonical compiler path and remove any need for a CAPI-specific semantic path.

### Work Items

- Add host-side `CapiDslAstCompile*` (or `DslAstCompile*`) entrypoints
- Convert internal AST-builder storage to compiler-consumable AST objects (or build canonical AST directly)
- Route compile call into `dsl_compiler`
- Surface compile diagnostics through C API
- Ensure no duplicate semantic evaluation exists in C API layer

### Deliverables

- host-side compile entrypoints
- end-to-end C API AST -> canonical compiler -> executable/render path
- compile diagnostics retrieval APIs

### Stop Gate

Equivalent parser DSL and AST-builder programs produce equivalent behavior for a parity scene that includes:

- component invoke
- fills/slots/children
- state overlays
- expression-based styling

## Phase 5 - Full Expression and Reference Parity (Host-Side AST Path)

### Goal

Cover the complete DSL value/expression surface required to drive all configurable behavior through AST and C API.

### Work Items

- Add missing expression kinds identified in Phase 1
- Support expression attachment to all DSL operation args
- Support param/arg resolution semantics used by components/variants
- Support token refs and recipe call expressions in `use(...)` and value positions
- Document unsupported Terra/Lua-only expression forms explicitly

### Deliverables

- full expression AST constructors in C API
- compiler support for all portable expression kinds
- parity tests for expression-driven behavior across all config blocks and states

### Stop Gate

No core DSL feature still requires an ad-hoc C API setter because expression support is missing.

## Phase 6 - Themes, Tokens, and Recipes Full Parity (Host-Side AST Path)

### Goal

Achieve full portable parity for theme/token/recipe semantics through AST and canonical compiler.

### Work Items

- Ensure `ThemeDecl`, `TokenDecl`, `RecipeDecl` are fully constructible in C API
- Implement recipe call AST path for `use(...)`
- Route recipe and token resolution through canonical compiler path
- Define and document extension points for host-provided recipes if needed
- Ensure diagnostics cover unknown token/recipe and bad recipe args

### Deliverables

- complete theme/token/recipe AST C API support
- parity tests for theme and recipe behavior
- documented portability boundary for non-AST Lua recipes if any remain

### Stop Gate

Parser DSL and C API AST can express and compile equivalent themed/recipe-driven scenes without a separate implementation path.

## Phase 7 - Conformance Test Harness (Parser DSL vs AST Builder)

### Goal

Make parity measurable and enforceable.

### Work Items

- Build a parity corpus with paired scenes:
  - parser DSL source/programmatic AST
  - equivalent C API AST build
- Compare compiled/runtime results using deterministic checks:
  - render command sequence/types/order
  - element IDs
  - layout bounds
  - text content/style values where inspectable
  - runtime state-dependent behavior
  - component/variant/fill/slot expansion behavior
- Reuse existing comparison patterns where possible

### Deliverables

- dedicated DSL-vs-CAPI AST parity tests in `argile/tests/`
- CI/local `make test` coverage or explicit test target documented and run in CI

### Stop Gate

Parity corpus covers the complete target feature matrix and is green.

## Phase 8 - Binding Author Documentation and Reference Wrapper

### Goal

Make the C API usable for non-Terra users without forcing them to reverse-engineer AST semantics.

### Work Items

- Document AST C API object model and lifecycle
- Document mapping from DSL constructs to C API builders
- Document error model and diagnostics retrieval
- Document unsupported Terra/Lua-only features
- Provide one reference wrapper (recommended: LuaJIT) showing:
  - table-based DSL wrapper
  - AST build
  - compile

### Deliverables

- docs for bindings authors
- reference wrapper example

### Stop Gate

A non-Terra user can implement a small DSL wrapper using:

- host-side AST/compiler API docs (for embedded Terra/Lua integrations), or
- runtime `ui.capi` docs (for runtime-only integration), depending on the chosen integration mode.

## Phase 9 - Runtime Shared-Library ABI Expansion (Optional, Future)

### Goal

Make more of the AST builder (and eventually AST compilation) available in the shared-library `ui.capi` without duplicating semantics.

### Work Items

- Define which AST builder pieces can be implemented as Terra-exportable runtime data APIs
- Add Terra-exportable handle/storage APIs for AST/IR data where useful
- Keep compile disabled/host-only until semantic lowering is Terra-exportable
- If runtime compilation is required, implement Terra-exportable semantic lowering path that matches canonical semantics
- Add parity tests between host-side compile and runtime ABI compile (if/when runtime compile exists)

### Deliverables

- expanded `ui.capi` AST-related ABI (data builder/storage and/or compile)
- explicit capability flags describing what is runtime-exported vs host-only

### Stop Gate

No runtime ABI AST compile is shipped unless it uses canonical semantics (shared lowering) and passes parity corpus coverage.

## Phase 10 - Internal Cleanup and Deletion of Temporary Duplication

### Goal

Guarantee the codebase does not retain parallel semantic paths.

### Work Items

- Delete any temporary API-side semantic helpers that duplicate compiler logic
- Consolidate feature flags to describe final capabilities only
- Ensure `capi.t` exports are grouped and documented
- Remove stale comments/docs referring to deprecated prototype paths

### Deliverables

- single canonical semantic path confirmed in code review
- final feature flags and docs aligned with shipped implementation

### Stop Gate

No duplicate CAPI semantic engine/evaluator exists.

## Test Strategy (Detailed)

## Test Categories

### 1. AST Builder Correctness Tests

Focus:

- handle allocation and destruction
- stale handle detection
- owner mismatch detection
- invalid kind errors
- graph structural constraints

### 2. Compiler Acceptance Tests (C API AST -> canonical compiler)

Focus:

- compile succeeds/fails correctly
- diagnostics are surfaced through C API
- parser-equivalent AST accepted

### 3. Parity Conformance Tests (Parser DSL vs C API AST)

Focus:

- equivalent runtime output
- equivalent element data and IDs
- state overlay behavior
- component expansion semantics
- variant behavior
- theme/token/recipe outcomes

### 4. Regression Tests

Every bug fix in AST C API or canonical compile integration adds a regression test. Prioritize:

- text inheritance and wrapper semantics
- `id(...)` behavior and element lookup
- slot/fill children insertion ordering
- variant filtering/selection
- state precedence
- recipe/token resolution edge cases

## Parity Corpus Coverage Matrix (Required)

The parity corpus must include explicit cases for:

- bare `el` and `text`
- nested nodes with styling
- text id and runtime state interaction
- component with params
- component with variants and invalid value diagnostics
- slot fallback behavior
- fill replacement behavior
- children marker insertion behavior
- invocation body `id(...)` override
- multiple state overlays with precedence interactions
- `use(...)` recipe application
- theme token references
- expression-driven config values in `layout`, `style`, `typography`, `paint`

## Migration and Rollout Rules

## Rules to Prevent Drift During Implementation

- No C API feature lands unless it maps to AST construction or canonical compiler integration
- No separate CAPI semantic interpretation code is allowed
- If a feature is hard to express in C API, extend AST/compiler contract first
- All new C API AST compile features require parser-vs-CAPI parity coverage before considered complete

## Commit Discipline (Recommended)

- one concern per commit:
  - AST schema change
  - compiler input refactor
  - C API AST handle infrastructure
  - compile entry integration
  - parity tests
- avoid mixed "feature + refactor + export + docs" commits when possible

## Acceptance Criteria (Definition of Done)

The project-level DSL AST API effort is done when all of the following are true:

- Host-side AST builder APIs can build Argile AST programs (full portable surface)
- AST-builder-produced ASTs compile through the same canonical compiler path as parser-produced ASTs
- Parser DSL and AST-builder AST are behaviorally equivalent across the parity corpus
- Themes/tokens/recipes/components/variants/states/`use(...)` portable semantics are supported
- Diagnostics are available and actionable through the AST builder/compile API
- No duplicate API-only semantic engine exists in the codebase
- Documentation is sufficient for a bindings author to build a host-language DSL wrapper

### Additional Acceptance Criteria for Runtime Shared-Library ABI (If Pursued)

- `ui.capi` exposes only Terra-exportable functions/structs/constants
- Any AST-related runtime ABI capability is explicitly feature-flagged
- If runtime ABI AST compilation exists, it uses canonical/shared semantics and passes parity corpus tests

## Open Questions (To Resolve Early, Not Leave Implicit)

These questions must be answered during Phase 1/2, not deferred indefinitely:

- Is `argile/src/lang/ast.t` directly usable as canonical AST, or do we need a normalized AST layer?
- Which current DSL features depend on Lua/Terra-only constructs and need explicit portable boundaries?
- What exact compile artifact should host-side `CapiDslAstCompile*` return/expose for non-Terra callers embedding Terra/Lua?
- Is runtime shared-library AST compilation actually required for project goals, or is host-side compile + runtime `ui.capi` sufficient?
- How much source metadata should the C API support for third-party DSL parsers?
- What compiler state must become explicit to support reentrant compilation from C API?

## Immediate Next Steps (After Adopting This Document)

These are not "minimal" completion criteria. They are the first implementation steps under the full architecture.

1. Commit this document update.
2. Continue Phase 1/2 canonical AST + compiler refactors (already started) until the AST contract is fully explicit.
3. Implement host-side handle-based `CapiDslAst*` (or `DslAst*`) builder on top of `lang/ast.t`.
4. Add host-side compile entrypoints that call `dsl_compiler`.
5. Only then decide which AST builder portions should be exported through `ui.capi` in Terra-exportable form.

## Summary

The correct Argile DSL API architecture is AST-first and semantics-canonical.

That means:

- host-side AST builder + compiler APIs for full language power today
- runtime shared-library `ui.capi` for stable runtime bindings today
- no duplicate semantic engines in either path

Bindings users should be able to recreate DSL ergonomics in their own languages on top of low-level AST APIs (host-side first, runtime ABI later if implemented).

The implementation plan in this document is deliberately full-scope and explicit so the team does not repeat the pattern of building a fast side path that later becomes a maintenance burden, while also respecting Terra's real export/runtime boundaries.
