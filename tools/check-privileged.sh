#!/bin/sh
# Static review of the privileged boundary.
set -u
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
fail=0
ok() { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; fail=$((fail + 1)); }

policy="$repo/tools/49-reddot.rules"
if grep -q 'reddot-tlp' "$policy" && grep -q 'reddot-thinkpad' "$policy"; then
    ok "polkit names both helpers"
else
    bad "polkit helper allowlist"
fi
if grep -q 'AUTH_ADMIN_KEEP' "$policy"; then ok "polkit keeps credentials short"; else bad "polkit auth policy"; fi
if find "$repo" -name '99-reddot*' -path '*sudoers*' -print -quit | grep -q .; then
    bad "sudoers exception present"
else
    ok "no sudoers exception"
fi
if grep -q 'set -eu' "$repo/tools/reddot-tlp" && grep -q 'set -eu' "$repo/tools/reddot-thinkpad"; then
    ok "helpers fail fast"
else
    bad "helpers do not fail fast"
fi
if grep -q 'valid_bat' "$repo/tools/reddot-tlp" && grep -q 'cmd_trackpoint' "$repo/tools/reddot-thinkpad"; then
    ok "argument guards present"
else
    bad "argument guard missing"
fi
exit "$fail"
