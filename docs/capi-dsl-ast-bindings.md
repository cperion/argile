# Argile DSL AST Host API for Bindings Authors

This document explains how to use the host-side Argile DSL AST API (`CapiDslAst*`) to build Argile AST programs and compile them through the canonical Argile compiler.

This is the low-level API intended for bindings/wrapper authors who want to rebuild Argile ergonomics in another host language while preserving canonical semantics.

Ownership note:

- official language bindings and backend reference demos are part of the `argile` repository/module
- higher-level widget kits (such as `argile-ui`) should sit on top of those bindings/runtime APIs instead of re-owning engine bindings

For the LuaJIT-specific layering/compatibility contract between engine bindings (`argile_lj`) and downstream widget bindings, see:

- `docs/luajit-binding-layering.md`

## Scope and Phase Boundary

Argile currently exposes two different integration surfaces:

- Host-side DSL AST + compiler API (Lua/Terra process): `ui.GetDslAstApi()`
- Runtime shared-library ABI (`ui.capi`): Terra-exported runtime APIs only

Important:

- `ui.GetDslAstApi()` is **host-side** and uses Lua/Terra modules.
- It is **not** part of the shared-library `ui.capi` export set.
- This is because `dsl_compiler` is host-side Lua/Terra metaprogramming and cannot be exported via `terralib.saveobj`.

The architecture still remains canonical:

- Parser DSL -> AST -> canonical compiler
- Host AST API -> AST -> canonical compiler

No duplicate semantics are implemented in the AST host API.

## Chosen Shipping Strategy (Current)

For official bindings (including LuaJIT FFI), the recommended near-term shipping model is:

- one `libargile.so`
- two API families inside that library:
  - runtime ABI (`ui.capi` style runtime/layout/render/input APIs)
  - compiler-host ABI (embedded Lua/Terra compiler contexts calling canonical `dsl_compiler`)
- compile-on-change with cache (not compile every frame)

This keeps one artifact for users while preserving the real execution-phase boundary.

Repository reference implementation (LuaJIT):

- `bindings/luajit/argile_lj/runtime.lua` (runtime `ui.capi` FFI wrapper)
- `bindings/luajit/argile_lj/ast.lua` (canonical AST reuse from `src/lang/ast.t`)
- `bindings/luajit/argile_lj/dsl.lua` (LuaJIT-native AST/DSL builders)
- `bindings/luajit/argile_lj/compiler.lua` (host compiler export detection / boundary reporting)
- `bindings/luajit/README.md` (package-level guide)
- `tools/experiment_luajit_ffi_surface_probe.lua` (runtime + callback + AST/DSL probe)
- `argile-ui/platforms/love2d/luajit/demo_ffi/` (reference app integration using the official LuaJIT binding)

Important:

- the compiler-host ABI is not the same thing as `ui.capi`
- the current canonical compiler is not directly exportable through Terra `saveobj`
- runtime AST compilation inside Terra-exported `ui.capi` remains a future option only if semantic lowering becomes Terra-exportable

## Where to Get the API

```lua
local ui = require("src.init")
local Ast = ui.GetDslAstApi()
```

The returned table aggregates:

- AST builder functions (`src/capi_dsl_ast.t`)
- host-side compile functions (`src/capi_dsl_compile.t`)
- host compiler context/cache functions (`src/capi_dsl_host_compiler.t`)
- host API feature flags (`src/capi_dsl_host.t`)

## Feature Flags (Host AST API)

Use capability checks instead of guessing what the host API supports:

- `CAPI_DSL_AST_FEATURE_CORE`
- `CAPI_DSL_AST_FEATURE_EXPRS`
- `CAPI_DSL_AST_FEATURE_COMPONENTS`
- `CAPI_DSL_AST_FEATURE_THEMES`
- `CAPI_DSL_AST_FEATURE_RECIPES`
- `CAPI_DSL_AST_FEATURE_COMPILE`
- `CAPI_DSL_AST_FEATURE_COMPILE_CACHE`
- `CAPI_DSL_AST_FEATURE_CALLBACK_BACKEND`
- `CAPI_DSL_AST_FEATURE_SOURCE_META`
- `CAPI_DSL_AST_FEATURE_DIAGNOSTICS`

Helpers:

- `CapiDslAstGetFeatureFlags()`
- `CapiDslAstHasFeature(flag)`

