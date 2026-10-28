# tools

| File | Purpose |
|---|---|
| `reddot-tlp` | root helper: status, set, profile, pause/resume, chargeonce/fullcharge |
| `reddot-thinkpad` | ThinkPad helper: status, TrackPoint, double-tap, fan curve, LEDs, triggers, timers, keyboard language |
| `tlp-acbat.conf` | `/etc/tlp.d` drop-in: AC performance, battery balanced, saver low-power |
| `install-extras.sh` | installs the helper, polkit rule, TLP policy and user tools |
| `49-reddot.rules` | polkit rule: admin auth kept for the TLP and ThinkPad helpers |
| `99-reddot-leds.rules` | mute triggers at boot, plus the LED event file for the open panel |
| `smoke-surfaces.sh` | optional runtime smoke: opens every pill surface and checks the layer |
| `check-lock-static.sh` | static lock state/flow review, no runtime lock |
| `test-lock-multimonitor.sh` | supervised two-output lock smoke; leaves cleanup to the operator |
| `check-privileged.sh` | polkit allowlist, sudoers absence and helper guards |
| `perf-snapshot.sh` | host-only PSS/RSS and layer geometry snapshot |
| `test-package-updates.sh` | fake pacman/dnf/zypper/apt backends for the package meter |
| `test_deploy_sandbox.py` | isolated deploy, re-deploy and uninstall |
| `check-qml-runtime.sh` | headless Quickshell runtime harness for PillSurface, SettingsSeg and ScrubValue |
| `test-installer-matrix.py` | synthetic five-family installer plan/resolve matrix |
| `check-systemd-contract.sh` | static session target contract |
| `check-static.sh` | headless CI gate: contracts, JS/Python tests, shell and Lua syntax |
| `check-integration.sh` | installer dry-run/selftests plus udev, polkit, systemd and TLP checks |
| `check-qml-warnings.mjs` | QML warning baseline by file and occurrence |
| `check-hypr-api.sh` | rejects legacy Hyprland syntax and validates Lua |
| `check-doc-links.mjs` | validates required docs and relative links |
| `check-ui-contract.mjs` | surface references, debug leftovers, wheel path and status coverage |
| `check-navigation.mjs` | manifest coverage for catalog, status row, Settings index and hubs |
| `test-reddot-tlp.sh` | 25 assertions with fake sysfs and fake tlp/ppd/systemctl |
| `test-reddot-thinkpad.sh` | fake ThinkPad sysfs: status and allowlisted writes |
| `reddot-bench.sh` | PSS/CPU + session cgroup anon/file snapshot |
| `reddot-power-report` | history + power policy + top CPU + recent packages |
| `check.sh` | full read-only gate for a deployed tree |

`install.sh` runs `install-extras.sh` after the Python installer unless
`--skip-extras` is passed.

| `reddot-sensors.rs` | one-shot native hwmon/thermal/power_supply scanner: every readable sensor for the System surface |
| `reddot-update.rs` | Rust update engine: clone, merge, manifest, dependency scan and JSON contract |
| `test-reddot-update-rust.sh` | integration parity for the Rust update engine |
