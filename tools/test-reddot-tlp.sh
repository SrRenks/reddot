#!/bin/sh
#
# Tests for reddot-tlp. No root, no battery, no TLP: a fake sysfs tree and
# fake tlp/tlp-stat/systemctl/powerprofilesctl scripts stand in for the host.
#
#   sh test-reddot-tlp.sh

set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
helper="$here/reddot-tlp"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fails=0

fail() {
    echo "FAIL: $*" >&2
    fails=$((fails + 1))
}

ok() {
    echo "ok - $*"
}

assert_contains() {
    if printf '%s\n' "$1" | grep -q -- "$2"; then
        ok "$3"
    else
        fail "$3 (missing: $2)"
    fi
}

assert_missing() {
    if printf '%s\n' "$1" | grep -q -- "$2"; then
        fail "$3 (unexpected: $2)"
    else
        ok "$3"
    fi
}

assert_exit() {
    expected=$1
    label=$2
    shift 2
    set +e
    "$@" >/dev/null 2>&1
    code=$?
    set -e
    if [ "$code" -eq "$expected" ]; then
        ok "$label"
    else
        fail "$label (exit $code, wanted $expected)"
    fi
}

make_battery() {
    dir=$1
    start=$2
    stop=$3
    legacy=$4
    mkdir -p "$dir"
    printf 'Battery\n' > "$dir/type"
    printf '43\n' > "$dir/cycle_count"
    printf '[auto] inhibit-charge force-discharge\n' > "$dir/charge_behaviour"
    if [ "$legacy" = "1" ]; then
        printf '%s\n' "$start" > "$dir/charge_start_threshold"
        printf '%s\n' "$stop" > "$dir/charge_stop_threshold"
    else
        printf '%s\n' "$start" > "$dir/charge_control_start_threshold"
        printf '%s\n' "$stop" > "$dir/charge_control_end_threshold"
    fi
}

mkdir -p "$tmp/sys/BAT0" "$tmp/sys/BAT1" "$tmp/sys/AC" "$tmp/bin" "$tmp/tlp.d"
mkdir -p "$tmp/cpufreq/cpu0/cpufreq"
printf 'balanced\n' > "$tmp/platform_profile"
printf 'balance_power\n' > "$tmp/cpufreq/cpu0/cpufreq/energy_performance_preference"
printf 'powersave\n' > "$tmp/cpufreq/cpu0/cpufreq/scaling_governor"
make_battery "$tmp/sys/BAT0" 40 80 0
make_battery "$tmp/sys/BAT1" 0 100 1
printf '1\n' > "$tmp/sys/AC/online"

cat > "$tmp/bin/tlp" <<EOF
#!/bin/sh
echo "\$*" >> "$tmp/tlp.log"
EOF
cat > "$tmp/bin/tlp-stat" <<'EOF'
#!/bin/sh
printf 'TLP profile    = performance/AC\nPower source   = AC\n'
EOF
cat > "$tmp/bin/systemctl" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod 755 "$tmp/bin/tlp" "$tmp/bin/tlp-stat" "$tmp/bin/systemctl"

run() {
    PATH="$tmp/bin:$PATH" \
    REDDOT_TLP_SYSFS="$tmp/sys" \
    REDDOT_TLP_CONF="$tmp/tlp.d/99-reddot.conf" \
    REDDOT_TLP_PLATFORM_PROFILE="$tmp/platform_profile" \
    REDDOT_TLP_CPUFREQ="$tmp/cpufreq" \
    REDDOT_TLP_TEST=1 \
    sh "$helper" "$@"
}

