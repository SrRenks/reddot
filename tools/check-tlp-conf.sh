#!/bin/sh
#
# Warn when /etc/tlp.conf redefines a key owned by the reddot drop-ins. TLP's
# tlp.conf takes precedence over tlp.d/*.conf, so this silently undoes the
# policy installed by install-extras.sh. The check is advisory: a new machine
# may still be intentionally configured this way while it is being repaired.
set -u

conf="${REDDOT_TLP_CONF:-/etc/tlp.conf}"
[ -r "$conf" ] || exit 0

if grep -qE '^[[:space:]]*(PLATFORM_PROFILE_|CPU_SCALING_GOVERNOR_|CPU_ENERGY_PERF_POLICY_|(START|STOP)_CHARGE_THRESH_)' "$conf"; then
    printf '%s\n' \
        "warning: $conf defines keys managed by the reddot TLP drop-ins." \
        "warning: tlp.conf takes precedence over /etc/tlp.d/*.conf; move these keys out" \
        "warning: of tlp.conf or the pill policy will be partially overridden." \
        "warning: see docs/operations.md, section TLP precedence." >&2
fi
exit 0
