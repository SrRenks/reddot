# Architecture review

Audit of the pill shell after the Startup, keybind, blur/transparency and
focus/back changes. This is a map of the current seams, not a rewrite proposal.

## Snapshot

| Area | Current shape |
|---|---|
| Pill QML | `Pill.qml` is ~3,000 lines |
| Shell/overlay | `shell.qml` is ~1,000 lines |
| Surface count | 40 catalog entries; 41 Loaders and 40 `surface === "..."` booleans |
| Size rule | every surface is capped at the monitor's vertical midpoint; `PillSurface` is a Flickable that scrolls the overflow and reports its content height to the host scrollbar |
| Surface sizes/morph | 40 entries in the `surfaces` map |
| Surface metadata | `lib/surfaces.js` catalog |
| Back routing | catalog parent + shared top-strip control + `Pill.surfaceBack()` special cases |
| Persistent UI state | `Flags.lastSurface` |
| Focus routing | `shell.qml` + `PillSurface` + `HyprlandFocusGrab` |
| QML lint | 180 warning occurrences in the reviewed baseline, zero errors |
| Navigation metadata | `lib/navigation.js`: titles, subtitles, aliases, tags and status targets; checked against the catalog and status order by `check-navigation.mjs` |
| Tests | `tools/check.sh` validates every QML file, the warning baseline, lua/helpers, the surface catalog, the UI contract and the documentation links; behavior still needs a Qt Quick test harness |

## Where adding a surface touches code

The catalog now removes the back/cold/classification edits, but a new surface
still requires:

1. `Pill.qml`: a `surface === "name"` boolean.
2. `Pill.qml`: a width constant.
3. `Pill.qml`: a `surfaces` size/ame entry.
4. `Pill.qml`: a `Loader`.
5. `Pill.qml`: the generic `rowNavSurface()` resolves it from `lib/surfaces.js`.
6. `shell.qml`: a convenience IPC function; `page <name>` already provides
   a generic fallback.
7. `Settings.qml`: an index row when it belongs in the settings index.
8. `Updates.qml`: a config-file label, when applicable.

That is still the main source of rigidity, but the duplicated lists that caused
drift are gone: `settingsLike`, `hasInlineBack`, parent routing, `lastSurface`
validation and the cold-unload set now all read `lib/surfaces.js`.

## Other concrete seams

- `Pill.qml` owns layout, surface metadata, loading, back routing, key routing
  and many feature-specific helpers in one file.
- `shell.qml` owns windowing, focus, pointer warp, IPC, layer geometry and
  panel presentation. The focus fix had to touch all of these.
- `lastSurface` is a bare string in `Flags`; there is no validation against the
  surface catalog and no back stack. A malformed value simply opens nothing.
- Back behavior is split between:
  - `SettingsHeader` chevrons;
  - the shell-level floating chevron;
  - `Pill.surfaceBack()` if-chain;
  - per-panel form closers.
- `settingsLike`, `hasInlineBack` and `cold` come from the catalog; the loader
  list is still explicit in `Pill.qml` and checked by `check-surfaces.mjs`.
- QML warnings are enforced through `tools/qml-warning-baseline.json`; new
  warnings fail the gate.
- The rishot current-monitor feature is a **local patch** outside this repo.
  `docs/RISHOT.md` records it, but a rishot reinstall loses it.

## Recommended modularity path

### P0 — metadata without changing the UI (applied)

- `lib/surfaces.js` now describes every surface:
  ```js
  { parent, settingsLike, inlineBack, cold }
  ```
- `Pill.qml` uses it for `settingsLike`, `hasInlineBack`, parent back routing,
  and the cold-unload loop.
- `shell.qml` validates both IPC surface names and `Flags.lastSurface`.
- A generic `page(mon, name)` IPC already existed and is the scripting door.
- `tools/check-surfaces.mjs` now fails if the catalog and `Pill.qml` surface
  booleans / cold-loader map drift.
- Remaining P0 follow-ups: width/loader/Settings-row generation, and a check
  that every catalog id maps to a Loader.

### P0.5 — navigation metadata (applied)

- `lib/navigation.js` names every catalog page and every status item.
- Status labels and hover tooltips read that manifest; the manifest is checked
  against `lib/surfaces.js`, `StatusOrderList.qml`, `Settings.qml` and the hub
  entries.
- `StatusTooltip.qml` is the shared hover label for the status row.
- The next step is P1: generate the Settings index and hubs from this metadata,
  then add the Search surface on the same model.

### P1 — SurfaceHost

- Extract Loader creation and cold-unload into `SurfaceHost.qml`.
- Keep a `Component` map keyed by catalog id. A `Repeater`/factory creates the
  loader with the standard `s`, `open`, `morphCloseness`, `onRequestClose`,
  `onRequestBack` wiring.
- Generate IPC verbs from the catalog, or replace the per-surface verbs with:
  ```text
  qs -c pill ipc call pill open <name>
  ```
  while keeping aliases for the old verbs.
- Generate Settings rows and hub entries from navigation metadata.
- Add Search over the same nodes, with page-first and row-focus results.

This removes the eight-touch-point problem without introducing a framework.

### P2 — split the monoliths

- `Pill.qml` → `PillFrame.qml` (visual body), `PillState.qml` (mode/size),
  `PillKeys.qml` (keyboard routing), `PillBack.qml` (navigation).
- `shell.qml` → `OverlayHost.qml` (layer windows), `FocusController.qml`
  (keyboard focus, grab, pointer warp), `IpcRouter.qml`.
- Only move code when a change touches the same seam twice; avoid a pure
  file-count refactor.

### P3 — state and navigation

- Add `stateVersion` to `flags.json` with explicit migrations.
- Validate `lastSurface` against the catalog; fall back to `settings`.
- Replace `lastSurface` with a small navigation state:
  ```js
  { current, backStack: [] }
  ```
  This would make “Escape goes to the previous panel” deterministic instead of
  a hardcoded parent map. Keep it in memory and persist only the last stable
  surface if persistence is still desired.
- Move transient focus/warp state out of `Flags`.

### P4 — testability

- `tools/check.sh`: add a QML load test and fail on `Failed to load
  configuration`.
- Add parser tests for `lib/autostart.js`, `lib/binds.js`, `lib/setDeco.js`.
- Add a lightweight QML test for Escape/back state, not full UI automation.
- Keep the QML warning baseline at zero new occurrences; clean existing
  warnings in reviewed batches.

## Priorities for this repository

1. Surface catalog + consistency check (highest value, low risk).
2. Generic surface IPC + Settings rows.
3. Focus/Overlay extraction.
4. Navigation back stack.
5. Split `Pill.qml` only after the catalog exists.

Do not introduce a new UI framework or generic event bus. The current
Quickshell/loader model is sound; the problem is duplicated metadata and
routing, not the widget layer.
