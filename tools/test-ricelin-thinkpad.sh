#!/bin/sh
#
# Tests for ricelin-thinkpad. No root, no ThinkPad: a fake sysfs tree and a fake
# systemctl stand in for the machine.

set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
helper="$here/ricelin-thinkpad"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0

fail() { echo "FAIL: $*" >&2; fails=$((fails + 1)); }
ok() { echo "ok - $*"; }
contains() {
    if printf '%s\n' "$1" | grep -q -- "$2"; then ok "$3"; else fail "$3 (missing $2)"; fi
}
missing() {
    if printf '%s\n' "$1" | grep -q -- "$2"; then fail "$3 (unexpected $2)"; else ok "$3"; fi
}
exits() {
    want=$1; label=$2; shift 2
    set +e; "$@" >/dev/null 2>&1; got=$?; set -e
    if [ "$got" -eq "$want" ]; then ok "$label"; else fail "$label (exit $got, want $want)"; fi
}

mkdir -p "$tmp/sys/devices/platform/thinkpad_acpi" \
    "$tmp/sys/devices/virtual/dmi/id" \
    "$tmp/sys/devices/platform/i8042/serio1" \
    "$tmp/sys/class/hwmon/hwmon0" \
    "$tmp/sys/class/hwmon/hwmon1" \
    "$tmp/sys/class/hwmon/hwmon2" \
    "$tmp/sys/class/leds/tpacpi::kbd_backlight" \
    "$tmp/sys/class/leds/platform::micmute" \
    "$tmp/sys/firmware/acpi" \
    "$tmp/proc" \
    "$tmp/bin"

printf 'ThinkPad E14 Gen 7\n' > "$tmp/sys/devices/virtual/dmi/id/product_version"
printf 'R2ZET38W (1.27 )\n' > "$tmp/sys/devices/virtual/dmi/id/bios_version"
printf '1\n' > "$tmp/sys/devices/platform/thinkpad_acpi/doubletap_enable"
printf 'k10temp\n' > "$tmp/sys/class/hwmon/hwmon0/name"
printf '50000\n' > "$tmp/sys/class/hwmon/hwmon0/temp1_input"
printf 'amdgpu\n' > "$tmp/sys/class/hwmon/hwmon1/name"
printf '47000\n' > "$tmp/sys/class/hwmon/hwmon1/temp1_input"
printf 'nvme\n' > "$tmp/sys/class/hwmon/hwmon2/name"
printf '41000\n' > "$tmp/sys/class/hwmon/hwmon2/temp1_input"
printf '128\n' > "$tmp/sys/devices/platform/i8042/serio1/sensitivity"
printf '0\n' > "$tmp/sys/devices/platform/i8042/serio1/press_to_select"
printf '2\n' > "$tmp/sys/class/leds/tpacpi::kbd_backlight/max_brightness"
printf '0\n' > "$tmp/sys/class/leds/tpacpi::kbd_backlight/brightness"
printf '1\n' > "$tmp/sys/class/leds/platform::micmute/brightness"
printf 'custom\n' > "$tmp/sys/firmware/acpi/platform_profile"
printf 'status:\t\tenabled\nspeed:\t\t2200\nlevel:\t\t2\n' > "$tmp/proc/fan"
printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/systemctl"
chmod 755 "$tmp/bin/systemctl"

run() {
    PATH="$tmp/bin:$PATH" \
    RICELIN_THINKPAD_SYSFS="$tmp/sys" \
    RICELIN_THINKPAD_PROC="$tmp/proc/fan" \
    RICELIN_THINKPAD_SERIO="$tmp/sys/devices/platform/i8042/serio1" \
    RICELIN_THINKPAD_TEST=1 \
    sh "$helper" "$@"
}

out=$(run status)
contains "$out" '^PRESENT=1$' "detects a ThinkPad"
contains "$out" '^MODEL=ThinkPad E14 Gen 7$' "reads the model"
contains "$out" '^FAN_RPM=2200$' "reads the fan speed"
contains "$out" '^FAN_LEVEL=2$' "reads the fan level"
contains "$out" '^THINKFAN=active$' "reports thinkfan"
contains "$out" '^TEMP_CPU=50$' "reads the CPU temperature"
contains "$out" '^TEMP_GPU=47$' "reads the GPU temperature"
contains "$out" '^LED_KBD_MAX=2$' "reads the backlight maximum"
contains "$out" '^TP_SENSITIVITY=128$' "reads TrackPoint sensitivity"
contains "$out" '^DOUBLETAP=1$' "reads double-tap"

run trackpoint sensitivity 160
contains "$(cat "$tmp/sys/devices/platform/i8042/serio1/sensitivity")" '^160$' "writes sensitivity"
run trackpoint press_to_select 1
contains "$(cat "$tmp/sys/devices/platform/i8042/serio1/press_to_select")" '^1$' "writes press-to-select"
run doubletap 0
contains "$(cat "$tmp/sys/devices/platform/thinkpad_acpi/doubletap_enable")" '^0$' "writes double-tap"
run led kbd 2
contains "$(cat "$tmp/sys/class/leds/tpacpi::kbd_backlight/brightness")" '^2$' "writes the backlight"

exits 2 "rejects an unknown attribute" run trackpoint foo 1
exits 2 "rejects an out-of-range sensitivity" run trackpoint sensitivity 300
exits 2 "rejects an out-of-range backlight" run led kbd 3
exits 2 "rejects an unknown LED" run led power 1

mkdir -p "$tmp/empty"
out=$(RICELIN_THINKPAD_SYSFS="$tmp/empty" RICELIN_THINKPAD_TEST=1 PATH="$tmp/bin:$PATH" sh "$helper" status)
contains "$out" '^PRESENT=0$' "reports no ThinkPad on other hardware"
missing "$out" '^MODEL=' "does not invent a model"

if [ "$fails" -ne 0 ]; then
    echo "$fails test(s) failed" >&2
    exit 1
fi
echo "all tests passed"
