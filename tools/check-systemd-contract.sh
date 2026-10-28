#!/bin/sh
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
unit="$repo/configs/systemd/user/hyprland-session.target"
fail=0
ok() { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; fail=$((fail + 1)); }

[ -f "$unit" ] || { bad "missing session target"; exit 1; }
for line in '[Unit]' 'BindsTo=graphical-session.target' 'Wants=graphical-session-pre.target' 'After=graphical-session-pre.target'; do
    grep -Fq "$line" "$unit" && ok "$line" || bad "missing $line"
done
if grep -Eq '^Exec(Start|Stop)=' "$unit"; then
    bad "unexpected executable in session target"
else
    ok "no executable in session target"
fi
exit "$fail"
