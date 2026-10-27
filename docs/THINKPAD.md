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
| Keyboard language | yes | `keyboard_lang` lists `be cz da de en es et fr fr-ch hu it jp nl nn pl pt sl sv tr` |
| Lap mode | yes | `dytc_lapmode` = 0 (desk) |
| USB-C Security | no | attribute absent on this model |
| Fn lock | no | attribute absent on this model |
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
| Keyboard language | `thinkpad_acpi/keyboard_lang` | write-only language code; reading returns the list |
| Lap mode | `thinkpad_acpi/dytc_lapmode` | read-only, model dependent |
| USB-C Security | `thinkpad_acpi/usb_c_security` | read-only, toggled by Fn+U then Fn+S |
| Fn lock | `thinkpad_acpi/fn_lock` | model dependent; absent here |
| Platform profile | low-power, balanced, performance; `custom` possible | ACPI platform profile driver |
| Battery thresholds | TLP / `charge_control_*` | ThinkPad EC support |
| Firmware | `fwupd` Lenovo plugin | BIOS/firmware present |

Do not offer a control unless the file or tool is present. Do not assume every
ThinkPad can control its fan; the module gate and the EC decide that.

Researched but not exposed in this build:

- `keyboard_lang` is write-only. Reading it returns the list of accepted codes,
  not the active code, so a picker cannot show the current value. A future
  control needs a separate state file.
- `dytc_lapmode` is read-only.
- `usb_c_security` is read-only and absent on the E14; the firmware toggles it
  with Fn+U then Fn+S.
- `fn_lock` is absent on the E14. It could become a generic row on models that
  expose it.

## Why there is no Fn lock LED

The E14 Gen 7 exposes neither `/sys/devices/platform/thinkpad_acpi/fn_lock` nor
a `fnlock` entry under `/sys/class/leds`. A filesystem search for `fnlock` is
empty. The Fn lock is handled inside the EC/keyboard firmware; the OS has no
attribute to read, so the helper cannot infer a state or drive a LED.

The helper and surface do implement `fn_lock` and `tpacpi::fnlock` when a model
exposes them. On this machine the row stays hidden instead of showing a guessed
"off" state.
- `lcdshadow` (PrivacyGuard) exists on older T-series, not here.

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
`tpacpi::power` and `tpacpi::standby` reflect firmware state. The mute LEDs are
writable; writing one clears its kernel trigger, which is the manual override.

## Layout proposal

One surface, not tabs. The pill already morphs vertically, and Look uses
collapsible groups. Groups keep status and controls in one field of view; tabs
would hide the fan temperature while changing a TrackPoint value.

Entry points:

- A laptop icon in the expanded pill, next to Mixer and Sound. It is visible only
  when ThinkPad hardware is detected, and carries a small vermilion status dot.
- `Super+Shift+T`.
- IPC `qs -c pill ipc call pill thinkpad ""`.

Surface width 396. Header glyph `思`, title `THINKPAD`, model on the right.

```
+--------------------------------------------------+
| 思  THINKPAD                    E14 G7 · BIOS 1.27|
|                                                  |
|  LIGHTING                                        |
|  Keyboard light        [ Off ][ Dim ][ Full ]    |
|  Mic mute                          [toggle]      |
|  Speaker mute                      [toggle]      |
|  Mic mute LED                      [toggle]      |
|  Speaker mute LED                  [toggle]      |
|  Lid logo                          [toggle]      |
|  Vantage                           [toggle]      |
|  Power LED / Standby / Caps / ...  [toggles]     |
|                                                  |
|  POINTING                                        |
|  Sensitivity                       [ 128 ]       |
|  Press to select                   [toggle]      |
|  Double-tap                        [toggle]      |
|  ----------------------------------------------  |
|  Battery and power >                             |
+--------------------------------------------------+
```

Fan RPM, temperatures, Glances sensor gauges and the fan curve live in
**System**, not here. Keeping them next to CPU/IGPU/memory avoids a second
telemetry stack and removes the duplicate temperature readout.

Why this order:

1. Lighting first: the reason to open this surface is usually a LED or the
   keyboard light.
2. Pointing second and collapsed: it is the least frequent edit.
3. Battery and power is a link to the Power surface, not a duplicate.

Rows that do not apply are hidden, not disabled: no `speed` row on the E14, no
Fn lock row without `fn_lock`. Every LED in `/sys/class/leds` is read from the
same `LEDS` status block and exposed as a row; mute LEDs are editable like the
rest.

## Controls and data flow

| Row | Read | Write | Fallback |
|---|---|---|---|
| Keyboard backlight | `tpacpi::kbd_backlight/brightness` | `ricelin-thinkpad led kbd 0-2` | hide if absent |
| Mute LEDs | `platform::micmute`, `platform::mute` | `ricelin-thinkpad led platform::micmute|mute 0|1` | trigger is cleared by the manual write |
| Lid logo / Vantage | `tpacpi::lid_logo_dot`, `tpacpi::thinkvantage` | `ricelin-thinkpad led lid|vantage 0|1` | hide if absent |
| Every LED | every LED in `/sys/class/leds` | `ricelin-thinkpad led <name> 0..max` | firmware or NIC may take it back |
| TrackPoint | `serio*/sensitivity`, `press_to_select` | `ricelin-thinkpad trackpoint ...` | detect attrs, hide missing |
| Double-tap | `thinkpad_acpi/doubletap_enable` | `ricelin-thinkpad doubletap 0|1` | hide if absent |

