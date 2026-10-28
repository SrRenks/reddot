# ADR 0006: Rust package argv core

- Status: implemented as a verified core, not wired into the installer yet
- Date: 2026-10-28

## Context

`installer/pkg.py` turns a package decision into a command. It covers native
installs, repo setup, AUR bootstrap, Portage overrides and the read-only installed
query. Running those commands stays in the installer; only argv construction is
needed for this phase.

## Decision

`tools/reddot-pkg.rs` implements the same argv builders:

- native install argv for all five families;
- AUR helper selection;
- copr, PPA, OBS and Gentoo overlay setup;
- package-list refresh;
- Portage keyword and USE lines;
- Portage override write steps;
- the yay bootstrap steps;
- the privileged wrapper;
- `is_installed`, the only read-only command that actually runs.

## Verification

- `rustc --edition=2021 --test tools/reddot-pkg.rs`: unit tests pass.
- `tools/test-reddot-pkg-rust.sh` compares the Rust argv with `installer/pkg.py`
  for all families, refresh, copr, OBS, overlay, Debian PPA, Portage lines,
  Portage config, AUR bootstrap and the privileged wrapper.
- Commands that write the system are not run by the test; the PPA and AUR
  branches are composed and compared only.

## Consequences

The installer still calls `pkg.py`. The next modules are `fallbacks.py`,
`deploy.py`, the TUI and the orchestrator. The Rust binary is a parity core until
the installer entry point changes.
