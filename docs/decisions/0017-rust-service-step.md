# ADR 0017: Rust service step

- Status: implemented in the package runner; orchestrator still Python
- Date: 2026-10-28

## Context

After package installation the installer enables NetworkManager and bluetooth,
plus hyprsunset when installed. Non-systemd inits need manual commands, not a
silent failure.

## Decision

The Rust runner accepts `--services --init systemd|openrc|...`. It appends the
service commands after the package batches:

- systemd: enable/start NetworkManager and bluetooth, plus the user hyprsunset
  unit when present;
- OpenRC: enable/start both services with the `bluetooth`/`bluetoothd` fallback;
- other init: no command, leaving the service note to the orchestrator.

The commands honour `--root` and the dry-run printer.

## Verification

`tools/test-reddot-run-rust.sh` checks the exact systemd command order after a
dry-run package plan. The package ordering test remains.

## Consequences

The runner now covers refresh, repos, native/AUR and systemd/OpenRC services.
Fallbacks, report and the entry point remain Python.
