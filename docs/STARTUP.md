# Startup hub

**Settings → Maintenance → Startup** lists the `hl.exec_cmd(...)` calls
inside `hl.on("hyprland.start", ...)` in `~/.config/hypr/modules/autostart.lua`.

- Core services are read-only: clipboard watcher, wallpaper init, cursor,
  session target, polkit agent, both watchdogs, the idle daemon and the
  `reddot-migrate` legacy step when present.
- KDE Connect, KDE Connect indicator, Fastfetch warm-up and commands added from
  the GUI are editable.
- Disabling an entry comments its line (`-- hl.exec_cmd(...)`), preserving order
  and the rest of the block.
- Use the ↑/↓ buttons on a user entry to reorder it. Core services keep their
  positions, so a user command cannot jump across a watchdog, the session target,
  the polkit agent or the idle daemon.
- Adding or editing writes one quoted `hl.exec_cmd("…")` line inside the
  autostart block. Editing an existing Lua expression with `$HOME` writes a
  shell-expanded string; Hyprland runs it through the shell.
- Changes take effect on the next Hyprland start. The hub does not run commands
  immediately, because replaying watchdogs and session services live would
  duplicate processes.

The parser lives in `configs/quickshell/pill/lib/autostart.js`. It is deliberately
limited to one `hl.exec_cmd(...)` per line; arbitrary Lua around the call is left
alone and is not listed.
