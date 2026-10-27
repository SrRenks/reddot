# rishot key integration

- `Print` and `Super+F9` start rishot in region/window mode.
- `Shift+Print` and `Super+Shift+Print` start it directly on the focused monitor,
  with no monitor-picker click.

The current-monitor path uses:

- `configs/hypr/scripts/reddot-shot-current.sh`: reads the focused monitor from
  `hyprctl -j activeworkspace` and passes `RISHOT_MONITOR` to rishot.
- A local `current` mode in `~/.local/share/rishot` that selects that monitor
  before the overlay becomes interactive.

The local rishot checkout is outside this repository. A rishot reinstall or
update can overwrite the `current` mode; re-apply the same two changes to
`bin/rishot` and `src/shell.qml` if that happens.
