# Argile Runtime Element Inspection (`GetElementData`)

Status: Draft M0 reference

Date: 2026-02-24

Related:
- `docs/argile-kernel-direction-rfc.md`
- `docs/argile-kernel-execution-program.md` (`K0-010`, `K0-011`)

## Purpose

This document defines the practical behavior contract for runtime element inspection via `GetElementData(...)`.

It exists to support bindings, backend demos, and debug tooling.

## API Surface (Current)

The runtime C API exports:

- `GetElementData(struct ElementId) -> struct ElementData`
- `SetDebugModeEnabled(bool)`
- `IsDebugModeEnabled(void) -> bool`

`ElementData` currently contains:

- `boundingBox`
- `found`

## Behavior Contract (Current + Recommended Usage)

### 1. Query timing

Recommended usage:
- query `GetElementData(...)` after layout finalization for the current frame

Reason:
- element bounding boxes are only meaningful after the engine has finished computing final layout positions

Practical rule for bindings/demos:
- `BeginLayout`
- build UI tree
- `FinalizeLayout` / `EndLayout`
- then call `GetElementData(...)`

### 2. Current-context dependency

`GetElementData(...)` is current-context based.

Implication:
- callers must ensure the correct context is current before querying

Binding recommendation:
- wrappers should either:
  - set the context current internally before querying, or
  - clearly document that the caller must do so

The official LuaJIT wrapper now sets the context current in its context helper (`ctx:get_element_data(...)`).

### 3. Missing element behavior

If an element ID is not present (or no valid bounding box exists for it in the current frame):

- `found == false`
- `boundingBox` fields are returned zeroed (`x=0`, `y=0`, `width=0`, `height=0`)

Consumers must check `found` before using the box.

### 4. No current context behavior

If no current context is set when `GetElementData(...)` is called:

- `found == false`
- `boundingBox` is zeroed

This is the expected safe failure mode for debug tooling and bindings.

### 5. Debug mode interaction

Debug mode toggles (`SetDebugModeEnabled`, `IsDebugModeEnabled`) do not change the `GetElementData(...)` return type.

Debug mode may enable additional diagnostics elsewhere, but `GetElementData(...)` remains a stable inspection path.

## What `boundingBox` Represents (M0 expectation)

For M0 debugging workflows, `boundingBox` should be interpreted as:

- the final computed box for the element in the current frame

If future features (scroll/overflow) introduce ambiguity between logical-content boxes and final visual boxes, that distinction must be documented explicitly and ideally exposed via an additive debug API.

## Binding and Demo Guidance

### LuaJIT (`argile_lj`)

Preferred helper:
- `ctx:get_element_data("element_name")`

This helper:
- accepts a string name or an `ElementId`
- sets the current context before querying
- converts `ElementData` to a Lua table (`found`, `x`, `y`, `width`, `height`)

### Debug overlays

A reliable debug overlay loop should:

1. finalize layout
2. query a stable set of IDs
3. check `found`
4. draw outlines/labels using the returned box

Avoid guessing layout state from visual artifacts alone when `GetElementData(...)` is available.

## Test Expectations (M0)

At minimum, regression coverage should verify:

1. valid element returns `found == true` after finalize
2. missing element returns `found == false`
3. no current context returns `found == false`

These cases are sufficient to make binding wrappers and demo overlays dependable.
