#!/bin/sh
# Integration parity for the Rust updater. Builds the binary, drives real git
# repos in a temp dir, and checks the JSON contract, merge classes and baseline.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/reddot-update"
rustc --edition=2021 -O "$here/reddot-update.rs" -o "$bin"
origin="$tmp/origin"
config="$tmp/config"
mkdir -p "$origin/configs/hypr/modules" "$origin/configs/quickshell/pill" "$origin/installer" \
         "$config/hypr/modules" "$config/quickshell/pill"

git -C "$origin" init -q -b e14g7
git -C "$origin" config user.name t
git -C "$origin" config user.email t@t
write() { mkdir -p "$(dirname "$1")"; printf '%s' "$2" > "$1"; }
export XDG_DATA_HOME="$tmp/data" XDG_STATE_HOME="$tmp/state"

write "$origin/configs/hypr/modules/binds.lua" 'bind one
spacer
spacer
bind two
spacer
spacer
bind three
'
write "$origin/configs/hypr/modules/monitors.lua" 'monitor A
monitor B
'
write "$origin/configs/hypr/hypridle.conf" 'on-timeout = hyprctl dispatch dpms off
'
write "$origin/configs/quickshell/pill/Look.qml" 'code v1
'
write "$origin/configs/hypr/scripts/tool.sh" '#!/bin/sh
echo tool
'
write "$origin/configs/hypr/scripts/test_tool.py" 'not deployed
'
write "$origin/installer/packages.json" '{"packages":[]}
'
git -C "$origin" add -A
git -C "$origin" commit -qm init

write "$origin/configs/hypr/modules/binds.lua" 'bind one
spacer
spacer
bind two upstream
spacer
spacer
bind three
'
write "$origin/configs/hypr/modules/monitors.lua" 'monitor A
monitor B
monitor C upstream
'
write "$origin/configs/quickshell/pill/Look.qml" 'code v2
'
git -C "$origin" add -A
git -C "$origin" commit -qm 'config bump

changelog: new monitor preset'

write "$config/hypr/modules/binds.lua" 'bind one
spacer
spacer
bind two
spacer
spacer
bind three
'
write "$config/hypr/modules/monitors.lua" 'monitor A
monitor B
'
write "$config/hypr/hypridle.conf" 'on-timeout = hyprctl dispatch dpms off
'
write "$config/quickshell/pill/Look.qml" 'stale
'

first=$("$bin" apply --remote "$origin" --config-root "$config")
printf '%s\n' "$first" | jq -e '.status == "ok" and .applied == true' >/dev/null
[ "$(cat "$config/quickshell/pill/Look.qml")" = 'code v2' ]
[ "$(cat "$config/hypr/hypridle.conf")" = 'on-timeout = hyprctl dispatch "hl.dsp.dpms({ action = '"'"'off'"'"' })"' ]
[ -x "$config/hypr/scripts/tool.sh" ]
[ ! -e "$config/hypr/scripts/test_tool.py" ]
[ ! -e "$config/sddm" ]
jq -e '.syncedSha != null' "$XDG_STATE_HOME/reddot/update.json" >/dev/null
echo 'ok - first run baseline, code copy, filters, hypridle migration'

base=$(jq -r .syncedSha "$XDG_STATE_HOME/reddot/update.json")
git -C "$origin" show "$base:configs/hypr/modules/binds.lua" > "$config/hypr/modules/binds.lua"
git -C "$origin" show "$base:configs/hypr/modules/monitors.lua" > "$config/hypr/modules/monitors.lua"
write "$config/hypr/modules/binds.lua" 'bind one local
spacer
spacer
bind two upstream
spacer
spacer
bind three
'
write "$config/hypr/modules/monitors.lua" 'monitor A
monitor B local
monitor C upstream
'
write "$origin/configs/hypr/modules/binds.lua" 'bind one
spacer
spacer
bind two upstream 2
spacer
spacer
bind three
'
write "$origin/configs/hypr/modules/monitors.lua" 'monitor A
monitor B
monitor C upstream
monitor D upstream
'
git -C "$origin" add -A
git -C "$origin" commit -qm 'second bump'
check=$("$bin" check --remote "$origin" --config-root "$config")
printf '%s\n' "$check" | jq -e '.behind == 1 and ([.modules[] | select(.state == "merged")] | length) == 2' >/dev/null
apply=$("$bin" apply --remote "$origin" --config-root "$config")
printf '%s\n' "$apply" | jq -e '.status == "ok" and .applied == true' >/dev/null
grep -q 'bind one local' "$config/hypr/modules/binds.lua"
grep -q 'bind two upstream 2' "$config/hypr/modules/binds.lua"
grep -q 'monitor C upstream' "$config/hypr/modules/monitors.lua"
echo 'ok - non-overlapping local/upstream edits merge'

# Reset only the binds base so the local and upstream changes overlap.
jq --arg b "$base" '.syncedSha=$b | .modules["hypr/modules/binds.lua"]=$b' \
    "$XDG_STATE_HOME/reddot/update.json" > "$tmp/manifest.json"
mv "$tmp/manifest.json" "$XDG_STATE_HOME/reddot/update.json"
git -C "$origin" show "$base:configs/hypr/modules/binds.lua" > "$config/hypr/modules/binds.lua"
write "$config/hypr/modules/binds.lua" 'bind one
spacer
spacer
bind two mine
spacer
spacer
bind three
'
before=$(cat "$config/hypr/modules/binds.lua")
conf=$("$bin" apply --remote "$origin" --config-root "$config")
printf '%s\n' "$conf" | jq -e '.status == "ok" and ([.modules[] | select(.state == "conflict")] | length) == 1' >/dev/null
[ "$(cat "$config/hypr/modules/binds.lua")" = "$before" ]
echo 'ok - overlapping edit stays a conflict and leaves the live file'

take=$("$bin" apply --remote "$origin" --config-root "$config" --take hypr/modules/binds.lua)
printf '%s\n' "$take" | jq -e '.status == "ok" and .applied == true' >/dev/null
grep -q 'bind two upstream 2' "$config/hypr/modules/binds.lua"
echo 'ok - --take resolves the conflict'

# Corrupt manifest and missing flag value must stay one JSON object, exit 0.
printf '{ broken\n' > "$XDG_STATE_HOME/reddot/update.json"
corrupt=$("$bin" check --remote "$origin" --config-root "$config")
printf '%s\n' "$corrupt" | jq -e '.status == "error" and (.error | test("manifest"))' >/dev/null
bad=$("$bin" check --config-root "$config" --remote)
printf '%s\n' "$bad" | jq -e '.status == "error" and .behind == 0' >/dev/null
echo 'ok - corrupt manifest and bad flags stay JSON errors'
echo 'all Rust updater tests passed'
