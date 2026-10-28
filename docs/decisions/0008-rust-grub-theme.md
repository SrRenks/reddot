# ADR 0008: Rust GRUB theme steps

- Status: implemented as a verified dry plan, not wired into the installer yet
- Date: 2026-10-28

## Context

`installer/grub_theme.py` plans three actions: copy the torii theme, set
`GRUB_THEME`, and regenerate `grub.cfg`. It never edits boot entries or
`os-prober`. The installer still executes the plan through Python.

## Decision

`tools/reddot-grub.rs` produces the same three actions with the same shell
commands and an explicit root command. The verification covers dry plans only;
no `/boot` or `/etc/default/grub` write happens in tests.

## Verification

- 2 Rust unit tests cover the action count and the `doas` root choice.
- `tools/test-reddot-grub-rust.sh` compares the Rust array with
  `installer/grub_theme._plan` for `sudo` and `doas`.
- `check-static.sh` builds and tests the module.

## Consequences

The GRUB plan is now a Rust parity core. The installer keeps the Python path
until the deploy layer and entry point move. The unsafe live path remains gated by
the bootloader check in the orchestrator.
