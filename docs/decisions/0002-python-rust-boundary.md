# ADR 0002: keep the Python installer and updater, use Rust for the sensor probe

- Status: accepted for the current scope
- Date: 2026-10-28

## Context

reddot has about 5,300 lines of Python across the installer, package resolver,
TUI, updater, palette helper and their tests. All of it uses the Python standard
library. The only Rust component is `tools/reddot-sensors.rs`, a 326-line native
sensor snapshot compiled on demand by `tools/install-extras.sh`.

Moving everything to Rust would remove Python from the install path, but would
replace code that already works with a larger build and distribution problem. The
installer runs before the shell, on five package families, and its tests exercise
the deploy set, the package matrix and the updater's three-way merge.

## Decision

Keep the Python installer, updater, palette helper and tests for now. Keep the
sensor snapshot in Rust because it maps directly to hardware reads and is already
isolated behind a command-line boundary.

Do not start a general Python rewrite. Reconsider Rust only for a component that
has a measured problem and a narrow interface.

## Reasons

- The Python code is standard-library only. The current dependency is the
  `python3` interpreter that the bootstrap already requires.
- The installer resolves distro package names, runs privileged package commands,
  drives an interactive terminal and backs up configuration. Rewriting that in
  Rust would add a compile step, a binary per architecture and a new dependency
  and release surface before it adds user value.
- The updater uses git subprocesses and a manifest with three-way file merges.
  A Rust port would either call git the same way or add a git library, while the
  current merge behavior has a real self-test.
- The sensor probe already has the properties that justify Rust: no Python
  process at runtime, direct `/sys` and power-supply reads, and a small output
  consumed by QML.
- The project has no benchmark showing that Python startup is a bottleneck on
  the install or update path.

## Consequences

- The install path keeps its Python requirement. `install.sh` checks for
  `python3` before cloning, so this is an explicit prerequisite.
- CI keeps the Python compile and self-test gates.
- The Rust toolchain remains optional, used only to build the sensor probe when
  `rustc` exists.
- A future migration must demonstrate a concrete need, such as removing the
  Python dependency from a minimal image, reducing a measured update latency, or
  shipping a single self-contained helper.

## Functional audit, 2026-10-28

The Python implementation runs and passes its own tests:

- `python3 tools/test-installer-matrix.py`: five package families, core plans and
  fallbacks passed;
- `python3 configs/hypr/scripts/test_reddot_update.py`: updater argument, clone,
  manifest and corruption cases passed;
- `python3 configs/hypr/scripts/test_wallcolors_apps.py`: app-specific palette
  cases passed;
- `python3 tools/test_deploy_sandbox.py`: deploy, re-deploy and uninstall passed;
- `python3 -m compileall installer configs/hypr/scripts tools`: no syntax errors.

There is no Rust implementation of these modules yet. A Rust rewrite would need
equivalents for the terminal raw mode in `tui.py` (`termios`, `select`), the git
and three-way merge behavior in `reddot-update.py`, and the package and fallback
tables in the installer. Rust's standard library has no JSON, diff or terminal
control crates, so a dependency-free port would be substantially larger than the
Python code. Adding crates is a separate dependency decision.

The Python modules are not resident at boot. Replacing them would not reduce the
1.6 GB login footprint; only the QuickShell/Qt processes and optional helpers do
that.

## Migration gate for a future Rust candidate

A component can move to Rust only when all of these are true:

1. It has a stable command or JSON interface.
2. It has tests that can be run against both implementations.
3. It has a measured problem that Rust solves, not only a language preference.
4. It has an install story that does not require Rust on the target machine.
5. It preserves the current error, backup and rollback behavior.

The updater would be the first candidate to evaluate because it is standalone and
has a clear JSON result. The installer is the last candidate because its value is
in distro knowledge and an interactive TUI, not in raw runtime speed.
