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
echo 'all Rust installer tests passed'
