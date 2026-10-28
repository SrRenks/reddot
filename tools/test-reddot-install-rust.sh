#!/bin/sh
# Quickstart dry-run integration for the Rust entry point and its binaries.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sh "$here/build-rust.sh" "$tmp/bin" >/dev/null
mkdir -p "$tmp/config"
out=$("$tmp/bin/reddot-install" --quickstart --dry-run --source "$repo/configs" --config-root "$tmp/config" --bin-dir "$tmp/bin" 2>&1)
printf '%s\n' "$out" | grep -q 'reddot-install: family='
printf '%s\n' "$out" | grep -q 'would run:'
printf '%s\n' "$out" | grep -q 'quickstart dry-run complete'
printf '%s\n' "$out" | grep -q 'would deploy' || printf '%s\n' "$out" | grep -q '"action":"deploy"'
echo 'ok - Rust quickstart dry-run integration'
# Managed no-deps quickstart then Rust uninstall, in an isolated HOME/config root.
mkdir -p "$tmp/apply-home" "$tmp/apply-config"
HOME="$tmp/apply-home" XDG_CONFIG_HOME="$tmp/apply-home/.config" XDG_STATE_HOME="$tmp/apply-home/.local/state" XDG_DATA_HOME="$tmp/apply-home/.local/share" \
    "$tmp/bin/reddot-install" --quickstart --no-deps --apply --source "$repo/configs" --config-root "$tmp/apply-config" --bin-dir "$tmp/bin" >/dev/null
[ -f "$tmp/apply-config/hypr/.reddot-managed" ]
HOME="$tmp/apply-home" XDG_CONFIG_HOME="$tmp/apply-home/.config" \
    "$tmp/bin/reddot-install" --uninstall --apply --config-root "$tmp/apply-config" --bin-dir "$tmp/bin" >/dev/null
[ ! -e "$tmp/apply-config/hypr" ]
echo 'ok - Rust quickstart apply and uninstall'
echo 'all Rust installer tests passed'
