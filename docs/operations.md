# Operations

## Updates

```sh
reddot update
```

The updater keeps protected settings, backs up replaced files and reports
conflicts instead of overwriting them. `reddot uninstall` removes managed
configuration and restores backups; run it from `~/.local/bin/reddot-install` if
the CLI is not available.

After changing helper code:

```sh
sudo ~/.local/share/reddot/tools/install-extras.sh
reddot restart pill
```

## Power and hardware

- The Power surface covers TLP profiles, charge thresholds, pause/resume and
  session actions.
- Presets combine a profile and charge window; they live in Settings → Power.
- Battery history comes from UPower.
- ThinkPad hardware exposes fan RPM, thermal sensors, fan curve, TrackPoint and
  keyboard LEDs through the optional helper.

See `tools/reddot-tlp` and `tools/reddot-thinkpad` for the privileged surfaces.

## Startup and appearance

- Startup commands are managed in Settings → Maintenance → Startup.
- Appearance covers theme, palette, typography, bar, shell and effects.
- Wallpaper changes drive matugen and the Rust palette engine.
- Window blur/transparency and panel blur are independent; `Super+Shift+F`
  toggles the window layer.

## Capture

`Print` or `Super+F9` starts rishot. `Shift+Print` captures the current monitor.
The recorder is available from the pill or `Super+Shift+R`.
