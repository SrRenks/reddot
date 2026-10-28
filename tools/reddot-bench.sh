#!/bin/sh
#
# reddot-bench.sh — one snapshot of the shell stack's PSS and idle CPU.
#
#   ./reddot-bench.sh        # 5 s sample
#   ./reddot-bench.sh 15     # longer sample
#
# Run it on a fresh login, then again after opening calendar, wallpaper and the
# POWER surface, to see what the lazy surfaces actually cost. PSS comes from
# smaps_rollup so shared Qt libraries are split between processes instead of
# counted once per process (RSS lies about that).
#
# It is read-only: no config, no state, no sudo.

set -eu

interval=${1:-5}
case "$interval" in
    ''|*[!0-9]*) echo "usage: $0 [seconds]" >&2; exit 2 ;;
esac

hz=$(getconf CLK_TCK 2>/dev/null || echo 100)

# The shell stack plus the helpers that live beside it. Names are comm names,
# so pgrep -x matches them exactly (no substring hits on editors).
names="qs Hyprland hypridle hyprpolkitagent xdg-desktop-por cava wl-paste cliphist kdeconnectd kdeconnect-indi"

pss_kb() {
    awk '/^Pss:/{print $2; exit}' "/proc/$1/smaps_rollup" 2>/dev/null || echo 0
}

ticks() {
    sed 's/^.*) //' "/proc/$1/stat" 2>/dev/null | awk '{print $12 + $13}' || echo 0
}

cmdline() {
    tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null | cut -c1-34
}

pids=$(for n in $names; do pgrep -x "$n" 2>/dev/null || true; done | sort -u)

if [ -z "$pids" ]; then
    echo "no reddot processes found — run this inside the Hyprland session" >&2
fi

# First sample.
before=$(mktemp)
after=$(mktemp)
trap 'rm -f "$before" "$after"' EXIT

for pid in $pids; do
    [ -r "/proc/$pid/stat" ] || continue
    printf '%s %s\n' "$pid" "$(ticks "$pid")" >> "$before"
done

sleep "$interval"

printf '\n  REDDOT BENCH  %s  (%ss, %s Hz)\n\n' "$(date '+%Y-%m-%d %H:%M')" "$interval" "$hz"
printf '  %-34s %7s %9s %7s\n' "PROCESS" "PID" "PSS MB" "CPU %"
printf '  %s\n' "------------------------------------------------------------------"

total_pss=0
count=0

for pid in $pids; do
    [ -r "/proc/$pid/stat" ] || continue
    now=$(ticks "$pid"); now=${now:-0}
    was=$(awk -v p="$pid" '$1 == p { print $2 }' "$before" 2>/dev/null)
    was=${was:-$now}

    pss=$(pss_kb "$pid"); pss=${pss:-0}

    cpu=$(awk -v d="$((now - was))" -v h="$hz" -v i="$interval" \
        'BEGIN { printf "%.1f", (d * 100) / (h * i) }')

    mb=$(awk -v k="$pss" 'BEGIN { printf "%.1f", k / 1024 }')
    total_pss=$((total_pss + pss))
    count=$((count + 1))

    label=$(cmdline "$pid")
    [ -n "$label" ] || label="pid $pid"
    printf '  %-34s %7s %9s %7s\n' "$label" "$pid" "$mb" "$cpu"
done

printf '  %s\n' "------------------------------------------------------------------"
awk -v k="$total_pss" -v c="$count" \
    'BEGIN { printf "  %-34s %7s %9.1f\n", "TOTAL (" c " processes)", "", k / 1024 }'

awk '/MemAvailable/{printf "  %-34s %7s %9.0f\n", "system MemAvailable", "", $2 / 1024}' /proc/meminfo

# Allocator: the 250 MB class only holds when the pill got the decay settings.
qspid=$(pgrep -x qs 2>/dev/null | head -n1 || true)
if [ -n "$qspid" ] && tr '\0' '\n' < "/proc/$qspid/environ" 2>/dev/null | grep -q MALLOC_CONF; then
    printf '  %-34s %7s %9s\n' "MALLOC_CONF" "" "set"
else
    printf '  %-34s %7s %9s\n' "MALLOC_CONF" "" "missing"
fi

printf '\n  top memory, whole session:\n'
ps -eo rss=,comm= --sort=-rss 2>/dev/null | head -n 8 | \
    awk '{ printf "  %-34s %9.1f MB\n", $2, $1 / 1024 }'

# The session cgroup separates real memory from page cache, which RSS never
# does. Walk up from our own scope until the login session scope.
cg=$(sed 's/^0:://' /proc/self/cgroup 2>/dev/null || true)
sess=""
p=$cg
while [ -n "$p" ] && [ "$p" != "/" ]; do
    case "${p##*/}" in
        session-*.scope) sess=$p; break ;;
    esac
    p=$(dirname "$p")
done

printf '\n  session cgroup:\n'
if [ -n "$sess" ] && [ -r "/sys/fs/cgroup$sess/memory.current" ]; then
    awk '/^anon /{printf "  %-34s %9.1f MB\n", "anon (real)", $2 / 1048576}
         /^file /{printf "  %-34s %9.1f MB\n", "file cache (reclaimable)", $2 / 1048576}' \
        "/sys/fs/cgroup$sess/memory.stat"
    awk '{ printf "  %-34s %9.1f MB\n", "total cgroup", $1 / 1048576 }' \
        "/sys/fs/cgroup$sess/memory.current"
else
    printf '  %-34s %9s\n' "session scope" "not found"
fi
printf '\n'
