# Manual gesture test

## Automated portion

`sh tools/check-qml-runtime.sh` exercises the real `PillSurface` viewport and
checks the clamped scroll range. Node tests cover the pure step, order and target
index calculations.

## Interactive portion

1. Open **Bar**.
2. Put the pointer inside the panel and use the wheel up and down. The content
   must stop at the first and last row without exposing a blank tail.
3. Drag the grip of **Weather** past two rows. The row must lift, the others must
   slide, and the drop line must follow. Release and confirm the order persists
   after closing and reopening the panel.
4. Start a drag, move one row and press Escape. The previous order must return.
5. Open **Settings → Shell**, press Escape and confirm the index is shown.
6. Close the panel, reopen it with `Super+Shift+Space` and confirm the last
   surface returns.
7. Repeat the scroll test with `PageUp`, `PageDown`, `Home` and `End`.
8. Test the same surfaces at `uiScale` 1.0 and 1.25. Restore 1.25 afterwards.

## Result

The windowless QML harness passes. On 2026-10-28 the physical Bar surface was
exercised with `dotool` against the real `eDP-1`, whose global x offset is 8960.

- `PageDown` moved through the status list and stopped at the last row.
- Dragging **Weather** by the grip changed the order; the saved
  `barStatusOrder` was restored afterwards.
- Starting another drag and pressing Escape left the order unchanged.
- Pointer wheel over the panel initially did not scroll: the surface consumed the
  event before the backdrop handler. `PillSurface` now forwards wheel input to
  its own Flickable; the same wheel gesture over the panel then scrolled the Bar
  list.
- The Bar surface rendered correctly at `uiScale` 1.25; the original `uiScale`
  (1) was restored.
- `barStatusOrder`, `uiScale` and `lastSurface` were restored after the run.
- Back routing was validated through the new `qs -c pill ipc call pill back`
  control: from Shell it returned `settings`, and the `surface` query reported
  the transition. The physical header chip uses the same parent routing.
- The physical header click itself was not delivered to the layer by `dotool`,
  but its parent-routing logic was validated through the IPC back control.
- `lastSurface` was validated: after opening Settings and closing, the real
  `Super+Shift+Space` binding reopened Settings.
