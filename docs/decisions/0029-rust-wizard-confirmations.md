# ADR 0029: wizard confirmations and apply actions

- Status: implemented; interactive profile/AUR plus SDDM/GRUB/Brave/fish
- Date: 2026-10-28

## Context

The basic Rust wizard asked only profile and AUR. The Python flow also asks for
optional apps, SDDM, GRUB, Brave and fish, and runs their installers.

## Decision

The Rust wizard now asks SDDM, GRUB (only when the detected bootloader is GRUB),
Brave and fish in interactive mode. Apply performs:

- `sddm/themes/torii/install.sh` with `SUDO`;
- `reddot-grub apply` for the detected GRUB box;
- `chsh -s` to fish when installed;
- the Brave post-install seed only when selected.

The report receives the same flags. `install.sh` forwards `--sddm`, `--grub`,
`--brave` and `--no-fish`.

## Verification

`tools/test-reddot-install-rust.sh` still covers dry-run and isolated apply/
uninstall. The wizard prompts are exercised through the no-TTY defaults in CI.

## Consequences

The common install choices are covered without Python. Optional-app subsetting,
custom profile, final report formatting and VM validation remain.
