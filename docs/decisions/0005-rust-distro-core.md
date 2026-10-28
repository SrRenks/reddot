# ADR 0005: Rust distro core

- Status: implemented as a verified core, not wired into the installer yet
- Date: 2026-10-28

## Context

`installer/distro.py` is pure decision logic: it detects the distro family and
turns each package manifest entry into a native, fallback or skip action. It does
not run a package manager or draw the terminal UI, which makes it the safest
installer module to move first.

## Decision

`tools/reddot-distro.rs` implements the same family tokens, name lookup, AUR
rules, repo lookup and `plan()` output. It reads `installer/packages.json` and
prints the ordered plan as JSON.

The installer still calls the Python module until the remaining installer
modules have Rust equivalents. This binary is a parity core, not yet the
installer entry point.

## Verification

- `rustc --edition=2021 --test tools/reddot-distro.rs`: 3 unit tests pass.
- `tools/test-reddot-distro-rust.sh` compares the Rust plan with the Python plan
  for all five families and for Arch with `aur=yay` and `aur=none`.
- A synthetic CachyOS os-release file checks family detection.
- The existing installer matrix still passes in `check-static.sh`.

## Consequences

The package decision table now has two implementations during the rollout. They
are compared by the integration test, not assumed equal. The Python installer
keeps working until the package runner, fallback handlers, deploy layer and TUI
move.