## Object Model and Ownership

### Builder Context Owns Everything

Create a builder first:

```lua
local b = Ast.CapiDslAstCreateBuilder()
```

The builder owns all AST objects created under it:

- programs
- declarations
- nodes
- states
- invokes/fills
- expressions
- ops
- strings embedded in AST values/tables you provide remain your responsibility if mutable

Destroying the builder invalidates all handles:

```lua
Ast.CapiDslAstDestroyBuilder(b)
```

Calling any API with a stale handle or destroyed builder raises an error.

### Handles Are Typed and Builder-Scoped

Every constructor returns an opaque handle table (host-side representation) that includes:

- builder identity
- object pool kind
- slot/generation

This gives:

- stale-handle detection
- owner/builder mismatch detection
- kind checking on API calls

Do not mutate handle internals.

## AST Construction Workflow

### 1. Create Program

```lua
local program = Ast.CapiDslAstCreateProgram(b)
```

A program contains:

- top-level declarations (`theme`, `component`)
- root body items (`el`, `text`, invokes, splices)

### 2. Add Declarations

Supported top-level declaration handles:

- `Theme`
- `Component`

```lua
local theme = Ast.CapiDslAstCreateTheme(b, "design")
Ast.CapiDslAstProgramAddDecl(b, program, theme)
```

Duplicate top-level declaration names are rejected (`theme`/`component`).

### 3. Build Nodes and Invocations

Node constructors:

- `CapiDslAstCreateNodeElement`
- `CapiDslAstCreateNodeText`

Invocation/fill constructors:

- `CapiDslAstCreateInvoke`
- `CapiDslAstCreateFill`

State overlays:

- `CapiDslAstCreateStateOverlay`

### 4. Build Expressions and Ops

Expressions are first-class AST objects and should be used wherever DSL values are accepted.

Expression constructors include:

- literals: `CreateExprLiteral`, `CreateExprBool`, `CreateExprInt`, `CreateExprFloat`, `CreateExprString`
- `CreateExprSymbol`
- `CreateExprTokenRef`
- `CreateExprPathRef`
- `CreateExprCall`
- `CreateExprLua` (host-only escape hatch, not portable)

Operations:

- `CapiDslAstCreateOp(name)`
- `CapiDslAstOpAddArgExpr(...)`

Attach ops to blocks:

- node: `CapiDslAstNodeAddOp(..., "layout"|"style"|"typography"|"paint", op)`
- state overlay: `CapiDslAstStateAddOp(..., "style"|"typography"|"paint", op)`
- recipe body: `CapiDslAstRecipeAddOp(..., blockKind, op)`

### 5. Attach Expressions to Directives

Examples:

- `CapiDslAstNodeSetIdExpr`
- `CapiDslAstNodeSetTextExpr`
- `CapiDslAstInvokeSetArgExpr`
- `CapiDslAstInvokeSetIdExpr`
- `CapiDslAstTokenSetValueExpr`
- `CapiDslAstNodeAddUseExpr`

## Mapping from DSL to AST Host API

### Theme / Token / Recipe

DSL:

```argile
theme design
    token color.surface = { r = 0.1, g = 0.2, b = 0.3, a = 1.0 }
    recipe card()
        style
            bg(token(color.surface))
        end
    end
end
```

Host AST API shape:

```lua
local theme = Ast.CapiDslAstCreateTheme(b, "design")
local tok = Ast.CapiDslAstCreateToken(b, "color.surface")
Ast.CapiDslAstTokenSetValueExpr(b, tok, Ast.CapiDslAstCreateExprLiteral(b, { r=0.1, g=0.2, b=0.3, a=1.0 }))
Ast.CapiDslAstThemeAddToken(b, theme, tok)

local recipe = Ast.CapiDslAstCreateRecipe(b, "card")
local op = Ast.CapiDslAstCreateOp(b, "bg")
Ast.CapiDslAstOpAddArgExpr(b, op, Ast.CapiDslAstCreateExprTokenRef(b, "color.surface"))
Ast.CapiDslAstRecipeAddOp(b, recipe, "style", op)
Ast.CapiDslAstThemeAddRecipe(b, theme, recipe)
```

### Component / Variant / Root

DSL:

```argile
component Badge(props)
    variant tone = primary | secondary
    root
        id(props.id)
        children
    end
end
```

