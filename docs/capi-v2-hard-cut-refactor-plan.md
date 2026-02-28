# Argile CAPI v2 Hard-Cut Refactor Plan

Status: Execution plan (design-phase)

Date: 2026-02-28

Companion spec:
- `docs/capi-v2-hard-cut-spec.md`

## 1. Objective

Execute a **hard-cut migration** from CAPI v1 element-construction APIs to CAPI v2 descriptor APIs with no compatibility layer.

Primary success conditions:

1. v1 element-construction symbols are fully removed from exports.
2. v2 descriptor open path is the only non-text element construction path.
3. All in-repo call sites (bench, bindings, tests, tools) are migrated.
4. Build/test/parity/bench workflows run against v2 only.

## 2. Non-Negotiable Constraints

1. No compatibility wrappers in CAPI exports.
2. No dual-path maintenance (`Attach*` plus descriptor) after cutover.
3. API version bump to `ARGILE_API_VERSION = 2` is mandatory.
4. Generated headers/ffi must reflect only v2 element-construction surface.

## 3. High-Level Program Map (Illustrated)

```text
P0 Spec Freeze
  |
  v
P1 Core Types (config/init)
  |
  v
P2 Engine Implementation (context)
  |
  v
P3 Export Surface Cut (capi/build)
  |
  v
P4 In-Repo Migration (bench/tools/bindings/tests)
  |
  v
P5 Validation + Performance Baseline
  |
  v
P6 Cleanup + Doc Finalization
```

Parallel work allowed:

- P4 bindings migration can begin when P3 is on branch and symbol list is stable.
- P4 benchmark migration can proceed in parallel with P4 test migration.

Blocked dependencies:

- P3 blocked on P2.
- P5 blocked on P4.
- P6 blocked on P5.

## 4. Exact API Delta

## 4.1 Add (v2)

Required new symbols:

1. `OpenElementWithDescForContext`
2. `OpenElementWithIdAndDescForContext`
3. `OpenElementWithIdCharsAndDescForContext`

Required new types/constants:

1. `ElementDesc`
2. `ElementDescFlags`
3. `DESC_HAS_*` constants

## 4.2 Remove (v1 hard cut)

Remove from export table (`src/capi.t`):

1. `OpenElement*` family (plain/id/idChars)
2. `OpenStyledElement*`
3. `ConfigureOpenElementBox*`
4. `SetOpenElementLayoutConfig*`
5. `Attach*Config*` family
6. `AttachOverflowConfig*`
7. `ApplyOpenElementConfigs*`
8. `OpenElementWith*ConfigBundle*`

Retain:

1. `CloseElementForContext`
2. text-open APIs
3. frame/init/input/render/hash APIs

## 5. File-Level Refactor Matrix

| Area | Files | Operation |
|---|---|---|
| Core type definitions | `src/config.t` | add `ElementDesc`, flags |
| Engine implementation | `src/context.t` | add descriptor open path; remove v1 composition entry points |
| Public UI surface | `src/init.t` | remove old forwards; add v2 forwards |
| Export surface | `src/capi.t` | drop old exports; add v2 exports |
| Header/ffi generation | `tools/build_argile.t` | no algorithm change, but verify output symbol set |
| LuaJIT binding | `bindings/luajit/argile_lj/runtime.lua` | replace old attach/open flows with descriptor calls |
| Bench harness | `bench/compare.lua` | use descriptor call only for non-text elements |
| Terra bench shim | `tools/terra_bench_api.t` | migrate element creation to descriptor path |
| Tests | `tests/*` | remove v1 tests, add v2 tests |
| Docs | `README.md`, `bench/README.md` | update API usage and migration notes |

## 6. Detailed Phase Plan

## P0 - Spec Freeze

Goal:

1. Freeze `ElementDesc` layout and flag semantics.
2. Freeze removed symbol list.

Tasks:

1. Review and approve `docs/capi-v2-hard-cut-spec.md`.
2. Resolve open questions (layout default fallback, overflow representation, text descriptor deferral).
3. Record final decision log section in spec.

Exit criteria:

1. No unresolved “Open Questions” section items.
2. Symbol add/remove list committed.

## P1 - Core Types

Goal:

Add v2 descriptor and constants in config layer.

Tasks:

1. In `src/config.t` add:
   - `ui.ElementDescFlags = uint32`
   - `ui.DESC_HAS_*` constants
   - `ui.ElementDesc` struct
2. Ensure `src/init.t` re-exports new type/constants.
3. Ensure order is stable and deterministic for generated C definitions.

