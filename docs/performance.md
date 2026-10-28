# Performance snapshots

Performance is measured on the live session, not in the headless gate. The
numbers depend on the compositor, the number of surfaces loaded and the
wallpaper pipeline, so they are diagnostic rather than universal thresholds.

## Command

```sh
sh tools/perf-snapshot.sh
```

The script finds the pill layer PID through `hyprctl layers` and prints:

- PSS, anonymous PSS and RSS from `/proc/<pid>/smaps_rollup` when the kernel
  exposes the process;
- a fallback `ps` row when `/proc` is restricted;
- the current layer geometry;
- the first `hyprctl configerrors` entries.

Run it with the pill closed, after opening one hub, and after opening System.
Record the three snapshots separately. Opening every surface in one run is not a
useful memory comparison because cold surfaces unload after 30 seconds.

## Detailed procedure

Run three snapshots in this order, waiting ten seconds between them:

1. closed pill, no surface;
2. after opening **Shell**;
3. after opening **System** and waiting for the sensor refresh.

For the lock, start it only in the disposable session described in
[manual-lock-test.md](manual-lock-test.md), take one snapshot, then unlock and
repeat once. Record the full output and the timestamp, not just the highest
number.

Package checks add a separate transient: run one snapshot immediately after
`Check now` and another after the process exits. Do not compare them as if they
were steady state.

## What to compare

- closed pill versus one settings hub;
- shell plus lock resident processes;
- package check running versus idle;
- a long session after the package timer and sensor refresh have run.

The lock process is intentionally not started by this script. Measure it only
after confirming that a lock cycle is safe in the current session.
