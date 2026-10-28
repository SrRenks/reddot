#!/bin/sh
# Compare Rust _build_plan with Python for quick/full, AUR and overlay choices.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/reddot-plan"
rustc --edition=2021 -O "$here/reddot-plan.rs" -o "$bin"
manifest="$repo/installer/packages.json"

for profile in quick full; do
    if [ "$profile" = full ]; then
        optional=$(jq -r '[.packages[] | select(.group=="full") | .id] | join(",")' "$manifest")
    else
        optional=""
    fi
    PYTHONPATH="$repo/installer" python3 - "$manifest" "$profile" "$optional" > "$tmp/python.json" <<'PY'
import json, sys
import distro, reddot_install as ri
m = distro.load_manifest(sys.argv[1])
family = distro.detect_family()
optional = set(filter(None, sys.argv[3].split(",")))
choices = {
    "profile": sys.argv[2], "aur_choice": "yay", "optional_ids": optional,
    "sddm": False, "grub": False, "fish": True, "brave": False,
    "root_cmd": "sudo", "overlays": True, "services": True,
}
p = ri._build_plan(m, {"family": family}, choices)
p["fallbacks"] = [[x[0], x[1]] for x in p["fallbacks"]]
p["optional_native"] = sorted(p["optional_native"])
print(json.dumps(p, sort_keys=True))
PY
    "$bin" --manifest "$manifest" --family "$(uname -s >/dev/null; PYTHONPATH="$repo/installer" python3 -c 'import distro; print(distro.detect_family())')" --profile "$profile" --optional "$optional" > "$tmp/rust.json"
    jq -S . "$tmp/python.json" > "$tmp/p"
    jq -S '.optional_native as $o | del(.optionalNative) | . + {optional_native:$o} | .fallbacks = [.fallbacks[]]' "$tmp/rust.json" > "$tmp/r"
    # Normalize Rust's camelCase field only; values should match.
    jq -S 'del(.optionalNative,.atomRepos) + {optional_native:(.optionalNative), atom_repos:(.atomRepos)}' "$tmp/rust.json" > "$tmp/r2"
    diff -u "$tmp/p" "$tmp/r2" || { echo "FAIL: plan parity $profile" >&2; exit 1; }
    echo "ok - $profile plan parity"
done

PYTHONPATH="$repo/installer" python3 - "$manifest" > "$tmp/python-none.json" <<'PY'
import json, sys
import distro, reddot_install as ri
m = distro.load_manifest(sys.argv[1])
p = ri._build_plan(m, {"family": "arch"}, {"profile":"quick","aur_choice":"none","optional_ids":set(),"sddm":False,"grub":False,"fish":True,"brave":False,"root_cmd":"sudo","overlays":True,"services":True})
p["fallbacks"] = [[x[0],x[1]] for x in p["fallbacks"]]
p["optional_native"] = sorted(p["optional_native"])
print(json.dumps(p, sort_keys=True))
PY
"$bin" --manifest "$manifest" --family arch --profile quick --aur none > "$tmp/rust-none.json"
jq -S . "$tmp/python-none.json" > "$tmp/pn"
jq -S 'del(.optionalNative,.atomRepos) + {optional_native:(.optionalNative), atom_repos:(.atomRepos)}' "$tmp/rust-none.json" > "$tmp/rn"
diff -u "$tmp/pn" "$tmp/rn" || { echo 'FAIL: aur none parity' >&2; exit 1; }
echo 'ok - AUR none parity'

PYTHONPATH="$repo/installer" python3 - "$manifest" > "$tmp/python-ov.json" <<'PY'
import json, sys
import distro, reddot_install as ri
m = distro.load_manifest(sys.argv[1])
p = ri._build_plan(m, {"family": "gentoo"}, {"profile":"quick","aur_choice":"yay","optional_ids":set(),"sddm":False,"grub":False,"fish":True,"brave":False,"root_cmd":"sudo","overlays":False,"services":True})
p["fallbacks"] = [[x[0],x[1]] for x in p["fallbacks"]]
p["optional_native"] = sorted(p["optional_native"])
print(json.dumps(p, sort_keys=True))
PY
"$bin" --manifest "$manifest" --family gentoo --profile quick --no-overlays > "$tmp/rust-ov.json"
jq -S . "$tmp/python-ov.json" > "$tmp/po"
jq -S 'del(.optionalNative,.atomRepos) + {optional_native:(.optionalNative), atom_repos:(.atomRepos)}' "$tmp/rust-ov.json" > "$tmp/ro"
diff -u "$tmp/po" "$tmp/ro" || { echo 'FAIL: overlay skip parity' >&2; exit 1; }
echo 'ok - overlay skip parity'
echo 'all Rust plan tests passed'
