#!/bin/sh
#
# check.sh — read-only gate for a deployed reddot tree.
#
#   ./tools/check.sh
#
# Helper tests, QML lint, shell/Lua syntax, Hyprland config, drift between this
# checkout and what is installed, and the helper's live status. No root.

set -u

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
cfg=${XDG_CONFIG_HOME:-$HOME/.config}
pill="$cfg/quickshell/pill"
fail=0

ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; fail=$((fail + 1)); }

echo "== helper tests =="
for test in test-ricelin-tlp.sh test-ricelin-thinkpad.sh; do
    if out=$(sh "$here/$test" 2>&1); then
        ok "$test"
    else
        bad "$test"
        printf '%s\n' "$out" | tail -n 8 | sed 's/^/        /'
    fi
done

echo "== qml =="
lint=$(command -v qmllint 2>/dev/null || true)
[ -n "$lint" ] || lint=/usr/lib/qt6/bin/qmllint
if [ -x "$lint" ]; then
    for f in \
        "$pill/TlpSurface.qml" \
        "$pill/BatterySurface.qml" \
        "$pill/Pill.qml" \
        "$pill/shell.qml" \
        "$pill/Look.qml" \
        "$pill/Singletons/Flags.qml" \
        "$pill/Singletons/Peripherals.qml" \
        "$pill/Singletons/PowerHistory.qml" \
        "$pill/Singletons/ThinkPad.qml" \
        "$pill/Singletons/PresetStore.qml" \
        "$pill/PresetsSurface.qml" \
        "$pill/ThinkPadSurface.qml" \
        "$pill/ThinkPadGroup.qml" \
        "$pill/ThinkPadCurve.qml" \
        "$pill/ThinkPadLighting.qml" \
        "$pill/ThinkPadThermalGraph.qml" \
        "$pill/ThinkPadHero.qml" \
        "$pill/ThinkPadState.qml"
    do
        if [ ! -f "$f" ]; then
            bad "missing $f"
            continue
        fi
        n=$("$lint" -I /usr/lib/qt6/qml "$f" 2>&1 | grep -c "Error:")
        if [ "$n" -eq 0 ]; then
            ok "$(basename "$f")"
        else
            bad "$(basename "$f") ($n errors)"
        fi
    done
else
    bad "qmllint not found"
fi

echo "== shell =="
before=$fail
for f in "$cfg"/hypr/scripts/*.sh "$cfg"/hypr/scripts/ricelin; do
    [ -f "$f" ] || continue
    sh -n "$f" 2>/dev/null || bad "sh -n $(basename "$f")"
done
[ "$fail" -eq "$before" ] && ok "hypr scripts parse"

echo "== lua =="
before=$fail
for f in "$cfg"/hypr/modules/*.lua "$cfg"/hypr/*.lua; do
    [ -f "$f" ] || continue
    case "$f" in *.bak*) continue ;; esac
    luac -p "$f" 2>/dev/null || bad "luac -p $(basename "$f")"
done
[ "$fail" -eq "$before" ] && ok "lua parses"

echo "== hyprland =="
if timeout 12s Hyprland --verify-config 2>&1 | grep -q "config ok"; then
    ok "config verify"
else
    bad "Hyprland --verify-config"
fi

echo "== drift =="
cmp -s "$repo/configs/quickshell/pill/TlpSurface.qml" "$pill/TlpSurface.qml" \
    && ok "TlpSurface.qml" || bad "TlpSurface.qml differs from checkout"
cmp -s "$repo/configs/quickshell/pill/Singletons/PowerHistory.qml" \
       "$pill/Singletons/PowerHistory.qml" \
    && ok "PowerHistory.qml" || bad "PowerHistory.qml differs from checkout"
cmp -s "$here/ricelin-bench.sh" "$HOME/.local/bin/ricelin-bench" \
    && ok "ricelin-bench" || bad "ricelin-bench not synced"
cmp -s "$here/ricelin-power-report" "$HOME/.local/bin/ricelin-power-report" \
    && ok "ricelin-power-report" || bad "ricelin-power-report not synced"

echo "== helper =="
if [ -x /usr/local/bin/ricelin-tlp ]; then
    if /usr/local/bin/ricelin-tlp status >/dev/null 2>&1; then
        ok "ricelin-tlp status"
    else
        bad "ricelin-tlp status"
    fi
else
    bad "/usr/local/bin/ricelin-tlp not installed"
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "all checks passed"
else
    echo "$fail check(s) failed"
fi
exit "$fail"
