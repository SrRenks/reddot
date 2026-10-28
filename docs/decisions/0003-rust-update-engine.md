# ADR 0003: Rust update engine

- Status: implemented, Python fallback kept for rollout
- Date: 2026-10-28

## Context

The updater is the most self-contained Python runtime: it has one JSON result, a
clean git clone, protected-file merges, a manifest and a small dependency scan.
ADR 0002 rejected a general rewrite because the installer's distro logic and TUI
are larger and because the Python code is not resident at boot.

The updater still benefits from a native binary: it is a single process started by
QML, it does not need Python imports, and its behavior can be tested against a
throwaway git repository.

## Decision

`configs/hypr/scripts/reddot-update` now selects `~/.local/bin/reddot-update`, a
Rust binary built from `tools/reddot-update.rs`. The Python engine remains as a
fallback when the binary has not been built. The QML surface and the `reddot`
CLI call the wrapper, so both paths have the same contract.

The Rust binary has no crates. It uses git for clone, fetch, show and
`git merge-file`, and includes a small JSON reader and writer for the manifest and
package files.

## Scope

Migrated:

- check, apply and baseline modes;
- the JSON contract consumed by `Updates.qml`;
- pristine clone, remote retarget, changelog range and behind count;
- protected-file three-way merges, conflict reporting and `--take`;
- code sync, deploy filters, executable bit, hypridle migration;
- devmode detection, manifest corruption handling and backups;
- the upstream package manifest scan and pkexec install path.

Still Python:

- `installer/` and its TUI, distro resolution, fallback handlers and deploy.

`wallcolors.py` moved in ADR 0004.

Those modules are not on the boot path and do not affect the memory measurement.

## Verification

- `rustc --edition=2021 --test tools/reddot-update.rs`: 4 unit tests pass.
- `sh tools/test-reddot-update-rust.sh`: integration test passes for first run,
  code copy, filters, hypridle migration, clean merge, conflict, `--take`,
  corrupt manifest and bad flags.
- Live `reddot-update check` against the fork returned
  `{"status":"ok","behind":101,"error":null}`.

## Consequences

- Machines without Rust keep the Python updater through the wrapper. That is a
  rollout fallback, not the target state.
- The installer still requires Python. Removing Python completely means porting
  the installer TUI and distro handlers, which is a separate phase with its own
  parity suite.
