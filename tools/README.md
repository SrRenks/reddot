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
| `reddot-wallcolors.rs` | Rust palette engine: wallpaper analysis, fastfetch, Hyprland, Ghostty and GTK app theme |
| `reddot-distro.rs` | Rust installer distro/package planner, parity-tested against installer/distro.py |
| `reddot-pkg.rs` | Rust package argv builder, parity-tested against installer/pkg.py |
| `reddot-fallbacks.rs` | Rust source-build/download/Flatpak fallback steps |
| `reddot-grub.rs` | Rust dry-plan for the torii GRUB theme |
| `reddot-deploy.rs` | Rust deploy ownership, backup, preserve and uninstall core |
| `reddot-neutralize.rs` | Rust monitors/env/hypridle/fish/fastfetch neutralization |
| `reddot-tui.rs` | Rust TUI renderer, raw terminal input and prompt state machines |
| `reddot-detect.rs` | Rust installer detection record |
| `reddot-plan.rs` | Rust installer plan: native, AUR, fallback and skip batches |
| `reddot-post.rs` | Rust wallpapers, app-theme, bridge, CLI link, Brave and baseline |
| `reddot-run.rs` | Rust fail-soft package runner, fallbacks and systemd/OpenRC services |
| `reddot-report.rs` | Rust pre-deploy summary lines |
| `build-rust.sh` | build all crate-free Rust helpers into one binary directory |
| `reddot-install.rs` | quickstart dry-run entry point chaining the cores |
| `test-reddot-install-rust.sh` | bundle + quickstart dry-run integration |
| `test-reddot-report-rust.sh` | summary parity
| `test-reddot-run-rust.sh` | dry-run package ordering
| `test-reddot-post-rust.sh` | post-install effects parity
| `test-reddot-plan-rust.sh` | profile, AUR and overlay plan parity
| `test-reddot-detect-rust.sh` | detection parity
| `test-reddot-tui-rust.sh` | fixed-width TUI render parity |
| `test-reddot-neutralize-rust.sh` | neutralize plan and applied-tree parity |
| `test-reddot-deploy-rust.sh` | deploy tree and uninstall parity |
| `test-reddot-grub-rust.sh` | GRUB dry-plan parity |
| `test-reddot-fallbacks-rust.sh` | all-family fallback parity
| `test-reddot-pkg-rust.sh` | native, repo, Portage and AUR argv parity |
| `test-reddot-distro-rust.sh` | family, AUR and plan parity for the Rust distro core |
| `test-reddot-wallcolors-rust.sh` | integration parity for the Rust palette engine |
| `test-reddot-update-rust.sh` | integration parity for the Rust update engine |
