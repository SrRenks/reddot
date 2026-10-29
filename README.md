<div align="center">

# reddot

A Hyprland desktop built around one morphing Quickshell pill.

Personal fork of [Ricelin](https://github.com/Gakuseei/Ricelin), maintained on a ThinkPad E14 Gen 7.

![reddot](assets/hero.png)

</div>

reddot replaces the usual bar, launcher, mixer and settings windows with one
pill. It starts as a thin status strip and expands into the page you need:
launcher, Search, Settings, system monitor, Wi‑Fi, Bluetooth, appearance,
battery and power tools. There are 41 surfaces in total.

The project is a personal setup, not a distribution. The supported installer
matrix is Arch, Debian 13+, Fedora 44+ and openSUSE Tumbleweed.

## The pill

Hover the top strip or use `Super+Shift+Space`. The pill grows in place, keeps
the same geometry while it morphs, and returns to the strip when you leave.

![Pill tour](assets/pill-tour.gif)

- `Super+A` opens the launcher.
- The wheel, scrollbar, `PageUp`/`PageDown`, `Home` and `End` work on long pages.
- `Search` finds pages by title, alias and tag.
- The back control returns to the parent page; `Escape` closes the surface.
- `Super+Shift+Space` reopens the last surface.

## Search

![Search](assets/search.gif)

Search understands informal names and small typos:

```text
wifi         → Wi‑Fi
volume       → Mixer
fingerprint  → Security
fan          → ThinkPad
gui          → Bar layout
```

## Bar

![Bar layout](assets/bar.gif)

The status cluster can be reordered, hidden and moved between zones. The Bar
page uses the same order and keeps it across restarts.

## System and security

- **System** shows CPU, iGPU, memory, temperature, fan RPM, network, disk, swap
  and compute governor without a background daemon.
- **Power** covers TLP profiles, charge windows, presets and session actions.
- **ThinkPad** exposes fan curve, TrackPoint and keyboard LEDs on supported
  hardware.
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

## Credits

Fork of [Ricelin](https://github.com/Gakuseei/Ricelin) by
[Gakuseei](https://github.com/Gakuseei). See [docs/CREDITS.md](docs/CREDITS.md)
for third-party work and asset credits.

MIT. Upstream © 2026 Gakuseei. reddot changes © 2026 Ricardo Castro (SrRenks).
