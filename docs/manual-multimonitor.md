# Manual multi-monitor test

The development machine has one physical output; a headless output was used for
the supervised surface and lock runs. Physical EDID, cable and hotplug remain
manual.

## Setup

- two outputs with different resolutions or scales;
- `hyprctl monitors -j` shows both names;
- the pill is visible on both;
- the lock service is running.

## Surface test

For each monitor name from `hyprctl monitors -j`:

```sh
qs -c pill ipc call pill open <monitor> settings
qs -c pill ipc call pill open <monitor> shell
qs -c pill ipc call pill open <monitor> packages
qs -c pill ipc call pill open <monitor> bar
```

Check:

- the pill grows from the top of the named monitor;
- the panel is capped at half of that monitor's height;
- back returns to the correct hub;
- closing one panel does not close the other monitor's pill;
- the status list drag stays inside the panel on both scales;
- the scrollbar remains inside the rounded edge.

## Lock test

- trigger the lock with both outputs connected;
- confirm a lock surface covers each output;
- confirm the auth panel appears on the primary output only;
- confirm no output shows the live desktop before unlock.

## Virtual output run, 2026-10-28

The machine has one physical output. A headless output was created with
`hyprctl output create headless`, configured as `HEADLESS-1` at
`1280x720@60`, position `10880x0`, scale `1.25`.

- all 40 surfaces opened on `HEADLESS-1`;
- all 40 surfaces opened on `eDP-1`;
- the pill layer on the virtual output used a 1024 px logical width;
- the panel cap and scrollbar stayed inside the virtual output;
- `HEADLESS-1` was removed afterwards and `eDP-1` remained active.

The lock-over-two-outputs check was not run. Physical EDID, cable, DPI and
hotplug remain manual.

## Lock over two outputs, 2026-10-28

A second headless output (`HEADLESS-3`) was configured at `1280x720@60`,
position `10880x0`, scale `1.25`; the real lock was triggered with both outputs
active.

- `qs -c lock ipc call lock secure` returned `false` before the lock;
- the same call returned `true` after the lock, meaning the compositor confirmed
  every screen covered;
- the auth panel stayed on `eDP-1`;
- the secondary output showed the lock background and no interactive panel;
- the headless output was removed after unlock and `eDP-1` remained active.

`tools/test-lock-multimonitor.sh` reproduces the setup, trigger and `secure`
check. It deliberately leaves cleanup to the operator because removing an output
while locked is not safe.

## Failure record

Record monitor names, scale, resolution, the surface that failed and whether the
issue reproduces after `qs -c pill ipc call pill page settings`.
