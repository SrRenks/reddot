# Repository map

The checkout separates the shell, the desktop configuration, the installer and
the helper tools. Python caches are not tracked; the old parity harness lives outside the checkout.

## Top level

| Path | Role |
|---|---|
| `assets/` | Screenshots and demonstration images referenced by the README. |
| `configs/` | Files deployed into the user's config directories. |
| `docs/` | Committed project documentation. |
| `installer/` | Rust installer support data: `packages.json` and starter wallpapers. |
| `tools/` | Helpers, checks, tests and privileged system policy. |
| `tests/qs/` | Windowless Quickshell runtime harness. |
| `install.sh` | Bootstrap that installs git/rustc, fetches the checkout and starts the Rust installer. |
| `README.md` | Short project introduction and install summary. |
| `WALLPAPERS.md` | Wallpaper sources and licensing notes. |

## Configuration

| Path | Role |
|---|---|
| `configs/hypr/hyprland.lua` | Loads the Hyprland modules. |
| `configs/hypr/modules/` | Lua modules for binds, decoration, input, monitors, rules, animations and autostart. |
| `configs/hypr/scripts/` | User-level Hyprland scripts and their tests. |
| `configs/quickshell/pill/` | Main pill QML, surfaces, components and singletons. |
| `configs/quickshell/pill/lib/` | Pure JS shared by QML or tests. |
| `configs/quickshell/pill/Singletons/` | Global QML state and the package parser. |
| `configs/quickshell/lock/` | Separate session-lock shell. |
| `configs/ghostty/`, `configs/fish/`, `configs/fastfetch/` | Terminal and shell presentation. |
| `configs/sddm/`, `configs/grub/`, `configs/kde/` | Login, boot and KDE integration. |
| `configs/systemd/user/` | User session target. |

## Installer

| Path | Role |
|---|---|
| `installer/packages.json` | Package manifest consumed by the Rust planner. |
| `installer/starter-wallpapers/` | Seed wallpapers copied by the Rust post-install step. |
| `tools/reddot-install.rs` | Rust orchestration entry point. |
| `tools/reddot-distro.rs` | Distribution detection and package resolution. |
| `tools/reddot-pkg.rs` | Package-manager argv, repositories and privilege rules. |
| `tools/reddot-fallbacks.rs` | Source-build/download/Flatpak fallback steps. |
| `tools/reddot-deploy.rs` | Deploy, neutralize, backup and uninstall planning. |
| `tools/reddot-tui.rs` | TUI renderer and input. |
| `tools/reddot-post.rs` | Post-install effects. |

## Tools

| Path | Role |
|---|---|
| `tools/check.sh` | Main validation gate. |
| `tools/check-static.sh` | Headless CI gate. |
| `tools/check-ui-contract.mjs` | Surface and status contracts. |
| `tools/check-qml-warnings.mjs` | QML warning baseline gate. |
| `tools/check-systemd-contract.sh` | Static session target contract. |
| `tools/check-hypr-api.sh` | Rejects legacy Hyprland syntax. |
| `tools/smoke-surfaces.sh` | Runtime surface smoke. |
| `tools/reddot-tlp` | Privileged TLP helper. |
| `tools/reddot-thinkpad` | Privileged ThinkPad helper. |
| `tools/reddot-sensors.rs` | Native sensor snapshot. |
| `tools/49-reddot.rules` | Polkit allowlist. |
| `tools/99-reddot-leds.rules` | ThinkPad mute LED udev rule. |
