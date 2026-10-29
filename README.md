<div align="center">

# reddot

A Hyprland desktop built around one morphing Quickshell pill.

Personal fork of [Ricelin](https://github.com/Gakuseei/Ricelin), maintained on a ThinkPad E14 Gen 7.

![reddot pill](assets/showcase/mixer.gif)

</div>

reddot replaces the usual bar, launcher, mixer and settings windows with one
pill. It starts as a thin status strip and expands into the page you need:
launcher, Search, Settings, system monitor, Wi-Fi, Bluetooth, appearance,
battery and power tools. There are 42 surfaces in total.

The project is a personal setup, not a distribution. The supported installer
matrix is Arch, Debian 13+, Fedora 44+ and openSUSE Tumbleweed.

## Showcase

Clean-workspace captures. Personal window titles are redacted.

<table align="center">
<tr>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/launcher.gif" alt="reddot launcher" width="100%"><br>
  <sub><b>Launcher</b><br>Apps, commands and inline calculations</sub>
</td>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/search.gif" alt="reddot search" width="100%"><br>
  <sub><b>Search</b><br>Titles, aliases and search keywords</sub>
</td>
</tr>
<tr>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/bar.gif" alt="reddot bar editor" width="100%"><br>
  <sub><b>Bar</b><br>Zones, status order and component widgets</sub>
</td>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/gamemode.gif" alt="reddot game mode" width="100%"><br>
  <sub><b>Game mode</b><br>Target window, keep list and scoped cleanup</sub>
</td>
</tr>
</table>

<table align="center">
<tr>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/thinkpad.gif" alt="reddot ThinkPad controls" width="100%"><br>
  <sub><b>ThinkPad hardware</b><br>Fan, LEDs, TrackPoint and BIOS</sub>
</td>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/tlp.gif" alt="reddot power and battery" width="100%"><br>
  <sub><b>Power &amp; battery</b><br>Profile, charge window and presets</sub>
</td>
</tr>
<tr>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/packages.gif" alt="reddot system packages" width="100%"><br>
  <sub><b>System packages</b><br>Native, AUR and Flatpak update deltas</sub>
</td>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/sysmon.gif" alt="reddot system monitor" width="100%"><br>
  <sub><b>System monitor</b><br>CPU, iGPU, memory, sensors and pressure</sub>
</td>
</tr>
</table>

<table align="center">
<tr>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/mixer.gif" alt="reddot mixer" width="100%"><br>
  <sub><b>Audio</b><br>Output, microphone, faders and routing</sub>
</td>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/recorder.gif" alt="reddot recorder" width="100%"><br>
  <sub><b>Recorder</b><br>Screen capture and source selection</sub>
</td>
</tr>
<tr>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/notice.gif" alt="reddot system notices" width="100%"><br>
  <sub><b>Notices</b><br>Battery, charger, mic and peripheral events</sub>
</td>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/settings.gif" alt="reddot settings" width="100%"><br>
  <sub><b>Settings</b><br>Grouped desktop, controls and system pages</sub>
</td>
</tr>
</table>

## The pill

Hover the top strip or use `Super+Shift+Space`. The pill grows in place, keeps
the same geometry while it morphs, and returns to the strip when you leave.

- `Super+A` opens the launcher.
- The wheel, scrollbar, `PageUp`/`PageDown`, `Home` and `End` work on long pages.
- `Search` finds pages by title, alias, tag and keyword.
- The back control returns to the parent page; `Escape` closes the surface.
- `Super+Shift+Space` reopens the last surface.

## Search

Search understands informal names, common service names and small typos:

```text
wifi         → Wi-Fi
volume       → Audio mixer
fingerprint  → Security & idle
fan          → ThinkPad hardware
gui          → Bar & widgets
mic          → Audio mixer / Pill & notices
pacman       → System packages
bios         → ThinkPad hardware
charger      → Power & battery / Pill & notices
widgets      → Bar & widgets
```

The manifest also drives tooltips and the page index, so a missing keyword is a
metadata fix rather than a second search implementation.

## Bar

The normal bar exposes the clock and status icons. Each icon opens its surface,
and the Bar page mirrors the same order across restarts.

`System packages` is both a status item and a widget: the download glyph remains
visible at zero, while the numeric badge appears only when there is something to
show. Its width follows the badge instead of reserving a fixed slot.

The component picker is grouped by Navigation, Information, Controls and
Hardware. Status order and the enabled item list are persisted in
`~/.local/state/reddot/bar.json`.

## Game mode

Open **Power & battery → Game mode**, or click the gamepad chip in the Mixer.
Choose the game window, keep the apps you still need, and start the mode. It
strips Hyprland decorations and animations, enables DND and keep-awake, pauses
the visualizer, and keeps the selected target tree and allowlist alive.

Closing other windows is opt-in and uses SIGTERM after confirmation. The cleanup
helper only considers mapped Hyprland windows and protects the game tree,
allowlisted apps, Steam/Gamescope and system/session services. The mode exits
when the target window disappears.

## System and security

- **System monitor** shows CPU, iGPU, memory, temperature, fan RPM, network,
  disk, swap and compute governor without a background daemon.
- **System packages** lists pending native, AUR and Flatpak updates with versions
  and marks critical stack updates such as Hyprland.
- **Power** covers TLP profiles, charge windows, presets and session actions.
- **ThinkPad** exposes fan curve, TrackPoint, keyboard LEDs and BIOS status on
  supported hardware.
- **Lock** uses PAM. Password and fingerprint are independent. On multiple
  monitors the primary output authenticates; secondaries show the clock, date and
  a `LOCKED` marker.
- **Appearance** derives a palette from the wallpaper with matugen and the Rust
  palette engine.

## Install

The bootstrap installs `git` and `rustc`, clones the checkout and runs the Rust
installer. It does not use Python.

```sh
curl -fsSL https://raw.githubusercontent.com/SrRenks/reddot/e14g7/install.sh | bash
```

Read `install.sh` before piping it. The installer backs up replaced files.

Useful flags:

```text
--quickstart   core defaults, no questions
--full         include the daily applications
--custom       choose optional applications
--sddm         install the torii SDDM theme
--no-deps      deploy configuration only
--dry-run      print the plan without changing anything
--reinstall    rerun an installed setup
--uninstall    remove managed configs and restore backups
```

Leap 15.6 and Gentoo are rejected: Leap has no OBS target for the Hyprland set,
and Gentoo is source-only and outside the verified binary matrix.

## Keybinds

| Keys | Action |
|---|---|
| `Super+Return` | Terminal |
| `Super+A` | Launcher |
| `Super+V` | Clipboard |
| `Super+W` | Wallpaper picker |
| `Super+L` | Lock |
| `Super+F` | Fullscreen |
| `Super+Shift+R` | Recorder |
| `Print`, `Super+F9` | rishot |
| `Shift+Print` | Current monitor |

The full map is in [docs/usage.md](docs/usage.md).

## Stack

| Layer | Technology |
|---|---|
| Compositor | Hyprland, Lua configuration |
| Shell | Quickshell and QML |
| Terminal | Ghostty |
| Login shell | fish |
| Palette | matugen and Rust |
| Installer and updater | Rust, compiled with `rustc` |
| Helpers | POSIX shell, systemd and polkit |

The active repository has no `.py` files. The old Python parity harness is
archived outside the checkout.

## Checks

```sh
tools/check.sh
tools/check-static.sh
tools/smoke-surfaces.sh   # needs a running pill
```

Real VM results and current gaps are in [docs/coverage.md](docs/coverage.md).
The supported matrix, not a five-family claim, is the install contract.

## Documentation

- [Documentation index](docs/index.md)
- [Getting started](docs/getting-started.md)
- [Usage](docs/usage.md)
- [Architecture](docs/architecture.md)
- [Operations](docs/operations.md)
- [Coverage](docs/coverage.md)
- [Roadmap](docs/roadmap.md)
- [Changelog](CHANGELOG.md)
- [Game mode study](docs/gamemode-study.md)

## Credits

Fork of [Ricelin](https://github.com/Gakuseei/Ricelin) by
[Gakuseei](https://github.com/Gakuseei). See [docs/CREDITS.md](docs/CREDITS.md)
for third-party work and asset credits.

MIT. Upstream © 2026 Gakuseei. reddot changes © 2026 Ricardo Castro (SrRenks).
