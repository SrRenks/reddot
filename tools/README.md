# tools

| File | Purpose |
|---|---|
| `ricelin-tlp` | root helper: status, set, profile, pause/resume, chargeonce/fullcharge |
| `tlp-acbat.conf` | `/etc/tlp.d` drop-in: AC performance, battery balanced, saver low-power |
| `install-extras.sh` | installs the helper, sudoers rule, TLP policy and user tools |
| `test-ricelin-tlp.sh` | 25 assertions with fake sysfs and fake tlp/ppd/systemctl |
| `ricelin-bench.sh` | PSS/CPU + session cgroup anon/file snapshot |
| `ricelin-power-report` | history + power policy + top CPU + recent packages |
| `check.sh` | full read-only gate for a deployed tree |

`install.sh` runs `install-extras.sh` after the Python installer unless
`--skip-extras` is passed.