# --- status ---------------------------------------------------------------
out=$(run status)
assert_contains "$out" '^TOOL=tlp$' "status detects TLP"
assert_contains "$out" '^ENABLED=1$' "status reports the service active"
assert_contains "$out" '^POWER=AC$' "status reads AC from sysfs"
assert_contains "$out" '^PROFILE=performance$' "status strips the /AC suffix"
assert_contains "$out" '^EFFECTIVE=balanced$' "status reports the sysfs profile"
assert_contains "$out" '^EPP=balance_power$' "status reports EPP"
assert_contains "$out" '^GOV=powersave$' "status reports the governor"
assert_contains "$out" '^BATTERY=BAT0|40|80|43|auto|1|1$' "BAT0 charge window and behaviour"
assert_contains "$out" '^BATTERY=BAT1|0|100|43|auto|1|1$' "BAT1 legacy *_threshold names"

# --- set (TLP path, persisted, merged) ------------------------------------
run set BAT0 45 85
assert_contains "$(cat "$tmp/tlp.d/99-reddot.conf")" 'START_CHARGE_THRESH_BAT0=45' "set writes the BAT0 start key"
assert_contains "$(cat "$tmp/tlp.d/99-reddot.conf")" 'STOP_CHARGE_THRESH_BAT0=85' "set writes the BAT0 stop key"
assert_contains "$(cat "$tmp/tlp.log")" 'setcharge 45 85 BAT0' "set calls tlp setcharge"

run set BAT1 50 90
conf=$(cat "$tmp/tlp.d/99-reddot.conf")
assert_contains "$conf" 'START_CHARGE_THRESH_BAT0=45' "second set keeps BAT0 start"
assert_contains "$conf" 'START_CHARGE_THRESH_BAT1=50' "second set adds BAT1 start"
assert_contains "$conf" 'STOP_CHARGE_THRESH_BAT1=90' "second set adds BAT1 stop"

# --- apply (profile + all battery windows, one command) -------------------
run apply balanced 95 100
conf=$(cat "$tmp/tlp.d/99-reddot.conf")
assert_contains "$conf" 'START_CHARGE_THRESH_BAT0=95' "apply writes BAT0 start"
assert_contains "$conf" 'STOP_CHARGE_THRESH_BAT0=100' "apply writes BAT0 stop"
assert_contains "$conf" 'START_CHARGE_THRESH_BAT1=95' "apply writes BAT1 start"
assert_contains "$conf" 'STOP_CHARGE_THRESH_BAT1=100' "apply writes BAT1 stop"
assert_contains "$(cat "$tmp/tlp.log")" 'setcharge 95 100 BAT0' "apply sets BAT0"
assert_contains "$(cat "$tmp/tlp.log")" 'setcharge 95 100 BAT1' "apply sets BAT1"
assert_contains "$(cat "$tmp/platform_profile")" '^balanced$' "apply writes the sysfs platform profile"
assert_contains "$(cat "$tmp/cpufreq/cpu0/cpufreq/scaling_governor")" '^powersave$' "apply writes the governor"
assert_contains "$(cat "$tmp/cpufreq/cpu0/cpufreq/energy_performance_preference")" '^balance_power$' "apply writes balance_power EPP"

# --- profile override (sysfs, not tlp <mode>) ------------------------------
run profile balanced
assert_contains "$(cat "$tmp/platform_profile")" '^balanced$' "profile balanced writes the platform profile"
assert_contains "$(cat "$tmp/cpufreq/cpu0/cpufreq/scaling_governor")" '^powersave$' "profile balanced writes the governor"
assert_contains "$(cat "$tmp/cpufreq/cpu0/cpufreq/energy_performance_preference")" '^balance_power$' "profile balanced writes the EPP"

run profile performance
assert_contains "$(cat "$tmp/platform_profile")" '^performance$' "profile performance writes the platform profile"
assert_contains "$(cat "$tmp/cpufreq/cpu0/cpufreq/energy_performance_preference")" '^performance$' "profile performance writes its EPP"

printf '0\n' > "$tmp/sys/AC/online"
assert_exit 2 "performance refused on battery" run profile performance
printf '1\n' > "$tmp/sys/AC/online"

