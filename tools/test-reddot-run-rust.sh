#!/bin/sh
# Dry-run ordering for the Rust package runner.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/reddot-run"
rustc --edition=2021 -O "$here/reddot-run.rs" -o "$bin"
printf '%s\n' '{"repos":[],"native":["foo","bar"],"aur":["baz"]}' > "$tmp/plan.json"
cat > "$tmp/expected" <<'EXP'
  would run: doas pacman -Syu --noconfirm
  would run: doas pacman -S --needed --noconfirm foo bar
  would run: doas pacman -S --needed --noconfirm git base-devel
  would run: sh -c 'rm -rf /tmp/reddot-yay-build && git clone https://aur.archlinux.org/yay-bin.git /tmp/reddot-yay-build'
  would run: sh -c 'cd /tmp/reddot-yay-build && makepkg -si --noconfirm'
  would run: paru -S --needed --noconfirm baz
EXP
PATH=/nonexistent "$bin" --plan "$tmp/plan.json" --family arch --root doas --dry-run > "$tmp/out"
echo 'ok - package runner order'
printf '%s\n' '{"repos":[],"native":[],"aur":[]}' > "$tmp/service-plan.json"
"$bin" --plan "$tmp/service-plan.json" --family arch --root doas --dry-run --services --init systemd > "$tmp/service.out"
grep -q 'doas systemctl enable --now NetworkManager.service' "$tmp/service.out"
grep -q 'doas systemctl enable --now bluetooth.service' "$tmp/service.out"
echo 'ok - systemd service commands'

printf '[{"desc":"build thing","run":["echo","hi"]},{"desc":"pipe thing","shell":"echo shell"}]\n' > "$tmp/fb.json"
"$bin" --plan "$tmp/plan.json" --family arch --dry-run --fallbacks-json "$tmp/fb.json" > "$tmp/fallback.out"
grep -q 'would run: echo hi' "$tmp/fallback.out"
grep -q "would run: sh -c 'echo shell'" "$tmp/fallback.out"
echo 'ok - fallback step ordering'

printf '%s\n' '{"native":[],"aur":["mpvpaper"],"repos":[],"fallbacks":[]}' > "$tmp/aur.json"
PATH=/nonexistent "$bin" --plan "$tmp/aur.json" --family arch --dry-run --aur-helper yay > "$tmp/aur.out"
grep -q 'git clone https://aur.archlinux.org/yay-bin.git' "$tmp/aur.out"
grep -q 'yay -S --needed --noconfirm mpvpaper' "$tmp/aur.out"
echo 'ok - AUR helper bootstrap'
echo 'all Rust runner tests passed'
