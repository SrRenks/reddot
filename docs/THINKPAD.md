# ThinkPad surface: E14 Gen 7 data and layout

Research, layout and implementation notes for the optional ThinkPad section in
the pill. The first part is what this exact machine exposes; the second is the
shipped layout, the safety rules and the remaining fan work.

Measured 2026-10-26 on a ThinkPad E14 Gen 7, model `21T1S25T00`, BIOS
`R2ZET38W (1.27)`, kernel `7.2.11`, TLP 1.10.2, thinkfan 2.0.0.

## What the E14 Gen 7 exposes

| Area | Confirmed | Value / path |
|---|---|---|
| Fan hardware | yes | `/proc/acpi/ibm/fan`: enabled, level 2, 2200 rpm; commands `level 0-7`, `auto`, `full-speed`, `watchdog 0-120` |
| Fan hwmon | yes | `hwmon5` (`thinkpad`): `fan1_input`, `fan2_input` (shares control), `pwm1` 72, `pwm1_enable` 1 |
| Fan control gate | yes | `thinkpad_acpi fan_control=1` set in `/etc/modprobe.d/thinkpad_acpi.conf` |
| Fan owner | thinkfan | service active, YAML levels 0-7 from `/etc/thinkfan.yaml`, `-b0` |
| Temperatures | yes | `k10temp` CPU 49 C, `amdgpu` 47 C, `nvme` 42 C, `spd5118` 47 C |
| Keyboard backlight | yes | `tpacpi::kbd_backlight`, brightness 0, max 2 |
| LEDs | yes | `platform::micmute`, `platform::mute`, `tpacpi::lid_logo_dot`, `tpacpi::power`, `tpacpi::standby`, `tpacpi::thinkvantage`, all 0644 root |
| TrackPoint | partial | `/sys/devices/platform/i8042/serio1/`: `sensitivity` 128, `press_to_select` 0. No `speed`, `dragging`, `drift_time` or `inertia` here |
| Double-tap | yes | `/sys/devices/platform/thinkpad_acpi/doubletap_enable` |
| Platform profile | inconsistent | `/sys/firmware/acpi/platform_profile` = `custom`; choices `low-power balanced performance`; TLP status says `performance/AC` |
| Firmware | yes | `fwupd` sees the Lenovo platform, BIOS and camera |
| Sensors | yes | `lm_sensors`: k10temp, amdgpu, nvme, acpitz, spd5118, BAT0 |

Two consequences:

- The fan is already owned by thinkfan. Writing levels from the pill would be
  overwritten on the next thinkfan cycle, and stopping thinkfan to take over is
  a safety risk, not a feature.
- `platform_profile` reads `custom` while thinkfan controls the fan. TLP's
  selected profile and the ACPI profile can disagree. A second profile selector
  in the ThinkPad surface would be misleading.

## What is confirmed for other ThinkPads

| Capability | Confirmed general rule | Condition |
|---|---|---|
| Fan monitoring | `fan1_input`, `fan2_input` in the `thinkpad` hwmon | driver exposes hwmon |
| Fan control | `/proc/acpi/ibm/fan` levels 0-7, `auto`, `full-speed`, watchdog | `fan_control=1` module parameter; some models need `experimental=1` |
| Second fan | not separately controllable, shares the main control | documented in thinkpad-acpi |
| thinkfan | supports `/proc/acpi/ibm/fan` and hwmon PWM | fan control enabled by the module |
| Keyboard backlight | `tpacpi::kbd_backlight` with model-specific `max_brightness` | LED present |
| Other LEDs | mic mute, mute, lid logo, power, standby, ThinkVantage | model and generation dependent |
| TrackPoint | `sensitivity`, `press_to_select`; some models add `speed`, `dragging`, `drift_time`, `inertia` | detect files, never assume |
| Double-tap | `thinkpad_acpi/doubletap_enable` | newer models |
| Fn lock | `thinkpad_acpi/fn_lock` | not present on this E14 |
| Platform profile | low-power, balanced, performance; `custom` possible | ACPI platform profile driver |
| Battery thresholds | TLP / `charge_control_*` | ThinkPad EC support |
| Firmware | `fwupd` Lenovo plugin | BIOS/firmware present |

