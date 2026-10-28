#!/bin/sh
# Host-only PSS budget. Run in the live session; /proc is not readable from the
# agent sandbox. Usage: test-perf-budget.sh idle|post|lock
set -u
state=${1:-idle}
case "$state" in
    idle) limit=270000 ;;
    post) limit=310000 ;;
    lock) limit=60000 ;;
    *) echo "usage: $0 idle|post|lock" >&2; exit 2 ;;
esac

if [ "$state" = "lock" ]; then
    pid=$(ps -eo pid,args | awk '/[q]s -c lock/ {print $1; exit}')
    label="lock"
else
    pid=$(hyprctl layers 2>/dev/null | sed -n 's/.*namespace: pill.*pid: \([0-9][0-9]*\).*/\1/p' | head -1)
    label="pill"
fi
[ -n "$pid" ] || { echo "$label process not found" >&2; exit 1; }
[ -r "/proc/$pid/smaps_rollup" ] || { echo "/proc/$pid/smaps_rollup is not readable; run on the host" >&2; exit 1; }
pss=$(awk '/^Pss:/ {print $2; exit}' "/proc/$pid/smaps_rollup")
[ -n "$pss" ] || { echo "Pss not found" >&2; exit 1; }
if [ "$pss" -gt "$limit" ]; then
    echo "FAIL $label PSS ${pss} kB > ${limit} kB"
    exit 1
fi
echo "ok $label PSS ${pss} kB <= ${limit} kB"
