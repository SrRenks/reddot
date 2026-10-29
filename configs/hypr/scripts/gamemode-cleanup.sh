#!/bin/sh
#
# List or terminate other windowed applications for game mode. Only PIDs that
# currently own a Hyprland toplevel are candidates. The selected game class,
# its ancestors, configured keep classes and system/firmware services are
# protected. SIGTERM is the only signal used; the UI confirms the action.
#
set -eu

mode=${1:-preview}
target=${2:-}
keep=${3:-}
[ -n "$target" ] || { echo "missing target class" >&2; exit 2; }
case "$mode" in preview|terminate) ;; *) echo "usage: gamemode-cleanup.sh preview|terminate <target-class> [keep-classes]" >&2; exit 2 ;; esac

clients=$(hyprctl clients -j)
[ -n "$clients" ] || exit 0
uid=$(id -u)

# Classes that own the session or implement firmware/system behavior. They are
# never candidates, even if a window is present.
protected='hyprland quickshell org.quickshell pipewire wireplumber hypridle hyprpaper swww xdg-desktop-portal xdg-desktop-portal-hyprland polkit-agent-1 systemd steam gamescope gameoverlay'

is_kept() {
    case ",$keep," in
        *",$1,"*) return 0 ;;
    esac
    return 1
}

is_protected() {
    case " $protected " in
        *" $1 "*) return 0 ;;
    esac
    return 1
}

ancestors() {
    p=$1
    while [ "$p" -gt 1 ] 2>/dev/null; do
        echo "$p"
        p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
        [ -n "$p" ] || break
    done
}

descendants() {
    for child in $(ps -o pid= --ppid "$1" 2>/dev/null); do
        echo "$child"
        descendants "$child"
    done
}

# Build the protected PID set from the target class and kept classes.
protected_pids=" "
target_pids=$(printf '%s\n' "$clients" | jq -r --arg t "$target" '.[] | select((.class // "") == $t) | .pid' 2>/dev/null || true)
for p in $target_pids; do
    for a in $(ancestors "$p"); do protected_pids="$protected_pids$a "; done
    for d in $(descendants "$p"); do protected_pids="$protected_pids$d "; done
done
if [ -n "$keep" ]; then
    keep_pids=$(printf '%s\n' "$clients" | jq -r --arg k "$keep" '.[] | .class as $c | select(($k | split(",")) | index($c)) | .pid' 2>/dev/null || true)
    for p in $keep_pids; do
        for a in $(ancestors "$p"); do protected_pids="$protected_pids$a "; done
        for d in $(descendants "$p"); do protected_pids="$protected_pids$d "; done
    done
fi

printf '%s\n' "$clients" | jq -r '.[] | [.pid, (.class // ""), (.title // "")] | @tsv' |
while IFS="$(printf '\t')" read -r pid class title; do
    [ -n "$pid" ] || continue
    [ "$pid" -gt 1 ] 2>/dev/null || continue
    [ "$class" != "$target" ] || continue
    is_kept "$class" && continue
    is_protected "$class" && continue
    case "$protected_pids" in *" $pid "*) continue ;; esac

    owner=$(ps -o uid= -p "$pid" 2>/dev/null | tr -d ' ') || continue
    [ "$owner" = "$uid" ] || continue
    cgroup=$(awk -F: '/::/ {print $3; exit}' "/proc/$pid/cgroup" 2>/dev/null || true)
    case "$cgroup" in
        /system.slice/*|/init.scope/*) continue ;;
    esac

    printf '%s %s %s\n' "$mode" "$pid" "$class"
    if [ "$mode" = "terminate" ]; then
        kill -TERM "$pid" 2>/dev/null || printf 'skip %s %s\n' "$pid" "$class" >&2
    fi
done