Refresh: one `status` read when the surface opens, and one after a write. There
is no timer, watcher or background poll. The hardware state wins when the
surface opens; manual LED writes are the override.

The fan curve editor moved to **System**. It still writes only the eight
thinkfan level bands, backs up `/etc/thinkfan.yaml` and sends SIGHUP.

## Privileges and polkit

The current desktop has `polkit 128`, `pkexec` and `hyprpolkitagent` active. The
agent opens a normal "Authentication Required" window; a test launch reached
that window. The helper is root-owned and allowlisted, so pkexec runs only that
binary, not a shell.

The alternative would be udev rules that chgrp the sysfs attributes. That works
for LEDs and TrackPoint on some machines, but it cannot write
`/etc/thinkfan.yaml` or reload thinkfan, and device permissions vary by kernel
and distribution. Polkit covers both cases with one policy and no permanent
passwordless rule.

The helper is a root-owned helper `ricelin-thinkpad`, invoked with
`pkexec /usr/local/bin/ricelin-thinkpad ...`. Reads work unprivileged; writes ask
the session polkit agent, `hyprpolkitagent`, for authentication. There is no
passwordless sudoers rule for either helper.

`tools/install-extras.sh` installs
`/etc/polkit-1/rules.d/49-ricelin.rules`. The rule returns
`AUTH_ADMIN_KEEP` only when the pkexec program is
`/usr/local/bin/ricelin-thinkpad` or `/usr/local/bin/ricelin-tlp`, so the first
write asks for the admin password and later writes inside five minutes reuse it.
Every other pkexec call keeps the default policy. No shell interpolation, allowlisted attributes, ranges
validated in the helper.

This is the same polkit flow desktop apps and Flatpak use. It requires a running
agent; without one pkexec fails visibly and the footer reports it. There is no
silent fallback to sudo.

## What ships now

The surface has two collapsible sections, Lighting and Pointing, plus the
Battery and power link. Fan telemetry and the curve are in System.

- `configs/quickshell/pill/Singletons/ThinkPad.qml` detects
  `/sys/devices/platform/thinkpad_acpi` with one `test -d` and calls the helper
  only when it exists.
- `ThinkPadSurface.qml` and its `ThinkPadGroup`, `ThinkPadLighting` and
  `ThinkPadState` components render the LEDs and pointing rows, with the battery
  link back to Power. The curve editor lives in System.
- The surface reads one status snapshot when it opens and after a write. There
  is no timer, graph history, watcher or background poll. A keyboard-driven LED
  change is reflected on the next open; the hardware value always wins over the
  panel's last view.
- `configs/quickshell/pill/Pill.qml`, `shell.qml`, `TlpSurface.qml` and
  `binds.lua` wire the surface, the IPC verb and `Super+Shift+T`.
- `FanCurvePanel.qml` lives in System; `Singletons/Sensors.qml` reads the
  Glances Sensors tab while System is open.
- `tools/ricelin-thinkpad` implements `status`, `trackpoint`, `doubletap`,
  `curve set` and `led kbd|lid|vantage`. `curve set` backs up
  `/etc/thinkfan.yaml`, replaces only the levels block and sends SIGHUP to
  thinkfan. `tools/test-ricelin-thinkpad.sh` covers success and refusal.
- `tools/install-extras.sh` installs the shared polkit rule on every machine and
  the ThinkPad helper only when a ThinkPad is detected. The same rule covers the
  TLP helper, so battery writes use the same prompt.

The ThinkPad surface never writes raw fan levels, `pwm1_enable` or
`/proc/acpi/ibm/fan`. The fan curve editor in System edits the thinkfan policy
that owns those levels.

## Base compatibility

- On a non-ThinkPad the probe exits non-zero, `present` stays false, the pill
  icon is hidden and no ThinkPad helper is installed. The shared polkit rule for
  the TLP helper is still installed.
- The singleton runs one `test -d` at startup for that icon; it does not call
  the helper, start a timer or read sysfs until the surface opens.
- The keybind opens the surface on any machine and shows a one-line "No ThinkPad
  hardware detected" state; nothing else changes.
- No package is added to the base installer. thinkfan remains the fan owner and
  is not required by the QML.

## LED write check

Every LED in `/sys/class/leds` was set to `max_brightness`, read back and
restored on 2026-10-27:

| LED | write |
|---|---|
| `enp1s0-0::lan`, `enp1s0-1::lan`, `enp1s0-2::lan` | accepted |
| `input3::capslock`, `input3::numlock`, `input3::scrolllock` | accepted |
| `platform::micmute`, `platform::mute` | accepted |
| `tpacpi::kbd_backlight` | accepted |
| `tpacpi::lid_logo_dot` | accepted; it was already at 255 |
| `tpacpi::power`, `tpacpi::standby`, `tpacpi::thinkvantage` | accepted |

