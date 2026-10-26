<div align="center">

# reddot

**A personal fork of [Ricelin](https://github.com/Gakuseei/Ricelin), the hand-written Quickshell pill for Hyprland.**

Fork point: `df7fd5f`. Everything upstream credits still applies.

![reddot desktop](assets/hero.png)

</div>

reddot is my daily-driver fork: the same one morphing pill, with the changes I
run on a ThinkPad E14 Gen 7 — auto-hide, a TLP power surface, UPower history in
the battery card and a few performance fixes. The upstream README is below,
kept close to the original.

## What this fork adds

- **Auto-hide pill** — retracts to a 10 px top-centre strip and returns on hover;
  `Pill mode` and `Reserve space` are in **Look → Pill**. Fullscreen still hides it.
- **Power surface** — charge window, profile and Pause/Resume, with multi-battery
  and power-profiles-daemon sysfs fallbacks (`Super+Shift+B`).
- **Battery history** — 24 h discharge bars and 1 h/24 h averages from UPower's
  own `GetHistory`; `ricelin-power-report` prints the same plus recent packages.
- **AC/BAT policy** — `/etc/tlp.d/99-ricelin-acbat.conf`: performance on AC,
  balanced on battery, low-power for the manual saver profile.
- **Performance** — jemalloc decay in the watchdog, 30 s surface unload,
  edge-driven peripheral polling.
- **Maintenance** — `tools/check.sh`, helper tests, and `docs/` describing the
  power and memory measurements.
- ThinkPad extras (optional): on a ThinkPad only, fan/thermal telemetry, an
  editable thinkfan curve, TrackPoint, double-tap and writable LEDs. Detection is
  lazy and the helper is installed only on ThinkPad hardware, so other machines are
  unchanged.

Install runs the upstream Python installer and then `tools/install-extras.sh`
for the root helper, polkit rule, TLP policy and user tools. On a ThinkPad it
also installs the optional `ricelin-thinkpad` helper and its polkit rule; other
machines skip both.

## Install (this fork)

```sh
curl -fsSL https://raw.githubusercontent.com/SrRenks/reddot/e14g7/install.sh | bash
```


## The shell

Everything you see is hand-written Quickshell. One pill bar that morphs into whatever surface I need.

![The pill surfaces](assets/shell.png)

The pill becomes media and now playing, a calendar, the wallpaper picker, clipboard history, an audio and brightness mixer, a sound page with an EQ, AutoEQ headphone profiles, per-app volume and a mic noise filter, and network and bluetooth controls. There is also an app launcher, a lock screen, and [rishot](https://github.com/Gakuseei/rishot), my own screenshot and annotation tool, which lives in its own repo so you can read all of it there.

## Stack

- WM: Hyprland, configured in Lua
- Shell UI: custom Quickshell
- Terminal: Ghostty
- Shell: fish
- Font: JetBrains Mono Nerd
- Colors: matugen, palette pulled from the wallpaper

matugen pulls a palette from each wallpaper and recolors the pill, terminal, window borders, fastfetch and GTK apps. The shell itself runs a warm vermilion theme I tuned by hand.

<div align="center">

![the palette is pulled from the wallpaper](assets/wallust.gif)

![Wallpaper retheme](assets/retheme.gif)

</div>

## Install

> [!WARNING]
> The installer is young. It hasn't had a clean-machine run beyond mine yet, so expect rough edges. Read `install.sh` first and keep backups. If something breaks, file a bug and say it's the installer.

One line, straight through the pipe:

```sh
curl -fsSL https://raw.githubusercontent.com/SrRenks/reddot/e14g7/install.sh | bash
```

`install.sh` is a thin bootstrap: it detects your distro (Arch, Debian, Fedora,
openSUSE or Gentoo), makes sure git and python3 are there, clones the rice into
`~/.local/share/reddot`, then hands off to the guided Python installer. That part
walks you through a short wizard, picks the right package names for your distro,
pulls the deps and copies the configs into `~/.config`, backing up anything it
replaces. The monitor layout and GPU env are swapped for portable defaults so it
boots on any hardware; my own layout is kept next to it as `monitors.lua.example`.
Then start `Hyprland` from a TTY.

Skip the wizard with flags, passed straight through the pipe:

```sh
curl -fsSL https://raw.githubusercontent.com/SrRenks/reddot/e14g7/install.sh | bash -s -- --quickstart
```

```
--quickstart  core defaults, no questions
--full        also install the daily apps (dolphin, keepassxc, zathura, imv, rnote)
--sddm        also install the torii SDDM login theme
--no-deps     skip the package step, just deploy the configs
--dry-run     walk the whole flow and change nothing
--skip-extras skip the TLP/ThinkPad helpers and user tools step
```

Ricelin is a Hyprland shell. On Niri, Sway or anything else only rishot (the
screenshot tool) makes sense; grab it from [rishot](https://github.com/Gakuseei/rishot)'s own installer.

## Keybinds

| Key | Action |
|---|---|
| `Super` + `Return` | terminal |
| `Super` + `A` | app launcher |
| `Super` + `V` | clipboard history |
| `Super` + `C` | wallpaper picker |
| `Super` + `B` | shuffle wallpaper and retheme |
| `Super` + `E` | file manager (yazi) |
| `Super` + `T` | toggle floating |
| `Super` + `L` | lock |
| `Super` + `Shift` + `B` | power surface |
| `Print` | rishot |

## Notes

These started as personal dotfiles, built around one machine. The installer
neutralises the hardware-specific monitor/env bits, but the fork still carries
my keymap, 0-gap/master layout and the TLP helper, so read before you borrow.

## License

MIT. Upstream code © 2026 [Gakuseei](https://github.com/Gakuseei); my changes
© 2026 Ricardo Castro (SrRenks). The full text is in [LICENSE](LICENSE).
Wallpapers are not in the repo; see [WALLPAPERS.md](WALLPAPERS.md). The SDDM
background is third-party; see [CREDITS](configs/sddm/themes/torii/CREDITS.md).

## Docs

- [Power and energy tooling](docs/POWER.md)
- [Measured memory and reductions](docs/LIGHTWEIGHT.md)
- [Maintenance and update procedure](docs/MAINTENANCE.md)
- [Related shells and ideas](docs/FORKS.md)
- [ThinkPad controls and layout](docs/THINKPAD.md)
- [Credits and licenses](docs/CREDITS.md)

## Credits

The lock screen, the SDDM background and the wallpapers are not mine. See [CREDITS](configs/sddm/themes/torii/CREDITS.md).

The sound page started as a proposal by [@Seza007](https://github.com/Seza007) in [#31](https://github.com/Gakuseei/Ricelin/issues/31). AutoEQ profiles come from [AutoEq](https://github.com/jaakkopasanen/AutoEq).
