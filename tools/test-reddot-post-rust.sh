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
echo 'all Rust post tests passed'
