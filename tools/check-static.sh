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

echo "== rust wallcolors =="
if command -v rustc >/dev/null 2>&1; then
    colors_bin="${TMPDIR:-/tmp}/reddot-wallcolors-test-$$"
    if rustc --edition=2021 -O "$repo/tools/reddot-wallcolors.rs" -o "$colors_bin" 2>/tmp/reddot-colors-build.log; then
        ok "rust wallcolors build"
        colors_unit="${TMPDIR:-/tmp}/reddot-wallcolors-unit-$$"
        if rustc --edition=2021 --test "$repo/tools/reddot-wallcolors.rs" -o "$colors_unit" 2>/tmp/reddot-colors-test-build.log && "$colors_unit" >/tmp/reddot-colors-unit.log 2>&1; then
            ok "rust wallcolors unit tests"
        else
            bad "rust wallcolors unit tests"
            tail -n 12 /tmp/reddot-colors-test-build.log /tmp/reddot-colors-unit.log 2>/dev/null | sed 's/^/        /'
        fi
        rm -f "$colors_unit"
        if command -v jq >/dev/null 2>&1; then
            if out=$(sh "$repo/tools/test-reddot-wallcolors-rust.sh" 2>&1); then ok "rust wallcolors integration"; else bad "rust wallcolors integration"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'; fi
        else
            printf '  skip  jq not found\n'
        fi
    else
        bad "rust wallcolors build"
        sed 's/^/        /' /tmp/reddot-colors-build.log | tail -n 12
    fi
    rm -f "$colors_bin"
else
    printf '  skip  rustc not found\n'
fi

echo "== rust distro =="
if command -v rustc >/dev/null 2>&1; then
    distro_bin="${TMPDIR:-/tmp}/reddot-distro-test-$$"
    if rustc --edition=2021 -O "$repo/tools/reddot-distro.rs" -o "$distro_bin" 2>/tmp/reddot-distro-build.log; then
        ok "rust distro build"
        distro_unit="${TMPDIR:-/tmp}/reddot-distro-unit-$$"
        if rustc --edition=2021 --test "$repo/tools/reddot-distro.rs" -o "$distro_unit" 2>/tmp/reddot-distro-test-build.log && "$distro_unit" >/tmp/reddot-distro-unit.log 2>&1; then
            ok "rust distro unit tests"
        else
            bad "rust distro unit tests"
            tail -n 12 /tmp/reddot-distro-test-build.log /tmp/reddot-distro-unit.log 2>/dev/null | sed 's/^/        /'
        fi
        rm -f "$distro_unit"
        if command -v jq >/dev/null 2>&1; then
            if out=$(sh "$repo/tools/test-reddot-distro-rust.sh" 2>&1); then ok "rust distro parity"; else bad "rust distro parity"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'; fi
        else
            printf '  skip  jq not found\n'
        fi
    else
        bad "rust distro build"
        sed 's/^/        /' /tmp/reddot-distro-build.log | tail -n 12
    fi
    rm -f "$distro_bin"
else
    printf '  skip  rustc not found\n'
fi

echo "== rust package argv =="
if command -v rustc >/dev/null 2>&1; then
    pkg_bin="${TMPDIR:-/tmp}/reddot-pkg-test-$$"
    if rustc --edition=2021 -O "$repo/tools/reddot-pkg.rs" -o "$pkg_bin" 2>/tmp/reddot-pkg-build.log; then
        ok "rust pkg build"
        pkg_unit="${TMPDIR:-/tmp}/reddot-pkg-unit-$$"
        if rustc --edition=2021 --test "$repo/tools/reddot-pkg.rs" -o "$pkg_unit" 2>/tmp/reddot-pkg-test-build.log && "$pkg_unit" >/tmp/reddot-pkg-unit.log 2>&1; then
            ok "rust pkg unit tests"
        else
            bad "rust pkg unit tests"
            tail -n 12 /tmp/reddot-pkg-test-build.log /tmp/reddot-pkg-unit.log 2>/dev/null | sed 's/^/        /'
        fi
        rm -f "$pkg_unit"
        if command -v jq >/dev/null 2>&1; then
            if out=$(sh "$repo/tools/test-reddot-pkg-rust.sh" 2>&1); then ok "rust pkg parity"; else bad "rust pkg parity"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'; fi
        else
            printf '  skip  jq not found\n'
        fi
    else
        bad "rust pkg build"
        sed 's/^/        /' /tmp/reddot-pkg-build.log | tail -n 12
    fi
    rm -f "$pkg_bin"
else
    printf '  skip  rustc not found\n'
fi

