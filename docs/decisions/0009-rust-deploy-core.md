# ADR 0009: Rust deploy ownership core

- Status: implemented ownership/deploy core, not wired into the installer yet
- Date: 2026-10-28

## Context

`installer/deploy.py` owns the filesystem contract: markers, foreign backups,
managed replacement, preserved user files, pruning and uninstall. A mistake here
can lose a user's config, so the port keeps the same plan/apply split and compares
the resulting trees.

## Decision

`tools/reddot-deploy.rs` implements:

- deploy-set detection;
- `.reddot-managed` markers for dirs and files;
- `.bak`, `.bak.N` backup selection;
- managed replacement;
- the PRESERVED carry-over list;
- dev-cruft filtering (`test_*.py`, `__pycache__`, `*.pyc`, `hypridle.conf`);
- uninstall and empty-directory pruning.

`neutralize()` is still Python. It is the next phase because it rewrites content:
monitors, env, hypridle home, fish and fastfetch.

## Verification

- 2 Rust unit tests cover ignore patterns and marker paths.
- `tools/test-reddot-deploy-rust.sh` compares plan JSON, deployed file names and
  contents, a second deploy, uninstall plan and the final tree against Python.
- Both implementations run in separate temporary config roots; the live config
  is never touched.

## Consequences

The ownership and rollback path now has a Rust parity implementation. The
installer still calls Python until neutralize, TUI and the orchestrator move.
