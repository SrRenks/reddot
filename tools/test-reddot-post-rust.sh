#!/bin/sh
# Effects parity for the Rust post-install helpers.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/reddot-post"
rustc --edition=2021 -O "$here/reddot-post.rs" -o "$bin"
starters="$repo/installer/starter-wallpapers"
py_home="$tmp/pyhome"; rs_home="$tmp/rshome"; mkdir -p "$py_home" "$rs_home" "$tmp/bin"
cat > "$tmp/bin/swww" <<'SH'
#!/bin/sh
exit 0
SH
cat > "$tmp/bin/swww-daemon" <<'SH'
#!/bin/sh
exit 0
SH
cat > "$tmp/bin/brave" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$tmp/bin/swww" "$tmp/bin/swww-daemon" "$tmp/bin/brave"

PYTHONPATH="$repo/installer" HOME="$py_home" XDG_STATE_HOME="$py_home/.local/state" PATH="$tmp/bin:/usr/bin:/bin" python3 - "$starters" >/dev/null <<'PY'
import sys
import reddot_install as ri
ri.seed_wallpapers(False)
ri.seed_app_theme(False)
ri.bridge_wallpaper_binary(False)
ri.seed_brave_gtk(False)
PY
HOME="$rs_home" XDG_STATE_HOME="$rs_home/.local/state" PATH="$tmp/bin:/usr/bin:/bin" "$bin" wallpapers --starters "$starters" >/dev/null
HOME="$rs_home" XDG_STATE_HOME="$rs_home/.local/state" PATH="$tmp/bin:/usr/bin:/bin" "$bin" app-theme >/dev/null
HOME="$rs_home" XDG_STATE_HOME="$rs_home/.local/state" PATH="$tmp/bin:/usr/bin:/bin" "$bin" bridge >/dev/null
HOME="$rs_home" XDG_STATE_HOME="$rs_home/.local/state" PATH="$tmp/bin:/usr/bin:/bin" "$bin" brave >/dev/null
[ -f "$py_home/.local/state/reddot/flags.json" ] && [ -f "$rs_home/.local/state/reddot/flags.json" ]
jq -e '.appTheme == true' "$rs_home/.local/state/reddot/flags.json" >/dev/null
(cd "$py_home/reddot/wallpapers" && find . -type f | sort) > "$tmp/py-wp"
(cd "$rs_home/reddot/wallpapers" && find . -type f | sort) > "$tmp/rs-wp"
diff -u "$tmp/py-wp" "$tmp/rs-wp"
[ -L "$py_home/.local/bin/awww" ] && [ -L "$rs_home/.local/bin/awww" ]
[ -f "$rs_home/.config/BraveSoftware/Brave-Browser/Default/Preferences" ]
echo 'ok - wallpapers, app theme, bridge and Brave effects'

# Baseline: both implementations call the engine with the checked-out HEAD.
py_root="$tmp/py-baseline"; rs_root="$tmp/rs-baseline"
mkdir -p "$py_root/hypr/scripts" "$rs_root/hypr/scripts"
cat > "$py_root/hypr/scripts/reddot-update.py" <<'PY'
import os, pathlib, sys
pathlib.Path(os.environ["BASELINE_LOG"]).write_text(" ".join(sys.argv[1:]))
PY
cat > "$rs_root/hypr/scripts/reddot-update" <<'SH'
#!/bin/sh
printf '%s' "$*" > "${BASELINE_LOG:?}"
SH
chmod +x "$rs_root/hypr/scripts/reddot-update"
HEAD=$(git -C "$repo" rev-parse HEAD)
BASELINE_LOG="$tmp/py-baseline.log" PYTHONPATH="$repo/installer" HOME="$py_home" python3 - "$repo/configs" "$py_root" >/dev/null <<'PY'
import sys
import reddot_install as ri
ok, detail = ri._seed_update_baseline(sys.argv[1], sys.argv[2], False)
assert ok, detail
PY
BASELINE_LOG="$tmp/rs-baseline.log" HOME="$rs_home" "$bin" baseline --source "$repo/configs" --config-root "$rs_root" --updater "$rs_root/hypr/scripts/reddot-update" >/dev/null
grep -q "baseline --sha $HEAD --config-root $py_root" "$tmp/py-baseline.log"
grep -q "baseline --sha $HEAD --config-root $rs_root" "$tmp/rs-baseline.log"
echo 'ok - update baseline handoff'
echo 'all Rust post tests passed'
