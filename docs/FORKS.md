# Fork research — Ricelin and neighbours

What exists, what each one does better, and what is worth taking into a fork.
Links checked 2026-10-26.

## The Ricelin lineage

| Project | Relation | What it adds / changes |
|---|---|---|
| [Gakuseei/Ricelin](https://github.com/Gakuseei/Ricelin) | upstream, MIT, 334★, pushed daily | the pill concept: one morphing capsule, per-monitor, Lua Hyprland config, matugen palette |
| [amanhex/Ukishima](https://github.com/amanhex/ukishima) | **substantial fork**, MIT | jemalloc launch script, 30 s surface unload, `unloadAll` IPC, auto-hide pill with a 10 px reveal strip, bottom dock, wallhaven search, scratchpad |
| [arubatoclaud/CapsuleOS](https://github.com/arubatoclaud/CapsuleOS) | rebrand fork | night-bridge theme (dark glass, fog grey, amber), same one-pill shell |
| [aprameyansr/Lumen](https://github.com/aprameyansr/Lumen) | rebrand fork | personal palette/structure, no architectural change |
| [VictorGSchneider/Morphshell](https://github.com/VictorGSchneider/Morphshell) | stale fork | copy of the shell, last push before the August upstream changes |
| ~20 more forks | copies | identity ricing, nothing portable |

Practical read: **Ukishima is the only fork with architecture worth reading.**
Everything else is a re-skin, and most are months behind upstream.

## Neighbours worth studying

| Project | Stack | What it does that Ricelin does not |
|---|---|---|
| [Impasto](https://github.com/andreumassanet/impasto) | Quickshell, **GPL-3** | liquid-glass materials, desktop widgets, per-screen bars, notes/tasks/games as island panels, full dotfiles takeover |
| [Tide Island](https://github.com/enhaoswen/Tide-island) | Quickshell + C++/Qt | native `BackgroundEffect` blur, lyrics, config app, niri support; old repo unmaintained, rewrite in progress |
| [k4](https://github.com/k4ditano/k4) | Quickshell, MIT | every widget is a plugin with a public API and permission manifest; dual-mode bar→dock; video wallpaper that pauses when hidden |
| [ChillPill](https://github.com/LUCKYS1NGHH/ChillPill-Shell) | Quickshell, GPL-3 | standalone pill, GUI config app, waybar-style custom modules, self-reported 200–500 MB |
| [Noctalia v5](https://noctalia.dev/blog/announcing-noctalia-v5) | own C++ shell | ~50 MB per monitor after the rewrite, capsule bar with auto-hide, plugins; not a morphing pill |
| [Caelestia](https://github.com/caelestia-dots/shell) | Quickshell | the polished full-shell benchmark; ~400 MB measured |
| [end-4](https://github.com/end-4/dots-hyprland) | Quickshell | densest feature set and the most copied visual language |
| [DMS](https://github.com/AvengeMedia/DankMaterialShell) | Quickshell + Go | Material 3, systemd service, dgop backend |
| [HyprPanel](https://github.com/Jas-SinghFSU/HyprPanel) | AGS/GJS | the cautionary tale: richest panels, heaviest runtime |
| [The Quickshell Book](https://programmersd21.github.io/the_quickshell_book/) | docs | RAM/lazy-loading/performance chapters, source tours of Caelestia and illogical-impulse |
| [Waybar](https://github.com/Alexays/Waybar) | GTK3/C | the low-RAM floor (~50 MB) and the `hide`/`invisible` mode |

## Backlog for the fork, in order

**P0 — cheap, contained, high value**

1. **Auto-hide pill with a reveal strip** (Ukishima) — **implemented here** as
   `Flags.pillMode` (`always`/`auto`) plus `pillReserve`. The pill retracts to a
   10 px top-centre strip and returns on hover; the band drops to zero. This was
   the single biggest UX gap.
2. **`unloadAll` IPC** (Ukishima). A one-function manual door that drops every
   closed surface now instead of waiting for the 30 s tail.
3. **Battery/TPM portability** (this repo). Multi-battery, PPD fallback, both
   sysfs ABIs, pause/resume, per-pack persistence; 24 tests.

**P1 — structural, still bounded**

4. **Plugin API** (k4). The k4 contract is the reference: plugins declare
   permissions, get validated, load isolated, and can be tested without
   restarting the bar. Even a narrow version (bar modules only) would let you
   add TLP/weather/whatever without touching `Pill.qml`.
5. **Native background blur** (Tide). Quickshell 0.3 exposes
   [`BackgroundEffect`](https://quickshell.org/docs/v0.3.0/types/Quickshell.Wayland/BackgroundEffect/)
   over `ext-background-effect-v1`; if Hyprland 0.56 negotiates it, the pill can
   ask the compositor for a blur region instead of the blanket
   `layer_rule … blur=true` in `decoration.lua`. Measure before switching.
6. **Video wallpaper that pauses when occluded** (k4). Their measurement: a
   1080p60 loop costs ~1.5 % of a 12-core CPU while visible, near zero when no
   window shows it. Ricelin's static `awww` pipeline has no equivalent.

**P2 — only if the fork grows**

7. **Per-monitor bar policy** (Impasto). "All / primary / focused" would remove
   one full Pill scene graph on a two-monitor desk; the mask and reserve code
   already branches per screen.
8. **Dock** (Ukishima). Auto-hiding, magnification, window previews. Nice, but
   it contradicts the one-pill minimalism and adds a second band.
9. **GUI config app** (Tide/ChillPill). Ricelin already has a settings surface;
   a separate app is only worth it if non-QML users are a goal.

## Performance notes

- **Allocator**: jemalloc decay is what moves a Quickshell shell from
  "RSS at the session peak" to "RSS at the working set". Ukishima's
  `launch.sh` and Ricelin's `watchdog.sh` now both set it.
- **Surface tail**: 120 s (upstream) vs 30 s (fork). Shorter tail returns
  objects sooner; reopening rebuilds synchronously.
- **The big idle item is still the resident lock** (`qs -c lock`), followed by
  `kdeconnectd` + `kdeconnect-indicator`. Neither is shell code.
- **Measurement rule** (prometheus-ai `core/docs/performance.md`): profile
  first. `ricelin-bench` exists for that; do not add complexity for a gain
  nobody measured.

## Upstream strategy

- Keep the machine-local pieces in `local.lua` and in files Ricelin does not
  track; an update replaces `shell.qml`, `Pill.qml`, `BatterySurface.qml`,
  `binds.lua` and `watchdog.sh`.
- Two patches are general enough to send upstream: `MALLOC_CONF` in
  `watchdog.sh`, and this TLP surface (multi-battery + PPD is useful to anyone
  outside the ThinkPad/CachyOS bubble).
- Licence check before copying code: Ricelin and Ukishima are MIT, k4 is MIT,
  Impasto and ChillPill are GPL-3. Copying GPL code into an MIT fork changes the
  fork's licence.
