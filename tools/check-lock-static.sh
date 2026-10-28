#!/bin/sh
# Lock flow is reviewed statically: a runtime smoke can lock the live session.
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
lock="$repo/configs/quickshell/lock/shell.qml"
fail=0
ok() { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; fail=$((fail + 1)); }

for needle in \
    'WlSessionLock' \
    'locked: false' \
    'function doLock' \
    'sessionLock.locked = true' \
    'sessionLock.locked = false' \
    'auth: pamAuth' \
    'Auth {'; do
    if grep -Fq "$needle" "$lock"; then ok "$needle"; else bad "missing $needle"; fi
done

if grep -RIn 'qs -c lock' "$repo/tools" "$repo/configs/hypr/scripts" 2>/dev/null | grep -vE 'check-lock-static|test-lock-multimonitor' >/dev/null; then
    bad "scripts invoke qs -c lock directly"
else
    ok "no automatic lock invocation"
fi

exit "$fail"
