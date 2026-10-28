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

`_seed_update_baseline` is included: it reads the source checkout's git HEAD and
invokes the update engine with `baseline --sha`, leaving a non-git source or a
missing engine as a clean skip.

## Verification

- 2 Rust unit tests cover JSON round-trip and image extensions.
- `tools/test-reddot-post-rust.sh` compares wallpaper trees, the app-theme flag,
  the awww bridge, Brave's seeded Preferences and the baseline handoff against the
  Python helpers in separate temporary HOMEs.
- No live config is touched.

## Consequences

The post-install effects are ready for a Rust runner. The runner, baseline call,
report and entry point remain.
