# Roadmap

Status of the main follow-ups after the Settings, package and scroll work.

## Now

- Keep the QML warning baseline from growing.
- Run the installer integration gate on every change to `installer/`.
- Keep the docs structure and links valid.
- Preserve one scroll path and one settings-row keyboard model.

## Next

- Qt Quick behavior tests for scroll, drag, back and lastSurface.
- A lock-shell smoke test that does not lock the live session.
- A PSS/RAM budget for the pill and lock processes.
- Adversarial tests for the updater and privileged helpers.
- Truly data-driven critical-package detection for the package meter.

## Later

- Split the largest QML files only where a tested lifecycle boundary exists.
- Replace synchronous Loader use with LazyLoader only after a startup and RAM measurement.
- Add per-section reset and search to Settings.
