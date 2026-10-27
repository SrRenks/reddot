#!/bin/sh
#
# Reddot extras — the parts the Python installer cannot own because they sit
# outside ~/.config: the TLP and ThinkPad helpers, their polkit rule, the AC/BAT
# policy and the user-level tools.
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
# the account that should receive ~/.local/bin.
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
install -Dm644 "$here/49-ricelin.rules" \
    /etc/polkit-1/rules.d/49-ricelin.rules
rm -f /etc/polkit-1/rules.d/49-ricelin-thinkpad.rules
rm -f /etc/sudoers.d/90-ricelin-tlp

if command -v tlp >/dev/null 2>&1; then
    install -Dm644 "$here/tlp-acbat.conf" /etc/tlp.d/99-ricelin-acbat.conf
    tlp start >/dev/null 2>&1 || echo "warning: tlp start failed; run sudo tlp start" >&2
    echo "  /etc/tlp.d/99-ricelin-acbat.conf"
fi

# ThinkPad extras are installed only when the hardware is actually present.
# Non-ThinkPad machines get no extra helper; the shared polkit rule is already installed.
if [ -d /sys/devices/platform/thinkpad_acpi ] \
    || grep -q ThinkPad /sys/devices/virtual/dmi/id/product_version 2>/dev/null; then
    install -m 0755 -o root -g root "$here/ricelin-thinkpad" /usr/local/bin/ricelin-thinkpad
    install -Dm644 "$here/99-ricelin-leds.rules" /etc/udev/rules.d/99-ricelin-leds.rules
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger --subsystem-match=leds --action=change 2>/dev/null || true
    # The udev rule handles boot; apply the current session too.
    printf 'audio-mute\n' > /sys/class/leds/platform::mute/trigger 2>/dev/null || true
    printf 'audio-micmute\n' > /sys/class/leds/platform::micmute/trigger 2>/dev/null || true
    rm -f /etc/sudoers.d/90-ricelin-thinkpad
    echo "  /usr/local/bin/ricelin-thinkpad"
    echo "  /etc/udev/rules.d/99-ricelin-leds.rules"
fi

command -v pkexec >/dev/null 2>&1 || \
    echo "warning: pkexec not found; install polkit for authentication" >&2

install -d -m 0755 -o "$user" -g "$group" "$home/.local/bin"
install -m 0755 -o "$user" -g "$group" "$here/ricelin-bench.sh" \
    "$home/.local/bin/ricelin-bench"
install -m 0755 -o "$user" -g "$group" "$here/ricelin-power-report" \
    "$home/.local/bin/ricelin-power-report"

echo "  /usr/local/bin/ricelin-tlp"
echo "  /etc/polkit-1/rules.d/49-ricelin.rules"
echo "  $home/.local/bin/ricelin-bench"
echo "  $home/.local/bin/ricelin-power-report"