Do not offer a control unless the file or tool is present. Do not assume every
ThinkPad can control its fan; the module gate and the EC decide that.

## Safety and ownership

Fan control is the delicate part.

- thinkfan is the fan owner on this machine. The UI must not write
  `/proc/acpi/ibm/fan` or `pwm1` while thinkfan runs.
- A fan preset should replace a **validated thinkfan curve**, not a raw level.
  The helper writes the chosen YAML, runs `systemctl reload thinkfan` (SIGHUP),
  and keeps the previous file as a backup. thinkfan keeps the old config if the
  new one fails to parse.
- Only two presets are proposed for the first version: `Balanced` (the current
  E14 Gen 7 config) and `Cool` (thresholds lowered by 4 C, louder but safer).
  A `Quiet` curve needs thermal testing before it ships; lowering the maximum
  level near 85 C is not something to guess.
- Raw levels, `full-speed`, and `disengaged` are not exposed. They are useful
  for benchmarks, not for a pill button.
- The module parameter, watchdog and EC limits stay documented in the helper
  help text.

TrackPoint and LED writes are low risk. Keep the helper allowlist narrow:
`sensitivity` 0-255, `press_to_select` 0/1, `kbd_backlight` 0-2, `doubletap` 0/1.
Do not write `tpacpi::power`, `tpacpi::standby`, or the mic-mute LED; those
reflect firmware state.

## Layout proposal

One surface, not tabs. The pill already morphs vertically, and Look uses
collapsible groups. Groups keep status and controls in one field of view; tabs
would hide the fan temperature while changing a TrackPoint value.

Entry points:

- A row at the foot of the Power surface: `ThinkPad · fans, LEDs, TrackPoint`.
- `Super+Shift+T`.
- IPC `qs -c pill ipc call pill thinkpad ""`.
- Optional later: a small `TP` chip in the expanded pill's right cluster.

Surface width 396. Header glyph `思`, title `THINKPAD`, model on the right.

```
+--------------------------------------------------+
| 思  THINKPAD                    E14 G7 · BIOS 1.27|
|                                                  |
|   2200 rpm             49 CPU · 47 GPU · 42 NVMe |
|   thinkfan · level 2                             |
|                                                  |
|  THERMAL                                         |
|  Fan            thinkfan · level 2               |
|  Sensors        49 / 47 / 42 C                   |
|  Platform       custom · read-only           >   |
|  ----------------------------------------------  |
|  INPUT                                           |
|  TrackPoint sensitivity            [ 128 ]       |
|  Press to select                   [toggle]      |
|  Double-tap                        [toggle]      |
|  Keyboard backlight        [ Off ][ Dim ][ Full ]|
|  ----------------------------------------------  |
|  INDICATORS                                      |
|  mic mute  o     speaker mute  o                 |
|  lid logo  o     power         o                 |
|  standby   o     ThinkVantage  o                 |
|  ----------------------------------------------  |
|  Battery and power >             helper: ready   |
+--------------------------------------------------+
```

Why this order:

1. Thermal first: the reason to open the surface is usually fan or temperature.
2. Input second: TrackPoint and keyboard backlight are the personal settings
   that survive reboots.
3. Indicators last and read-only: they explain hardware state, they are not
   controls.
4. Battery and power is a link to the Power surface, not a duplicate.

Rows that do not apply are hidden, not disabled: no `speed` row on the E14, no
fan row when the EC telemetry is absent, no platform row when the ACPI file is
missing. Fan profile switching is not in this build; see phase 3.

## Controls and data flow

