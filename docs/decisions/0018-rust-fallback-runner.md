# ADR 0018: fallback execution in the package runner

- Status: implemented in the runner; entry point still Python
- Date: 2026-10-28

## Context

Fallback steps are described as JSON (`desc` plus `run` argv or `shell`). The
package runner needs to execute those steps in order and fail-soft, while a dry
run still prints the exact command.

## Decision

`reddot-run.rs` accepts `--fallbacks-json PATH` and executes each step after the
native/AUR batches, before services:

- `run`: quoted argv;
- `shell`: `sh -c`;
- missing steps are rejected;
- a failed step increments the failure count and exits nonzero after the pass.

No fallback runs in the tests; the dry-run test checks the order and quoting.

## Verification

`tools/test-reddot-run-rust.sh` now checks the fallback dry-run lines in addition
to package and service ordering.

## Consequences

The runner covers packages, AUR, fallbacks and services. The remaining
orchestrator work is the report, wizard-to-runner wiring and the Rust entry point.
