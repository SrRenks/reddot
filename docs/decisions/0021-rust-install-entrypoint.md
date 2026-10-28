# ADR 0021: Rust quickstart entry point

- Status: first integration exists; quickstart dry-run only
- Date: 2026-10-28

## Context

The bundle can build all cores, but no process connected them. A first entry
point should prove the integration without changing the live system or pretending
the interactive flow is finished.

## Decision

`tools/reddot-install.rs` accepts `--quickstart --dry-run` and chains:

```text
reddot-detect
reddot-plan
reddot-report
reddot-run --dry-run
reddot-deploy (plan)
reddot-neutralize (plan)
reddot-post (dry-run)
```

It requires an explicit `--bin-dir`, so tests can use a temporary bundle. The
interactive wizard, real apply, fallback step generation and install.sh handoff
are not wired yet; they are rejected rather than silently guessed.

## Verification

- `tools/test-reddot-install-rust.sh` builds the complete bundle, runs the
  quickstart dry-run in a temporary config root and checks detection, commands and
  completion.
- No live config is touched.

## Consequences

The cores now have a runnable integration test. Completing the installer needs
the wizard, fallback step generation, apply path, report integration and the
`install.sh` switch.
