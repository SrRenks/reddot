#!/bin/sh
# Focus a window in a direction; when the movefocus dispatcher has no window to
# land on, focus the adjacent monitor instead. Keeps Super+arrows useful on an
# empty second screen without stealing same-monitor window focus.
set -eu
dir=${1:?usage: focus-direction.sh l|r|u|d}
case "$dir" in l|r|u|d) ;; *) exit 2 ;; esac

before=$(hyprctl monitors -j | jq -r 'map(select(.focused)) | .[0].name // empty')
before_win=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' 2>/dev/null || true)
hyprctl dispatch "hl.dsp.focus({ direction = \"$dir\" })" >/dev/null 2>&1 || true
after=$(hyprctl monitors -j | jq -r 'map(select(.focused)) | .[0].name // empty')
after_win=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' 2>/dev/null || true)

[ -n "$after" ] || exit 0
if [ "$after" != "$before" ] || [ "$after_win" != "$before_win" ]; then
    exit 0
fi

# Focus did not move. Pick the nearest monitor on the requested axis.
target=$(hyprctl monitors -j | jq -r --arg a "$after" --arg d "$dir" '
    (map(select(.name == $a)) | .[0]) as $cur
    | map(select(.name != $a))
    | map(select(
        if $d == "l" then .x < $cur.x elif $d == "r" then .x > $cur.x
        elif $d == "u" then .y < $cur.y else .y > $cur.y end))
    | sort_by(
        if $d == "l" or $d == "r" then (((.x + (.width / .scale / 2)) - (($cur.x + ($cur.width / $cur.scale / 2))) | fabs))
        else (((.y + (.height / .scale / 2)) - (($cur.y + ($cur.height / $cur.scale / 2))) | fabs) end)
    | .[0].name // empty')
[ -n "$target" ] && hyprctl dispatch focusmonitor "$target" >/dev/null 2>&1 || true
