#!/bin/sh
#
# Tests for reddot-thinkpad. No root, no ThinkPad: a fake sysfs tree and a fake
# systemctl stand in for the machine.

set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
helper="$here/reddot-thinkpad"
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
    "$tmp/sys/class/leds/tpacpi::lid_logo_dot" \
    "$tmp/sys/class/leds/tpacpi::thinkvantage" \
    "$tmp/sys/class/leds/platform::micmute" \
    "$tmp/sys/class/leds/input3::capslock" \
    "$tmp/sys/class/leds/enp1s0-0::lan" \
    "$tmp/sys/firmware/acpi" \
    "$tmp/proc" \
    "$tmp/bin"

printf 'ThinkPad E14 Gen 7\n' > "$tmp/sys/devices/virtual/dmi/id/product_version"
printf 'R2ZET38W (1.27 )\n' > "$tmp/sys/devices/virtual/dmi/id/bios_version"
printf '1\n' > "$tmp/sys/devices/platform/thinkpad_acpi/doubletap_enable"
printf '0\n' > "$tmp/sys/devices/platform/thinkpad_acpi/fn_lock"
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
printf '255\n' > "$tmp/sys/class/leds/tpacpi::lid_logo_dot/max_brightness"
printf '0\n' > "$tmp/sys/class/leds/tpacpi::lid_logo_dot/brightness"
printf 'none default [none] timer\n' > "$tmp/sys/class/leds/tpacpi::lid_logo_dot/trigger"
printf '0\n' > "$tmp/sys/class/leds/tpacpi::lid_logo_dot/delay_on"
printf '0\n' > "$tmp/sys/class/leds/tpacpi::lid_logo_dot/delay_off"
printf '255\n' > "$tmp/sys/class/leds/tpacpi::thinkvantage/max_brightness"
printf '0\n' > "$tmp/sys/class/leds/tpacpi::thinkvantage/brightness"
printf '1\n' > "$tmp/sys/class/leds/platform::micmute/brightness"
printf '0\n' > "$tmp/sys/class/leds/input3::capslock/brightness"
printf '1\n' > "$tmp/sys/class/leds/input3::capslock/max_brightness"
printf '0\n' > "$tmp/sys/class/leds/enp1s0-0::lan/brightness"
printf '255\n' > "$tmp/sys/class/leds/enp1s0-0::lan/max_brightness"
printf 'custom\n' > "$tmp/sys/firmware/acpi/platform_profile"
printf 'be cz da de en es fr fr-ch\n' > "$tmp/sys/devices/platform/thinkpad_acpi/keyboard_lang"
printf '0\n' > "$tmp/sys/devices/platform/thinkpad_acpi/dytc_lapmode"
printf 'status:\t\tenabled\nspeed:\t\t2200\nlevel:\t\t2\n' > "$tmp/proc/fan"
cat > "$tmp/thinkfan.yaml" <<'YAML'
sensors:
  - hwmon: /sys/class/hwmon
    name: k10temp
    indices: [1]
fans:
  - tpacpi: /proc/acpi/ibm/fan
levels:
  - ["level 0",  0, 42]
  - ["level 1", 39, 48]
  - ["level 2", 45, 55]
  - ["level 3", 52, 62]
  - ["level 4", 59, 68]
  - ["level 5", 65, 74]
  - ["level 6", 72, 80]
  - ["level 7", 77, 84]
YAML
printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/systemctl"
chmod 755 "$tmp/bin/systemctl"

