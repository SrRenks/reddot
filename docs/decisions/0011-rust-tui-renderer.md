# ADR 0011: Rust TUI renderer

- Status: rendering layer implemented and parity-tested; input layer still Python
- Date: 2026-10-28

## Context

The installer TUI has two parts: deterministic rendering and a terminal raw-mode
input loop. Rendering can be compared byte for byte; input needs `/dev/tty`,
termios and a key loop. Splitting them keeps the migration verifiable.

## Decision

`tools/reddot-tui.rs` renders:

- torii banner, detected rows and info blocks;
- step headers, gutters and spacers;
- bracket-wrapped answers;
- single-choice and multiselect menus;
- confirmation blocks;
- the closing summary and outro.

The renderer has a fixed width and honours `NO_COLOR`. Raw key handling,
`select_one`, `select_many` and `confirm` still run in Python.

## Verification

- 3 Rust unit tests cover visible width, clipping and wrapping.
- `tools/test-reddot-tui-rust.sh` compares a full sample render with Python at
  width 80 and `NO_COLOR=1`.
- `check-static.sh` builds and tests the renderer.

## Consequences

The visual contract now has a Rust implementation. The next phase is the raw
input loop and prompt state machines, then the orchestrator and entry point.
