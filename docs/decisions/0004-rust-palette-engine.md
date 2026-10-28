# ADR 0004: Rust palette engine

- Status: implemented, Python fallback kept for rollout
- Date: 2026-10-28

## Context

`wallcolors.py` is called on every wallpaper change and on the Appearance actions.
Its output is a small set of files: the pill palette, Fastfetch config, Hyprland
colours, Ghostty palette and optionally the GTK app theme. It has no daemon of its
own and uses external programs for image analysis and desktop settings.

## Decision

`tools/reddot-wallcolors.rs` implements the same command-line modes:

```text
<wallpaper>
--hue <degrees> [light|dark] [saturation]
--static
--apps [off]
```

The wrapper `configs/hypr/scripts/wallcolors` selects
`~/.local/bin/reddot-wallcolors` and keeps the Python script as a rollout fallback.
`wallpaper.sh`, `Appearance.qml` and the installer call the wrapper.

The Rust binary has no crates. It parses the ImageMagick histogram, does HLS
conversion, writes the same palette consumers, and drives gsettings, flatpak and
gdbus for the app theme.

## Verification

- 3 Rust unit tests cover HLS round trips, the static accent and the path layout.
- `tools/test-reddot-wallcolors-rust.sh` covers the static palette, the wallpaper
  histogram path with a fake matugen, app theme enable and disable, and restoration
  of a user's GTK theme.
- `check-static.sh` builds and runs both the unit and integration suites.
- The Python app-theme self-test remains the behavioural reference during rollout.

## Consequences

The palette and updater no longer require Python on the normal path when the
binaries are built. The installer remains Python, and the wrappers keep the Python
fallback until the installer is ported.
