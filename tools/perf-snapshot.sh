#!/bin/sh
# Host-only diagnostic. Reads the live quickshell process from the layer PID.
set -u
pid=$(hyprctl layers 2>/dev/null | sed -n 's/.*namespace: pill.*pid: \([0-9][0-9]*\).*/\1/p' | head -1)
if [ -z "$pid" ]; then
    echo "pill layer not found; start the shell first" >&2
    exit 1
fi
echo "pill pid: $pid"
if [ -r "/proc/$pid/smaps_rollup" ]; then
    grep -E '^(Pss|Pss_Anon|Rss|Private_Clean|Private_Dirty):' "/proc/$pid/smaps_rollup" || true
else
    echo "PSS unavailable: /proc/$pid is not readable in this namespace"
    ps -o pid,rss,pcpu,comm -p "$pid" 2>/dev/null || true
fi
echo "layer:"
hyprctl layers 2>/dev/null | grep 'namespace: pill' | sed 's/.*xywh: //;s/, a.*//'
echo "config errors:"
hyprctl configerrors 2>/dev/null | head -5
