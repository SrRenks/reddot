#!/bin/sh
# Capture the focused monitor in rishot without its monitor-picker step.
set -eu

monitor=$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.monitor // empty' 2>/dev/null || true)
if [ -z "$monitor" ]; then
    monitor=$(hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null | head -n1 || true)
fi

exec env RISHOT_MONITOR="$monitor" "$HOME/.local/share/rishot/bin/rishot" current
