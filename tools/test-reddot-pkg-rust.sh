#!/bin/sh
# Compare Rust pkg argv with installer/pkg.py. Read-only; no package manager runs.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname "$here")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/reddot-pkg"
rustc --edition=2021 -O "$here/reddot-pkg.rs" -o "$bin"
manifest="$repo/installer/packages.json"

py() {
    PATH="$tmp/empty" PYTHONPATH="$repo/installer" /usr/bin/python3 - "$manifest" <<'PY'
import json, sys
import pkg
print(json.dumps({
    "arch": pkg.install_argv(["foo"], "arch"),
    "debian": pkg.install_argv(["foo", "bar"], "debian"),
    "fedora": pkg.install_argv(["foo"], "fedora"),
    "suse": pkg.install_argv(["foo"], "suse"),
    "gentoo": pkg.install_argv(["gui-wm/hyprland"], "gentoo"),
    "refresh": {f: pkg.refresh_argv(f) for f in ("arch", "debian", "fedora", "suse", "gentoo")},
    "copr": pkg.enable_repo_argv("copr:solopasha/hyprland", "fedora"),
    "obs": pkg.enable_repo_argv("obs:home:AvengeMedia:danklinux", "suse"),
    "overlay": pkg.enable_repo_argv("overlay:guru", "gentoo"),
    "ppa_debian": pkg.enable_repo_argv("ppa:avengemedia/danklinux", "debian"),
    "portage_lines": pkg.portage_lines({"gui-wm/hyprland": "overlay:hyproverlay", "gui-apps/quickshell": "overlay:guru", "app-shells/fish": None, "app-shells/zoxide": None, "media-sound/cava": None}),
    "portage_config": pkg.portage_config_argv({"gui-wm/hyprland": "overlay:hyproverlay"}),
    "aur_steps": pkg.ensure_aur_helper_steps(),
    "priv": pkg.privileged(["pacman", "-S", "x"], "arch"),
}, sort_keys=True))
PY
}
py > "$tmp/python.json"
"$bin" install --family arch foo > "$tmp/arch.json"
"$bin" install --family debian foo bar > "$tmp/debian.json"
"$bin" install --family fedora foo > "$tmp/fedora.json"
"$bin" install --family suse foo > "$tmp/suse.json"
"$bin" install --family gentoo gui-wm/hyprland > "$tmp/gentoo.json"
for f in arch debian fedora suse gentoo; do
    jq -S . "$tmp/$f.json" > "$tmp/$f.sorted"
done
jq -S . "$tmp/python.json" > "$tmp/python.sorted"

# Build a single JSON from the Rust subcommands and compare selected fields.
{
  printf '{"arch":'; cat "$tmp/arch.sorted"; printf ',"debian":'; cat "$tmp/debian.sorted";
  printf ',"fedora":'; cat "$tmp/fedora.sorted"; printf ',"suse":'; cat "$tmp/suse.sorted";
  printf ',"gentoo":'; cat "$tmp/gentoo.sorted"; printf ',"refresh":{';
  i=0; for f in arch debian fedora suse gentoo; do [ $i -gt 0 ] && printf ','; printf '"%s":' "$f"; "$bin" refresh --family "$f"; i=1; done
  printf '},"copr":'; "$bin" repo --family fedora --repo copr:solopasha/hyprland;
  printf ',"obs":'; "$bin" repo --family suse --repo obs:home:AvengeMedia:danklinux;
  printf ',"overlay":'; "$bin" repo --family gentoo --repo overlay:guru;
  printf ',"ppa_debian":'; "$bin" repo --family debian --repo ppa:avengemedia/danklinux;
  printf ',"portage_lines":'; "$bin" portage-lines --atoms 'gui-wm/hyprland=overlay:hyproverlay,gui-apps/quickshell=overlay:guru,app-shells/fish,app-shells/zoxide,media-sound/cava';
  printf ',"portage_config":'; "$bin" portage-config --atoms 'gui-wm/hyprland=overlay:hyproverlay';
  printf ',"aur_steps":'; PATH="$tmp/empty" "$bin" aur-steps;
  printf ',"priv":'; "$bin" privileged --family arch pacman -S x;
  printf '}\n';
} > "$tmp/rust-combined.json"
jq -S . "$tmp/rust-combined.json" > "$tmp/rust.sorted"
# Compare field by field with clear diagnostics.
for key in arch debian fedora suse gentoo copr obs overlay ppa_debian portage_lines portage_config aur_steps priv; do
    jq -S ".$key" "$tmp/python.sorted" > "$tmp/p.$key"
    jq -S ".$key" "$tmp/rust.sorted" > "$tmp/r.$key"
    if ! diff -u "$tmp/p.$key" "$tmp/r.$key"; then
        echo "FAIL: parity for $key" >&2
        exit 1
    fi
done
for key in arch debian fedora suse gentoo; do
    printf '%s ' "$key"; cat "$tmp/p.$key"; echo
done
if command -v yay >/dev/null 2>&1 || command -v paru >/dev/null 2>&1; then
    "$bin" install --family arch --aur dotool > "$tmp/aur.json"
    PYTHONPATH="$repo/installer" python3 - "$manifest" <<'PY' > "$tmp/py-aur.json"
import json, pkg
print(json.dumps(pkg.install_argv(["dotool"], "arch", aur=True), sort_keys=True))
PY
    jq -S . "$tmp/aur.json" > "$tmp/a1"; jq -S . "$tmp/py-aur.json" > "$tmp/a2"
    diff -u "$tmp/a2" "$tmp/a1"
fi
echo 'all Rust pkg tests passed'
