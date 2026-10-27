# Battery and energy data — the 2026 landscape

What to use to understand where the energy goes, what is trustworthy, and what
this setup now shows in the battery surface.

## The data source: UPower history

UPower keeps per-device history in `/var/lib/upower/history-*.dat` and serves it
over D-Bus:

```
org.freedesktop.UPower.Device.GetHistory(type, timespan, resolution)
    type       "charge" | "rate" | "time-empty" | "time-full" | "voltage"
    timespan   seconds (86400 here)
    resolution seconds (300 = 5 min)
    returns    a(udu): (timestamp, value, state)
```

That is the same data GNOME Power Statistics was built on. The files themselves
are root-only (`0640`), but the D-Bus call works from the session user, which is
why the shell reads it directly instead of running a sampler or a daemon.

What it gives: charge % and watts over time, at UPower's native 5-minute
resolution, for the days the daemon kept. What it does not give: per-application
energy, or anything while the machine sat on AC.

## The tools, and what each one answers

| Tool | 2026 status | Answers | Needs root |
|---|---|---|---|
| **UPower** 1.91.5 | in every desktop stack | charge/rate history, health, cycles, thresholds | no (D-Bus) |
| **powertop** 2.16.1 | Intel, still the reference | wakeups, device/USB/PCIe state, C/P-states, component estimates, CSV/HTML/markdown, `--auto-tune` | yes |
| **powerstat** | Colin Ian King, packaged widely (AUR on Arch) | controlled average watts over a fixed window; battery or RAPL mode; A/B comparisons | usually |
| **turbostat** 2026.04.21 | in the kernel tree | `PkgWatt`/`CorWatt`/`GFXWatt`, per-core C/P-state residency | yes |
| **btop** | live monitor | instantaneous battery %, not history | no |
| **scaphandre** | RAPL-based, ops-oriented | estimated per-process/container power on servers; not a desktop UI | yes |
| **GNOME Power Statistics** | legacy, unmaintained | the UPower history UI that this surface replaces | no |

The consensus workflow is layered: **UPower for history**, **powertop for the
audit**, **powerstat for A/B numbers**, **turbostat when the CPU is the suspect**.

Per-application wattage is the weak spot. PowerTOP attributes *wakeups* to
processes, not watts; scaphandre estimates process power from RAPL plus cgroup
accounting and is aimed at servers. On a laptop the honest method is
correlation: a discharge-rate jump that lines up with an app, an update or a
kernel change.

## What this setup now does

- `Singletons/PowerHistory.qml` calls `GetHistory` for `rate` on the physical
  battery when the battery surface opens (cached for 60 s, discharging samples
  only). No polling daemon, no extra packages: `busctl` + `python`-free parsing
  in QML.
- The battery card renders **24 hourly bars** of average discharge watts, the
  **24 h average**, the **peak**, and a **1 h average** row.
- `reddot-power-report` prints the same numbers plus current state, top CPU,
  recent package activity and failed units. It is the thing to run after an
  update when the fan or the battery feels wrong.

## How to use it when something drains

1. On battery, idle for 5 minutes, then note the 1 h average in the battery
   surface (or `reddot-power-report`).
2. Compare with the number you remember, or with the 24 h average from before
   the update. A sustained idle jump above ~2 W is worth investigating; a single
   peak is usually a compile, a video call or a game.
3. If it is high:

   ```sh
   sudo powertop --csv=/tmp/powertop.csv --time=60   # wakeups, devices, tunables
   sudo turbostat --quiet --show PkgWatt,CorWatt --interval 5 --num_iterations 2
   sudo powerstat 300 5                              # controlled average
   ```

4. If it started after a package change, `reddot-power-report` already lists
   the last 12 ALPM actions; check kernel, firmware, GPU driver, PipeWire and
   the desktop shell first.
5. Battery wear is separate: `upower -i <path>` and `tlp-stat -b` show cycles,
   full capacity and design capacity. This battery: 44 cycles, 100 % capacity,
   48.48 Wh full vs 48 Wh design.

## Interpretation notes

- Idle draw on a recent ThinkPad/Ryzen laptop is usually **4–8 W** with the
  panel on and Wi-Fi idle; 8–12 W is a browser plus a few apps; 15 W+ is real
  work or something stuck.
- UPower's rate is a smoothed estimate from the battery, not a lab meter; treat
  ±5 % as noise and look at averages, not single points.
- History is **discharge-only** here. While on AC the surface keeps the last
  discharge curve, so the numbers are "what it costs when unplugged", not "what
  it is doing now". Current draw is the `Rate` row.
- The 5-minute resolution is UPower's, not the surface's; polling faster would
  only interpolate.

## Is this the community-standard way?

Split it in two:

- **The data source: yes.** `GetHistory` is UPower's public D-Bus API; it is the
  same history GNOME Power Statistics consumed, and UPower is in every desktop
  stack. The surface is a thin read-only binding to it, not a fork of another
  project.
- **The UI: no established Quickshell package does this.** The shell ecosystems
  (DMS, Noctalia, Caelestia, reddot itself) show live battery state; none ships
  a history widget. The implementation here is custom but small and isolated to
  one singleton and one card block, so there is little to inherit.
- **The audit tooling: yes.** PowerTOP, powerstat and turbostat are what distro
  docs and 2026 guides point at; they stay root-only and on demand.

What is *not* standard anywhere: per-application wattage. Treat any tool that
claims it on a laptop as an estimate, and use the discharge curve plus event
correlation instead.

## Sources

- UPower D-Bus API and history files: <https://upower.freedesktop.org/docs/Device.html#Device:GetHistory>
- Arch Wiki, power management tool list: <https://wiki.archlinux.org/title/Power_management>
- powertop manual (`--csv`, `--html`, `--markdown`, `--time`, `--auto-tune`): `man powertop`
- powertop vs powerstat vs turbostat, June 2026: <https://www.pistack.xyz/posts/2026-06-02-linux-power-analysis-powertop-powerstat-turbostat-guide/>
- scaphandre, per-process power estimation: <https://github.com/hubblo-org/scaphandre>
- powerstat: <https://github.com/ColinIanKing/powerstat>
