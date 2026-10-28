#!/bin/sh
# Parity between installer/distro.py and tools/reddot-distro.rs.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/reddot-distro"
rustc --edition=2021 -O "$here/reddot-distro.rs" -o "$bin"
manifest="$repo/installer/packages.json"

for family in arch debian fedora suse gentoo; do
    PYTHONPATH="$repo/installer" python3 - "$manifest" "$family" <<'PY' > "$tmp/python.json"
import json, sys
import distro
manifest = distro.load_manifest(sys.argv[1])
print(json.dumps(distro.plan(manifest, sys.argv[2], groups=("core",)), sort_keys=True))
PY
    "$bin" plan --manifest "$manifest" --family "$family" > "$tmp/rust.json"
    if ! jq -S . "$tmp/python.json" > "$tmp/python.sorted" || ! jq -S . "$tmp/rust.json" > "$tmp/rust.sorted"; then
        echo "FAIL: invalid JSON for $family" >&2
        exit 1
    fi
    if ! diff -u "$tmp/python.sorted" "$tmp/rust.sorted"; then
        echo "FAIL: plan parity for $family" >&2
        exit 1
    fi
    echo "ok - $family core plan parity"
done

cat > "$tmp/os-release" <<'OSR'
NAME="CachyOS Linux"
ID=cachyos
ID_LIKE=arch
PRETTY_NAME="CachyOS Linux"
OSR
detect=$("$bin" detect --os-release "$tmp/os-release")
printf '%s\n' "$detect" | jq -e '.family == "arch" and .pretty == "CachyOS Linux"' >/dev/null
echo 'ok - os-release family detection'

for aur in yay none; do
    "$bin" plan --manifest "$manifest" --family arch --aur "$aur" > "$tmp/rust-$aur.json"
    PYTHONPATH="$repo/installer" python3 - "$manifest" "$aur" <<'PY' > "$tmp/python-$aur.json"
import json, sys
import distro
manifest = distro.load_manifest(sys.argv[1])
print(json.dumps(distro.plan(manifest, "arch", groups=("core",), aur_choice=sys.argv[2]), sort_keys=True))
PY
    jq -S . "$tmp/rust-$aur.json" > "$tmp/r.sorted"
    jq -S . "$tmp/python-$aur.json" > "$tmp/p.sorted"
    diff -u "$tmp/p.sorted" "$tmp/r.sorted"
    echo "ok - arch aur=$aur parity"
done

echo 'all Rust distro tests passed'
