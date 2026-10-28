#!/bin/sh
# Integration test for the Rust wallcolors binary in an isolated HOME.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/reddot-wallcolors"
rustc --edition=2021 -O "$here/reddot-wallcolors.rs" -o "$bin"
home="$tmp/home"
mkdir -p "$home/.config/fastfetch" "$home/.cache" "$home/.local/state" "$home/.local/share" "$tmp/bin"
printf 'x __KEYS__ __SEP__ __LANTERN__ __LOGO1__ __LOGO2__ __LOGO3__ __LOGO4__ __LOGO5__ __LOGO6__ __LOGO7__\n' > "$home/.config/fastfetch/config.jsonc.in"
export HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" XDG_STATE_HOME="$home/.local/state"
export GSETTINGS_STATE="$tmp/gsettings"

# Fake gsettings keeps the test away from the live desktop.
cat > "$tmp/bin/gsettings" <<'SH'
#!/bin/sh
set -eu
state="${GSETTINGS_STATE:?}"
if [ "$1" = get ]; then
    key=$3
    [ -f "$state/$key" ] && cat "$state/$key" || printf 'default\n'
else
    mkdir -p "$state"
    printf '%s\n' "$4" > "$state/$3"
fi
SH
cat > "$tmp/bin/flatpak" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "${FLATPAK_LOG:?}"
exit 0
SH
cat > "$tmp/bin/gdbus" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$tmp/bin/gsettings" "$tmp/bin/flatpak" "$tmp/bin/gdbus"
export PATH="$tmp/bin:$PATH"
export FLATPAK_LOG="$tmp/flatpak.log"
mkdir -p "$GSETTINGS_STATE"
printf 'Nordic\n' > "$GSETTINGS_STATE/gtk-theme"
printf 'prefer-dark\n' > "$GSETTINGS_STATE/color-scheme"

"$bin" --static
jq -e '.primary == "#e60012" and .surface == "#0b0b0b"' "$home/.cache/reddot/colors.json" >/dev/null
grep -q 'active = "#e60012"' "$home/.cache/reddot/hypr-colors.lua"
grep -q 'palette = 0=#151515' "$home/.cache/reddot/ghostty-colors"
grep -q '230;0;18' "$home/.config/fastfetch/config.jsonc"
echo 'ok - static palette and consumers'

# A tiny red image exercises the histogram path.
magick -size 32x32 xc:'#e60012' "$tmp/red.png"
# Fake matugen only for the generated path.
{
  printf '{ "base16": {'
  i=0
  while [ "$i" -lt 16 ]; do
    h=$(printf '%02x' "$i")
    printf '"base%s": {"dark": {"color": "#%02x%02x%02x"}}' "$h" "$i" "$i" "$i"
    i=$((i + 1))
    [ "$i" -lt 16 ] && printf ','
  done
  printf '} }\n'
} > "$tmp/matugen.json"
cat > "$tmp/bin/matugen" <<SH
#!/bin/sh
cat "$tmp/matugen.json"
SH
chmod +x "$tmp/bin/matugen"
"$bin" "$tmp/red.png"
jq -e '.primary != null and .surface != null' "$home/.cache/reddot/colors.json" >/dev/null
grep -q 'active = ' "$home/.cache/reddot/hypr-colors.lua"
grep -q 'palette = 15=' "$home/.cache/reddot/ghostty-colors"
echo 'ok - wallpaper palette and matugen consumers'

# App theme via the migrated --apps path.
"$bin" --apps
[ -f "$home/.config/gtk-4.0/gtk.css" ]
grep -q 'reddot app theme' "$home/.config/gtk-4.0/gtk.css"
grep -q '@define-color accent_bg_color' "$home/.config/gtk-4.0/reddot.css"
[ -f "$home/.local/state/reddot/apptheme.json" ]
echo 'ok - app theme enable'

"$bin" --apps off
[ ! -e "$home/.config/gtk-4.0/gtk.css" ]
[ ! -e "$home/.config/gtk-4.0/reddot.css" ]
[ ! -e "$home/.local/state/reddot/apptheme.json" ]
[ "$(cat "$GSETTINGS_STATE/gtk-theme")" = 'Nordic' ]
echo 'ok - app theme disable restores the user theme'
echo 'all Rust wallcolors tests passed'