# --- validation -----------------------------------------------------------
assert_exit 2 "rejects start >= stop" run set BAT0 90 80
assert_exit 2 "rejects a non-numeric start" run set BAT0 abc 80
assert_exit 2 "rejects an unknown battery" run set BAT9 40 80
assert_exit 2 "rejects a path as a battery" run set ../etc 40 80
assert_exit 2 "rejects an unknown profile" run profile turbo
assert_exit 2 "rejects an invalid apply window" run apply balanced 90 80
assert_exit 2 "rejects an invalid apply profile" run apply turbo 50 80
assert_exit 2 "rejects shell metacharacters in a battery" run set 'BAT0;id' 40 80
assert_exit 2 "rejects an extra battery argument" run set BAT0 40 80 extra
assert_exit 2 "rejects shell metacharacters in a profile" run profile 'balanced;id'
assert_exit 2 "rejects an empty battery" run set '' 40 80

# --- pause / resume -------------------------------------------------------
run pause BAT0
assert_contains "$(cat "$tmp/sys/BAT0/charge_behaviour")" 'inhibit-charge' "pause writes inhibit-charge"
run resume BAT0
assert_contains "$(cat "$tmp/sys/BAT0/charge_behaviour")" 'auto' "resume writes auto"

# --- no TLP: PPD fallback -------------------------------------------------
pbin="$tmp/pbin"
mkdir -p "$pbin"
for tool in cat awk grep cut tr id dirname mkdir mv rm; do
    path=$(command -v "$tool" || true)
    [ -n "$path" ] && ln -sf "$path" "$pbin/$tool"
done
cat > "$pbin/powerprofilesctl" <<EOF
#!/bin/sh
if [ "\${1:-}" = get ]; then echo balanced; else echo "\$*" >> "$tmp/ppd.log"; fi
EOF
cat > "$pbin/systemctl" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod 755 "$pbin/powerprofilesctl" "$pbin/systemctl"

out=$(PATH="$pbin" REDDOT_TLP_SYSFS="$tmp/sys" REDDOT_TLP_CONF="$tmp/ppd.conf" REDDOT_TLP_TEST=1 /bin/sh "$helper" status)
assert_contains "$out" '^TOOL=ppd$' "status falls back to power-profiles-daemon"
assert_contains "$out" '^PROFILE=balanced$' "PPD profile is read"

PATH="$pbin" REDDOT_TLP_SYSFS="$tmp/sys" REDDOT_TLP_CONF="$tmp/ppd.conf" REDDOT_TLP_TEST=1 /bin/sh "$helper" profile power-saver
assert_contains "$(cat "$tmp/ppd.log")" 'set power-saver' "profile falls back to powerprofilesctl set"

# --- sysfs-only set (no TLP, no PPD) --------------------------------------
mkdir -p "$tmp/plain"
for tool in cat awk grep cut tr id dirname mkdir mv rm printf; do
    path=$(command -v "$tool" || true)
    [ -n "$path" ] && ln -sf "$path" "$tmp/plain/$tool"
done
PATH="$tmp/plain" REDDOT_TLP_SYSFS="$tmp/sys" REDDOT_TLP_CONF="$tmp/plain.conf" REDDOT_TLP_TEST=1 /bin/sh "$helper" set BAT0 55 88
assert_contains "$(cat "$tmp/sys/BAT0/charge_start_threshold" 2>/dev/null || cat "$tmp/sys/BAT0/charge_control_start_threshold")" '55' "sysfs-only set writes the start threshold"
assert_contains "$(cat "$tmp/sys/BAT0/charge_control_end_threshold")" '88' "sysfs-only set writes the stop threshold"

# --- no batteries ---------------------------------------------------------
mkdir -p "$tmp/empty"
out=$(REDDOT_TLP_SYSFS="$tmp/empty" REDDOT_TLP_CONF="$tmp/none.conf" REDDOT_TLP_TEST=1 PATH="$tmp/bin:$PATH" sh "$helper" status)
assert_missing "$out" 'BATTERY=' "a desktop with no battery reports none"

if [ "$fails" -ne 0 ]; then
    echo "$fails test(s) failed" >&2
    exit 1
fi
echo "all tests passed"
