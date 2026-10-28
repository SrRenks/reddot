# Roadmap

Status of the main follow-ups after the Settings, package and scroll work.

## Now

- Keep the QML warning baseline from growing.
- Run the installer integration gate on every change to `installer/`.
- Keep the docs structure and links valid.
- Preserve one scroll path and one settings-row keyboard model.

## Next

- Real PAM/unlock execution in a disposable session.
- Gesture tests in a real compositor: scroll, drag, back and lastSurface.
- A PSS/RAM budget defined from host measurements.
- More aggressive adversarial tests for the updater and privileged helpers.
- Truly data-driven critical-package detection for the package meter.
- A multi-monitor run on hardware with two outputs.

## Later

- Split the largest QML files only where a tested lifecycle boundary exists.
- Replace synchronous Loader use with LazyLoader only after a startup and RAM measurement.
- Add per-section reset and search to Settings.
