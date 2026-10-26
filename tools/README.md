# tools

| File | Purpose |
|---|---|
| `ricelin-tlp` | root helper: status, set, profile, pause/resume, chargeonce/fullcharge |
| `ricelin-thinkpad` | ThinkPad helper: status, TrackPoint, double-tap, fan curve, LEDs |
| `tlp-acbat.conf` | `/etc/tlp.d` drop-in: AC performance, battery balanced, saver low-power |
| `install-extras.sh` | installs the helper, polkit rule, TLP policy and user tools |
| `49-ricelin-thinkpad.rules` | polkit rule: admin auth kept for the helper only |
| `test-ricelin-tlp.sh` | 25 assertions with fake sysfs and fake tlp/ppd/systemctl |
| `test-ricelin-thinkpad.sh` | fake ThinkPad sysfs: status and allowlisted writes |
| `ricelin-bench.sh` | PSS/CPU + session cgroup anon/file snapshot |
| `ricelin-power-report` | history + power policy + top CPU + recent packages |
| `check.sh` | full read-only gate for a deployed tree |

`install.sh` runs `install-extras.sh` after the Python installer unless
`--skip-extras` is passed.