echo "== rust fallbacks =="
if command -v rustc >/dev/null 2>&1; then
    fb_bin="${TMPDIR:-/tmp}/reddot-fallbacks-test-$$"
    if rustc --edition=2021 -O "$repo/tools/reddot-fallbacks.rs" -o "$fb_bin" 2>/tmp/reddot-fb-build.log; then
        ok "rust fallbacks build"
        fb_unit="${TMPDIR:-/tmp}/reddot-fallbacks-unit-$$"
        if rustc --edition=2021 --test "$repo/tools/reddot-fallbacks.rs" -o "$fb_unit" 2>/tmp/reddot-fb-test-build.log && "$fb_unit" >/tmp/reddot-fb-unit.log 2>&1; then
            ok "rust fallbacks unit tests"
        else
            bad "rust fallbacks unit tests"
            tail -n 12 /tmp/reddot-fb-test-build.log /tmp/reddot-fb-unit.log 2>/dev/null | sed 's/^/        /'
        fi
        rm -f "$fb_unit"
        if command -v jq >/dev/null 2>&1; then
            if out=$(sh "$repo/tools/test-reddot-fallbacks-rust.sh" 2>&1); then ok "rust fallbacks parity"; else bad "rust fallbacks parity"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'; fi
        else
            printf '  skip  jq not found\n'
        fi
    else
        bad "rust fallbacks build"
        sed 's/^/        /' /tmp/reddot-fb-build.log | tail -n 12
    fi
    rm -f "$fb_bin"
else
    printf '  skip  rustc not found\n'
fi

echo "== rust grub =="
if command -v rustc >/dev/null 2>&1; then
    grub_bin="${TMPDIR:-/tmp}/reddot-grub-test-$$"
    if rustc --edition=2021 -O "$repo/tools/reddot-grub.rs" -o "$grub_bin" 2>/tmp/reddot-grub-build.log; then
        ok "rust grub build"
        grub_unit="${TMPDIR:-/tmp}/reddot-grub-unit-$$"
        if rustc --edition=2021 --test "$repo/tools/reddot-grub.rs" -o "$grub_unit" 2>/tmp/reddot-grub-test-build.log && "$grub_unit" >/tmp/reddot-grub-unit.log 2>&1; then
            ok "rust grub unit tests"
        else
            bad "rust grub unit tests"
            tail -n 12 /tmp/reddot-grub-test-build.log /tmp/reddot-grub-unit.log 2>/dev/null | sed 's/^/        /'
        fi
        rm -f "$grub_unit"
        if command -v jq >/dev/null 2>&1; then
            if out=$(sh "$repo/tools/test-reddot-grub-rust.sh" 2>&1); then ok "rust grub parity"; else bad "rust grub parity"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'; fi
        else
            printf '  skip  jq not found\n'
        fi
    else
        bad "rust grub build"
        sed 's/^/        /' /tmp/reddot-grub-build.log | tail -n 12
    fi
    rm -f "$grub_bin"
else
    printf '  skip  rustc not found\n'
fi

echo "== rust deploy =="
if command -v rustc >/dev/null 2>&1; then
    deploy_bin="${TMPDIR:-/tmp}/reddot-deploy-test-$$"
    if rustc --edition=2021 -O "$repo/tools/reddot-deploy.rs" -o "$deploy_bin" 2>/tmp/reddot-deploy-build.log; then
        ok "rust deploy build"
        deploy_unit="${TMPDIR:-/tmp}/reddot-deploy-unit-$$"
        if rustc --edition=2021 --test "$repo/tools/reddot-deploy.rs" -o "$deploy_unit" 2>/tmp/reddot-deploy-test-build.log && "$deploy_unit" >/tmp/reddot-deploy-unit.log 2>&1; then
            ok "rust deploy unit tests"
        else
            bad "rust deploy unit tests"
            tail -n 12 /tmp/reddot-deploy-test-build.log /tmp/reddot-deploy-unit.log 2>/dev/null | sed 's/^/        /'
        fi
        rm -f "$deploy_unit"
        if command -v jq >/dev/null 2>&1; then
            if out=$(sh "$repo/tools/test-reddot-deploy-rust.sh" 2>&1); then ok "rust deploy parity"; else bad "rust deploy parity"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'; fi
        else
            printf '  skip  jq not found\n'
        fi
    else
        bad "rust deploy build"
        sed 's/^/        /' /tmp/reddot-deploy-build.log | tail -n 12
    fi
    rm -f "$deploy_bin"
else
    printf '  skip  rustc not found\n'
fi

