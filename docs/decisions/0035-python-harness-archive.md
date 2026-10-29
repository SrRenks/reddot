# ADR 0035: Python harness archived

- Status: accepted
- Date: 2026-10-29

## Context

The runtime no longer invokes Python, but the repository still carried the old
installer modules and their parity tests. That kept `.py` files in the checkout
and made "remove Python" ambiguous.

## Decision

The complete Python reference harness is archived outside the Git checkout at:

```text
/home/renks/Projects/reddot-python-parity-archive-2026-10-29/
/home/renks/Projects/reddot-python-parity-archive-2026-10-29.tar.gz
```

Archive metadata:

```text
source commit: 431394da6c029a9b06bcae984a607f7eb0b7ceb1
tar sha256:    5d3ea88215ada2a1238d991939485492bf3828d8c8f4f1ea4f89de758650d40b
```

Removed from the repository:

- `installer/*.py`;
- `configs/hypr/scripts/*.py`;
- Python-only installer/deploy matrices and the old `check-integration.sh`;
- parity shell tests that imported the Python modules.

The Rust unit tests, the four-family installer VM matrix, the runtime Python
audit and the remaining shell/QML/Node gates stay in the checkout.

## Consequences

- the active repository contains no `.py` files;
- Python-only parity coverage is no longer in CI; the archived tests preserve it
  for reference but are not a gate;
- the supported matrix is Arch, Debian 13+, Fedora 44+ and Tumbleweed;
- the archive must be restored alongside a checkout at the recorded commit to be
  runnable.
