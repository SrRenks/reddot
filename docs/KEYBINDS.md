# Keybinds

The active map lives in `configs/hypr/modules/binds.lua`. Screenshots are in the
same file so the Settings → Keybinds editor can see them; the old
`configs/hypr/rishot.lua` was removed.

## Core

| Keys | Action |
|---|---|
| `Super+Return` | Ghostty |
| `Super+Q`, `Super+Shift+Q` | close / kill |
| `Super+E` | Yazi |
| `Super+A` | launcher |
| `Super+V` | clipboard |
| `Super+L` | lock |
| `Super+F` | fullscreen |
| `Super+1..0` | focus workspace |
| `Super+Shift+1..0` | move window to workspace |
| `Super+Left/Right/Up/Down` | focus |
| `Super+Shift+Left/Right/Up/Down` | move window |
| `Super+Space` | keyboard layout |
| `Super` + LMB/RMB | drag/resize |
| `Print`, `Shift+Print` | screenshot / monitor screenshot |

## Apps and media

| Keys | Action |
|---|---|
| `Super+W`, `Super+Shift+W` | wallpaper picker / flush |
| `Super+Shift+R` | record |
| `Super+Shift+C` | color picker |
| `Super+Shift+E` | EasyEffects bypass |
| `Super+Shift+F` | toggle general window blur |
| `Super+Shift+B` | TLP surface |
| `Super+Shift+T` | ThinkPad surface |
| `Super+G` | game mode |
| `Super+P`, `Super+Shift+P` | private workspace / send window |
| `Super+S`, `Super+Shift+S` | stash / send window |
| `Super+T`, `Super+M`, `Super+Shift+M` | float, minimize, minimized stash |
| `XF86Audio*`, `XF86MonBrightness*` | hardware keys |
| `XF86AudioMicMute` | microphone mute |

## Removed

- `Super+Shift+L` hibernate: too close to lock, no confirmation.
- `Super+F12` and `Super+Shift+F12`: duplicates of `Print`/`Shift+Print`.
- `Super+XF86AudioMute` and `Super+Shift+XF86AudioMute`: impractical media-key chords.
- `Super+B`, `Super+C`, `Super+D`: replaced by `Super+W`, `Super+Shift+W`,
  `Super+Shift+R`.

Hyprland dynamic spaces still add `Super+<key>` and `Super+Shift+<key>` from
`spaces.lua`; the Keybinds editor only lists `binds.lua`, so those dynamic rows
remain outside it.
