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

# One-way cleanup and config adoption from the old ricelin names.
if [ -f /etc/tlp.d/99-ricelin.conf ] && [ ! -e /etc/tlp.d/99-reddot.conf ]; then
    cp -p /etc/tlp.d/99-ricelin.conf /etc/tlp.d/99-reddot.conf
fi
if [ -f /etc/tlp.d/99-ricelin-acbat.conf ] && [ ! -e /etc/tlp.d/99-reddot-acbat.conf ]; then
    cp -p /etc/tlp.d/99-ricelin-acbat.conf /etc/tlp.d/99-reddot-acbat.conf
fi
rm -f /usr/local/bin/ricelin-tlp /usr/local/bin/ricelin-thinkpad /usr/local/bin/ricelin-sensors
rm -f /etc/polkit-1/rules.d/49-ricelin.rules
rm -f /etc/udev/rules.d/99-ricelin-leds.rules
rm -f /etc/sudoers.d/90-ricelin-tlp /etc/sudoers.d/90-ricelin-thinkpad
rm -f /etc/tlp.d/99-ricelin.conf /etc/tlp.d/99-ricelin-acbat.conf

if command -v rustc >/dev/null 2>&1; then
    sensor_tmp=$(mktemp)
    if rustc --edition=2021 -O -C strip=symbols "$here/reddot-sensors.rs" -o "$sensor_tmp"; then
        install -d -m 0755 -o "$user" -g "$group" "$home/.local/bin"
        install -m 0755 -o "$user" -g "$group" "$sensor_tmp" "$home/.local/bin/reddot-sensors"
        echo "  $home/.local/bin/reddot-sensors"
    else
        echo "warning: could not build reddot-sensors" >&2
    fi
    rm -f "$sensor_tmp"
else
    echo "warning: rustc not found; System sensor helper not installed" >&2
fi

if command -v rustc >/dev/null 2>&1; then
    updater_tmp=$(mktemp)
    if rustc --edition=2021 -O -C strip=symbols "$here/reddot-update.rs" -o "$updater_tmp"; then
        install -d -m 0755 -o "$user" -g "$group" "$home/.local/bin"
        install -m 0755 -o "$user" -g "$group" "$updater_tmp" "$home/.local/bin/reddot-update"
        echo "  $home/.local/bin/reddot-update"
    else
        echo "warning: could not build reddot-update" >&2
    fi
    rm -f "$updater_tmp"
else
    echo "warning: rustc not found; updater not installed" >&2
fi

if command -v rustc >/dev/null 2>&1; then
    colors_tmp=$(mktemp)
    if rustc --edition=2021 -O -C strip=symbols "$here/reddot-wallcolors.rs" -o "$colors_tmp"; then
        install -d -m 0755 -o "$user" -g "$group" "$home/.local/bin"
        install -m 0755 -o "$user" -g "$group" "$colors_tmp" "$home/.local/bin/reddot-wallcolors"
        echo "  $home/.local/bin/reddot-wallcolors"
    else
        echo "warning: could not build reddot-wallcolors" >&2
    fi
    rm -f "$colors_tmp"
else
    echo "warning: rustc not found; wallcolors not installed" >&2
fi

install -m 0755 -o root -g root "$here/reddot-tlp" /usr/local/bin/reddot-tlp
install -Dm644 "$here/49-reddot.rules" \
    /etc/polkit-1/rules.d/49-reddot.rules
rm -f /etc/polkit-1/rules.d/49-reddot-thinkpad.rules
rm -f /etc/sudoers.d/90-reddot-tlp

if command -v tlp >/dev/null 2>&1; then
    install -Dm644 "$here/tlp-acbat.conf" /etc/tlp.d/99-reddot-acbat.conf
    tlp start >/dev/null 2>&1 || echo "warning: tlp start failed; run sudo tlp start" >&2
    echo "  /etc/tlp.d/99-reddot-acbat.conf"
fi

# ThinkPad extras are installed only when the hardware is actually present.
# Non-ThinkPad machines get no extra helper; the shared polkit rule is already installed.
if [ -d /sys/devices/platform/thinkpad_acpi ] \
    || grep -q ThinkPad /sys/devices/virtual/dmi/id/product_version 2>/dev/null; then
    install -m 0755 -o root -g root "$here/reddot-thinkpad" /usr/local/bin/reddot-thinkpad
    install -Dm644 "$here/99-reddot-leds.rules" /etc/udev/rules.d/99-reddot-leds.rules
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger --subsystem-match=leds --action=change 2>/dev/null || true
    # The udev rule handles boot; apply the current session too.
    printf 'audio-mute\n' > /sys/class/leds/platform::mute/trigger 2>/dev/null || true
    printf 'audio-micmute\n' > /sys/class/leds/platform::micmute/trigger 2>/dev/null || true
    rm -f /etc/sudoers.d/90-reddot-thinkpad
    echo "  /usr/local/bin/reddot-thinkpad"
    echo "  /etc/udev/rules.d/99-reddot-leds.rules"
fi

command -v pkexec >/dev/null 2>&1 || \
    echo "warning: pkexec not found; install polkit for authentication" >&2

install -d -m 0755 -o "$user" -g "$group" "$home/.local/bin"
if command -v rustc >/dev/null 2>&1; then
    deploy_tmp=$(mktemp)
    if rustc --edition=2021 -O -C strip=symbols "$here/reddot-deploy.rs" -o "$deploy_tmp"; then
        install -d -m 0755 -o "$user" -g "$group" "$home/.local/bin"
        install -m 0755 -o "$user" -g "$group" "$deploy_tmp" "$home/.local/bin/reddot-deploy"
        echo "  $home/.local/bin/reddot-deploy"
    else
        echo "warning: could not build reddot-deploy" >&2
    fi
    rm -f "$deploy_tmp"
else
    echo "warning: rustc not found; deploy helper not installed" >&2
fi

if command -v rustc >/dev/null 2>&1; then
    installer_tmp=$(mktemp)
    if rustc --edition=2021 -O -C strip=symbols "$here/reddot-install.rs" -o "$installer_tmp"; then
        install -d -m 0755 -o "$user" -g "$group" "$home/.local/bin"
        install -m 0755 -o "$user" -g "$group" "$installer_tmp" "$home/.local/bin/reddot-install"
        echo "  $home/.local/bin/reddot-install"
    else
        echo "warning: could not build reddot-install" >&2
    fi
    rm -f "$installer_tmp"
else
    echo "warning: rustc not found; installer not installed" >&2
fi

install -m 0755 -o "$user" -g "$group" "$here/reddot-bench.sh" \
    "$home/.local/bin/reddot-bench"
install -m 0755 -o "$user" -g "$group" "$here/reddot-power-report" \
    "$home/.local/bin/reddot-power-report"

echo "  /usr/local/bin/reddot-tlp"
echo "  /etc/polkit-1/rules.d/49-reddot.rules"
echo "  $home/.local/bin/reddot-bench"
echo "  $home/.local/bin/reddot-power-report"
