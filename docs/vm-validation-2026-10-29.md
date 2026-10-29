# VM validation: 2026-10-29

Real cloud VMs, QEMU/KVM, cloud-init and a passwordless sudo user. Each run used
`install.sh --quickstart` with the Rust installer; no Python installer.

| Distro | Result | Evidence |
| --- | --- | --- |
| Debian 13 (trixie) | PASS, including reboot | Hyprland, quickshell, matugen; NetworkManager and bluetooth enabled; `reddot-update check` returned JSON after reboot |
| openSUSE Tumbleweed 20261027 | PASS | Hyprland, quickshell, services enabled; closing report |
| Fedora 43 | PARTIAL | quickshell, matugen and services installed; Hyprland COPR dependencies (`libaquamarine.so.10`, `libhyprutils.so.12`) unresolved |
| openSUSE Leap 15.6 | FAIL | OBS `home:AvengeMedia:danklinux` has no `openSUSE_Leap_15.6` target; native package batch fails |
| Arch | not VM-tested | host runtime was tested directly |
| Gentoo | not VM-tested | dry-run only |

## Fixes found by the VMs

- `install.sh` must probe that `/dev/tty` opens, not just exists.
- Debian must not enable the Ubuntu-only avengemedia PPA; quickshell is in
  trixie-backports.
- Debian apt must target `<codename>-backports` and the runner must parse
  `VERSION_CODENAME` correctly.
- Distro cargo 1.85 is too old for matugen; the fallback bootstraps rustup when
  cargo is below 1.88.
- Fedora's `solopasha/hyprland` COPR no longer has Fedora 42; Fedora 43 uses
  `hermitfeather/hyprland`, but that COPR alone does not carry all Hyprland
  runtime libraries.
- The openSUSE OBS URL must use the detected Leap target, but that target does
  not exist for the AvengeMedia project; Tumbleweed works.
- `--skip-broken` hid a missing Hyprland package and produced a false success.

## Remaining validation

- Fix or fallback Fedora Hyprland dependencies.
- Decide whether Leap 15.6 is supported; if yes, add source fallbacks or a repo.
- Boot-test Fedora/Tumbleweed after the package fixes.
- Real Arch and Gentoo installs.
