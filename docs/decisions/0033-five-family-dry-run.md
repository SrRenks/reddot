# ADR 0033: five-family orchestration dry-run

- Status: implemented; real VM installation still unavailable
- Date: 2026-10-28

## Context

The host only has `systemd-nspawn` without rootfs/images. A real package
installation could not be validated across families. The orchestrator can still
be exercised with real plan/fallback/command generation and no package writes.

## Decision

The entry point accepts `--family` to override detection for matrix tests.
`tools/test-reddot-install-matrix.sh` builds the bundle and runs
`--quickstart --dry-run --family {arch,debian,fedora,suse,gentoo}` in separate
HOMEs/config roots, checking completion and the final report.

## Verification

```text
arch quickstart dry-run
debian quickstart dry-run
fedora quickstart dry-run
suse quickstart dry-run
gentoo quickstart dry-run
all family dry-run tests passed
```

No package manager is executed.

## Consequences

The five-family orchestration is covered. Real package/deploy/reboot validation
still needs VMs and remains the final blocker.
