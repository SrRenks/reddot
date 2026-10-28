# ADR 0014: Rust installer plan

- Status: plan core implemented; orchestrator still Python
- Date: 2026-10-28

## Context

`_build_plan` combines the selected profile with installed-package and
present-fallback checks, then splits native, AUR and fallback work. It is the
contract between detection, package argv and the runner.

## Decision

`tools/reddot-plan.rs` reads the manifest and emits the same plan shape:
repositories, native, AUR, fallbacks, skipped, optional native packages, manual
overlay packages and atom-to-repo mappings. It performs only read-only probes
(`pacman -Qq`, `dpkg-query`, `rpm`, `portageq`, `flatpak info`, PATH checks).

## Verification

- `tools/test-reddot-plan-rust.sh` compares quick and full profiles, `aur=none`
  and the Gentoo overlay-skip path with `reddot_install._build_plan`.
- Fallback rows are normalized to `[id, handler]` for JSON comparison.
- `check-static.sh` builds the binary and tests parity.

## Consequences

The plan layer is ready for a Rust orchestrator. The Python orchestrator still
uses it until the runner and post-install steps move.
