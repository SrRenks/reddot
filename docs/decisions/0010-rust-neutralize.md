# ADR 0010: Rust neutralize core

- Status: implemented as a verified core, not wired into the installer yet
- Date: 2026-10-28

## Context

`neutralize()` is the content-sensitive half of deploy: monitors, env, hypridle
home paths, fish portability and the fastfetch render. Getting these wrong can
reset a user's layout or break the first terminal render.

## Decision

`tools/reddot-neutralize.rs` implements the same steps and preserves the
pristine-only guard: a file that differs from the repo copy is left untouched.
It reads the live cached palette when valid and falls back to the static palette.
Plans are the default; `--apply` writes.

## Verification

- 3 Rust unit tests cover fish stripping, ANSI colour conversion and flat palette
  parsing.
- `tools/test-reddot-neutralize-rust.sh` deploys both implementations into
  separate roots, compares the neutralize plan with normalized roots/HOME, applies
  both and compares every resulting file.
- No live config is touched.

## Consequences

The ownership core and the neutralization core are now separate Rust units. The
installer still calls Python until the TUI and orchestrator move. The deploy core
and this module can then become the entry point without changing the file
contracts.
