# ADR 0023: install.sh Rust handoff

- Status: quickstart handoff implemented; interactive path still Python
- Date: 2026-10-28

## Context

The Rust quickstart can install packages, deploy, neutralize and run post steps.
The bootstrap still calls Python unconditionally.

## Decision

When `rustc` is available and the command is not `--reinstall` or `--uninstall`,
`install.sh` builds the complete bundle with `tools/build-rust.sh` and runs
`reddot-install --quickstart`, forwarding `--dry-run`, `--full`, `--no-deps` and
`--brave`. If the build fails or no toolchain exists, it falls back to the Python
installer.

## Verification

- `sh -n install.sh` passes.
- The bundle and quickstart dry-run are covered by
  `tools/test-reddot-install-rust.sh`.
- The handoff still needs a VM run for each family.

## Consequences

The default install path is now Rust when the toolchain exists. The interactive
wizard, uninstall and reinstall stay Python, and the Python fallback is still
present until those paths move.
