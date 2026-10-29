# Changelog

All notable changes are recorded here. The project follows Keep a Changelog and
semantic versioning when it cuts a release.

## Unreleased

### Added

- Bar component catalog (`BarCatalog.qml`) and persisted instance layout
  (`BarLayout.qml`, `bar.json`) with a pure `barLayout.js` model. Clock,
  Workspaces, Bar and the 14 status components now share metadata, mode and host
  declarations.
- One-time migration from the legacy bar flags to `bar.json`; Bar, Clock and
  Workspaces settings now read and write the persisted layout.
- Generic `BarComponentHost` with Clock/Workspaces icon and widget modes, host
  moves through Settings and IPC, and a catalog glyph fallback for status
  components placed outside the right cluster. Status components also render a
  generic widget chip when switched to widget mode. Settings uses static editor
  rows for every catalog definition, including the Bar container, which now has
  a persisted instance mounted at `settings.catalog` and a static widget preview.
- Optional `command` bar provider with argv-only execution, interval, timeout,
  JSON output, and icon/widget rendering. `reddot bar export` and
  `reddot bar import` validate and move the persisted layout.
- Removed the hot-trio surface preload and replaced the 16 inline component
  editors with one selected-item editor plus a compact selector. Tighter PSS
  budgets: 180 MB idle, 230 MB post, 55 MB lock.
- Paused the Ame canvas/timer whenever its form is off, eliminating the 6-8%
  CPU loop after closing a surface. Replaced the live Bar preview with a static
  card so opening Bar no longer leaves a redraw loop.
- Moved the 14-item status cluster into `BarStatusRow.qml`, built only while
  the bar is expanded. Idle no longer constructs network, tray, media and system
  widgets that cannot be clicked until hover.
- Added a persisted `workspaceDisplay` setting for the Workspaces bar component:
  `dots` (clearer current strip) or `number` (active workspace numeral), editable
  from the component editor and through `barConfig`.
- Updates now render as a compact, dynamic-width count badge and disappear when
  the package count is zero (unless the check itself failed).
- Updates has a dedicated widget renderer: the download icon is always present
  and the count badge is omitted at zero. The catalog default is now `widget`.
- Navigation metadata now carries search keywords for every page and status,
  with short-query fuzzy matching disabled for keywords/tags. Titles and hub
  labels were aligned across Search, Settings and the Bar picker.
- Added a target-aware Game mode surface: select a running window, keep
  allowlisted apps, optionally terminate other user windows with SIGTERM after
  confirmation, and restore the visual strip when the target exits.
- Fixed the System packages widget position: in `bar.right` it now renders inline
  at its status order, with no trailing widget gap, and its width grows only when
  the count badge is present.
- Settings moved Security into System and grouped the Bar component picker by
  Navigation, Information, Controls and Hardware.
- The Workspaces numeral uses a tabular chip with a vermilion accent, sharing
  `Typography` and bar scale.
- ThinkPad gained an on-demand BIOS check against Lenovo's official catalog for
  the detected machine type, with an official download page button when a newer
  version exists.
- Added configurable system notices for battery low (5–15% threshold), charger
  plug/unplug, battery full, microphone mute, microphone plug/unplug, and low
  peripheral batteries. Key notices remain independent.
- Fixed ThinkPad LED controls updating the UI before the privileged write
  succeeded. Failed or cancelled polkit authentication now leaves the last
  kernel state visible and reports the failure instead of pretending the LED
  turned on.
- Keyboard backlight now uses UPower's KbdBacklight D-Bus API: menu changes no
  longer require polkit, and Fn+Space/firmware changes update the menu through
  `BrightnessChanged`.
- Mute LEDs now follow the PipeWire source/sink mute state through
  `brightnessctl`; keyboard mute keys, the audio rows and the OSD keep the
  hardware indicators in sync.
- Added watchdog-driven memory recycling: after two idle checks over 220 MB PSS
  with no open surface or top-strip pointer, the pill process is replaced to
  release the QML type cache. The cold restart takes about 1.75 s and keeps a
  single instance.
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

- Added a semantic type scale (`micro`, `caption`, `body`, `bodyLarge`,
  `subtitle`, `title`, `display`, `hero`) through the Typography singleton and
  migrated shared settings chrome, System and Packages to it. SYSTEM labels and
  values are larger and reflow vertically at 125%.


- `reddot update`, `reddot uninstall`, the updater wrapper, the palette wrapper
  and the wallpaper search no longer invoke Python; the remaining `.py` files are
  parity tests only.

- Renamed `docs/ARCHITECTURE.md` to `docs/architecture.md` and
  `docs/COVERAGE.md` to `docs/coverage.md`.
- Moved the package parser into `Singletons/PackageUpdatesParser.js` so the QML
  singleton no longer imports across directories.
- README now points to the documentation index instead of an incomplete list.
- Architecture and coverage notes reflect the current warning baseline and
  verification commands.

### Changed

- Supported matrix is Arch, Debian 13+, Fedora 44+ and openSUSE Tumbleweed.
  Leap 15.6 and Gentoo are rejected up front instead of failing in package
  repositories or source builds.

### Fixed

- An open surface now spans the full monitor so an outside click reaches the
  backdrop and dismisses it immediately.
- Clicking another monitor dismisses the open surface through `focusedmon` /
  `activewindow`; the other outputs use an empty input mask, so the click reaches
  the desktop instead of being swallowed by a stale pill grab.
- Lock content now renders the date/time on every monitor; secondary screens
  show a LOCKED marker while authentication stays on the primary.
- The physical two-output lock was verified with `secure=true` on eDP-1 and
  HDMI-A-1, including the HDMI 2560x1080@75 mode.

- The `swww` source fallback now installs the Wayland XML/protocol headers on
  Debian, Fedora, openSUSE and Gentoo; a reinstall no longer fails at
  `waybackend-scanner` with "could not find wayland.xml". Debian fallback
  dependencies also target `trixie-backports`, matching the native batch.

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

- Fedora 44 uses `awww` and the `lionheartp/Hyprland` COPR; Fedora 44 VM install
  and reboot now pass.

- Fedora installs the `awww` package; the `swww` name is provided by the
  bridge and dnf treats it as a no-op on the Terra package set.
