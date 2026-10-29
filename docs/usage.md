# Usage

The pill is the interface. It starts as a status strip at the top of the screen
and morphs into the page you choose.

## Opening

- `Super+Shift+Space` opens or closes the last surface.
- Hover the top strip, or use `Super+A` for the launcher.
- `Search` opens from the launcher or Settings and finds pages by title, alias or
  tag.
- `Escape` closes the current surface; the back control returns to the parent
  page.
- Clicking outside closes the surface, including on another monitor. While a
  surface is open, the other outputs stay click-through instead of holding a
  stale keyboard grab.
- The wheel, scrollbar, `PageUp`/`PageDown`, `Home` and `End` work on long pages.

![Pill tour](../assets/pill-tour.gif)

## Surfaces

The shell has 41 surfaces. The main paths are:

| Area | Surfaces |
|---|---|
| Navigation | Launcher, Search, Settings |
| Desktop | Appearance, Bar, Shell, Windows, Display, Input, Security |
| System | System monitor, Packages, Updates, Maintenance |
| Audio and media | Mixer, Sound, Media, Recorder |
| Hardware | Battery, TLP, ThinkPad |
| Session | Power, Calendar, Clipboard, Notifications, Wallpaper |

Settings is a hub: `Appearance`, `Shell`, `Windows` and `Display` under Desktop;
`Input`, `Security` and `Shortcuts` under Controls; `Power`, `System` and
`Maintenance` under System.

## Search

![Search](../assets/search.gif)

Search ranks the navigation manifest. Examples:

```text
wifi         → Wi-Fi
volume       → Mixer
fingerprint  → Security
fan          → ThinkPad
gui          → Bar layout
```

## Bar

![Bar layout](../assets/bar.gif)

The normal bar exposes the clock and status icons. Clicking Wi‑Fi, battery or the
package meter opens the matching surface; the status cluster can be reordered,
hidden and moved between zones. Settings → Shell → Bar mirrors the same order and
survives a restart.

The Workspaces component has a `workspaceDisplay` setting in its `config`:

```json
"config": { "workspaceDisplay": "dots" }
```

`dots` is the default strip; `number` shows the active workspace as a numeral.
Both are editable from Settings → Shell → Bar by selecting Workspaces.

## Command providers

A `command` component runs a local executable with an argv array and reads one
JSON object from stdout. It is exported with the rest of the layout:

```json
{
  "id": "provider.balance",
  "component": "command",
  "host": "bar.right",
  "mode": "widget",
  "enabled": true,
  "config": {
    "label": "Balance",
    "icon": "sparkles",
    "command": ["/home/me/.local/bin/balance"],
    "interval": 300,
    "timeout": 10,
    "surface": "packages"
  }
}
```

The provider prints:

```json
{"label":"Balance","value":"42","detail":"tokens left","state":"ok","tooltip":"API balance"}
```

`state` may be `ok`, `warn` or `error`. The optional `surface` opens an existing
pill page; `url` opens a URL when no surface is set. Keep credentials in the
environment or a keyring, not in `config`.

```sh
reddot bar export ~/bar.json
reddot bar import ~/bar.json
```

Import validates the JSON before replacing the live layout. Export includes the
command and its arguments, so review a shared file before importing it.

## Keybinds

The active map is `configs/hypr/modules/binds.lua`. Core bindings:

| Keys | Action |
|---|---|
| `Super+Return` | Terminal |
| `Super+A` | Launcher |
| `Super+V` | Clipboard |
| `Super+W` | Wallpaper picker |
| `Super+L` | Lock |
| `Super+F` | Fullscreen |
| `Super+M`, `Super+Shift+M` | Minimize / minimized stash |
| `Super+S`, `Super+Shift+S` | Stash / send window to stash |
| `Super+Space` | Keyboard layout |
| `Super+Shift+R` | Recorder |
| `Print`, `Super+F9` | rishot |
| `Shift+Print` | Capture current monitor |

## Lock

The lock uses PAM. Password and fingerprint are independent, and any enrolled
finger can authenticate through `pam_fprintd`. On multiple monitors, the
primary output carries authentication; secondary outputs show the clock, date
and a `LOCKED` marker. A physical lock test with two outputs is recorded in
[coverage.md](coverage.md).