echo "== rust neutralize =="
if command -v rustc >/dev/null 2>&1; then
    neutral_bin="${TMPDIR:-/tmp}/reddot-neutralize-test-$$"
    if rustc --edition=2021 -O "$repo/tools/reddot-neutralize.rs" -o "$neutral_bin" 2>/tmp/reddot-neutral-build.log; then
        ok "rust neutralize build"
        neutral_unit="${TMPDIR:-/tmp}/reddot-neutralize-unit-$$"
        if rustc --edition=2021 --test "$repo/tools/reddot-neutralize.rs" -o "$neutral_unit" 2>/tmp/reddot-neutral-test-build.log && "$neutral_unit" >/tmp/reddot-neutral-unit.log 2>&1; then
            ok "rust neutralize unit tests"
        else
            bad "rust neutralize unit tests"
            tail -n 12 /tmp/reddot-neutral-test-build.log /tmp/reddot-neutral-unit.log 2>/dev/null | sed 's/^/        /'
        fi
        rm -f "$neutral_unit"
        if command -v jq >/dev/null 2>&1; then
            if out=$(sh "$repo/tools/test-reddot-neutralize-rust.sh" 2>&1); then ok "rust neutralize parity"; else bad "rust neutralize parity"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'; fi
        else
            printf '  skip  jq not found\n'
        fi
    else
        bad "rust neutralize build"
        sed 's/^/        /' /tmp/reddot-neutral-build.log | tail -n 12
    fi
    rm -f "$neutral_bin"
else
    printf '  skip  rustc not found\n'
fi

echo "== rust tui =="
if command -v rustc >/dev/null 2>&1; then
    tui_bin="${TMPDIR:-/tmp}/reddot-tui-test-$$"
    if rustc --edition=2021 -O "$repo/tools/reddot-tui.rs" -o "$tui_bin" 2>/tmp/reddot-tui-build.log; then
        ok "rust tui build"
        tui_unit="${TMPDIR:-/tmp}/reddot-tui-unit-$$"
        if rustc --edition=2021 --test "$repo/tools/reddot-tui.rs" -o "$tui_unit" 2>/tmp/reddot-tui-test-build.log && "$tui_unit" >/tmp/reddot-tui-unit.log 2>&1; then
            ok "rust tui unit tests"
        else
            bad "rust tui unit tests"
            tail -n 12 /tmp/reddot-tui-test-build.log /tmp/reddot-tui-unit.log 2>/dev/null | sed 's/^/        /'
        fi
        rm -f "$tui_unit"
        if command -v jq >/dev/null 2>&1; then
            if out=$(sh "$repo/tools/test-reddot-tui-rust.sh" 2>&1); then ok "rust tui render parity"; else bad "rust tui render parity"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'; fi
        else
            printf '  skip  jq not found\n'
        fi
    else
        bad "rust tui build"
        sed 's/^/        /' /tmp/reddot-tui-build.log | tail -n 12
    fi
    rm -f "$tui_bin"
else
    printf '  skip  rustc not found\n'
fi

echo "== rust detect =="
if command -v rustc >/dev/null 2>&1; then
    detect_bin="${TMPDIR:-/tmp}/reddot-detect-test-$$"
    if rustc --edition=2021 -O "$repo/tools/reddot-detect.rs" -o "$detect_bin" 2>/tmp/reddot-detect-build.log; then
        ok "rust detect build"
        detect_unit="${TMPDIR:-/tmp}/reddot-detect-unit-$$"
        if rustc --edition=2021 --test "$repo/tools/reddot-detect.rs" -o "$detect_unit" 2>/tmp/reddot-detect-test-build.log && "$detect_unit" >/tmp/reddot-detect-unit.log 2>&1; then
            ok "rust detect unit tests"
        else
            bad "rust detect unit tests"
            tail -n 12 /tmp/reddot-detect-test-build.log /tmp/reddot-detect-unit.log 2>/dev/null | sed 's/^/        /'
        fi
        rm -f "$detect_unit"
        if command -v jq >/dev/null 2>&1; then
            if out=$(sh "$repo/tools/test-reddot-detect-rust.sh" 2>&1); then ok "rust detect parity"; else bad "rust detect parity"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'; fi
        else
            printf '  skip  jq not found\n'
        fi
    else
        bad "rust detect build"
        sed 's/^/        /' /tmp/reddot-detect-build.log | tail -n 12
    fi
    rm -f "$detect_bin"
else
    printf '  skip  rustc not found\n'
fi

