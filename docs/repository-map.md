# Repository map

The checkout separates the shell, the desktop configuration, the installer and
the helper tools. Generated files and Python caches are not tracked.

## Top level

| Path | Role |
|---|---|
| `assets/` | Screenshots and demonstration images referenced by the README. |
| `configs/` | Files deployed into the user's config directories. |
| `docs/` | Committed project documentation. |
| `installer/` | Python installer: distro detection, package planning, deployment, TUI. |
| `tools/` | Helpers, checks, tests and privileged system policy. |
| `install.sh` | Bootstrap that fetches the checkout and starts the Python installer. |
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
| `installer/reddot_install.py` | Flow orchestration and CLI. |
| `installer/distro.py` | Distribution detection and package resolution. |
| `installer/pkg.py` | Package-manager argv, repositories and privilege rules. |
| `installer/fallbacks.py` | Source-build fallbacks for packages unavailable in a distro. |
| `installer/deploy.py` | Deploy, neutralize, backup and uninstall planning. |
| `installer/tui.py` | Interactive prompts and reports. |
| `installer/packages.json` | Package manifest. |

## Tools

| Path | Role |
|---|---|
| `tools/check.sh` | Main validation gate. |
| `tools/check-integration.sh` | Installer, udev, polkit, systemd and TLP checks. |
| `tools/check-ui-contract.mjs` | Surface and status contracts. |
| `tools/check-qml-warnings.mjs` | QML warning baseline gate. |
| `tools/check-hypr-api.sh` | Rejects legacy Hyprland syntax. |
| `tools/smoke-surfaces.sh` | Runtime surface smoke. |
| `tools/reddot-tlp` | Privileged TLP helper. |
| `tools/reddot-thinkpad` | Privileged ThinkPad helper. |
| `tools/reddot-sensors.rs` | Native sensor snapshot. |
| `tools/49-reddot.rules` | Polkit allowlist. |
| `tools/99-reddot-leds.rules` | ThinkPad mute LED udev rule. |