Host AST API shape:

```lua
local comp = Ast.CapiDslAstCreateComponent(b, "Badge")
Ast.CapiDslAstComponentAddParam(b, comp, "props")

local variant = Ast.CapiDslAstCreateVariant(b, "tone")
Ast.CapiDslAstVariantAddValue(b, variant, "primary")
Ast.CapiDslAstVariantAddValue(b, variant, "secondary")
Ast.CapiDslAstComponentAddVariant(b, comp, variant)

local root = Ast.CapiDslAstCreateNodeElement(b)
Ast.CapiDslAstNodeSetIdExpr(b, root, Ast.CapiDslAstCreateExprPathRef(b, "props.id"))
Ast.CapiDslAstNodeSetChildrenMarker(b, root, true)
Ast.CapiDslAstComponentSetRootNode(b, comp, root)
```

### `use(...)` Recipe Calls

Portable host-side form uses `PathRefExpr + CallExpr`:

```lua
local callee = Ast.CapiDslAstCreateExprPathRef(b, "design.card")
local call = Ast.CapiDslAstCreateExprCall(b, callee, "named")
Ast.CapiDslAstNodeAddUseExpr(b, node, call)
```

Named args:

```lua
Ast.CapiDslAstExprCallAddNamedArg(b, call, "tone", Ast.CapiDslAstCreateExprSymbol(b, "primary"))
```

Positional args:

```lua
local call = Ast.CapiDslAstCreateExprCall(b, callee, "positional")
Ast.CapiDslAstExprCallAddPosArg(b, call, Ast.CapiDslAstCreateExprString(b, "foo"))
```

## Structural Validation (Parser-Parity Rules)

The AST host API rejects many structural errors early to match parser behavior more closely.

Examples of rejected cases:

- duplicate top-level component/theme declarations
- duplicate token declaration within a theme
- duplicate recipe declaration within a theme
- duplicate component param / variant / variant value
- duplicate component root
- duplicate node `id(...)`, `part(...)`, `slot(...)`
- duplicate invocation `id(...)`
- `slot(...)` and `children` on the same node
- duplicate `children` marker
- duplicate state overlay on a node
- duplicate invoke arg name

Component template validation also rejects:

- duplicate slot names within a component template
- duplicate sibling `part(...)` names
- reserved part name `root`

## Source Metadata / Span Attachment

Bindings often have their own parser. You can attach source metadata to AST objects for diagnostics:

- `CapiDslAstSetSourceSpan(builder, handle, file, line, column, line_end, column_end, context, user_tag)`
- `CapiDslAstSetSourceMeta(builder, handle, metaTable)`

Supported metadata fields are stored on the AST node span object (currently via `lang/argile_span.t`):

- `file`
- `line`, `column`
- `line_end`, `column_end`
- `context`
- `tag`

Example:

```lua
Ast.CapiDslAstSetSourceSpan(b, node, "mydsl.ui", 42, 9, 42, 24, "text(...)", 1234)
```

## Compile API (Host-Side Canonical Compiler)

Compile entrypoints live in the host API and call the canonical `dsl_compiler` path.

- `CapiDslAstCompileProgramQuote(builder, program, env_fn, registry?)`
- `CapiDslAstCompileProgramFunction(builder, name, program, env_fn, registry?)`
- `CapiDslAstCompileProgramRenderFunction(builder, name, program, env_fn, registry?)`

These **raise** on compile errors.

Try-style variants capture the error and return status:

- `CapiDslAstTryCompileProgramQuote(...)`
- `CapiDslAstTryCompileProgramFunction(...)`
- `CapiDslAstTryCompileProgramRenderFunction(...)`

Return convention (host-side Lua/Terra):

```lua
local ok, result, err = Ast.CapiDslAstTryCompileProgramQuote(b, program, env_fn)
```

Compile diagnostics helpers:

- `CapiDslAstGetLastCompileError(builder)` -> `{ code = <number>, message = <string> }`
- `CapiDslAstClearLastCompileError(builder)`

Builder diagnostics helpers:

- `CapiDslAstTryCall(builder, apiName, ...)`
- `CapiDslAstGetLastBuilderError(builder)` -> `{ code, message, api }`
- `CapiDslAstClearLastBuilderError(builder)`
- builder error code constants:
  - `CAPI_DSL_AST_BUILDER_ERR_NONE`
  - `CAPI_DSL_AST_BUILDER_ERR_CALL`

