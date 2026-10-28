# Validation checklist

Run these checks before declaring a change complete. The full gate is
`tools/check.sh`; the commands below explain what each part covers.

## Default gate

- [ ] `sh tools/check.sh`
- [ ] `sh tools/check-static.sh`
- [ ] `qml-warning-baseline` has no new warnings.
- [ ] `Hyprland --verify-config` reports `config ok`.
- [ ] `hyprctl configerrors` is empty.
- [ ] `git diff --check` is clean.

## QML and surfaces

- [ ] `node tools/check-ui-contract.mjs`
- [ ] `sh tools/check-qml-runtime.sh` carrega PillSurface, SettingsSeg e ScrubValue.
- [ ] all 40 surfaces are present in the catalog and every request resolves;
- [ ] the single wheel path is intact (`shell.qml` backdrop only);
- [ ] scrollbar and keyboard navigation still work in a live session;
- [ ] `tools/smoke-surfaces.sh` opens all 40 surfaces.

## Hyprland

- [ ] `sh tools/check-hypr-api.sh`
- [ ] no `windowrulev2`, textual `bind =` or textual `layerrule =` in Lua;
- [ ] the pill layer rule still names `namespace = "pill"`;
- [ ] `luac -p configs/hypr/modules/*.lua`.

## Installer and system

- [ ] `sh tools/check-integration.sh`
- [ ] installer dry-run completes;
- [ ] deploy/distro/pkg/fallbacks/tui selftests pass;
- [ ] udev, polkit, session target and TLP checks pass.
- [ ] `python3 tools/test_deploy_sandbox.py` passes.
- [ ] `python3 tools/test-installer-matrix.py` passes.
- [ ] `sh tools/check-systemd-contract.sh` passes.
- [ ] `sh tools/check-lock-static.sh` and `sh tools/check-privileged.sh` pass.

## Documentation

- [ ] `node tools/check-doc-links.mjs`
- [ ] `docs/index.md` links to every committed guide;
- [ ] no placeholder text or broken relative links;
- [ ] behavior changes are reflected in the README or the relevant guide.

## Behavior

- [ ] settings open, close and return through the correct parent;
- [ ] last surface survives a backdrop close;
- [ ] drag reorder persists and cancel restores the previous order;
- [ ] PageUp/PageDown and the scrollbar reach the end of long pages;
- [ ] 1.25 UI scale does not clip the package page or the status list.

## Review

- [ ] diff reviewed line by line;
- [ ] no debug logs, dead code or unrelated refactor;
- [ ] no new dependency without approval;
- [ ] commit is atomic and stages explicit paths only.
