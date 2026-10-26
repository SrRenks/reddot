#!/bin/sh
#
# Reddot extras — the parts the Python installer cannot own because they sit
# outside ~/.config: the TLP helper, its sudoers rule, the AC/BAT policy and
# the user-level tools.
#
# Called by install.sh through sudo after the config deploy. Safe to re-run.

set -eu

[ "$(id -u)" -eq 0 ] || {
    echo "install-extras: run as root (install.sh does this through sudo)" >&2
    exit 1
}

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")

user="${SUDO_USER:-}"
# install.sh can legitimately run as root directly; the checkout owner is then
# the account that should receive ~/.local/bin and the sudoers rule.
if [ -z "$user" ]; then
    user=$(stat -c %U "$repo" 2>/dev/null || true)
fi
[ -n "$user" ] && [ "$user" != "root" ] || {
    echo "install-extras: cannot determine the desktop user" >&2
    exit 1
}

home=$(getent passwd "$user" | cut -d: -f6)
group=$(id -gn "$user")

install -m 0755 -o root -g root "$here/ricelin-tlp" /usr/local/bin/ricelin-tlp

printf '%s ALL=(root) NOPASSWD: /usr/local/bin/ricelin-tlp\n' "$user" \
    > /etc/sudoers.d/90-ricelin-tlp
chmod 0440 /etc/sudoers.d/90-ricelin-tlp
visudo -cf /etc/sudoers.d/90-ricelin-tlp >/dev/null

if command -v tlp >/dev/null 2>&1; then
    install -Dm644 "$here/tlp-acbat.conf" /etc/tlp.d/99-ricelin-acbat.conf
    tlp start >/dev/null 2>&1 || echo "warning: tlp start failed; run sudo tlp start" >&2
    echo "  /etc/tlp.d/99-ricelin-acbat.conf"
fi

# ThinkPad extras are installed only when the hardware is actually present.
# Non-ThinkPad machines get no extra binary and no extra sudoers rule.
if [ -d /sys/devices/platform/thinkpad_acpi ] \
    || grep -q ThinkPad /sys/devices/virtual/dmi/id/product_version 2>/dev/null; then
    install -m 0755 -o root -g root "$here/ricelin-thinkpad" /usr/local/bin/ricelin-thinkpad
    printf '%s ALL=(root) NOPASSWD: /usr/local/bin/ricelin-thinkpad\n' "$user" \
        > /etc/sudoers.d/90-ricelin-thinkpad
    chmod 0440 /etc/sudoers.d/90-ricelin-thinkpad
    visudo -cf /etc/sudoers.d/90-ricelin-thinkpad >/dev/null
    echo "  /usr/local/bin/ricelin-thinkpad"
    echo "  /etc/sudoers.d/90-ricelin-thinkpad"
fi

install -d -m 0755 -o "$user" -g "$group" "$home/.local/bin"
install -m 0755 -o "$user" -g "$group" "$here/ricelin-bench.sh" \
    "$home/.local/bin/ricelin-bench"
install -m 0755 -o "$user" -g "$group" "$here/ricelin-power-report" \
    "$home/.local/bin/ricelin-power-report"

echo "  /usr/local/bin/ricelin-tlp"
echo "  /etc/sudoers.d/90-ricelin-tlp"
echo "  $home/.local/bin/ricelin-bench"
echo "  $home/.local/bin/ricelin-power-report"