This proves the sysfs path accepts the write. It does not promise that the NIC,
keyboard controller or EC will keep the value; the UI reads the value back after
each write. Lock LEDs do not change the actual lock state.

## Mute LEDs

`platform::mute` and `platform::micmute` default to the `[none]` trigger. The
kernel exposes `audio-mute` and `audio-micmute`, but nothing selects them, so
muting ALSA changed the audio while the LEDs stayed off.

`tools/99-ricelin-leds.rules` selects the triggers at boot:

```udev
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="platform::mute", ATTR{trigger}="audio-mute"
ACTION=="add", SUBSYSTEM=="leds", KERNEL=="platform::micmute", ATTR{trigger}="audio-micmute"
```

Linux does not emit a udev change event for LED brightness changes, so there is
no event file or watcher in the panel.

The first version used `add|change` for the trigger. That caused a feedback
loop and the LEDs blinked, because every trigger write generated another
`change` event. The trigger lines are now `add` only; no udev rule runs on LED
brightness changes.

Verified by toggling `wpctl set-mute` on the default sink and source:

| State | `platform::mute` | `platform::micmute` |
|---|---|---|
| both muted | 1 | 1 |
| both live | 0 | 0 |
| muted again | 1 | 1 |

No daemon, no polling and no polkit prompt runs on mute changes. The trigger
lights the LED on a mute edge. Writing brightness directly clears the trigger,
which is why the panel exposes the mute LEDs as manual toggles: you can mute the
microphone and still turn its LED off. After a manual write the trigger stays
off until the next boot/install re-arms it; the hardware mute function itself is
never blocked.

## Implementation phases

Phase 1, read-only surface: shipped.

Phase 2, input and LED writes: shipped, guarded by the helper allowlist and the
polkit rule.

Phase 3, fan curve editor: shipped in System, next to the fan gauges and
Glances temperatures. It edits the eight level bands in place and leaves raw fan
levels untouched.

Phase 4, other ThinkPads: capability detection hides rows that do not exist.
Per-model presets remain out of scope without a confirmed thinkfan config.

## Open decisions

- Whether to add named curve presets on top of the editor. The editor itself is
  shipped; presets would only prefill it.
- Whether to expose the `custom` platform profile in this surface or keep it in
  Power.
- Whether the pill icon should also show the current fan level when the pill is
  in hover mode.

## Enabling on an existing install

A fresh install from this fork already deploys the files. For a checkout that is
already running on a ThinkPad, back up the live files, then copy only the new
and changed ones:

```sh
cd ~/Projects/reddot
cp ~/.config/quickshell/pill/Pill.qml ~/.config/quickshell/pill/Pill.qml.bak
cp ~/.config/quickshell/pill/shell.qml ~/.config/quickshell/pill/shell.qml.bak
cp ~/.config/quickshell/pill/TlpSurface.qml ~/.config/quickshell/pill/TlpSurface.qml.bak

sudo tools/install-extras.sh
install -Dm644 configs/quickshell/pill/ThinkPadSurface.qml ~/.config/quickshell/pill/ThinkPadSurface.qml
install -Dm644 configs/quickshell/pill/Singletons/ThinkPad.qml ~/.config/quickshell/pill/Singletons/ThinkPad.qml
install -Dm644 configs/quickshell/pill/Singletons/qmldir ~/.config/quickshell/pill/Singletons/qmldir
install -Dm644 configs/quickshell/pill/Pill.qml ~/.config/quickshell/pill/Pill.qml
install -Dm644 configs/quickshell/pill/shell.qml ~/.config/quickshell/pill/shell.qml
install -Dm644 configs/quickshell/pill/TlpSurface.qml ~/.config/quickshell/pill/TlpSurface.qml
install -Dm644 configs/hypr/modules/binds.lua ~/.config/hypr/modules/binds.lua

~/.config/hypr/scripts/watchdog.sh pill
```

On a non-ThinkPad, skip the ThinkPad helper: the QML probe hides the entry. The
shared polkit rule still belongs to the TLP helper, so keep running
`install-extras.sh` for battery control.

## Sources

- Linux kernel, thinkpad-acpi: <https://www.kernel.org/doc/html/latest/admin-guide/laptops/thinkpad-acpi.html>
- thinkfan manual: `man thinkfan`; thinkfan.conf: <https://manpages.debian.org/testing/thinkfan/thinkfan.conf.5.en.html>
- Arch Wiki, Laptop/Lenovo (battery and firmware): <https://wiki.archlinux.org/title/Laptop/Lenovo>
- TLP platform profile: <https://linrunner.de/tlp/settings/platform.html>
- Arch Wiki polkit: <https://wiki.archlinux.org/title/Polkit>
- Hyprland polkit agent: <https://wiki.hypr.land/Hypr-Ecosystem/hyprpolkitagent/>
- fwupd: <https://fwupd.org/>
