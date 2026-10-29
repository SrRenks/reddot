# Game mode study

## Current state

`Singletons/GameMode.qml` owns a single persisted flag, `Flags.gameMode`. Entering
the mode snapshots DND, music visualizer and keep-awake, forces DND and keep-awake,
pauses the visualizer, and calls `configs/hypr/scripts/gamemode.sh`. That script
strips gaps, borders, rounding, blur, shadows and animations through
`hyprctl eval`, and keeps a restore snapshot.

What it does not do:

- identify a game window or process;
- prefer a target process;
- change CPU/GPU performance policy;
- list or terminate other applications;
- exit automatically when the game closes.

`gamemoded` and `gamemoderun` are installed. `powerprofilesctl` is not, while
`/sys/firmware/acpi/platform_profile` currently reads `performance`. Any power
policy integration must detect what the host provides instead of assuming PPD.

## Goal

Add a target-aware game mode:

1. pick a running window as the game;
2. show its process identity and resource use;
3. let the user keep a small allowlist, commonly Discord and a browser;
4. optionally stop other user applications after an explicit confirmation;
5. apply compositor and performance changes;
6. restore the desktop when the game exits or the mode is disabled.

The mode should reduce contention and memory pressure, not promise that free RAM
alone raises a frame rate. On Linux, unused RAM is not a performance reserve. The
useful gains come from fewer CPU/GPU/IO contenders, lower compositor work, less
memory pressure and a suitable power profile.

## Proposed UX

Entry points:

- the existing gamepad chip in the Mixer opens a Game mode surface instead of
  toggling immediately;
- an existing target can still be toggled directly;
- the keyboard/IPC path remains available for quick use.

Game mode surface:

```text
GAME MODE

Target window
  [ icon ] Game title                    fullscreen / PID
  [ icon ] Other window                  windowed / PID

Keep running
  [x] Discord              class
  [x] Zen Browser          class
  [ ] Other application    class

[ Preview cleanup ]   [ Start game mode ]

After preview:
  Close 7 applications, about 1.4 GB?
  [ ] Also close Electron apps
  [ Cancel ] [ Terminate selected ]
```

The cleanup preview is a dry run. No process is terminated until the user
confirms the list. SIGTERM is the default. SIGKILL is a separate destructive
choice, never automatic.

Target identity is class-based, not PID-based. A PID can be reused and a Flatpak
or Steam process often has a tree of children. The window picker resolves a
session/cgroup, but class and window title are the persistent identity.

## What can be killed

Candidates come only from visible Hyprland toplevels, not from the whole process
table. For each candidate:

- resolve `pid`, `class`, `title`, `workspace`, `fullscreen`;
- group descendants and sibling processes that belong to the same app;
- show memory as PSS when available, plus CPU and process count;
- keep the target game and its descendants;
- keep allowlisted classes and all their descendants;
- keep ancestors needed to keep the game alive, especially Steam, Proton,
  Gamescope and the launching terminal;
- skip processes without a window when they are not part of a windowed app;
- refuse other users and PID 1;
- re-check PID start time and class immediately before signaling.

Never kill, even if no window protection matched:

- Hyprland, Quickshell, the session bus or systemd;
- PipeWire, WirePlumber, portals, polkit, the notification server;
- input methods, cliphist, hypridle, wallpaper or display services;
- kernel, D-Bus, logind, UPower and other system services;
- another user's process.

The implementation should use a protected-class list in addition to window and
cgroup checks. A class allowlist alone is not sufficient because Electron apps
spawn many child processes and a game can be wrapped by Gamescope.

## Resource measurement

Collect one snapshot when the cleanup preview opens, not on every UI repaint:

- PSS from `/proc/<pid>/smaps_rollup` when readable, otherwise RSS;
- start time from `/proc/<pid>/stat`;
- parent and cgroup from `/proc/<pid>/status` and `/proc/<pid>/cgroup`;
- process tree from `pgrep -P` or the ppid map;
- commit charge and MemAvailable for the system context;
- PSI memory/CPU if available for pressure, not just a free-RAM number.

After the game exits, compare the same counters for a factual report. A useful
baseline is game frametime plus `MemAvailable`, PSI and the target's PSS.

## Performance actions

High value, low risk:

- existing visual strip: gaps, borders, rounding, blur, shadows, animations;
- DND and keep-awake;
- stop the audio visualizer;
- keep the pill hidden and use the game-mode bar strip already present;
- avoid extra overlays and polling while the game is fullscreen.

Optional, host-dependent:

- Feral GameMode through `gamemoderun` or its D-Bus registration. Do not
  reimplement nice, scheduler and GPU policy if the daemon is present;
- A performance power profile only when the host exposes a supported control:
  TLP helper, power-profiles-daemon or `platform_profile`;
- CPU/GPU performance hints only when they are reversible and reported by the
  host. Do not write global sysctl or drop caches.

Not recommended:

- dropping page cache or changing `vm.swappiness` during a game;
- CPU pinning by default;
- killing every process that is not whitelisted;
- treating free RAM as a direct FPS metric.

## Architecture

Add a Game mode surface to the surface catalog and navigation manifest. Keep the
surface UI in QML, and keep process discovery and termination in a small,
testable script/helper, not in QML event handlers.

```text
GameMode.qml
  state, target class, allowlist, snapshots

GameModeSurface.qml
  window picker, allowlist, preview, confirmation

gamemode-cleanup.sh
  read-only cleanup preview OR terminate selected PIDs
  class/cgroup protection, DRY_RUN=1 default

gamemode.sh
  compositor snapshot/restore (already exists)

Feral GameMode (optional)
  gamemoderun / D-Bus registration
```

Extend the existing GameMode singleton to snapshot the selected target class and
allowlist. Do not persist a PID across a restart. The visual snapshot already
survives a pill restart; the target can be re-resolved by class, and if it is gone,
the mode exits.

`GameModeSurface` should own the selected window and the cleanup preview. The
cleanup helper accepts a JSON request containing selected PIDs, expected start
times, classes and allowlist, never an arbitrary `kill` command string.

## Entry and exit

Start:

1. verify the target window still exists and resolve its class;
2. snapshot game mode state, target class, allowlist and current profile;
3. apply the visual strip and optional performance profile;
4. optionally terminate user-selected applications with SIGTERM;
5. watch the target window; if it disappears, exit.

Exit:

1. restore compositor state;
2. restore DND, visualizer, keep-awake and profile;
3. leave the allowlist and target class configured for the next run;
4. never attempt to restart killed applications automatically.

If the game closes while the cleanup confirmation is still open, cancel the
preview and exit instead of terminating processes without a target.

## Phases

1. Surface, window picker, target resolution, allowlist and dry-run preview.
   No process termination yet.
2. Integrate the existing visual strip, GameMode daemon and host profile
   detection; add target-close detection and restore tests.
3. Add SIGTERM cleanup with confirmation, start-time validation, protected
   classes/cgroups, and an opt-in SIGKILL path.
4. Measure the result and decide whether further CPU/GPU tuning is justified.

## Success criteria

- selecting a game and starting the mode changes only the expected settings;
- allowlisted apps and the game tree survive;
- no system or startup service is ever a candidate;
- cancel and dry run never signal a process;
- SIGTERM frees memory for selected apps and games can still exit cleanly;
- leaving the mode restores every visual and profile setting;
- a crashed or restarted pill restores the compositor snapshot and does not
  resurrect a stale target;
- measured FPS/frametime or pressure improvement is reported, not assumed.
