#!/bin/sh
# Headless checks shared by local development and CI. No Wayland, root or
# package-manager access is required.
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
fail=0
ok() { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; fail=$((fail + 1)); }

run_node() {
    command -v node >/dev/null 2>&1 || { printf '  skip  node not found\n'; return; }
    if out=$(node "$@" 2>&1); then ok "$(basename "$1")"; else bad "$(basename "$1")"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'; fi
}

echo "== static contracts =="
run_node "$here/check-surfaces.mjs"
run_node "$here/check-ui-contract.mjs"
run_node "$here/check-navigation.mjs"
run_node "$here/check-doc-links.mjs"
for test in "$repo"/configs/quickshell/pill/lib/*.test.mjs; do
    [ -f "$test" ] && run_node "$test"
done

echo "== lock and privileged boundaries =="
for check in check-lock-static.sh check-privileged.sh; do
    if out=$(sh "$here/$check" 2>&1); then ok "$check"; else bad "$check"; printf '%s\n' "$out" | tail -n 10 | sed 's/^/        /'; fi
done

echo "== installer matrix =="
if out=$(python3 "$here/test-installer-matrix.py" 2>&1); then ok "$out"; else bad "installer matrix"; printf '%s\n' "$out" | tail -n 8 | sed 's/^/        /'; fi
if out=$(sh "$here/check-systemd-contract.sh" 2>&1); then ok "session target contract"; else bad "session target contract"; printf '%s\n' "$out" | tail -n 8 | sed 's/^/        /'; fi

echo "== deploy sandbox =="
if out=$(python3 "$here/test_deploy_sandbox.py" 2>&1); then ok "$out"; else bad "deploy sandbox"; printf '%s\n' "$out" | tail -n 10 | sed 's/^/        /'; fi

echo "== python =="
if out=$(PYTHONPYCACHEPREFIX=/tmp/reddot-ci-pycache python3 -m compileall -q "$repo/installer" "$repo/configs/hypr/scripts" "$repo/tools" 2>&1); then
    ok "python compile"
else
    bad "python compile"
    printf '%s\n' "$out" | tail -n 8 | sed 's/^/        /'
fi
for test in test_reddot_update.py test_wallcolors_apps.py; do
    file="$repo/configs/hypr/scripts/$test"
    [ -f "$file" ] || continue
    if out=$(python3 "$file" 2>&1); then ok "$test"; else bad "$test"; printf '%s\n' "$out" | tail -n 8 | sed 's/^/        /'; fi
done
for module in deploy distro pkg fallbacks tui; do
    if out=$(cd "$repo/installer" && timeout 60s python3 -c "import $module; $module._selftest()" 2>&1); then
        ok "$module selftest"
    else
        bad "$module selftest"
        printf '%s\n' "$out" | tail -n 8 | sed 's/^/        /'
    fi
done

echo "== rust updater =="
if command -v rustc >/dev/null 2>&1; then
    binary="${TMPDIR:-/tmp}/reddot-update-test-$$"
    if rustc --edition=2021 -O "$repo/tools/reddot-update.rs" -o "$binary" 2>/tmp/reddot-rust-build.log; then
        ok "rust updater build"
        unit="${TMPDIR:-/tmp}/reddot-update-unit-$$"
        if rustc --edition=2021 --test "$repo/tools/reddot-update.rs" -o "$unit" 2>/tmp/reddot-rust-test-build.log && "$unit" >/tmp/reddot-rust-unit.log 2>&1; then
            ok "rust updater unit tests"
        else
            bad "rust updater unit tests"
            tail -n 12 /tmp/reddot-rust-test-build.log /tmp/reddot-rust-unit.log 2>/dev/null | sed 's/^/        /'
        fi
        rm -f "$unit"
        if command -v jq >/dev/null 2>&1; then
            if out=$(sh "$repo/tools/test-reddot-update-rust.sh" 2>&1); then ok "rust updater integration"; else bad "rust updater integration"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'; fi
        else
            printf '  skip  jq not found\n'
        fi
    else
        bad "rust updater build"
        sed 's/^/        /' /tmp/reddot-rust-build.log | tail -n 12
    fi
    rm -f "$binary"
else
    printf '  skip  rustc not found\n'
fi

echo "== shell and lua =="
for test in test_launch_guard.sh test-reddot-tlp.sh test-reddot-thinkpad.sh test-package-updates.sh; do
    file="$repo/tools/$test"
    [ -f "$file" ] || file="$repo/configs/hypr/scripts/$test"
    [ -f "$file" ] || continue
    interpreter=sh
    case "$(head -n 1 "$file")" in
        *bash*) interpreter=bash ;;
    esac
    if out=$("$interpreter" "$file" 2>&1); then ok "$test"; else bad "$test"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'; fi
done
for f in "$repo"/configs/hypr/scripts/*.sh "$repo"/tools/*.sh "$repo/install.sh"; do
    [ -f "$f" ] || continue
    case "$(head -n 1 "$f")" in
        *bash*) syntax=bash ;;
        *) syntax=sh ;;
    esac
    "$syntax" -n "$f" 2>/dev/null || bad "$syntax -n $(basename "$f")"
done
ok "shell syntax"
luac_bin=
for candidate in luac luac5.4 luac5.3; do
    if command -v "$candidate" >/dev/null 2>&1; then luac_bin=$(command -v "$candidate"); break; fi
done
if [ -n "$luac_bin" ]; then
    for f in "$repo"/configs/hypr/modules/*.lua "$repo"/configs/hypr/*.lua; do
        [ -f "$f" ] || continue
        "$luac_bin" -p "$f" 2>/dev/null || bad "luac $(basename "$f")"
    done
    ok "Lua syntax"
else
    printf '  skip  luac not found\n'
fi

exit "$fail"
