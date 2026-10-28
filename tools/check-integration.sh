#!/bin/sh
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
fail=0
ok() { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; fail=$((fail + 1)); }

echo "== installer =="
if out=$(cd "$repo/installer" && timeout 45s python3 reddot_install.py --dry-run --quickstart 2>&1); then
    if printf '%s\n' "$out" | grep -q 'Dry run complete'; then
        ok "dry run"
    else
        bad "dry run did not complete"
        printf '%s\n' "$out" | tail -n 8 | sed 's/^/        /'
    fi
else
    bad "dry run exited non-zero"
    printf '%s\n' "$out" | tail -n 8 | sed 's/^/        /'
fi
if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["packages"]; print(len(d["packages"]))' "$repo/installer/packages.json" >/dev/null 2>&1; then
    ok "packages.json"
else
    bad "packages.json"
fi
if sh -n "$repo/install.sh"; then ok "install.sh syntax"; else bad "install.sh syntax"; fi
if PYTHONPYCACHEPREFIX=/tmp/reddot-pycache python3 -m compileall -q "$repo/installer" >/dev/null 2>&1; then
    ok "installer compile"
else
    bad "installer compile"
fi

echo "== installer selftests =="
for module in deploy distro pkg fallbacks tui; do
    if out=$(cd "$repo/installer" && timeout 60s python3 -c "import $module; $module._selftest()" 2>&1); then
        ok "$module._selftest"
    else
        bad "$module._selftest"
        printf '%s\n' "$out" | tail -n 8 | sed 's/^/        /'
    fi
done

echo "== system files =="
if command -v udevadm >/dev/null 2>&1; then
    if udevadm verify "$repo/tools/99-reddot-leds.rules" >/dev/null 2>&1; then
        ok "udev LED rule"
    else
        bad "udev LED rule"
    fi
else
    printf '  skip  udevadm not found\n'
fi
polkit_tmp=$(mktemp /tmp/reddot-polkit.XXXXXX.js)
cp "$repo/tools/49-reddot.rules" "$polkit_tmp"
if node --check "$polkit_tmp" >/dev/null 2>&1; then
    ok "polkit rule syntax"
else
    bad "polkit rule syntax"
fi
rm -f "$polkit_tmp"
if grep -q 'auth_admin_keep' "$repo/tools/49-reddot.rules" 2>/dev/null \
    || grep -q 'AUTH_ADMIN_KEEP' "$repo/tools/49-reddot.rules" 2>/dev/null; then
    ok "polkit auth policy"
else
    bad "polkit auth policy"
fi
if [ -f "$repo/configs/systemd/user/hyprland-session.target" ] \
    && grep -q '^\[Unit\]' "$repo/configs/systemd/user/hyprland-session.target"; then
    ok "session target shape"
else
    bad "session target shape"
fi
if [ -f "$repo/tools/tlp-acbat.conf" ]     && grep -q '^PLATFORM_PROFILE_ON_AC=performance' "$repo/tools/tlp-acbat.conf"     && grep -q '^CPU_SCALING_GOVERNOR_ON_BAT=powersave' "$repo/tools/tlp-acbat.conf"; then
    ok "TLP policy"
else
    bad "TLP policy"
fi

exit "$fail"
