# ADR 0013: Rust installer detection

- Status: read-only detection implemented; orchestrator still Python
- Date: 2026-10-28

## Context

The installer branches on family, package manager, compositor, bootloader,
init, display manager and root command. These probes are read-only and have a
clear Python counterpart.

## Decision

`tools/reddot-detect.rs` emits the detection record as JSON: family, pretty name,
package manager, compositor, bootloader, display-manager presence, root command,
init, immutability and AUR helper. It also exposes the networkd/iwd check used by
the service step.

No configuration or package database is modified.

## Verification

- 2 Rust unit tests cover family tokens and the root-command invariant.
- `tools/test-reddot-detect-rust.sh` compares every shared field with
  `distro`/`pkg`/`reddot_install` on this host.
- The installed config is not part of this record; `deploy.detect_existing()` is
  already covered by the deploy core parity test.

## Consequences

The detection layer is ready for a Rust orchestrator. The Python orchestrator
still consumes its own detection until the plan/run layers move.
