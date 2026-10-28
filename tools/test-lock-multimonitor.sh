#!/bin/sh
# Supervised multi-output lock smoke. Creates an extra headless output, locks,
# and verifies that the compositor reports every screen covered. The user must
# unlock the session before cleanup; this script never removes a locked output.
set -eu
before=$(hyprctl monitors -j | jq -r '.[].name')
hyprctl output create headless >/dev/null
sleep 1
after=$(hyprctl monitors -j | jq -r '.[].name')
mon=$(printf '%s\n%s\n' "$before" "$after" | sort | uniq -u | head -1)
[ -n "$mon" ] || { echo "new headless output not found" >&2; exit 1; }
hyprctl eval "hl.monitor({ output = \"$mon\", mode = \"1280x720@60\", position = \"10880x0\", scale = 1.25 })" >/dev/null
sleep 1
qs -c lock ipc call lock lock >/dev/null
sleep 1
secure=$(qs -c lock ipc call lock secure)
[ "$secure" = "true" ] || { echo "FAIL lock secure=$secure" >&2; exit 1; }
echo "ok lock secure=true on eDP-1 + $mon"
echo "unlock the session, then run: hyprctl output remove $mon"
