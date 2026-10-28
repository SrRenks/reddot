#!/bin/sh
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
fail=0
ok() { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; fail=$((fail + 1)); }

files=$(find "$repo/configs/hypr" -name '*.lua' -type f | sort)
if [ -z "$files" ]; then
    bad "no Lua config found"
    exit 1
fi

for pattern in 'windowrulev2' 'layerrule[[:space:]]*=' 'bind[[:space:]]*=' 'exec-once[[:space:]]*='; do
    if hits=$(grep -nE "$pattern" $files 2>/dev/null); then
        bad "legacy Hyprland syntax: $pattern"
        printf '%s\n' "$hits" | sed 's/^/        /'
    fi
done

if grep -q 'hl.layer_rule' "$repo/configs/hypr/modules/ui-blur.lua" \
    && grep -Eq 'namespace[[:space:]]*=[[:space:]]*"pill"' "$repo/configs/hypr/modules/ui-blur.lua" \
    && grep -Eq 'blur[[:space:]]*=[[:space:]]*true' "$repo/configs/hypr/modules/ui-blur.lua"; then
    ok "pill layer rule"
else
    bad "pill layer rule"
fi

if grep -q 'hl.window_rule' "$repo/configs/hypr/modules/window_rules.lua"; then
    ok "window rules"
else
    bad "window rules"
fi

if command -v luac >/dev/null 2>&1; then
    for f in $files; do
        if ! luac -p "$f" 2>/dev/null; then bad "luac $(basename "$f")"; fi
    done
    [ "$fail" -eq 0 ] && ok "Lua syntax"
else
    bad "luac not found"
fi

exit "$fail"
