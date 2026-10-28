# ADR 0019: Rust install summary

- Status: summary core implemented; orchestrator still Python
- Date: 2026-10-28

## Context

`_summary_lines` is the go/no-go text before deployment. It combines the plan
counts, repository and fallback names, Gentoo specifics, SDDM/GRUB/Brave/fish
choices and whether this is an update.

## Decision

`tools/reddot-report.rs` builds the same summary from the plan JSON and explicit
flags. It prints one line per statement in the same order as Python.

The closing report (`_report`) still uses the Python TUI; its renderer already
exists in Rust and will move with the entry point.

## Verification

- `tools/test-reddot-report-rust.sh` compares the full summary against
  `_summary_lines` and checks `--no-deps`, SDDM, GRUB and Brave flags.
- `check-static.sh` builds the binary and runs the test.

## Consequences

The pre-deploy summary is covered. Remaining orchestrator work is the runner
wiring, closing report, entry point and removal of Python fallbacks.
