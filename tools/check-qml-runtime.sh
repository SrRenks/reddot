#!/bin/sh
# Real QML runtime harness. qmltestrunner cannot load the Quickshell plugin, so
# this starts a windowless Quickshell config and waits for its result file.
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
out=$(mktemp /tmp/reddot-qml-runtime.XXXXXX)
log=$(mktemp /tmp/reddot-qml-runtime-log.XXXXXX)
trap 'rm -f "$out" "$log"' EXIT
if ! command -v qs >/dev/null 2>&1; then
    echo "skip: qs not found"
    exit 0
fi
REDDOT_TEST_OUT="$out" REDDOT_TEST_PILL="$repo/configs/quickshell/pill" timeout 12s qs -p "$repo/tests/qs" >"$log" 2>&1 &
pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25; do
    [ -s "$out" ] && break
    sleep 0.2
done
kill "$pid" 2>/dev/null || true
wait "$pid" 2>/dev/null || true
if [ ! -s "$out" ]; then
    echo "FAIL: no result (see $log)"
    tail -n 20 "$log" | sed 's/^/  /'
    exit 1
fi
result=$(cat "$out")
case "$result" in
    pass) echo "QML runtime: pass" ;;
    *) echo "QML runtime: $result"; exit 1 ;;
esac
