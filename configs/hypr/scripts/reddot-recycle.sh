#!/bin/sh
#
# Recycle the pill process after a long, surface-free idle when its resident
# QML cache has grown past a threshold. Cold page loaders free their object
# trees but not the engine's compiled type cache; a fresh process is the only
# reliable way to return to the idle floor. This is deliberately a last-resort
# hygiene pass, not a per-page action: it never runs while a surface is open
# and skips the bar's active hover region.
#
# Tunables are env vars for tests. The watchdog starts this once per session.

threshold=${REDDOT_RECYCLE_THRESHOLD:-220000} # kB PSS
ticks=${REDDOT_RECYCLE_TICKS:-2}
interval=${REDDOT_RECYCLE_INTERVAL:-20}
runtime=${XDG_RUNTIME_DIR:-/tmp}
log="$runtime/reddot-recycle.log"
hits=0

# Do not inherit the watchdog flock; a replacement watchdog must be able to
# start if this helper is ever left behind.
exec 9>&-

logline() {
    printf '%s %s\n' "$(date -Is)" "$*" >> "$log"
}

while :; do
    sleep "$interval"
    sig=${HYPRLAND_INSTANCE_SIGNATURE:-}
    if [ -z "$sig" ]; then
        sock=$(ls "$runtime"/hypr/*/.socket.sock 2>/dev/null | head -1)
        [ -n "$sock" ] && sig=$(basename "$(dirname "$sock")")
    fi
    [ -n "$sig" ] && [ -S "$runtime/hypr/$sig/.socket.sock" ] || exit 0

    pid=$(hyprctl layers -j 2>/dev/null \
        | jq -r '.. | objects | select(.namespace? == "pill") | .pid' 2>/dev/null \
        | head -1)
    [ -n "$pid" ] && [ -r "/proc/$pid/smaps_rollup" ] || { hits=0; continue; }

    surface=$(qs -c pill ipc call pill surface 2>/dev/null)
    [ -z "$surface" ] || { hits=0; continue; }

    # A pointer in the top strip means the bar is being read or is about to open.
    cursor=$(hyprctl cursorpos 2>/dev/null)
    cx=${cursor%,*}
    cy=${cursor#*,}
    if [ -n "$cx" ] && [ -n "$cy" ] && command -v jq >/dev/null 2>&1; then
        if hyprctl monitors -j 2>/dev/null | jq -e \
            --argjson x "$cx" --argjson y "$cy" \
            '.[] | select((.x <= $x) and ($x < (.x + .width)) and (.y <= $y) and ($y < (.y + 300)))' \
            >/dev/null 2>&1; then
            hits=0
            continue
        fi
    fi

    pss=$(awk '/^Pss:/{print $2; exit}' "/proc/$pid/smaps_rollup" 2>/dev/null)
    [ -n "$pss" ] && [ "$pss" -gt "$threshold" ] || { hits=0; continue; }

    hits=$((hits + 1))
    if [ "$hits" -lt "$ticks" ]; then
        continue
    fi

    logline "recycling pill pid=$pid pss=${pss}kB after ${ticks} idle ticks"
    "$(dirname -- "$0")/reddot" restart pill >> "$log" 2>&1
    hits=0
done
