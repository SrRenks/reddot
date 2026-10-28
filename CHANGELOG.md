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

### Changed

- Renamed `docs/ARCHITECTURE.md` to `docs/architecture.md` and
  `docs/COVERAGE.md` to `docs/coverage.md`.
- Moved the package parser into `Singletons/PackageUpdatesParser.js` so the QML
  singleton no longer imports across directories.
- README now points to the documentation index instead of an incomplete list.
- Architecture and coverage notes reflect the current warning baseline and
  verification commands.

### Fixed

- Strict string comparisons in the wallpaper, launcher and app lists.
- Dynamic host contract in the notification toast, keeping the QML boundary explicit.
- Nested Tooltip access to the component scale.
- Package parser test path after the parser move.
