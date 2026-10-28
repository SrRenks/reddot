#!/bin/sh
# Compare the Rust TUI renderer with Python at fixed width, colors off.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/reddot-tui"
rustc --edition=2021 -O "$here/reddot-tui.rs" -o "$bin"
NO_COLOR=1 "$bin" --width 80 > "$tmp/rust.txt"
NO_COLOR=1 PYTHONPATH="$repo/installer" python3 - > "$tmp/python.txt" <<'PY'
import tui
out = []
tui._width = lambda: 80
tui._write = out.append
tui.banner()
tui.detected([("OS", "CachyOS", True), ("Session", "Hyprland", True), ("Package manager", "pacman", True), ("AUR helper", "yay", True)])
tui.info(["A quiet note about this step."])
for line in tui._menu_block("Install profile", [("Quick", "Core defaults, no questions", True), ("Full", "Everything, the daily apps too", False), ("Custom", "Walk every choice yourself", False)], 0, {0}, False, 80):
    out.append(line + "\n")
for line in tui._collapsed_block("Install profile", "Quick", 80):
    out.append(line + "\n")
for line in tui._confirm_block("Ready", ["Install this?"], 0, 80):
    out.append(line + "\n")
tui.closing("Done", "12 packages", [("restart", "the shell"), ("read", "docs/KEYBINDS.md")], [("log in", "reboot")], ["Keep the installer log"])
tui.outro("Done")
import sys
sys.stdout.write("".join(out))
PY
if ! diff -u "$tmp/python.txt" "$tmp/rust.txt"; then
    echo 'FAIL: TUI render parity' >&2
    exit 1
fi
echo 'ok - TUI render parity'
echo 'all Rust TUI tests passed'
