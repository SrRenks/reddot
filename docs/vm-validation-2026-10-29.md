# VM validation: 2026-10-29

Real cloud VMs, QEMU/KVM, cloud-init and a passwordless sudo user. Each run used
`install.sh --quickstart` with the Rust installer; no Python installer.

| Distro | Result | Evidence |
| --- | --- | --- |
| Debian 13 (trixie) | PASS, including reboot | Hyprland, quickshell, matugen; NetworkManager and bluetooth enabled; `reddot-update check` returned JSON after reboot |
| openSUSE Tumbleweed 20261027 | PASS | Hyprland, quickshell, services enabled; closing report |
| Fedora 44 | PASS, including reboot | Hyprland 0.57, quickshell, awww, matugen; NetworkManager and bluetooth enabled; `reddot-update check` returns JSON |
| openSUSE Leap 15.6 | FAIL | OBS `home:AvengeMedia:danklinux` has no `openSUSE_Leap_15.6` target; native package batch fails; use Tumbleweed for the SUSE family |
| Arch | PASS, including reboot | Hyprland, quickshell, matugen, yay; NetworkManager and bluetooth enabled; AUR bootstrap built yay-bin; `reddot-update check` returns JSON after reboot |
| Gentoo | not VM-tested | dry-run only |

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
- Decide whether Leap 15.6 is supported; if yes, add source fallbacks or a repo.
- Boot-test Fedora/Tumbleweed after the package fixes.
- Gentoo install.

## Follow-up after the run

- The Fedora COPR still lacks `libaquamarine.so.10` and `libhyprutils.so.12`
  for both `hyprland` and `hyprland-git`; the installer now fails instead of
  reporting success with Hyprland absent.
- Fedora 43's `quickshell`, `matugen` and services did install.
- Tumbleweed's Hyprland/quickshell services were present after install.