echo "== rust plan =="
if command -v rustc >/dev/null 2>&1; then
    plan_bin="${TMPDIR:-/tmp}/reddot-plan-test-$$"
    if rustc --edition=2021 -O "$repo/tools/reddot-plan.rs" -o "$plan_bin" 2>/tmp/reddot-plan-build.log; then
        ok "rust plan build"
        plan_unit="${TMPDIR:-/tmp}/reddot-plan-unit-$$"
        if rustc --edition=2021 --test "$repo/tools/reddot-plan.rs" -o "$plan_unit" 2>/tmp/reddot-plan-test-build.log && "$plan_unit" >/tmp/reddot-plan-unit.log 2>&1; then
            ok "rust plan unit tests"
        else
            bad "rust plan unit tests"
            tail -n 12 /tmp/reddot-plan-test-build.log /tmp/reddot-plan-unit.log 2>/dev/null | sed 's/^/        /'
        fi
        rm -f "$plan_unit"
        if command -v jq >/dev/null 2>&1; then
            if out=$(sh "$repo/tools/test-reddot-plan-rust.sh" 2>&1); then ok "rust plan parity"; else bad "rust plan parity"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'; fi
        else
            printf '  skip  jq not found\n'
        fi
    else
        bad "rust plan build"
        sed 's/^/        /' /tmp/reddot-plan-build.log | tail -n 12
    fi
    rm -f "$plan_bin"
else
    printf '  skip  rustc not found\n'
fi

echo "== rust post =="
if command -v rustc >/dev/null 2>&1; then
    post_bin="${TMPDIR:-/tmp}/reddot-post-test-$$"
    if rustc --edition=2021 -O "$repo/tools/reddot-post.rs" -o "$post_bin" 2>/tmp/reddot-post-build.log; then
        ok "rust post build"
        post_unit="${TMPDIR:-/tmp}/reddot-post-unit-$$"
        if rustc --edition=2021 --test "$repo/tools/reddot-post.rs" -o "$post_unit" 2>/tmp/reddot-post-test-build.log && "$post_unit" >/tmp/reddot-post-unit.log 2>&1; then
            ok "rust post unit tests"
        else
            bad "rust post unit tests"
            tail -n 12 /tmp/reddot-post-test-build.log /tmp/reddot-post-unit.log 2>/dev/null | sed 's/^/        /'
        fi
        rm -f "$post_unit"
        if command -v jq >/dev/null 2>&1; then
            if out=$(sh "$repo/tools/test-reddot-post-rust.sh" 2>&1); then ok "rust post effects parity"; else bad "rust post effects parity"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'; fi
        else
            printf '  skip  jq not found\n'
        fi
    else
        bad "rust post build"
        sed 's/^/        /' /tmp/reddot-post-build.log | tail -n 12
    fi
    rm -f "$post_bin"
else
    printf '  skip  rustc not found\n'
fi

echo "== rust run =="
if command -v rustc >/dev/null 2>&1; then
    run_bin="${TMPDIR:-/tmp}/reddot-run-test-$$"
    if rustc --edition=2021 -O "$repo/tools/reddot-run.rs" -o "$run_bin" 2>/tmp/reddot-run-build.log; then
        ok "rust run build"
        run_unit="${TMPDIR:-/tmp}/reddot-run-unit-$$"
        if rustc --edition=2021 --test "$repo/tools/reddot-run.rs" -o "$run_unit" 2>/tmp/reddot-run-test-build.log && "$run_unit" >/tmp/reddot-run-unit.log 2>&1; then
            ok "rust run unit tests"
        else
            bad "rust run unit tests"
            tail -n 12 /tmp/reddot-run-test-build.log /tmp/reddot-run-unit.log 2>/dev/null | sed 's/^/        /'
        fi
        rm -f "$run_unit"
        if out=$(sh "$repo/tools/test-reddot-run-rust.sh" 2>&1); then ok "rust run ordering"; else bad "rust run ordering"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'; fi
    else
        bad "rust run build"
        sed 's/^/        /' /tmp/reddot-run-build.log | tail -n 12
    fi
    rm -f "$run_bin"
else
    printf '  skip  rustc not found\n'
fi

echo "== rust report =="
if command -v rustc >/dev/null 2>&1; then
    report_bin="${TMPDIR:-/tmp}/reddot-report-test-$$"
    if rustc --edition=2021 -O "$repo/tools/reddot-report.rs" -o "$report_bin" 2>/tmp/reddot-report-build.log; then
        ok "rust report build"
        if out=$(sh "$repo/tools/test-reddot-report-rust.sh" 2>&1); then ok "rust report parity"; else bad "rust report parity"; printf '%s\n' "$out" | tail -n 12 | sed 's/^/        /'; fi
    else
        bad "rust report build"
        sed 's/^/        /' /tmp/reddot-report-build.log | tail -n 12
    fi
    rm -f "$report_bin"
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
for f in "$repo"/configs/hypr/scripts/reddot "$repo"/configs/hypr/scripts/reddot-update "$repo"/configs/hypr/scripts/wallcolors; do
    [ -f "$f" ] || continue
    sh -n "$f" 2>/dev/null || bad "sh -n $(basename "$f")"
done
ok "wrapper syntax"
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
