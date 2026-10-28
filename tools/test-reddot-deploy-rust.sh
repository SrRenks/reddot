#!/bin/sh
# Compare Rust deploy plan/apply/uninstall with installer/deploy.py in temp roots.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/reddot-deploy"
rustc --edition=2021 -O "$here/reddot-deploy.rs" -o "$bin"
src="$repo/configs"
root_py="$tmp/py-config"; root_rs="$tmp/rs-config"; mkdir -p "$root_py" "$root_rs"

PYTHONPATH="$repo/installer" python3 - "$src" "$root_py" > "$tmp/py-plan.json" <<'PY'
import json, sys
import deploy
print(json.dumps(deploy.deploy(sys.argv[1], sys.argv[2], apply=False), sort_keys=True))
PY
"$bin" deploy --src "$src" --config-root "$root_rs" > "$tmp/rs-plan.json"
jq -S . "$tmp/py-plan.json" > "$tmp/p"; jq -S . "$tmp/rs-plan.json" > "$tmp/r"
sed "s|$root_py|ROOT|g" "$tmp/p" > "$tmp/pn"; sed "s|$root_rs|ROOT|g" "$tmp/r" > "$tmp/rn"
if ! diff -u "$tmp/pn" "$tmp/rn"; then echo 'FAIL: deploy plan parity' >&2; exit 1; fi
echo 'ok - deploy plan parity'

PYTHONPATH="$repo/installer" python3 - "$src" "$root_py" >/dev/null <<'PY'
import deploy, sys
deploy.deploy(sys.argv[1], sys.argv[2], apply=True)
PY
"$bin" deploy --src "$src" --config-root "$root_rs" --apply >/dev/null
# Compare all relative file names and contents. Markers are empty files.
(cd "$root_py" && find . -type f -o -type l | sort) > "$tmp/py-files"
(cd "$root_rs" && find . -type f -o -type l | sort) > "$tmp/rs-files"
diff -u "$tmp/py-files" "$tmp/rs-files"
while IFS= read -r file; do
    [ -f "$root_py/$file" ] || continue
    cmp -s "$root_py/$file" "$root_rs/$file" || { echo "FAIL: content differs: $file" >&2; exit 1; }
done < "$tmp/py-files"
echo 'ok - deployed tree contents match'

# A second deploy is a replace on both sides and keeps the same tree.
PYTHONPATH="$repo/installer" python3 - "$src" "$root_py" >/dev/null <<'PY'
import deploy, sys
deploy.deploy(sys.argv[1], sys.argv[2], apply=True)
PY
"$bin" deploy --src "$src" --config-root "$root_rs" --apply >/dev/null
echo 'ok - re-deploy is idempotent'

PYTHONPATH="$repo/installer" python3 - "$root_py" > "$tmp/py-uninstall.json" <<'PY'
import json, sys, deploy
print(json.dumps(deploy.uninstall(sys.argv[1], apply=False), sort_keys=True))
PY
"$bin" uninstall --config-root "$root_rs" > "$tmp/rs-uninstall.json"
jq -S . "$tmp/py-uninstall.json" > "$tmp/pu"; jq -S . "$tmp/rs-uninstall.json" > "$tmp/ru"
# Paths differ by root, normalize them before comparing.
sed "s|$root_py|ROOT|g" "$tmp/pu" > "$tmp/pun"; sed "s|$root_rs|ROOT|g" "$tmp/ru" > "$tmp/run"
diff -u "$tmp/pun" "$tmp/run"
echo 'ok - uninstall plan parity'

PYTHONPATH="$repo/installer" python3 - "$root_py" >/dev/null <<'PY'
import deploy, sys
deploy.uninstall(sys.argv[1], apply=True)
PY
"$bin" uninstall --config-root "$root_rs" --apply >/dev/null
(cd "$root_py" && find . -mindepth 1 | sort) > "$tmp/py-after"
(cd "$root_rs" && find . -mindepth 1 | sort) > "$tmp/rs-after"
diff -u "$tmp/py-after" "$tmp/rs-after"
echo 'ok - uninstall leaves the same tree'
echo 'all Rust deploy tests passed'
