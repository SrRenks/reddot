# ADR 0015: Rust post-install helpers

- Status: implemented as a verified core, not wired into the installer yet
- Date: 2026-10-28

## Context

After packages and deploy, the orchestrator seeds wallpapers, enables the app
theme, bridges `awww` to `swww`, links the `reddot` CLI and optionally seeds
Brave's GTK preference. These are small, independent filesystem effects.

## Decision

`tools/reddot-post.rs` implements those effects with a `--dry-run` path. It
preserves the installed `flags.json` object and adds `appTheme=true`, copies
starter wallpapers only when no image is present, and creates the same symlinks
and Brave preference file as Python.

`_seed_update_baseline` is not in this module yet; it invokes the update engine
and will move with the runner.

## Verification

- 2 Rust unit tests cover JSON round-trip and image extensions.
- `tools/test-reddot-post-rust.sh` compares wallpaper trees, the app-theme flag,
  the awww bridge and Brave's seeded Preferences against the Python helpers in
  separate temporary HOMEs.
- No live config is touched.

## Consequences

The post-install effects are ready for a Rust runner. The runner, baseline call,
report and entry point remain.