## Host Compiler Contexts and Compile Cache (Host-Side)

For the chosen Option 1 shipping model, wrappers should compile through an explicit host compiler context and cache results across frames/reloads.

Context lifecycle:

- `CapiDslAstHostCreateCompilerContext([options])`
- `CapiDslAstHostDestroyCompilerContext(ctx)`
- `CapiDslAstHostResetCompilerContext(ctx)`

Cache operations:

- `CapiDslAstHostGetCompileCacheStats(ctx)` -> `{ hits, misses, quote_entries, function_entries, render_function_entries, total_entries }`
- `CapiDslAstHostClearCompileCache(ctx)`
- `CapiDslAstHostInvalidateCompileCacheKey(ctx, key)`

Cached compile entrypoints:

- `CapiDslAstHostCompileProgramQuoteCached(ctx, key, builder, program, env_fn, registry?)`
- `CapiDslAstHostCompileProgramFunctionCached(ctx, key, builder, name, program, env_fn, registry?)`
- `CapiDslAstHostCompileProgramRenderFunctionCached(ctx, key, builder, name, program, env_fn, registry?)`
- `CapiDslAstHostTryCompileProgram*Cached(...)` variants

Cache key types accepted today:

- `string`
- `number`
- `boolean`

Use a stable key derived from your AST + compile options/environment.

Host compiler-context diagnostics:

- `CapiDslAstHostGetLastCompilerContextError(ctx)` -> `{ code, message, api }`
- `CapiDslAstHostClearLastCompilerContextError(ctx)`
- error code constants:
  - `CAPI_DSL_AST_HOST_COMPILER_ERR_NONE`
  - `CAPI_DSL_AST_HOST_COMPILER_ERR_INVALID_CONTEXT`
  - `CAPI_DSL_AST_HOST_COMPILER_ERR_INVALID_ARGUMENT`
  - `CAPI_DSL_AST_HOST_COMPILER_ERR_COMPILE`

## Error Model (Current Host API)

### Builder/Mutation Errors

Most AST construction/mutation functions currently raise Lua errors immediately (`error(...)`) on invalid usage:

- invalid/stale handle
- wrong builder
- wrong handle kind
- duplicate structural directives
- invalid block kind

This is intentional for host-side API simplicity, and is suitable for wrappers that use `pcall`.

If you want structured builder diagnostics, use `CapiDslAstTryCall(...)` instead of direct calls.

### Compile Errors

Compile errors can be handled via:

- direct exception (`CapiDslAstCompileProgram*`)
- try-style return (`CapiDslAstTryCompileProgram*`)
- `CapiDslAstGetLastCompileError`

## Portable vs Host-Only AST Constructs

Portable AST (bindings-friendly target):

- literals
- symbols
- token refs
- path refs
- call expressions
- standard nodes/decls/states/invokes/fills

Host-only (Lua/Terra extension boundary):

- `CapiDslAstCreateExprLua(...)`
- `CapiDslAstCreateSplice(...)`

Use these only when you explicitly depend on host-side Lua/Terra behavior. They are not portable to a plain C ABI without an equivalent runtime/compiler mechanism.

## Reference Wrapper Strategy (Recommended)

Build a small wrapper in your host language that:

1. Maps your language-native DSL/table/object shape to `CapiDslAst*` calls
2. Uses expressions as the default value path (avoid ad-hoc setters)
3. Attaches source metadata if you have your own parser
4. Compiles via `CapiDslAstCompileProgram*`
5. Treats builder lifetime as a compilation session boundary
6. Uses a compile cache keyed by AST + compiler options + environment signature

See:

- `argile/examples/host_dsl_ast_wrapper_demo.t`

## Practical Integration Modes

### A. Embedded Terra/Lua Host (Available Today)

Use the host AST API + canonical compiler + runtime APIs in one process.

This is the recommended semantic baseline and the easiest way to validate wrapper parity.

### A2. One-`.so` Hybrid (Recommended Shipping Form for LuaJIT FFI)

Ship one `libargile.so` that contains:

- runtime ABI exports (Terra `saveobj` exports; `ui.capi` family)
- compiler-host ABI exports (C shim embedding Lua/Terra and invoking canonical compiler)

Recommended behavior:

