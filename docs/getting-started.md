# Getting started

## Requirements

- Hyprland with Wayland.
- Quickshell 0.3.x.
- One of the supported package families:

```text
Arch
Debian 13+
Fedora 44+
openSUSE Tumbleweed
```

Leap 15.6 and Gentoo are intentionally rejected: the former has no OBS target
for the Hyprland set, and the latter is source-only and outside the verified
binary matrix.

The bootstrap installs `git` and `rustc`; the installer itself is Rust and
contains no Python entry point.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/SrRenks/reddot/e14g7/install.sh | bash
```

Read `install.sh` first if you piped it. It backs up replaced files and deploys
the configuration to `~/.config`.

Useful flags:

```text
--quickstart   core defaults, no questions
--full         include the daily applications
--custom       choose optional applications interactively
--sddm         install the torii SDDM theme
--no-deps      deploy configuration only
--dry-run      print the plan without changing anything
--reinstall    rerun an existing installation
--uninstall    remove managed configuration and restore backups
```

Then start Hyprland from a TTY. The pill starts with the session; if it is not
visible:

```sh
qs -c pill
```

## First checks

```sh
tools/check.sh
tools/check-static.sh
tools/smoke-surfaces.sh   # needs a running pill
```

`reddot update` checks the installed version; `reddot status` shows the pill and
lock process. The full validation matrix is in [coverage.md](coverage.md).