Implementation notes:

- Use POD fields only; no pointer members inside `ElementDesc` except existing pointer fields already inside nested config structs (e.g., paint ops).
- Keep field ordering stable to avoid accidental ABI churn.

Validation commands:

```bash
make build
rg "ElementDesc|DESC_HAS_" build/argile_api.h build/argile_api_ffi.lua
```

Exit criteria:

1. `ElementDesc` and flags exist in generated header and ffi.
2. No behavior changes yet.

## P2 - Engine Path Implementation

Goal:

Implement descriptor-driven open path in context layer.

Tasks:

1. Add internal helper in `src/context.t`:
   - `Context:applyElementDesc(desc)`
2. Add CAPI entry points:
   - `OpenElementWithDescForContext`
   - `OpenElementWithIdAndDescForContext`
   - `OpenElementWithIdCharsAndDescForContext`
3. Enforce config apply order exactly as spec.
4. Reuse existing store/attach internals (`store*Config`, `attachElementConfig`) to avoid solver changes.
5. Handle paint copy semantics using existing `storePaintConfig` path.

Pseudo flow:

```text
OpenElementWithDescForContext
  -> openElement/openElementWithId
  -> apply layout (desc or default)
  -> attach shared/border/clip/aspect/image/custom/floating/paint by flags
  -> return bool
```

Validation commands:

```bash
make test
```

Exit criteria:

1. New open API works with direct unit coverage.
2. No use of removed APIs required by engine internals.

## P3 - Export Surface Hard Cut

Goal:

Remove v1 construction symbols from public CAPI.

Tasks:

1. Edit `src/capi.t` export table:
   - delete removed symbol list
   - add v2 descriptor symbols
2. Edit `src/init.t` public forwards:
   - delete removed forwards
   - add new forwards
3. Bump `ARGILE_API_VERSION` in `src/context.t` from `1` to `2`.
4. Rebuild and verify generated outputs.

Validation commands:

```bash
make build
rg "OpenElementWithDescForContext|OpenElementWithIdAndDescForContext" build/argile_api.h
rg "AttachBorderConfigForContext|ConfigureOpenElementBoxForContext|OpenElementWithConfigBundleForContext" build/argile_api.h && false || true
```

Exit criteria:

1. Old symbols absent from `build/argile_api.h` and `build/argile_api_ffi.lua`.
2. New v2 symbols present.
3. API version is 2.

## P4 - In-Repo Call-Site Migration

Goal:

Update all in-repo consumers to v2 APIs.

### P4-A Bench (LuaJIT)

Files:

- `bench/compare.lua`

Tasks:

1. Replace non-text open paths with `ElementDesc` construction and one open call.
2. Keep text paths on `OpenTextElementWithLengthForContext`.
3. Preserve strict parity checks and fair-mode mechanics.

### P4-B Terra Bench Shim

Files:

- `tools/terra_bench_api.t`

Tasks:

1. Replace old compose steps with descriptor call path.
2. Keep benchmark scenario equivalence with Clay.

### P4-C LuaJIT Binding Runtime

Files:

- `bindings/luajit/argile_lj/runtime.lua`

Tasks:

1. Remove runtime methods that rely on removed attach/configure APIs.
2. Introduce descriptor constructor helpers (Lua table -> `struct ElementDesc`).
3. Expose one `open_element_desc(...)` method.
4. Ensure existing wrapper users fail loudly if still calling removed methods.

### P4-D Tests

Files:

- add: `tests/test_capi_element_desc.t`
- add: `tests/test_capi_element_desc_errors.t`
- update/remove tests that call removed symbols.

Test cases (minimum):

1. descriptor with layout+shared renders expected rectangle command.
2. descriptor with border/custom/image/aspect toggles attaches correct config types.
3. id variants map correctly.
4. missing context returns false.
5. paint copy path works.

Validation commands:

```bash
make test
make bench-quick
make build-bench-c
make bench-c-heavy
```

Exit criteria:

1. No in-repo source references removed symbols.
2. Bench and test suites compile/run on v2 surface.

## P5 - Validation and Performance Gate

Goal:

Validate functional parity and benchmark characteristics after hard cut.

Tasks:

1. Run regression matrix:
   - `make test`
   - `make parity-quick`
   - `make bench-quick`
   - `make bench-c-heavy`
2. Confirm benchmark checksum behavior:
   - expected text mismatch remains explicit until text parity task is completed.
3. Capture before/after for config-heavy scenario (`Config churn mixed`).

