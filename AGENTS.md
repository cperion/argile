# Repository Guidelines

## Project Structure & Module Organization
This repository is at project start: we are building a Terra library by porting behavior from `ref/clay.h`, and most content is documentation.
- `docs/design.md`: architecture blueprint for the Terra-native UI engine.
- `docs/ai-guide.md`: implementation mapping from Clay C APIs to Terra targets.
- `docs/terra/getting-started.md` and `docs/terra/api.md`: Terra setup, syntax, and semantics references.
- `ref/clay.h`: upstream Clay reference header used for exact behavior parity.

When code is added, separate concerns (`src/`, `tests/`, `examples/`) and mirror `ui` namespace names.

## Build, Test, and Development Commands
No project-local build/test scripts are committed yet. Current useful commands are:
- `rg --files`: list tracked project files quickly.
- `rg "pattern" docs ref`: locate function or struct references.
- `wc -l ref/clay.h`: gauge reference file size before targeted ports.

If you add runnable code, document stable entry points in `README.md` (for example `make test`, `make lint`).

## Coding Style & Naming Conventions
Follow conventions from `docs/design.md`, `docs/ai-guide.md`, and `docs/terra/*`:
- Use the `ui` namespace; avoid `Clay_` / `CLAY__` prefixes in new Terra code.
- Prefer data-oriented, flat-array designs and arena allocation patterns.
- Keep ports behaviorally exact to `ref/clay.h`; change syntax, not logic.
- Before adding Terra syntax features, verify behavior and idioms against `docs/terra/api.md`.

## Testing Guidelines
Until a test harness exists, validate ports by deterministic comparison against Clay behavior.
- Place future tests under `tests/` with names like `*_spec.t` or `test_*.terra` (pick one pattern and stay consistent).
- Cover layout sizing passes, text wrapping, hash stability, and render command ordering.
- Add regression tests for each bug fix in layout math or hashing.

## Commit & Pull Request Guidelines
Git history is not available in this workspace snapshot, so adopt a strict baseline:
- Commit format: `type(scope): imperative summary` (for example `feat(layout): port y-axis sizing pass`).
- Keep commits focused; avoid mixing refactors with behavior changes.
- PRs should include: purpose, files changed, linked sections from `docs/ai-guide.md` and `docs/terra/*`, and validation notes.
- Include before/after output or screenshots for visual layout changes.

## Security & Configuration Tips
- Treat `ref/clay.h` as authoritative reference input; avoid editing it unless intentionally updating upstream parity.
- Do not introduce dynamic allocation paths that bypass the arena model without explicit design approval.
