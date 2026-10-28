# ADR 0027: rustc bootstrap

- Status: installed as the primary bootstrap; Python fallback retained
- Date: 2026-10-28

## Context

`install.sh` still installed python3 and used Python as the guaranteed fallback,
which kept Python on the install path even when the Rust bundle was available.

## Decision

The bootstrap now installs `git` and `rustc` (plus cargo where the family names
it separately). It builds the bundle and runs `reddot-install`. Python is used
only when the Rust build fails and `python3` already exists; otherwise the
bootstrap fails with an explicit message.

## Verification

- `sh -n install.sh` passes.
- Package cases updated for Arch, Debian, Fedora, SUSE and Gentoo.
- The Rust quickstart/apply/uninstall tests remain green.

## Consequences

A fresh supported machine no longer needs Python to install reddot. Python files
remain in the repository for the rollout fallback and parity tests until the
interactive installer is fully ported.
