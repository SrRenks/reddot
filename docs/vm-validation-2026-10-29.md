# VM validation: 2026-10-29

Real cloud VMs, QEMU/KVM, cloud-init and a passwordless sudo user. Each run used
`install.sh --quickstart` with the Rust installer; no Python installer.

| Distro | Result | Evidence |
| --- | --- | --- |
| Debian 13 (trixie) | PASS, including reboot | Hyprland, quickshell, matugen; NetworkManager and bluetooth enabled; `reddot-update check` returned JSON after reboot |
| openSUSE Tumbleweed 20261027 | PASS | Hyprland, quickshell, services enabled; closing report |
| Fedora 44 | PASS, including reboot | Hyprland 0.57, quickshell, awww, matugen; NetworkManager and bluetooth enabled; `reddot-update check` returns JSON |
| openSUSE Leap 15.6 | REJECTED | no OBS target for `home:AvengeMedia:danklinux`; use Tumbleweed |
| Arch | PASS, including reboot | Hyprland, quickshell, matugen, yay; NetworkManager and bluetooth enabled; AUR bootstrap built yay-bin; `reddot-update check` returns JSON after reboot |
| Gentoo | REJECTED | source-only and outside the verified binary matrix |

## Fixes found by the VMs

- `install.sh` must probe that `/dev/tty` opens, not just exists.
- Debian must not enable the Ubuntu-only avengemedia PPA; quickshell is in
  trixie-backports.
- Debian apt must target `<codename>-backports` and the runner must parse
  `VERSION_CODENAME` correctly.
- Distro cargo 1.85 is too old for matugen; the fallback bootstraps rustup when
  cargo is below 1.88.
- Fedora 44 uses `lionheartp/Hyprland`; `hermitfeather/hyprland` lacked the
  Hyprland runtime libraries on Fedora 43. Fedora's wallpaper daemon is packaged
  as `awww`, not `swww`.
- The openSUSE OBS URL must use the detected Leap target, but that target does
  not exist for the AvengeMedia project; Tumbleweed works.
- `--skip-broken` hid a missing Hyprland package and produced a false success.
- Arch had no AUR helper on the cloud image; the runner now bootstraps `yay-bin`
  with base-devel before the AUR batch.

## Remaining validation

- Fedora 44 pass replaces the earlier Fedora 43 partial result.
- Leap 15.6 and Gentoo are intentionally rejected with a clear message.
- Arch, Debian and Fedora were reboot-tested; Tumbleweed was validated without a reboot.

## Follow-up after the run

- Fedora 44 uses `lionheartp/Hyprland` and `awww`; the older Fedora 43
  `hermitfeather/hyprland` package set lacked the required runtime libraries.
- Tumbleweed's Hyprland/quickshell services were present after install.
- The remaining test gaps are recorded in [coverage.md](coverage.md).


## Follow-up: updater, reinstall and physical lock

- Debian updater: 17 commits behind; `reddot-update apply` returned
  `applied=true`, `codeChanged=true`, no conflicts and no dependency failures.
- Debian reinstall: `install.sh --reinstall --quickstart` completed after adding
  Wayland headers and Debian backports to the `swww` fallback; `swww` and
  `swww-daemon` are installed in `~/.local/bin`.
- Physical outputs: eDP-1 1920x1200@60 and HDMI-A-1 2560x1080@74.99.
  `WlSessionLock.secure=true` covered both; the primary shows authentication and
  the secondary shows date, clock and a LOCKED marker.
- Headless hotplug: `HEADLESS-1` received a pill layer and the current wallpaper,
  then was removed cleanly. A physical cable unplug/replug was not performed.
