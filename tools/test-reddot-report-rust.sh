#!/bin/sh
# Compare summary lines with reddot_install._summary_lines.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/reddot-report"
rustc --edition=2021 -O "$here/reddot-report.rs" -o "$bin"
printf '%s\n' '{"native":["a","b"],"aur":["c"],"fallbacks":[["x","ghostty"]],"skipped":["d"],"repos":["copr:x"],"manual":[],"atomRepos":{}}' > "$tmp/plan.json"
PYTHONPATH="$repo/installer" python3 - "$tmp/plan.json" > "$tmp/python.txt" <<'PY'
import json, sys
import reddot_install as ri
p = json.load(open(sys.argv[1]))
p["fallbacks"] = [tuple(x) + ({},) for x in p["fallbacks"]]
info = {"family":"arch","existing":{},"init":"systemd"}
choices = {"sddm":False,"grub":False,"brave":False,"fish":True}
print("\n".join(ri._summary_lines(info, choices, p, None, True)))
PY
"$bin" --plan "$tmp/plan.json" --family arch > "$tmp/rust.txt"
diff -u "$tmp/python.txt" "$tmp/rust.txt"
echo 'ok - summary parity'
"$bin" --plan "$tmp/plan.json" --family gentoo --no-deps --sddm --grub --brave --no-fish > "$tmp/rust2.txt"
grep -q 'Skipping packages' "$tmp/rust2.txt"
grep -q 'SDDM' "$tmp/rust2.txt"
grep -q 'GRUB' "$tmp/rust2.txt"
echo 'ok - summary flags'
echo 'all Rust report tests passed'
