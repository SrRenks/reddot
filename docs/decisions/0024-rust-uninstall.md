# ADR 0024: Rust uninstall path

- Status: quickstart install and uninstall implemented; interactive wizard remains
- Date: 2026-10-28

## Context

Uninstall is a managed removal: restore pristine backups, remove only marked
destinations, remove the app theme and the CLI link. It has no wizard.

## Decision

`reddot-install --uninstall --apply` runs the Rust deploy uninstall, disables the
app theme through the wallcolors wrapper and removes the `~/.local/bin/reddot`
symlink. `--dry-run` only plans the deploy removals. `install.sh` forwards
`--uninstall` to this path when `rustc` is available; the Python uninstaller
remains the toolchain-less fallback.

## Verification

`tools/test-reddot-install-rust.sh` now:

1. builds the bundle;
2. runs quickstart dry-run;
3. runs `--quickstart --no-deps --apply` in an isolated HOME/config root;
4. asserts the managed marker;
5. runs `--uninstall --apply`;
6. asserts the managed tree is gone.

## Consequences

Install and uninstall now have a Rust path. The interactive wizard, reinstall
flags and VM matrix remain Python/unknown.