Acceptance thresholds:

1. No new parity mismatch categories beyond known text issue.
2. Config-heavy benchmark no longer regresses from API call-shape overhead.

## P6 - Cleanup and Final Docs

Goal:

Remove dead code and finalize docs for v2-only world.

Tasks:

1. Delete dead helper code in `src/context.t` tied only to removed symbols.
2. Remove outdated docs mentioning attach/configure compose style.
3. Update README/bench docs/binding docs with descriptor-first examples.
4. Add migration note entry summarizing hard cut.

Exit criteria:

1. No dead exported or internal entry points for removed v1 construction APIs.
2. Docs show only v2 descriptor usage.

## 7. Symbol and Reference Audit Checklist

Run these checks during P3-P6.

### 7.1 Removed Symbol Detection

```bash
rg "OpenStyledElement|ConfigureOpenElementBox|Attach(Border|Clip|Custom|Image|Aspect|Paint|Shared|Floating)|OpenElementWithConfigBundle|ApplyOpenElementConfigs" src bindings tools bench tests
```

Expected final result:

- no runtime code references removed symbols.

### 7.2 v2 Symbol Presence

```bash
rg "OpenElementWithDescForContext|OpenElementWithIdAndDescForContext|OpenElementWithIdCharsAndDescForContext|ElementDesc|DESC_HAS_" src build
```

Expected final result:

- all present in source and generated outputs.

## 8. Detailed Risk Register

| Risk | Impact | Probability | Mitigation |
|---|---|---|---|
| Descriptor layout churn during implementation | ABI break noise | Medium | freeze field order in spec before coding |
| Hidden references to removed symbols in bindings/tools | build failures late | High | run symbol audit in every phase |
| Behavior drift from changed config apply order | parity regressions | Medium | enforce spec order + dedicated tests |
| Paint ownership mistakes | crashes/data corruption | Medium | explicit tests for copied ops and null checks |
| Hard cut lands without docs sync | user confusion | High | P6 requires docs completion gate |

## 9. Rollout and Branch Strategy

Recommended branch model:

1. `feature/capi-v2-desc-hard-cut` main integration branch.
2. One commit per phase milestone where possible.
3. Avoid mixed commits (spec + engine + bindings all at once) except final squash if desired.

Suggested commit sequence:

1. `docs(capi): add v2 hard-cut spec and plan`
2. `feat(capi): add element desc types and flags`
3. `feat(context): implement descriptor open APIs`
4. `refactor(capi): remove v1 construction exports, bump api version`
5. `refactor(bench): migrate to descriptor path`
6. `refactor(bindings): migrate luajit runtime to descriptor path`
7. `test(capi): add descriptor API coverage`
8. `docs(capi): finalize v2-only usage docs`

## 10. Verification Matrix

| Gate | Command | Expected |
|---|---|---|
| Build | `make build` | success, v2 header/ffi generated |
| Unit tests | `make test` | all pass |
| Parity quick | `make parity-quick` | pass with existing tolerances |
| LuaJIT bench quick | `make bench-quick` | runs, strict parity only fails on known text mismatch until fixed |
| C bench heavy | `make bench-c-heavy` | runs, reports explicit parity summary |
| Symbol removal | `rg` audit commands | no v1 construction references |

## 11. Illustrated Data-Path Before/After

### Before (v1 compose model)

```text
Caller
  -> OpenElement
  -> ConfigureOpenElementBox
  -> AttachBorder?
  -> AttachClip?
  -> AttachCustom?
  -> AttachImage?
  -> AttachAspect?
  -> CloseElement
```

### After (v2 descriptor model)

```text
Caller
  -> Fill ElementDesc{flags + configs}
  -> OpenElementWithDesc
  -> CloseElement
```

### Engine Internal (v2)

```text
OpenElementWithDesc
  +-- open element node
  +-- apply layout/default
  +-- attach configs by flag in fixed order
  +-- return bool
```

## 12. Definition of Done

All must be true:

1. `ARGILE_API_VERSION == 2`.
2. Removed v1 construction APIs are absent from generated CAPI artifacts.
3. All in-repo callers compile and run against v2.
4. Benchmark and parity paths are v2-only for non-text element construction.
5. Docs and binding guidance are v2-only and descriptor-centric.

## 13. Immediate Next Actions

1. Approve this execution plan and spec.
2. Start P1 on `src/config.t` + `src/init.t`.
3. Implement P2 in `src/context.t`.
4. Cut exports in P3 and migrate bench/binding/tests in P4.
