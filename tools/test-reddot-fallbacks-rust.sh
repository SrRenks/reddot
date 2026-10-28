#!/bin/sh
# Compare Rust fallback steps with installer/fallbacks.py. No build runs.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/reddot-fallbacks"
rustc --edition=2021 -O "$here/reddot-fallbacks.rs" -o "$bin"

for family in arch debian fedora suse gentoo; do
    PYTHONPATH="$repo/installer" python3 - "$repo/installer/packages.json" "$family" <<'PY' > "$tmp/python.json"
import json, sys
import fallbacks
m = json.load(open(sys.argv[1]))
out = {}
for pkg in m["packages"]:
    fb = pkg.get("fallback")
    if not fb:
        continue
    out[pkg["id"]] = fallbacks.steps_for(fb, pkg, sys.argv[2])
print(json.dumps(out, sort_keys=True))
PY
    {
        printf '{'
        first=1
        for id in $(jq -r '.packages[] | select(.fallback != null) | .id' "$repo/installer/packages.json"); do
            fb=$(jq -r --arg id "$id" '.packages[] | select(.id == $id) | .fallback' "$repo/installer/packages.json")
            app=$(jq -r --arg id "$id" '.packages[] | select(.id == $id) | .flatpak_id // ""' "$repo/installer/packages.json")
            [ "$first" -eq 0 ] && printf ','
            first=0
            printf '"%s":' "$id"
            "$bin" steps --fallback "$fb" --id "$id" --family "$family" --app "$app"
        done
        printf '}\n'
    } > "$tmp/rust.json"
    jq -S . "$tmp/python.json" > "$tmp/p.sorted"
    jq -S . "$tmp/rust.json" > "$tmp/r.sorted"
    if ! diff -u "$tmp/p.sorted" "$tmp/r.sorted"; then
        echo "FAIL: fallback parity for $family" >&2
        exit 1
    fi
    echo "ok - $family fallback parity"
done

# Unknown handler stays empty.
empty=$("$bin" steps --fallback nope --id x --family debian)
[ "$empty" = '[]' ]
echo 'ok - unknown fallback is empty'

# The root wrapper follows --root.
doas=$("$bin" steps --fallback dotool --id dotool --family gentoo --root doas)
printf '%s\n' "$doas" | jq -e '.[0].run[0] == "doas"' >/dev/null
echo 'ok - root wrapper follows the wizard choice'
echo 'all Rust fallback tests passed'
