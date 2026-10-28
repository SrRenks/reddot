#!/bin/sh
#
# check.sh — checkout gate with deployed-tree drift checks.
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
for test in test-reddot-tlp.sh test-reddot-thinkpad.sh; do
    if out=$(sh "$here/$test" 2>&1); then
        ok "$test"
    else
        bad "$test"
        printf '%s\n' "$out" | tail -n 8 | sed 's/^/        /'
    fi
done

echo "== script tests =="
if [ -f "$cfg/hypr/scripts/test_launch_guard.sh" ]; then
    if out=$(sh "$cfg/hypr/scripts/test_launch_guard.sh" 2>&1); then
        ok "test_launch_guard.sh"
    else
        bad "test_launch_guard.sh"
        printf '%s\n' "$out" | tail -n 8 | sed 's/^/        /'
    fi
else
    bad "test_launch_guard.sh missing"
fi
for test in test_reddot_update.py test_wallcolors_apps.py; do
    if [ -f "$cfg/hypr/scripts/$test" ]; then
        if out=$(python3 "$cfg/hypr/scripts/$test" 2>&1); then
            ok "$test"
        else
            bad "$test"
            printf '%s\n' "$out" | tail -n 8 | sed 's/^/        /'
        fi
    fi
done
if command -v node >/dev/null 2>&1; then
    for test in "$pill"/lib/*.test.mjs; do
        [ -f "$test" ] || continue
        if out=$(node "$test" 2>&1); then ok "$(basename "$test")"; else bad "$(basename "$test")"; printf '%s\n' "$out" | tail -n 8 | sed 's/^/        /'; fi
    done
fi

echo "== python syntax =="
if out=$(PYTHONPYCACHEPREFIX=/tmp/reddot-pycache python3 -m compileall -q installer configs/hypr/scripts tools 2>&1); then
    ok "python compile"
else
    bad "python compile"
    printf '%s\n' "$out" | tail -n 8 | sed 's/^/        /'
fi

echo "== surfaces =="
if command -v node >/dev/null 2>&1; then
    if node "$here/check-surfaces.mjs"; then ok "surface catalog"; else bad "surface catalog"; fi
else
    printf '  skip  node not found\n'
fi

echo "== integration =="
if out=$(sh "$here/check-integration.sh" 2>&1); then
    ok "installer and system files"
else
    bad "installer and system files"
    printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'
fi

echo "== qml contract =="
if command -v node >/dev/null 2>&1; then
    if node "$here/check-ui-contract.mjs"; then ok "UI contract"; else bad "UI contract"; fi
else
    printf '  skip  node not found\n'
fi

echo "== qml warnings =="
if command -v node >/dev/null 2>&1; then
    if out=$(node "$here/check-qml-warnings.mjs" 2>&1); then ok "$out"; else bad "QML warnings"; printf '%s\n' "$out" | tail -n 10 | sed 's/^/        /'; fi
else
    printf '  skip  node not found\n'
fi

echo "== hypr api =="
if out=$(sh "$here/check-hypr-api.sh" 2>&1); then ok "Hyprland API"; else bad "Hyprland API"; printf '%s\n' "$out" | tail -n 10 | sed 's/^/        /'; fi

echo "== docs =="
if command -v node >/dev/null 2>&1; then
    if out=$(node "$here/check-doc-links.mjs" 2>&1); then ok "$out"; else bad "docs links"; printf '%s\n' "$out" | tail -n 10 | sed 's/^/        /'; fi
else
    printf '  skip  node not found\n'
fi

echo "== qml =="
lint=$(command -v qmllint 2>/dev/null || true)
[ -n "$lint" ] || lint=/usr/lib/qt6/bin/qmllint
if [ -x "$lint" ]; then
    before=$fail
    n=0
    for f in "$pill"/*.qml "$pill"/Singletons/*.qml "$cfg"/quickshell/lock/*.qml "$cfg"/quickshell/lock/Singletons/*.qml; do
        [ -f "$f" ] || continue
        n=$((n + 1))
        errors=$("$lint" -I /usr/lib/qt6/qml "$f" 2>&1 | grep -c "Error:")
        if [ "$errors" -ne 0 ]; then
            bad "$(basename "$f") ($errors errors)"
        fi
    done
    [ "$fail" -eq "$before" ] && ok "$n QML files"
else
    bad "qmllint not found"
fi

echo "== sensors =="
if [ -x $HOME/.local/bin/reddot-sensors ]; then
    ok "reddot-sensors"
else
    bad "reddot-sensors (run tools/install-extras.sh)"
fi

echo "== shell =="
before=$fail
for f in "$cfg"/hypr/scripts/*.sh "$cfg"/hypr/scripts/reddot; do
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
cmp -s "$here/reddot-bench.sh" "$HOME/.local/bin/reddot-bench" \
    && ok "reddot-bench" || bad "reddot-bench not synced"
cmp -s "$here/reddot-power-report" "$HOME/.local/bin/reddot-power-report" \
    && ok "reddot-power-report" || bad "reddot-power-report not synced"

echo "== helper =="
if [ -x /usr/local/bin/reddot-tlp ]; then
    if /usr/local/bin/reddot-tlp status >/dev/null 2>&1; then
        ok "reddot-tlp status"
    else
        bad "reddot-tlp status"
    fi
else
    bad "/usr/local/bin/reddot-tlp not installed"
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "all checks passed"
else
    echo "$fail check(s) failed"
fi
exit "$fail"
