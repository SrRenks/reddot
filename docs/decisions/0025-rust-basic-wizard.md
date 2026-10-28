# ADR 0025: basic Rust installer wizard

- Status: profile/AUR prompt implemented; optional app picker and confirmations remain
- Date: 2026-10-28

## Context

The quickstart entry point can install and uninstall, but install.sh always
forced Quick defaults. The first interactive step must choose the profile and AUR
helper without changing terminal state permanently.

## Decision

When `--quickstart` is absent, `reddot-install` prompts on `/dev/tty` for:

- profile: `1` Quick or `2` Full;
- AUR helper on Arch: `yay`, `paru` or `none`.

With no controlling terminal, both prompts fall back to the Quick defaults. The
chosen values feed `reddot-plan` and the report.

`install.sh` no longer injects `--quickstart`; it forwards the user's flag. Full
can also be selected with `--full`.

## Verification

The quickstart dry-run and isolated apply/uninstall tests still pass. The
prompt fallback is exercised when no `/dev/tty` is available.

## Consequences

The default Rust path now asks the two decisions that change the package plan.
Optional apps, SDDM/GRUB/Brave/fish confirmations and the final go/no-go prompt
remain outside the Rust wizard.
