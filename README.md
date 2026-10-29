<div align="center">

# reddot

A Hyprland desktop built around one morphing Quickshell pill.

Personal fork of [Ricelin](https://github.com/Gakuseei/Ricelin), maintained on a ThinkPad E14 Gen 7.

![reddot launcher](assets/showcase/launcher.gif)

</div>

One pill replaces the status bar and the usual launcher, mixer and settings
windows. It starts as a thin strip, expands in place, and returns to the strip
when you leave. **42 surfaces**, no background daemon for the shell itself.

Every clip starts on a bare workspace. The pill appears after the tour begins,
then the pointer opens and navigates the surface. All clips run at **30 fps**.
Network names, window titles and notification examples are redacted or generic.

## Find and focus

<table align="center">
<tr>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/launcher.gif" alt="Launcher with inline math" width="100%"><br>
  <sub><b>Launcher</b><br>Apps, commands and inline math from the workspace chip</sub>
</td>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/search.gif" alt="Search results" width="100%"><br>
  <sub><b>Search</b><br>Type <code>bios</code>; keywords find ThinkPad hardware</sub>
</td>
</tr>
<tr>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/bar.gif" alt="Bar and widget editor" width="100%"><br>
  <sub><b>Bar</b><br>Zones, status order and component widgets</sub>
</td>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/settings.gif" alt="Settings index" width="100%"><br>
  <sub><b>Settings</b><br>Desktop, controls and system sections</sub>
</td>
</tr>
</table>

## Connect and listen

<table align="center">
<tr>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/wifi.gif" alt="Wi-Fi" width="100%"><br>
  <sub><b>Wi-Fi</b><br>Networks, signal and connection controls; names redacted</sub>
</td>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/bluetooth.gif" alt="Bluetooth" width="100%"><br>
  <sub><b>Bluetooth</b><br>Adapters, paired devices and discovery; names redacted</sub>
</td>
</tr>
<tr>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/audio.gif" alt="Audio mixer and routing" width="100%"><br>
  <sub><b>Audio</b><br>Volume, mic mute, output and input routing while music plays</sub>
</td>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/media.gif" alt="Now playing" width="100%"><br>
  <sub><b>Media</b><br>Now playing, transport and album art from the media bud</sub>
</td>
</tr>
</table>

## Own the machine

<table align="center">
<tr>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/game-mode.gif" alt="Game mode" width="100%"><br>
  <sub><b>Game mode</b><br>Target window, keep list and scoped cleanup</sub>
</td>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/thinkpad.gif" alt="ThinkPad controls" width="100%"><br>
  <sub><b>ThinkPad</b><br>Fan, LEDs, TrackPoint and BIOS</sub>
</td>
</tr>
<tr>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/power.gif" alt="Power and battery" width="100%"><br>
  <sub><b>Power &amp; battery</b><br>Profile, charge window and presets</sub>
</td>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/system-monitor.gif" alt="System monitor" width="100%"><br>
  <sub><b>System monitor</b><br>CPU, iGPU, memory, temperature and pressure</sub>
</td>
</tr>
</table>

## Feedback and capture

<table align="center">
<tr>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/system-packages.gif" alt="System packages" width="100%"><br>
  <sub><b>System packages</b><br>Native, AUR and Flatpak pending updates</sub>
</td>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/recorder.gif" alt="Recorder" width="100%"><br>
  <sub><b>Recorder</b><br>Source selection and screen capture</sub>
</td>
</tr>
<tr>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/notices.gif" alt="System notices" width="100%"><br>
  <sub><b>Notices</b><br>Battery, charger, mic and peripheral OSD events</sub>
</td>
<td width="50%" align="center" valign="top">
  <img src="assets/showcase/notifications.gif" alt="Notification inbox" width="100%"><br>
  <sub><b>Notifications</b><br>Inbox with critical and normal entries</sub>
</td>
</tr>
</table>

## Use it

- Hover the top strip, or press `Super+Shift+Space`, to open the pill.
- Click the workspace chip for the launcher; `Search` is inside Settings.
- Wheel, scrollbar, `PageUp`/`PageDown`, `Home` and `End` scroll long pages.
- Back returns to the parent page; `Escape` closes the surface.
- Status order and widgets persist in `~/.local/state/reddot/bar.json`.
- `System packages` keeps its download glyph at zero and grows only with the count badge.

Search is metadata-driven:

```text
wifi → Wi-Fi            bios → ThinkPad hardware
mic  → Audio / Pill     pacman → System packages
```

## Game mode

Open **Power & battery → Game mode**, or use the gamepad chip in the Mixer.
Choose the game window, mark the apps to keep, then start. The mode strips
Hyprland decorations and animations, enables DND and keep-awake, pauses the
visualizer, and keeps the target tree and allowlist alive.

Closing other apps is opt-in and uses SIGTERM after confirmation. Only mapped
Hyprland windows are candidates; the game tree, allowlist, Steam/Gamescope and
session services are protected. The mode exits when the target window closes.

## Install and check

```sh
curl -fsSL https://raw.githubusercontent.com/SrRenks/reddot/e14g7/install.sh | bash

tools/check.sh
tools/check-static.sh
tools/smoke-surfaces.sh   # needs a running pill
```

Arch, Debian 13+, Fedora 44+ and openSUSE Tumbleweed are supported. The bootstrap
installs `git` and `rustc`; the installer backs up replaced files. See
[docs/getting-started.md](docs/getting-started.md) for `--quickstart`, `--full`,
`--dry-run` and `--uninstall`.

[Usage](docs/usage.md) · [Architecture](docs/architecture.md) ·
[Operations](docs/operations.md) · [Coverage](docs/coverage.md) ·
[Game mode study](docs/gamemode-study.md) · [Changelog](CHANGELOG.md)

Hyprland + Lua · Quickshell + QML · Rust installer and helpers · MIT.
Fork of [Ricelin](https://github.com/Gakuseei/Ricelin) by Gakuseei.
