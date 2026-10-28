#!/bin/sh
# Compare Rust and Python neutralization in isolated config roots and HOME.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
deploy_bin="$tmp/reddot-deploy"
neutral_bin="$tmp/reddot-neutralize"
rustc --edition=2021 -O "$here/reddot-deploy.rs" -o "$deploy_bin"
rustc --edition=2021 -O "$here/reddot-neutralize.rs" -o "$neutral_bin"
src="$repo/configs"
home_py="$tmp/home-py"; home_rs="$tmp/home-rs"; root_py="$tmp/py"; root_rs="$tmp/rs"
mkdir -p "$home_py" "$home_rs" "$root_py" "$root_rs"

PYTHONPATH="$repo/installer" HOME="$home_py" python3 - "$src" "$root_py" >/dev/null <<'PY'
import deploy, sys
deploy.deploy(sys.argv[1], sys.argv[2], apply=True)
PY
"$deploy_bin" deploy --src "$src" --config-root "$root_rs" --apply >/dev/null

PYTHONPATH="$repo/installer" HOME="$home_py" python3 - "$src" "$root_py" > "$tmp/py-plan.json" <<'PY'
import json, sys
import deploy
print(json.dumps(deploy.neutralize(sys.argv[2], apply=False, src=sys.argv[1]), sort_keys=True))
PY
HOME="$home_rs" "$neutral_bin" --src "$src" --config-root "$root_rs" > "$tmp/rs-plan.json"
jq -S . "$tmp/py-plan.json" > "$tmp/p"; jq -S . "$tmp/rs-plan.json" > "$tmp/r"
sed "s|$root_py|ROOT|g;s|$home_py|HOME|g" "$tmp/p" > "$tmp/pn"
sed "s|$root_rs|ROOT|g;s|$home_rs|HOME|g" "$tmp/r" > "$tmp/rn"
diff -u "$tmp/pn" "$tmp/rn"
echo 'ok - neutralize plan parity'

PYTHONPATH="$repo/installer" HOME="$home_py" python3 - "$src" "$root_py" >/dev/null <<'PY'
import deploy, sys
deploy.neutralize(sys.argv[2], apply=True, src=sys.argv[1])
PY
HOME="$home_rs" "$neutral_bin" --src "$src" --config-root "$root_rs" --apply >/dev/null
(cd "$root_py" && find . -type f | sort) > "$tmp/py-files"
(cd "$root_rs" && find . -type f | sort) > "$tmp/rs-files"
diff -u "$tmp/py-files" "$tmp/rs-files"
while IFS= read -r file; do
    [ -f "$root_py/$file" ] || continue
    sed "s|$root_py|ROOT|g;s|$home_py|HOME|g" "$root_py/$file" > "$tmp/a"
    sed "s|$root_rs|ROOT|g;s|$home_rs|HOME|g" "$root_rs/$file" > "$tmp/b"
    cmp -s "$tmp/a" "$tmp/b" || { echo "FAIL: content differs: $file" >&2; exit 1; }
done < "$tmp/py-files"
echo 'ok - neutralize applied tree matches'
echo 'all Rust neutralize tests passed'
