#!/bin/sh
# Build every crate-free reddot helper into one directory. No cargo, no crates.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
out=${1:-${DESTDIR:-$HOME/.local/bin}}
mkdir -p "$out"
command -v rustc >/dev/null 2>&1 || { echo "build-rust: rustc not found" >&2; exit 1; }
for name in reddot-update reddot-wallcolors reddot-distro reddot-pkg reddot-fallbacks \
            reddot-grub reddot-deploy reddot-neutralize reddot-tui reddot-detect \
            reddot-plan reddot-post reddot-run reddot-report reddot-install; do
    src="$here/$name.rs"
    [ -f "$src" ] || { echo "build-rust: missing $src" >&2; exit 1; }
    rustc --edition=2021 -O -C strip=symbols "$src" -o "$out/$name"
    echo "  $out/$name"
done
