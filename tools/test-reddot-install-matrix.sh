#!/bin/sh
# Five-family orchestration dry-run. No package manager executes.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sh "$here/build-rust.sh" "$tmp/bin" >/dev/null
for family in arch debian fedora suse gentoo; do
    mkdir -p "$tmp/home-$family" "$tmp/config-$family"
    HOME="$tmp/home-$family" XDG_CONFIG_HOME="$tmp/home-$family/.config" XDG_STATE_HOME="$tmp/home-$family/.local/state" XDG_DATA_HOME="$tmp/home-$family/.local/share" \
        "$tmp/bin/reddot-install" --quickstart --dry-run --family "$family" --source "$repo/configs" --config-root "$tmp/config-$family" --bin-dir "$tmp/bin" > "$tmp/out-$family" 2>&1
    grep -q "quickstart dry-run complete" "$tmp/out-$family"
    grep -q "Dry run complete" "$tmp/out-$family"
    echo "ok - $family quickstart dry-run"
done
echo 'all family dry-run tests passed'
