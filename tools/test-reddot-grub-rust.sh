#!/bin/sh
# Compare Rust GRUB dry actions with installer/grub_theme.py.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
source="$repo/configs"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/reddot-grub"
rustc --edition=2021 -O "$here/reddot-grub.rs" -o "$bin"
for root in sudo doas; do
    PYTHONPATH="$repo/installer" ROOT="$root" python3 - "$source" "$root" <<'PY' > "$tmp/python.json"
import json, sys
import distro, grub_theme
distro.ROOT = sys.argv[2]
out = [{"desc": d, "cmd": c} for d, c in grub_theme._plan(sys.argv[1])]
print(json.dumps(out, sort_keys=True))
PY
    "$bin" plan --source "$source" --root "$root" > "$tmp/rust.json"
    jq -S . "$tmp/python.json" > "$tmp/p"
    jq -S . "$tmp/rust.json" > "$tmp/r"
    diff -u "$tmp/p" "$tmp/r"
    echo "ok - grub dry plan parity ($root)"
done
echo 'all Rust grub tests passed'
