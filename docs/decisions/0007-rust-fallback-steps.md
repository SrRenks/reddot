# ADR 0007: Rust fallback steps

- Status: implemented as a verified core, not wired into the installer yet
- Date: 2026-10-28

## Context

`installer/fallbacks.py` builds the ordered steps for packages with no native
package: source builds, release download, cargo installs, Flatpak and a project
installer. The module describes commands and does not execute them.

## Decision

`tools/reddot-fallbacks.rs` implements every handler:

- `cargo`, including the swww source build;
- `ghostty`, with Terra on Fedora and the pinned Zig build elsewhere;
- `dotool`, including its build deps and uinput setup;
- `nerdfont` and `github` downloads;
- per-user Flatpak;
- rishot's own installer.

The binary prints step JSON and has a `present` probe. The installer still calls
the Python module until the remaining deploy/TUI work lands.

## Verification

- `rustc --edition=2021 --test tools/reddot-fallbacks.rs`: 3 unit tests pass.
- `tools/test-reddot-fallbacks-rust.sh` compares every manifest fallback on all
  five families against `installer/fallbacks.py`, plus unknown ids and a `doas`
  root choice.
- No build, download or installer is run by the test.

## Consequences

The source-build recipes now have a Rust parity implementation. The next layers
are `deploy.py`, `grub_theme.py`, the TUI and the orchestrator. Python remains the
installer entry point until those are proven.
