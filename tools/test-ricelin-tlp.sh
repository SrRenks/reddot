#!/bin/sh
#
# Tests for ricelin-tlp. No root, no battery, no TLP: a fake sysfs tree and
# fake tlp/tlp-stat/systemctl/powerprofilesctl scripts stand in for the host.
#
#   sh test-ricelin-tlp.sh

set -eu

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
helper="$here/ricelin-tlp"
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
    RICELIN_TLP_SYSFS="$tmp/sys" \
    RICELIN_TLP_CONF="$tmp/tlp.d/99-ricelin.conf" \
    RICELIN_TLP_TEST=1 \
    sh "$helper" "$@"
}

# --- status ---------------------------------------------------------------
out=$(run status)
assert_contains "$out" '^TOOL=tlp$' "status detects TLP"
assert_contains "$out" '^ENABLED=1$' "status reports the service active"
assert_contains "$out" '^POWER=AC$' "status reads AC from sysfs"
assert_contains "$out" '^PROFILE=performance$' "status strips the /AC suffix"
assert_contains "$out" '^BATTERY=BAT0|40|80|43|auto|1|1$' "BAT0 charge window and behaviour"
assert_contains "$out" '^BATTERY=BAT1|0|100|43|auto|1|1$' "BAT1 legacy *_threshold names"

# --- set (TLP path, persisted, merged) ------------------------------------
run set BAT0 45 85
assert_contains "$(cat "$tmp/tlp.d/99-ricelin.conf")" 'START_CHARGE_THRESH_BAT0=45' "set writes the BAT0 start key"
assert_contains "$(cat "$tmp/tlp.d/99-ricelin.conf")" 'STOP_CHARGE_THRESH_BAT0=85' "set writes the BAT0 stop key"
assert_contains "$(cat "$tmp/tlp.log")" 'setcharge 45 85 BAT0' "set calls tlp setcharge"

run set BAT1 50 90
conf=$(cat "$tmp/tlp.d/99-ricelin.conf")
assert_contains "$conf" 'START_CHARGE_THRESH_BAT0=45' "second set keeps BAT0 start"
assert_contains "$conf" 'START_CHARGE_THRESH_BAT1=50' "second set adds BAT1 start"
assert_contains "$conf" 'STOP_CHARGE_THRESH_BAT1=90' "second set adds BAT1 stop"

# --- apply (profile + all battery windows, one command) -------------------
run apply balanced 95 100
conf=$(cat "$tmp/tlp.d/99-ricelin.conf")
assert_contains "$conf" 'START_CHARGE_THRESH_BAT0=95' "apply writes BAT0 start"
assert_contains "$conf" 'STOP_CHARGE_THRESH_BAT0=100' "apply writes BAT0 stop"
assert_contains "$conf" 'START_CHARGE_THRESH_BAT1=95' "apply writes BAT1 start"
assert_contains "$conf" 'STOP_CHARGE_THRESH_BAT1=100' "apply writes BAT1 stop"
assert_contains "$(cat "$tmp/tlp.log")" 'setcharge 95 100 BAT0' "apply sets BAT0"
assert_contains "$(cat "$tmp/tlp.log")" 'setcharge 95 100 BAT1' "apply sets BAT1"
assert_contains "$(cat "$tmp/tlp.log")" '^balanced$' "apply switches the TLP profile"

# --- validation -----------------------------------------------------------
assert_exit 2 "rejects start >= stop" run set BAT0 90 80
assert_exit 2 "rejects a non-numeric start" run set BAT0 abc 80
assert_exit 2 "rejects an unknown battery" run set BAT9 40 80
assert_exit 2 "rejects a path as a battery" run set ../etc 40 80
assert_exit 2 "rejects an unknown profile" run profile turbo
assert_exit 2 "rejects an invalid apply window" run apply balanced 90 80
assert_exit 2 "rejects an invalid apply profile" run apply turbo 50 80

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

out=$(PATH="$pbin" RICELIN_TLP_SYSFS="$tmp/sys" RICELIN_TLP_CONF="$tmp/ppd.conf" RICELIN_TLP_TEST=1 /bin/sh "$helper" status)
assert_contains "$out" '^TOOL=ppd$' "status falls back to power-profiles-daemon"
assert_contains "$out" '^PROFILE=balanced$' "PPD profile is read"

PATH="$pbin" RICELIN_TLP_SYSFS="$tmp/sys" RICELIN_TLP_CONF="$tmp/ppd.conf" RICELIN_TLP_TEST=1 /bin/sh "$helper" profile power-saver
assert_contains "$(cat "$tmp/ppd.log")" 'set power-saver' "profile falls back to powerprofilesctl set"

# --- sysfs-only set (no TLP, no PPD) --------------------------------------
mkdir -p "$tmp/plain"
for tool in cat awk grep cut tr id dirname mkdir mv rm printf; do
    path=$(command -v "$tool" || true)
    [ -n "$path" ] && ln -sf "$path" "$tmp/plain/$tool"
done
PATH="$tmp/plain" RICELIN_TLP_SYSFS="$tmp/sys" RICELIN_TLP_CONF="$tmp/plain.conf" RICELIN_TLP_TEST=1 /bin/sh "$helper" set BAT0 55 88
assert_contains "$(cat "$tmp/sys/BAT0/charge_start_threshold" 2>/dev/null || cat "$tmp/sys/BAT0/charge_control_start_threshold")" '55' "sysfs-only set writes the start threshold"
assert_contains "$(cat "$tmp/sys/BAT0/charge_control_end_threshold")" '88' "sysfs-only set writes the stop threshold"

# --- no batteries ---------------------------------------------------------
mkdir -p "$tmp/empty"
out=$(RICELIN_TLP_SYSFS="$tmp/empty" RICELIN_TLP_CONF="$tmp/none.conf" RICELIN_TLP_TEST=1 PATH="$tmp/bin:$PATH" sh "$helper" status)
assert_missing "$out" 'BATTERY=' "a desktop with no battery reports none"

if [ "$fails" -ne 0 ]; then
    echo "$fails test(s) failed" >&2
    exit 1
fi
echo "all tests passed"