| Row | Read | Write | Fallback |
|---|---|---|---|
| Fan RPM / level | `/proc/acpi/ibm/fan`, `hwmon5/fan1_input` | none | hide if absent |
| Temperatures | hwmon `k10temp`, `amdgpu`, `nvme`, `acpitz` | none | hide missing sensors |
| Platform profile | `/sys/firmware/acpi/platform_profile` | none in this surface; link to Power | read-only text |
| TrackPoint | `serio*/sensitivity`, `press_to_select` | `ricelin-thinkpad trackpoint ...` | detect attrs, hide missing |
| Double-tap | `thinkpad_acpi/doubletap_enable` | `ricelin-thinkpad doubletap 0|1` | hide if absent |
| Keyboard backlight | `tpacpi::kbd_backlight/brightness` | `ricelin-thinkpad led kbd 0-2` | hide if absent |
| Indicators | LED `brightness` values | none | hide missing LEDs |

Refresh: one timer every 2 s, `running: surface.open`, one `Process` calling the
helper's `status` verb. Nothing polls while the surface is closed. This is the
same model as the Power surface.

Privilege: a new root-owned helper `ricelin-thinkpad`, one sudoers rule, the
same pattern as `ricelin-tlp`. Reads work unprivileged; writes use
`sudo -n`. No shell interpolation, allowlisted attributes, ranges validated in
the helper.

## What ships now

The surface is implemented as a read-only thermal view plus the input knobs that
are safe to write.

- `configs/quickshell/pill/Singletons/ThinkPad.qml` detects
  `/sys/devices/platform/thinkpad_acpi` with one `test -d` and calls the helper
  only when it exists.
- `configs/quickshell/pill/ThinkPadSurface.qml` renders the hero, Thermal,
  Input and Indicators groups, with the battery link back to Power.
- `configs/quickshell/pill/Pill.qml`, `shell.qml`, `TlpSurface.qml` and
  `binds.lua` wire the surface, the IPC verb and `Super+Shift+T`.
- `tools/ricelin-thinkpad` implements `status`, `trackpoint`, `doubletap` and
  `led kbd`; `tools/test-ricelin-thinkpad.sh` covers both success and refusal.
- `tools/install-extras.sh` installs the helper and its sudoers rule only when
  a ThinkPad is detected.

Fan presets are phase 3. The surface never writes fan levels, `pwm1_enable` or
`/proc/acpi/ibm/fan`; it reports what thinkfan and the EC are doing.

## Base compatibility

- On a non-ThinkPad the probe exits non-zero, `present` stays false, the Power
  row is hidden and no helper or sudoers file is installed.
- The singleton is constructed only when Power or the ThinkPad surface opens,
  so a normal session does not pay for the probe.
- The keybind opens the surface on any machine and shows a one-line "No ThinkPad
  hardware detected" state; nothing else changes.
- No package is added to the base installer. thinkfan remains the fan owner and
  is not required by the QML.

## Implementation phases

Phase 1, read-only surface: shipped.

Phase 2, writes: shipped, guarded by the helper allowlist and the sudoers rule.

Phase 3, fan profiles:

- `configs/thinkfan/e14g7-balanced.yaml` and `e14g7-cool.yaml`.
- helper `fan preset` with backup, reload, model guard.
- only after a thermal test on this machine; no Quiet preset before that.

Phase 4, other ThinkPads: capability detection already hides rows; add per-model
fan presets only with a confirmed thinkfan config, never a generic curve.

Phase 4, other ThinkPads:

- capability detection already hides rows; add per-model fan presets only with
  a confirmed thinkfan config, never a generic curve.

## Open decisions

- Ship `Cool` as the only fan preset, or keep fan read-only until a full thermal
  test? Current build is read-only.
- Show the `custom` platform profile at all, or replace the row with a link to
  the TLP section?
- Allow a lid-logo LED toggle, or keep every indicator read-only?
- Put the entry in the Power surface, or also add a chip to the expanded pill?

## Sources

- Linux kernel, thinkpad-acpi: <https://www.kernel.org/doc/html/latest/admin-guide/laptops/thinkpad-acpi.html>
- thinkfan manual: `man thinkfan`; thinkfan.conf: <https://manpages.debian.org/testing/thinkfan/thinkfan.conf.5.en.html>
- Arch Wiki, Laptop/Lenovo (battery and firmware): <https://wiki.archlinux.org/title/Laptop/Lenovo>
- TLP platform profile: <https://linrunner.de/tlp/settings/platform.html>
- fwupd: <https://fwupd.org/>
