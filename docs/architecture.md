# Architecture

## Stack

| Layer | Technology |
|---|---|
| Compositor | Hyprland, configured in Lua |
| Shell | Quickshell and QML |
| Terminal | Ghostty |
| Login shell | fish |
| Palette | matugen and the Rust `reddot-wallcolors` engine |
| Installer | Rust, crate-free `rustc` build |
| Updates | Rust `reddot-update` engine |
| Helpers | POSIX shell, systemd user units, polkit |

## Type scale

`Singletons/Typography.qml` is the single source of type sizes. Surfaces pass
their local `s` into `Typography.size(role, s)`; `s` already includes monitor
scale and UI scale. The roles are:

```text
micro     8.5   labels and uppercase eyebrows
caption   9.5   secondary metadata
body     11     copy and list lines
bodyLarge 12.5  row titles and values
subtitle 14     headers
title    16     glyphs and prominent labels
display  22     gauges
hero     30     large numerals
```

At 125% the SYSTEM gauges keep their columns and the content scrolls vertically;
small labels and values grow together instead of staying at fixed pixel sizes.

## Shell

The pill is a single morphing surface family. `configs/quickshell/pill/shell.qml`
owns the per-monitor layer windows and the open/close state. `Pill.qml` hosts the
surfaces; `lib/surfaces.js` is the surface catalog (parent, loader, `cold`
lifecycle), and `lib/navigation.js` supplies human-facing names, aliases and
search tags.

The lock is a separate Quickshell instance under `configs/quickshell/lock/`. It
uses `WlSessionLock`; each output gets a lock surface, with authentication on the
primary and clock/date on the secondaries.

## Installer and updater

`install.sh` detects the family, installs git/rustc and builds the Rust bundle
with `tools/build-rust.sh`. `tools/reddot-install.rs` orchestrates detection,
planning, package execution, deploy, neutralize, post-install and the closing
report. The package manifest remains at `installer/packages.json`.

`tools/reddot-update.rs` owns the update JSON contract, clone/fetch, three-way
merge, backups and dependency scan. `reddot update` and `reddot uninstall` in
`configs/hypr/scripts/reddot` execute the Rust binaries directly.

## Verification

The headless gate is `tools/check-static.sh` (CI). The local checkout gate is
`tools/check.sh`. VM results, coverage gaps and the Python parity archive are
tracked in [coverage.md](coverage.md).
