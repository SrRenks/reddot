# ADR 0016: Rust package runner

- Status: package phase implemented; orchestrator still Python
- Date: 2026-10-28

## Context

The plan separates native, AUR, repositories and Portage work. The package runner
must execute those batches in order, fail-soft, and print the exact command in a
dry run.

## Decision

`tools/reddot-run.rs` consumes the plan JSON and executes:

1. package-index refresh;
2. repository steps;
3. the native batch, with Fedora's `--skip-broken`;
4. the AUR batch through the chosen helper.

Dry-run prints the same quoted commands. Failures are reported and the process
exits nonzero; a dry run always succeeds.

Fallbacks and services stay in the orchestrator until the next integration step.

## Verification

- 2 Rust unit tests cover batch shape and shell quoting.
- `tools/test-reddot-run-rust.sh` checks the exact dry-run order for refresh,
  native and AUR with `doas` and `paru`.
- No package manager runs in the test.

## Consequences

The package phase has a Rust executor. The remaining orchestrator work is choices,
fallbacks, services, report and entry point.
