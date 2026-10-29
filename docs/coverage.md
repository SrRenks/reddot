# Coverage

The repository has no QML coverage instrumentation. This page records what was
actually exercised, not a percentage.

## Supported matrix

| Family | Real VM result |
|---|---|
| Arch | install, AUR bootstrap, services, reboot |
| Debian 13 | install, reboot, update apply, reinstall |
| Fedora 44 | install, reboot |
| openSUSE Tumbleweed | install, services |
| Leap 15.6 | rejected |
| Gentoo | rejected |

## Green gates

```text
tools/check.sh          checkout, QML, scripts, Lua, docs, drift
tools/check-static.sh   CI: contracts, Node tests, Rust units, runtime audit
```

The installer matrix and dry-run integration are in `tools/`. Real VM logs are
summarized here; the old Python parity harness is archived outside Git.

## Known gaps

- Updater with conflict/rollback (clean apply passed on Debian).
- Physical cable hotplug and mixed DPI.
- Two-output PAM unlock (the lock visual and `secure=true` passed on eDP-1 +
  HDMI-A-1; the test unlocked by ending the lock process).
- Reinstall idempotence on Arch/Fedora/Tumbleweed.
- Individual controls of all 41 surfaces and Search row focus.
- SDDM, GRUB, Brave and fish paths in a real installer run.
- RAM and visual checks on hardware other than this ThinkPad.
- Tumbleweed reboot (install and services passed without reboot).

## Archived harness

The Python reference modules and parity tests are outside the checkout at
`/home/renks/Projects/reddot-python-parity-archive-2026-10-29/` (tar and
`SHA256SUMS` included). They are not a CI dependency; no `.py` files are tracked.