run() {
    PATH="$tmp/bin:$PATH" \
    REDDOT_THINKPAD_SYSFS="$tmp/sys" \
    REDDOT_THINKPAD_PROC="$tmp/proc/fan" \
    REDDOT_THINKPAD_SERIO="$tmp/sys/devices/platform/i8042/serio1" \
    REDDOT_THINKPAD_THINKFAN="$tmp/thinkfan.yaml" \
    REDDOT_THINKPAD_TEST=1 \
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
contains "$out" '^CURVE=0:0:42;1:39:48;2:45:55;3:52:62;4:59:68;5:65:74;6:72:80;7:77:84$' "reads the fan curve"
contains "$out" '^LEDS=.*input3::capslock|0|1;' "lists every LED"
contains "$out" '^DOUBLETAP=1$' "reads double-tap"
contains "$out" '^FN_LOCK=0$' "reads Fn lock state"
contains "$out" '^KEYBOARD_LANGS=be cz da de en es fr fr-ch$' "reads keyboard language choices"
contains "$out" '^LAP_MODE=0$' "reads lap mode"
contains "$out" '^LED_META=.*tpacpi::lid_logo_dot|255|0|none|none,default,timer|0|0;' "reads LED trigger metadata"

run trackpoint sensitivity 160
contains "$(cat "$tmp/sys/devices/platform/i8042/serio1/sensitivity")" '^160$' "writes sensitivity"
run trackpoint press_to_select 1
contains "$(cat "$tmp/sys/devices/platform/i8042/serio1/press_to_select")" '^1$' "writes press-to-select"
run doubletap 0
contains "$(cat "$tmp/sys/devices/platform/thinkpad_acpi/doubletap_enable")" '^0$' "writes double-tap"
run fnlock 1
contains "$(cat "$tmp/sys/devices/platform/thinkpad_acpi/fn_lock")" '^1$' "writes Fn lock"
run led kbd 2
contains "$(cat "$tmp/sys/class/leds/tpacpi::kbd_backlight/brightness")" '^2$' "writes the backlight"

exits 2 "rejects an unknown attribute" run trackpoint foo 1
exits 2 "rejects an out-of-range sensitivity" run trackpoint sensitivity 300
exits 2 "rejects an out-of-range backlight" run led kbd 3
exits 2 "rejects an unknown LED" run led power 1

run led lid 1
contains "$(cat "$tmp/sys/class/leds/tpacpi::lid_logo_dot/brightness")" '^255$' "writes the lid logo LED"
run led vantage 1
contains "$(cat "$tmp/sys/class/leds/tpacpi::thinkvantage/brightness")" '^255$' "writes the ThinkVantage LED"
run led input3::capslock 1
contains "$(cat "$tmp/sys/class/leds/input3::capslock/brightness")" '^1$' "writes a generic LED"
run led enp1s0-0::lan 255
contains "$(cat "$tmp/sys/class/leds/enp1s0-0::lan/brightness")" '^255$' "writes a LAN LED"
exits 2 "rejects a path LED name" run led ../brightness 1

run led-trigger tpacpi::lid_logo_dot timer
contains "$(cat "$tmp/sys/class/leds/tpacpi::lid_logo_dot/trigger")" '^timer$' "writes an LED trigger"
run led-delay tpacpi::lid_logo_dot 500 1250
contains "$(cat "$tmp/sys/class/leds/tpacpi::lid_logo_dot/delay_on")" '^500$' "writes LED delay_on"
contains "$(cat "$tmp/sys/class/leds/tpacpi::lid_logo_dot/delay_off")" '^1250$' "writes LED delay_off"
exits 2 "rejects an unknown trigger" run led-trigger tpacpi::lid_logo_dot bogus
exits 2 "rejects an oversized delay" run led-delay tpacpi::lid_logo_dot 20000 1
run keyboard-lang de
contains "$(cat "$tmp/sys/devices/platform/thinkpad_acpi/keyboard_lang")" '^de$' "writes keyboard language"
exits 2 "rejects an unknown keyboard language" run keyboard-lang xx

run curve set '0:0:40;1:38:46;2:44:53;3:51:60;4:58:66;5:64:72;6:70:78;7:75:82'
contains "$(cat "$tmp/thinkfan.yaml")" 'level 0", 0, 40' "writes the fan curve"
contains "$(cat "$tmp/thinkfan.yaml")" 'level 7", 75, 82' "writes every curve level"
exits 2 "rejects an incomplete curve" run curve set '0:0:40;1:38:46'
exits 2 "rejects low above high" run curve set '0:0:40;1:48:46;2:44:53;3:51:60;4:58:66;5:64:72;6:70:78;7:75:82'

mkdir -p "$tmp/empty"
out=$(REDDOT_THINKPAD_SYSFS="$tmp/empty" REDDOT_THINKPAD_TEST=1 PATH="$tmp/bin:$PATH" sh "$helper" status)
contains "$out" '^PRESENT=0$' "reports no ThinkPad on other hardware"
missing "$out" '^MODEL=' "does not invent a model"

if [ "$fails" -ne 0 ]; then
    echo "$fails test(s) failed" >&2
    exit 1
fi
echo "all tests passed"
