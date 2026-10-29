#!/bin/sh
# Runtime entry points must not invoke Python. The .py files are parity tests.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
for file in \
    install.sh \
    configs/hypr/scripts/reddot \
    configs/hypr/scripts/reddot-update \
    configs/hypr/scripts/wallcolors \
    configs/hypr/scripts/wallpaper-search.sh; do
    if grep -n 'python3' "$repo/$file" >/dev/null 2>&1; then
        echo "FAIL: runtime Python reference in $file" >&2
        grep -n 'python3' "$repo/$file" >&2
        exit 1
    fi
done
echo 'ok - runtime scripts contain no python3 invocation'
