#!/bin/sh
name="$1"
run="${XDG_RUNTIME_DIR:-/tmp}"
exec 9>"$run/${name}-${HYPRLAND_INSTANCE_SIGNATURE}-watchdog.lock"
flock -n 9 || exit 0

# Ported from Ukishima's launch.sh (the reddot fork): Quickshell links jemalloc
# on Arch, and its default retention keeps RSS at the session peak instead of the
# live working set. Decay returns freed pages to the OS; retain:false makes the
# purge actually drop them from RSS. 100ms keeps the madvise off the UI's free
# path. Applies to both surfaces, since both are spawned from here.
export MALLOC_CONF="background_thread:true,retain:false,dirty_decay_ms:100,muzzy_decay_ms:100"

# Migrate the old ricelin state/cache/data names once before either surface
# starts. The lock makes the two watchdogs share one migration pass.
if [ -x "$(dirname -- "$0")/reddot-migrate" ]; then
    ( flock -n 8 || exit 0; "$(dirname -- "$0")/reddot-migrate" ) 8>"$run/reddot-migrate.lock"
fi

# Pill-only memory hygiene: recycle a long-idle process once its QML type
# cache grows past the threshold. The helper must not hold the watchdog lock.
if [ "$name" = "pill" ]; then
    recycle="$(dirname -- "$0")/reddot-recycle.sh"
    if [ -x "$recycle" ]; then
        "$recycle" 9>&- &
        recycle_pid=$!
        trap 'kill "$recycle_pid" 2>/dev/null' EXIT INT TERM
    fi
fi

while :; do
    qs -c "$name" 9>&- >/dev/null 2>&1
    [ -S "$run/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock" ] || exit 0
    sleep 1
done
