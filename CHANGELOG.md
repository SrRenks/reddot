# Changelog

All notable changes are recorded here. The project follows Keep a Changelog and
semantic versioning when it cuts a release.

## Unreleased

### Added

- QML warning baseline and gate, tracking each warning occurrence per file.
- Hyprland API and legacy-syntax check.
- Documentation index, getting-started guide, repository map, roadmap and
  validation checklist.
- Relative-link checker for committed documentation.
- Project conventions for QML surfaces, singletons, loaders, scale and Hyprland
  modules.
- Headless CI gate and reusable `check-static.sh`.
- Node tests for scroll and status-order behavior.
- Static lock-flow review and isolated deploy/re-deploy/uninstall test.
- Host-only performance snapshot and privileged-boundary check.
- Five-family synthetic installer matrix and a static session-target contract.
- QML runtime harness, detailed lock/multi-monitor checks and a broader
  performance procedure.
- First real PSS/RSS measurements for pill states and the resident lock.
- Password and fingerprint authentication split into independent PAM contexts;
  fingerprint is started explicitly with Enter on an empty field.
- Security page grouping fingerprint, auto-lock, screen-off and suspend
  controls.
- Advisory helper validation cases for shell metacharacters, extra arguments and
  path-like names.
- `WlSessionLock.secure` diagnostic and a supervised two-output lock smoke.
- Physical Bar drag and Escape-cancel validation against the real eDP-1 layout.
- Wheel input over an open panel now scrolls instead of being swallowed by the
  surface.
- IPC `back` and `surface` controls for supervised surface-routing tests.
- `lastSurface` reopen validated with the real Super+Shift+Space binding.
- Navigation manifest with aliases/tags, status hover tooltips and a contract
  tying catalog, status order, Settings index and hubs together.
- `SUPER+SHIFT+F` now restores usable active/inactive opacity instead of
  preserving an opaque saved state.
- Updater clones from the old Ricelin origin are retargeted to
  `SrRenks/reddot` on branch `e14g7`.
- Search surface with pure alias/tag/typo ranking over the navigation manifest.
- Package meter now detects pacman, dnf/RPM, zypper/RPM and apt backends and
  labels the native source accordingly.
- Package meter accepts `paru` as an AUR fallback, prefers `checkupdates` for a
  rootless refresh and hides sources that are not installed.
- Fan RPM keeps the highest valid sensor value instead of being overwritten by a
  zeroed generic hwmon entry.
- The update engine is implemented in Rust and selected through a wrapper; the
  Python engine remains as a fallback until the extras build the binary.
- The palette engine is implemented in Rust and selected through a wrapper;
  wallpaper, Appearance and the installer call the same entry point.
- CI portability fixes: bash-only scripts use bash for syntax, and the package
  selftest no longer assumes pacman is installed on the Ubuntu runner.

### Changed

- Renamed `docs/ARCHITECTURE.md` to `docs/architecture.md` and
  `docs/COVERAGE.md` to `docs/coverage.md`.
- Moved the package parser into `Singletons/PackageUpdatesParser.js` so the QML
  singleton no longer imports across directories.
- README now points to the documentation index instead of an incomplete list.
- Architecture and coverage notes reflect the current warning baseline and
  verification commands.

### Fixed

- The Fedora runner no longer passes `--skip-broken`; a missing required
  Hyprland package now fails the install instead of printing success.

- Mouse-close no longer arms the keyboard hover guard, so the pill can be
  reopened from the top strip immediately after an outside click.
- A monitor connected after the awww daemon starts now gets the current wallpaper
  instead of the black default; `monitor.added`/`monitor.removed` reapply it.
- Super+arrows fall back to the adjacent monitor when no window exists in that
  direction, so an empty second output is still reachable.
- Debian 13 installs target `trixie-backports` for the Hyprland/quickshell set
  instead of enabling an Ubuntu PPA, and cargo fallbacks no longer abort when a
  distro cargo has no `~/.cargo/env`.
- The package runner stops claiming success when a native install fails; the
  installer exits nonzero instead of printing the closing "reddot is in" report.
- Strict string comparisons in the wallpaper, launcher and app lists.
- Dynamic host contract in the notification toast, keeping the QML boundary explicit.
- Nested Tooltip access to the component scale.
- Package parser test path after the parser move.

- Fedora Hyprland packages now use the `hermitfeather/hyprland` COPR, which
  has Fedora 43+ builds; openSUSE Leap uses its matching OBS target instead of
  the Tumbleweed URL.

- Arch AUR packages now bootstrap `yay-bin` when no helper is present, instead
  of failing with `yay: No such file or directory`.
- Arch cloud VM validation: install, AUR build, services and reboot pass.

- Fedora's Hyprland packages now use `lionheartp/Hyprland`, which has complete
  Fedora 43/44 builds; Fedora 44 is the validation target.

- Fedora's `swww` now uses the `hermitfeather/hyprland` COPR, whose Fedora 44
  build exists; the old `agonie/swww` repo stopped at Fedora 43.
