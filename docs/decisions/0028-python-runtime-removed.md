# ADR 0028: Python removed from runtime paths

- Status: implemented; Python remains a test/parity harness only
- Date: 2026-10-28

## Context

`install.sh`, `reddot-update` and `wallcolors` still fell back to Python. That
kept Python on the normal install and live-shell paths even though the Rust
binaries had parity tests.

## Decision

- `install.sh` fails if the Rust bundle cannot be built; it no longer calls the
  Python installer.
- `reddot-update` and `wallcolors` execute the Rust binaries and fail with a
  clear message if they are missing; no Python fallback.
- The Python files remain for parity tests and historical reference, not as
  runtime entry points.

## Verification

- `reddot-update check` through the wrapper returned
  `{"status":"ok","behind":131}`.
- `wallcolors --static` through the wrapper wrote the expected palette in an
  isolated HOME with `XDG_BIN_HOME` pointing at the built bundle.
- `check-static.sh` and the Python parity suites pass.
- No `python3 ... reddot_install/wallcolors/reddot-update` call remains in the
  runtime scripts.

## Consequences

A machine without `rustc` can no longer complete an install. The bootstrap
installs rustc; unsupported failures are explicit. The interactive Rust wizard is
still partial (optional apps, SDDM/GRUB/fish confirmations), and VM validation is
outstanding.