- create a long-lived compiler context
- compile on startup / source change / theme change
- cache compiled artifacts
- execute compiled artifacts via runtime APIs each frame

This avoids per-frame compile cost while preserving canonical semantics.

For environments that cannot directly expose the host compiler API cleanly, a **cached callback compile backend** (Terra -> Lua callback -> host compiler cache -> function pointer) is a valid transitional integration strategy. See:

- `argile/docs/capi-dsl-callback-compile-backend-evaluation.md`
- `argile/tools/experiment_terra_lua_callback_compile_cache.t`

### B. Runtime Shared Library (`ui.capi`) Only (Available Today)

Use runtime layout/render/input APIs only. AST compilation is not exported there yet.

This mode is runtime-only. If your wrapper wants DSL/AST compilation, you need the host compiler API surface (embedded host or one-`.so` hybrid compiler-host ABI).

### C. Future Runtime ABI AST Builder/Compile (Optional)

If Argile later adds Terra-exportable semantic lowering, parts of AST build/compile may move into `ui.capi` with capability flags. Until then, do not assume AST compilation exists in the shared library ABI.

## Compile Cache Guidance (Recommended)

Immediate-mode UI does not require recompilation every frame. Compile only when inputs change.

Cache compiled artifacts using a key that includes at least:

- canonical AST content hash
- compiler options
- theme/token inputs that affect compile-time behavior
- Argile/compiler version
- runtime ABI version (if compile artifact depends on it)

Recommended runtime behavior:

- keep previous compiled artifact active while recompiling a new version
- swap on successful compile
- surface diagnostics without tearing down the running UI

## Callback Bridge to Host Compiler (Cached Transitional Backend)

Terra can call Lua through cast function pointers. This is slower than pure-Terra paths, but it can be a practical and shippable backend when compilation is cached and happens on change instead of every frame.

Use this backend when:

- you need DSL compilation in a host-integrated environment now
- you can cache compiled artifacts
- you want canonical semantics through the host compiler path

Do **not** use this backend as:

- a per-frame compile path
- a replacement for a future pure-Terra runtime compiler if runtime AST compilation in `ui.capi` becomes a hard requirement
- a reason to duplicate semantic logic outside the canonical compiler path

Measured experiment and tradeoff discussion:

- `argile/docs/capi-dsl-callback-compile-backend-evaluation.md`

Practical user-facing framing:

- "Compilation is cached and occurs on load/change; frame execution uses compiled UI functions."
- "Runtime-only mode remains available through `ui.capi` without DSL compilation."

## Host Callback Backend Helper API (Host-Side)

Argile now includes a host-side helper API that packages the cached callback backend pattern used in the evaluation experiment:

- create backend:
  - `CapiDslAstHostCreateCallbackBackend(hostCompilerCtx, builder, program, env_fn, registry?, options?)`
- configure routes (mode -> cache key + optional global compile name):
  - `CapiDslAstHostCallbackSetRenderRoute(...)`
  - `CapiDslAstHostCallbackGetRenderRoute(...)`
- fetch pointers directly:
  - `CapiDslAstHostCallbackFetchRenderFunctionPointer(...)`
  - `CapiDslAstHostCallbackTryFetchRenderFunctionPointer(...)`
- get Terra callback function pointer (`int32 -> &opaque`):
  - `CapiDslAstHostCallbackGetFetchRenderFunctionPointerCallback(...)`
- diagnostics/stats/lifecycle:
  - `CapiDslAstHostCallbackGetLastError(...)`
  - `CapiDslAstHostCallbackClearLastError(...)`
  - `CapiDslAstHostCallbackGetStats(...)`
  - `CapiDslAstHostDestroyCallbackBackend(...)`

This helper is intended to support host-integrated bindings and future compiler shims while keeping semantics on the canonical host compiler path.

## Testing Guidance for Wrapper Authors

When adding a host-language wrapper, copy the Argile parity strategy:

- build the same scene in parser DSL and your wrapper
- compare runtime render command sequences
- compare `GetElementData(...)` for explicit IDs
- include themes/tokens/recipes/components/variants/states/`use(...)`

Current Argile references:

- `argile/tests/test_capi_dsl_ast.t`
- `argile/tests/test_dsl_ast_parity.t`
- `argile/docs/capi-dsl-ast-canonical-architecture.md`
