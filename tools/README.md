# tools

| File | Purpose |
|---|---|
| `reddot-tlp` | root helper: status, set, profile, pause/resume, chargeonce/fullcharge |
| `reddot-thinkpad` | ThinkPad helper: status, TrackPoint, double-tap, fan curve, LEDs, triggers, timers, keyboard language |
| `tlp-acbat.conf` | `/etc/tlp.d` drop-in: AC performance, battery balanced, saver low-power |
| `install-extras.sh` | installs the helper, polkit rule, TLP policy and user tools |
| `49-reddot.rules` | polkit rule: admin auth kept for the TLP and ThinkPad helpers |
| `99-reddot-leds.rules` | mute triggers at boot, plus the LED event file for the open panel |
| `test-reddot-tlp.sh` | 25 assertions with fake sysfs and fake tlp/ppd/systemctl |
| `test-reddot-thinkpad.sh` | fake ThinkPad sysfs: status and allowlisted writes |
| `reddot-bench.sh` | PSS/CPU + session cgroup anon/file snapshot |
| `reddot-power-report` | history + power policy + top CPU + recent packages |
| `check.sh` | full read-only gate for a deployed tree |

`install.sh` runs `install-extras.sh` after the Python installer unless
`--skip-extras` is passed.

| `reddot-sensors.rs` | one-shot native hwmon/thermal/power_supply scanner: every readable sensor for the System surface |
