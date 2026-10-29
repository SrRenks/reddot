# Roadmap

Status of the main follow-ups after the Settings, package and scroll work.

## Now

- Keep the QML warning baseline from growing.
- Run the installer integration gate on every change to `installer/`.
- Keep the docs structure and links valid.
- Preserve one scroll path and one settings-row keyboard model.

## Done on 2026-10-28

- Real password and fingerprint PAM execution, with the lock auth split into
  independent contexts.
- Physical Bar verification: drag, Escape-cancel, wheel over an open panel,
  scale 1.25 and `lastSurface` via the real keybind.
- PSS budget checked on the host for fresh idle, post-surface and resident-lock
  states.
- Adversarial argument cases for the TLP and ThinkPad helpers.
- Two-output lock verified with `WlSessionLock.secure=true` on `eDP-1` plus a
  headless output.
- Physical pointer click on the panel back chip confirmed working by the user.
- Navigation manifest, status hover labels and a Search surface with pure
  alias/tag/typo ranking. Enter activation was confirmed by the user.
- `SUPER+SHIFT+F` opacity restoration, updater remote/branch migration and the
  Ubuntu CI portability fixes.

## Next / deferred

- Search row-level focus: open a page and focus a specific setting row.
- Updater adversarial fuzz: helper arguments were covered, the update helper was
  not fuzzed in this cycle.
- Installer execution in VMs for the supported four families; done in the
  Arch/Debian/Fedora/Tumbleweed matrix (Leap and Gentoo intentionally rejected).
- Multi-monitor physical test of hotplug, mixed DPI and a two-output lock.
- Decide whether to remove the three extra enrolled `fprintd` fingers.
- Truly data-driven critical-package detection for the package meter.

## Later

- The Rust runtime migration is complete for the supported matrix; the Python
  parity harness is archived per [ADR 0035](decisions/0035-python-harness-archive.md).

- Split the largest QML files only where a tested lifecycle boundary exists.
- Replace synchronous Loader use with LazyLoader only after a startup and RAM measurement.
