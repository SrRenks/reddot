#!/bin/sh
# Optional runtime smoke: open every settings-like surface in the running pill,
# confirm the layer expands, then close it. Requires quickshell + Hyprland.
set -u
ids=${*:-"settings search shell clock pillsettings packages appearance windows look animation powerhub tlp presets idlelock shortcuts keybinds workspaces maintenance startup updates sysmon display input battery thinkpad thinkpadcurve"}
fail=0
for id in $ids; do
    qs -c pill ipc call pill open "" "$id" >/dev/null 2>&1 || { printf 'FAIL open %s\n' "$id"; fail=$((fail+1)); continue; }
    sleep 0.35
    w=$(hyprctl layers 2>/dev/null | awk '/namespace: pill/{for(i=1;i<=NF;i++) if($i=="xywh:") print $(i+3)}' | head -1)
    if [ "$w" = "1920" ]; then
        printf 'ok   %s\n' "$id"
    else
        printf 'FAIL %s layer=%s\n' "$id" "${w:-none}"
        fail=$((fail+1))
    fi
    qs -c pill ipc call pill close >/dev/null 2>&1 || true
    sleep 0.2
done
exit "$fail"
