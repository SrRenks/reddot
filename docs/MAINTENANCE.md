# Maintaining reddot

What is upstream, what is this fork, how to update and how to prove nothing
broke.

## Layout

| Path | Role |
|---|---|
| `configs/hypr/` | Hyprland Lua modules, scripts, sound config. Deployed to `~/.config/hypr` |
| `configs/quickshell/` | pill and lock QML. Deployed to `~/.config/quickshell` |
| `installer/` | upstream Python wizard: packages, deploy, neutralize, backup |
| `install.sh` | bootstrap: clone/update, run the wizard, then `tools/install-extras.sh` |
| `tools/` | TLP helper, TLP AC/BAT policy, bench, power report, tests, `check.sh` |
| `docs/` | power, keybinds, startup, memory, related shells, credits |
| `assets/` | screenshots and demo images only |

## What is local to this fork

- `configs/hypr/scripts/watchdog.sh`: `MALLOC_CONF` jemalloc decay.
- `configs/hypr/modules/binds.lua`: personal keymap, `Super+Shift+B` power surface.
- `configs/hypr/modules/{decoration,animations,autostart,env,input,monitors,spaces}.lua`:
  this machine's taste/hardware. The installer neutralizes monitors/env when it
  deploys them to a fresh machine.
- `configs/quickshell/pill/`: auto-hide (`shell.qml`, `Pill.qml`, `Look.qml`,
  `Flags.qml`), 30 s unload (`Pill.qml`), `TlpSurface.qml`, `PowerHistory.qml`,
  battery card changes, edge-driven `Peripherals.qml`, and the optional
  `ThinkPadSurface.qml`, its group/curve/lighting/graph components,
  `Singletons/ThinkPad.qml`, `PresetsSurface.qml`,
  `Singletons/PresetStore.qml`, `StartupSurface.qml` and
  `lib/autostart.js`.
- `tools/`: all new shell-side tooling, the TLP helper and the ThinkPad helper
  (installed only when a ThinkPad is detected).
- `configs/hypr/scripts/reddot-update.py`: `DEFAULT_REMOTE` points at this fork.

## Update

The in-app updater now pulls this fork (three-way merge for protected files):

```sh
reddot update
```

For a fresh machine or a forced refresh:

```sh
git -C ~/Projects/reddot pull
sudo ~/Projects/reddot/install.sh --reinstall
```

The Python installer only owns `~/.config`. The ThinkPad helper, polkit rule,
TLP policy and user tools are outside it; after a pull that changes `tools/`:

```sh
sudo ~/.local/share/reddot/tools/install-extras.sh
reddot stop && reddot start
~/Projects/reddot/tools/check.sh
```

## Tests

```sh
~/Projects/reddot/tools/check.sh          # gate: helper, QML, syntax, drift
~/Projects/reddot/tools/test-reddot-tlp.sh
~/Projects/reddot/tools/test-reddot-thinkpad.sh
python3 ~/.config/hypr/scripts/test_reddot_update.py
python3 ~/.config/hypr/scripts/test_wallcolors_apps.py
node ~/.config/quickshell/pill/lib/fuzzy.test.mjs
node ~/.config/quickshell/pill/lib/monitors.test.mjs
sh ~/.config/hypr/scripts/test_launch_guard.sh   # needs writable /run/user/$UID
```

## Backups

The installer keeps backups of replaced configs. The three-way merge base and
last applied sha live in `~/.local/state/reddot/update.json`. For the local
history of this fork see `git log`; each feature was committed separately.

## Known trade-offs

- **Resident lock**: `qs -c lock` idles at ~40–70 MB for instant locking. On-demand
  start (Ukishima) saves that at the cost of 200–400 ms and a riskier lock path.
- **Auto-hide**: `pillMode=auto`, `pillReserve=false`. If the strip does not
  reveal, any surface keybind makes the pill modal; then **Look → Pill mode →
  Always**, or edit `~/.local/state/reddot/flags.json`.
- **TLP helper**: root-owned `/usr/local/bin/reddot-tlp`, called through
  `pkexec`. TLP has no unprivileged threshold API; TLPUI escalates the same way.
- **Mute LEDs**: `tools/99-reddot-leds.rules` selects `audio-mute` and
  `audio-micmute` at boot. No daemon; the two LEDs are followers.
- **ThinkPad helper**: `pkexec` plus polkit, not sudoers. The shared rule returns
  `AUTH_ADMIN_KEEP` only for `/usr/local/bin/reddot-thinkpad` and
  `/usr/local/bin/reddot-tlp`; reads do not prompt. This needs a running polkit
  agent (`hyprpolkitagent` here).
- **Two QuickShell processes** (pill + lock): ~311 MB anon for the whole session
  on the reference machine (`docs/LIGHTWEIGHT.md`).

## Docs

- `docs/POWER.md` — battery/energy tooling and what is trustworthy
- `docs/LIGHTWEIGHT.md` — measured memory and ranked reductions
- `docs/FORKS.md` — related shells and features worth borrowing
- `docs/CREDITS.md` — upstream, ideas and assets
