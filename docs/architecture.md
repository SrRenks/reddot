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

## Bar components

Bar chrome is moving from per-item flags to a catalog of definitions plus
persisted instances:

```text
Singletons/BarCatalog.qml   identity, name, icon, modes, hosts
Singletons/BarLayout.qml    bar.json, ordering, visibility, migration
Singletons/barLayout.js     pure normalize/migrate/order policy
```

`BarLayout` seeds `~/.local/state/reddot/bar.json` once from the legacy
`barWorkspaces`, `barClock`, `bar*` visibility flags and `barStatusOrder`.
After that the file is authoritative. The Bar, Clock, Workspaces and status
settings read and write it. Clock and Workspaces render through the generic
`BarComponentHost` in icon or widget mode. Status components keep their current
right-cluster visual in icon mode, render a generic widget row in widget mode,
and fall back to a catalog glyph when moved outside `bar.right`.

Each catalog definition declares `icon` and `widget` modes, a default host and
the hosts it accepts. `bar` is a container with a persisted instance mounted at
`settings.catalog` and a static preview. The optional `command` component runs
an argv-based provider, parses one JSON object from stdout and renders icon or
widget output. Settings uses one selected-item editor and a compact selector
instead of allocating a full control block for every definition.
`System packages` in widget mode is rendered inline in `BarStatusRow`, at its
normal status order and before recorder/settings/power. The download glyph is
always visible; the numeric badge only appears when the count is nonzero or the
check failed, so the item has a single-icon width at zero and grows with the
badge. It is not mounted in the trailing status-widget row.

The hot trio no longer preloads; surfaces build on first open. The host-only
performance gate uses 180 MB PSS idle, 230 MB post and 55 MB lock limits.

The right-side status cluster lives in `BarStatusRow.qml` and is instantiated by
a Loader only while the bar is expanded. Its width and Ame anchors are exposed
by the component; idle keeps only the rest capsule and the shell services.

The watchdog also starts `reddot-recycle.sh` for the pill. After two consecutive
20 s checks with no open surface, no pointer in the bar strip and PSS above
220 MB, it recycles the process once; the replacement returns to the idle floor.
This is a cache safety net, not a per-page reload.

`EventNotices.qml` owns configurable system-event notices (battery, charger,
microphone and low peripherals). It emits through the same monochrome pill OSD
as `KeyNotice`, but has its own flags and is independent from keybind notices.

`GameModeSurface.qml` is the target picker for game mode. `GameMode.qml` owns the
window list, target class, allowlist and cleanup process; the cleanup script
validates mapped windows, ownership, cgroups and protected classes before sending
SIGTERM. The game process tree and its ancestors are protected.

## Shell

The pill is a single morphing surface family. `configs/quickshell/pill/shell.qml`
owns the per-monitor layer windows and the open/close state. `Pill.qml` hosts the
surfaces; `lib/surfaces.js` is the surface catalog (parent, loader, `cold`
lifecycle), and `lib/navigation.js` supplies human-facing names, aliases and
search tags.

The lock is a separate Quickshell instance under `configs/quickshell/lock/`. It
uses `WlSessionLock`; each output gets a lock surface, with authentication on the
primary and clock/date on the secondaries.

Search metadata lives in `lib/navigation.js`: titles, aliases, tags and a separate
keyword list per page/status. Keyword matches skip fuzzy subsequence matching, so
short queries like `mic` or `bios` do not pull in unrelated sections. Settings
groups live in the same manifest; the Bar component picker groups its static rows
by the catalog category.

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
