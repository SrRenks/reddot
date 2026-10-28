# ADR 0026: reinstall through the Rust path

- Status: implemented; Python remains only as a toolchain-less fallback
- Date: 2026-10-28

## Context

`install.sh` still routed `--reinstall` to Python because the Rust entry point
had no explicit flag. The default apply flow already handles an existing managed
install through the deploy core.

## Decision

`install.sh` now attempts the Rust bundle for every non-uninstall invocation when
`rustc` exists. `reddot-install --reinstall` is accepted as an explicit apply
alias. Uninstall keeps its own Rust path.

## Verification

- `sh -n install.sh` passes.
- `tools/test-reddot-install-rust.sh` covers quickstart dry-run and isolated
  apply/uninstall.
- A reinstall uses the same apply path; no separate code path can drift.

## Consequences

Python remains only when `rustc`/bundle build is unavailable. The wizard still
covers profile and AUR; optional apps and the final report remain incomplete.
