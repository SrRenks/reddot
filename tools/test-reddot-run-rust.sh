#!/bin/sh
# Dry-run ordering for the Rust package runner.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/reddot-run"
rustc --edition=2021 -O "$here/reddot-run.rs" -o "$bin"
printf '%s\n' '{"repos":[],"native":["foo","bar"],"aur":["baz"]}' > "$tmp/plan.json"
"$bin" --plan "$tmp/plan.json" --family arch --root doas --aur-helper paru --dry-run > "$tmp/out"
cat > "$tmp/expected" <<'EXP'
  would run: doas pacman -Syu --noconfirm
  would run: doas pacman -S --needed --noconfirm foo bar
  would run: paru -S --needed --noconfirm baz
EXP
diff -u "$tmp/expected" "$tmp/out"
echo 'ok - package runner order'
echo 'all Rust runner tests passed'
