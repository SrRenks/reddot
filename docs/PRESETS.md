# Power presets

A preset is one named snapshot of the TLP power policy: profile plus charge
window. Applying it changes both at once through one `pkexec` call.

The defaults are deliberately the two modes this machine uses:

| Name | Profile | Charge |
|---|---|---|
| Desktop | Performance | 40–80% |
| Laptop | Balanced | 95–100% |

Names are user-editable. Create, rename or delete presets from
**Settings → Presets**.

## Using it

- **Apply** writes the profile and the charge window for every battery.
- **New preset** opens a form with name, profile and two charge values.
- Clicking a row opens the same form for editing.
- **Delete** removes the selected preset; **Cancel** leaves it untouched.
- The active dot comes from a live `reddot-tlp status`, not from the last
  button pressed. If the live profile or window differs, no preset is marked
  active.

The status read is unprivileged. Only Apply asks for authentication, and the
polkit rule keeps that authentication for five minutes.

## Storage

```text
~/.local/state/reddot/presets.json
```

The file is ordinary JSON and can be edited by hand:

```json
{
  "version": 1,
  "presets": [
    { "name": "Desktop", "profile": "performance", "start": 40, "stop": 80 },
    { "name": "Laptop",  "profile": "balanced",    "start": 95, "stop": 100 }
  ]
}
```

Valid profiles are `performance`, `balanced` and `power-saver`. Charge values
must satisfy `0 <= start < stop <= 100`. Names are unique and limited to 32
characters by the UI. The file is watched, so external edits appear without a
restart.

## What a preset does not change

The ThinkPad fan curve, LEDs and TrackPoint stay separate. A preset changes the
TLP profile and charge window only; this matches the actual desktop/laptop
difference on this machine. A future schema can add a fan curve snapshot
without changing the current file format.

## Efficiency

The surface reads TLP status once when it opens and once after Apply. It does
not poll while closed, and the list is a small Repeater over the JSON array.

## Implementation

| File | Role |
|---|---|
| `configs/quickshell/pill/Singletons/PresetStore.qml` | JSON store and watcher |
| `configs/quickshell/pill/PresetsSurface.qml` | list, editor and apply |
| `configs/quickshell/pill/Settings.qml` | Presets category |
| `tools/reddot-tlp` | `apply <profile> <start> <stop>` batch verb |
| `tools/49-reddot.rules` | polkit rule for TLP and ThinkPad helpers |
