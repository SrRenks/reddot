# ADR 0012: Rust TUI input

- Status: implemented; the orchestrator still uses Python
- Date: 2026-10-28

## Context

The renderer was already byte-compatible with Python. The remaining TUI work was
the raw terminal and the three prompt state machines: single choice, multiselect
and confirmation.

## Decision

`tools/reddot-tui.rs` now opens the controlling terminal read/write, saves the
`stty` state, enters raw/no-echo mode with `min 0 time 1`, and restores the state
on drop. It decodes arrows, Enter, space, Escape and Ctrl-C, and implements
`select_one`, `select_many` and `confirm` with in-place redraw and a collapsed
answer row on submission.

The binary's `--demo` path exercises all three prompts. `--width` keeps rendering
deterministic. The Python TUI remains the orchestrator's entry point until the
installer flow moves.

## Verification

- `tools/test-reddot-tui-rust.sh` still checks the full render against Python.
- A pseudo-terminal smoke run feeds `j`, Enter, space, Enter, Enter to `--demo`;
  it exits 0 and the final screen contains the collapsed `Ready` answer.
- The build has no warnings.

## Consequences

The TUI is functionally complete in Rust for the prompt layer. The remaining
installer work is the orchestration and entry point.
