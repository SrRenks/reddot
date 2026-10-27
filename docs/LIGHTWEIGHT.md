# Lightweight check — where the memory goes

Measured on 2026-10-26, after the jemalloc/30 s/Peripherals changes and the
auto-hide pill. Session cgroup (`session-2.scope`, Hyprland + two QuickShell
instances + helpers):

| | |
|---|---|
| **anon (real)** | **311 MB** |
| file cache (reclaimable) | 496 MB |
| total cgroup | 825 MB |
| peak | 888 MB |
| processes | 21 |

Outside the session scope, the user services add ~57 MB (pipewire 9, wireplumber
18, hyprpolkitagent 20, portal 7, hypridle 1, hyprsunset 1). Zen Browser is
2.1 GB in its own scope — bigger than the entire desktop shell, which is the
normal shape of things.

## Is that good?

For Hyprland + two Qt/QuickShell runtimes + helpers, ~311 MB anon is a healthy
number on 16 GB (about 2 %). It is not the floor:

| Setup | Footprint | Note |
|---|---|---|
| Waybar + fuzzel + mako + hyprlock | ~60–120 MB | no morphing pill, assembled theming |
| Noctalia v5 | ~50 MB/monitor | own C++ shell, no QuickShell/Qt runtime |
| Ukishima | ~250 MB RSS | same architecture as reddot, one qs, jemalloc |
| **reddot here** | **311 MB anon** | compositor + pill + resident lock + helpers |
| Caelestia | ~400 MB RSS | one qs, feature-dense |

The 250–400 MB band is the cost of the QuickShell/Qt architecture; you are at
the lower end of it. The remaining wins are architectural, not micro-tuning.

## Ranked next steps

1. **Lock on demand** — the lock is a second resident `qs` (~40–70 MB). Ukishima
   starts it from `lock.sh` instead of keeping it warm. Trade: 200–400 ms before
   the lock appears, and a failed start is a security bug, so this needs care.
   This is the biggest single win left.
2. **KDE Connect** — `kdeconnectd` + `kdeconnect-indicator` are spawned by the
   session and typically cost 40–100 MB. If phone integration is not in daily
   use, dropping both is free memory with no shell change.
3. **Second-monitor pill** — the pill is instantiated per screen. A policy of
   "all / primary / focused" would remove one full Pill scene graph (~40–70 MB)
   on this two-screen desk. Impasto and Noctalia support per-screen bar policy;
   reddot does not yet.
4. **GPU, not RAM** — Hyprland blur passes, window opacity and the pill's
   effects cost battery and GPU time, not resident memory. Lowering them is a
   different optimisation; do not expect the RAM number to move.
5. **Switching shell** — Noctalia or Waybar would save 150–250 MB, but you lose
   the single morphing pill. That is a product decision, not a tuning step.

Do **not** chase: JS timers (already event-driven or gated), lazy surfaces
(already unloaded after 30 s), the `MALLOC_CONF` (already set), `fastfetch`
(transient), or `tlp-pd` (adds a daemon to replace a 3-command switch).

## How to re-measure

```sh
reddot-bench 10      # PSS per process + session cgroup anon/file
```

`anon` is the number to compare over time. `file cache` is reclaimable and
should be ignored when judging pressure. `reddot-bench` walks up from its own
cgroup to the `session-*.scope`, so it reports the same block without root.

## References

- Ukishima (on-demand lock, jemalloc launch, 30 s unload): <https://github.com/amanhex/ukishima>
- Noctalia v5 C++ rewrite, ~50 MB/monitor: <https://noctalia.dev/blog/announcing-noctalia-v5>
- Quickshell Book, memory/performance chapters: <https://programmersd21.github.io/the_quickshell_book/>
- Waybar as the low-RAM floor: <https://github.com/Alexays/Waybar>
