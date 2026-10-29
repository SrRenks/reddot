# Getting started

reddot targets Arch Linux with Hyprland and Quickshell. The installer can also
deploy the configuration on Debian 13+, Fedora 44+ and openSUSE Tumbleweed, but the
reference environment is Hyprland 0.56 and Quickshell 0.3.2.

## Install

Run the bootstrap from a TTY:

```sh
curl -fsSL https://raw.githubusercontent.com/SrRenks/reddot/e14g7/install.sh | bash
```

The bootstrap installs `git` and `python3`, clones the checkout into
`~/.local/share/reddot`, and hands off to the Python wizard. The wizard installs
packages, deploys the configuration to `~/.config`, backs up replaced files and
then runs `tools/install-extras.sh` for the privileged helpers.

Non-interactive paths:

```text
--quickstart  core defaults, no questions
--full        also install the daily applications
--sddm        install the Torii SDDM theme
--no-deps     skip packages and only deploy configs
--dry-run     print the full plan without changing anything
--skip-extras skip TLP, ThinkPad helpers and user tools
```

Start Hyprland from a TTY after the installer finishes. The pill starts through
the Hyprland autostart module; if it does not appear, run:

```sh
qs -c pill
```

## First checks

From the checkout:

```sh
sh tools/check.sh
sh tools/check-integration.sh
sh tools/smoke-surfaces.sh
```

`check.sh` is the main gate. `check-integration.sh` validates the installer and
the system files. `smoke-surfaces.sh` needs a running pill and opens each surface
in sequence; it is optional outside a desktop session.

## Configuration sources

- `~/.config/hypr/modules/` — Hyprland Lua modules.
- `~/.config/quickshell/pill/` — pill QML and singletons.
- `~/.local/state/reddot/flags.json` — user settings.
- `~/.local/state/reddot/` — presets, update state and recording state.

Do not edit the deployed copy to make a permanent change: edit the checkout and
redeploy, or use the in-app updater. Protected user files are listed in
[Maintenance](MAINTENANCE.md).
