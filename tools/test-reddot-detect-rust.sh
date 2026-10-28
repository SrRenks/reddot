#!/bin/sh
# Compare the Rust detection record with the Python helpers on this host.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/reddot-detect"
rustc --edition=2021 -O "$here/reddot-detect.rs" -o "$bin"
PYTHONPATH="$repo/installer" python3 - > "$tmp/python.json" <<'PY'
import json
import distro, pkg
import reddot_install as ri
print(json.dumps({
    "family": distro.detect_family(),
    "pretty": distro.detect_pretty(),
    "pm": distro.PM.get(distro.detect_family(), "Unknown"),
    "compositor": ri._compositor(),
    "bootloader": ri._bootloader(),
    "hasDisplayManager": ri._has_display_manager(),
    "rootCmd": ri._root_cmd(),
    "init": distro.detect_init(),
    "immutable": distro.is_immutable(),
    "aurHelper": pkg.aur_helper(),
}, sort_keys=True))
PY
"$bin" > "$tmp/rust.json"
jq -S . "$tmp/python.json" > "$tmp/p"; jq -S . "$tmp/rust.json" > "$tmp/r"
# networkdOrIwd is an extra Rust field; drop it for the shared record.
jq 'del(.networkdOrIwd)' "$tmp/r" > "$tmp/rr"
diff -u "$tmp/p" "$tmp/rr"
echo 'ok - detection parity'
echo 'all Rust detect tests passed'
