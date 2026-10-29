#!/usr/bin/env bash

UA="Mozilla/5.0 (X11; Linux x86_64) Gecko/20100101 Firefox/126.0"

search_moewalls() {
    local query="${1:-}" enc page posts tmp url html prev token thumb res w h
    [ -n "$query" ] || { printf '[]\n'; return 0; }
    enc=$(jq -rn --arg q "$query" '$q|@uri') || { printf '[]\n'; return 0; }
    page=$(curl -fsSL --max-time 12 -A "$UA" -e "https://moewalls.com/" "https://moewalls.com/?s=${enc}") || { printf '[]\n'; return 0; }
    posts=$(printf '%s' "$page" | grep -oP 'href="\Khttps://moewalls\.com/[a-z0-9-]+/[a-z0-9-]+-live-wallpaper/' | awk '!seen[$0]++' | head -n 24)
    [ -n "$posts" ] || { printf '[]\n'; return 0; }

    tmp=$(mktemp "${TMPDIR:-/tmp}/moewalls.XXXXXX")
    trap 'rm -f "$tmp"' EXIT
    : > "$tmp"
    while IFS= read -r url; do
        [ -n "$url" ] || continue
        html=$(curl -fsSL --max-time 10 -A "$UA" -e "https://moewalls.com/" "$url") || continue
        prev=$(printf '%s' "$html" | grep -oP '<source src="\K/wp-content/uploads/preview/[^"]+' | head -1)
        token=$(printf '%s' "$html" | grep -oP 'id="moe-download"[^>]*data-url="\K[^"]+' | head -1)
        thumb=$(printf '%s' "$html" | grep -oP 'poster="\K[^"]+' | head -1)
        res=$(printf '%s' "$html" | grep -oP 'resolutions-\K[0-9]+x[0-9]+' | head -1)
        [ -n "$prev" ] && [ -n "$token" ] || continue
        case "$prev" in http*) ;; *) prev="https://moewalls.com$prev" ;; esac
        case "$thumb" in "" ) thumb="" ;; http*) ;; *) thumb="https://moewalls.com$thumb" ;; esac
        w=0 h=0
        [ -n "$res" ] && { w=${res%x*}; h=${res#*x}; }
        jq -cn --arg image "https://go.moewalls.com/download.php?video=${token}" --arg thumb "$thumb" --arg preview "$prev" --argjson w "${w:-0}" --argjson h "${h:-0}"             '{image:$image, thumb:$thumb, preview:$preview, w:$w, h:$h}' >> "$tmp" 2>/dev/null || true
    done <<EOF
$posts
EOF
    jq -s '.' "$tmp" 2>/dev/null || printf '[]\n'
}

search() {
    local query="${1:-}" kind="${2:-all}"
    [ -n "$query" ] || { printf '[]\n'; return 0; }

    if [ "$kind" = "motion" ]; then
        search_moewalls "$query"
        return 0
    fi

    local q="$query" f=",,,"
    case "$kind" in
        still)  f="type:photo" ;;
    esac

    local enc vqd raw
    enc=$(jq -rn --arg q "$q" '$q|@uri') || { printf '[]\n'; return 0; }

    vqd=$(curl -s --max-time 10 "https://duckduckgo.com/?q=${enc}&iax=images&ia=images" -A "$UA" \
        | grep -oP 'vqd=\\?"?\K[0-9-]+' | head -1)
    [ -n "$vqd" ] || { printf '[]\n'; return 0; }

    raw=$(curl -s --max-time 10 \
        "https://duckduckgo.com/i.js?l=us-en&o=json&q=${enc}&vqd=${vqd}&f=${f}&p=-1" \
        -A "$UA" -H "Referer: https://duckduckgo.com/")
    [ -n "$raw" ] || { printf '[]\n'; return 0; }

    printf '%s' "$raw" | jq -c --arg kind "$kind" '
        (.results // [])
        | if $kind == "motion" then map(select(.image // "" | test("\\.gif(\\?|$)"; "i")))
          elif $kind == "still" then map(select(.image // "" | test("\\.gif(\\?|$)"; "i") | not))
          else . end
        | map({
            image: .image,
            thumb: (.thumbnail // .image),
            w: (.width // 0 | if . == null then 0 else . end),
            h: (.height // 0 | if . == null then 0 else . end)
          })
        | map(select(.image != null and .image != ""))
        | .[0:60]
    ' 2>/dev/null || printf '[]\n'
}

download() {
    set -euo pipefail
    url="${1:-}"
    [ -n "$url" ] || exit 1

    flags="${XDG_STATE_HOME:-$HOME/.local/state}/reddot/flags.json"
    wpdir=$(jq -r '.wallpaperDir // ""' "$flags" 2>/dev/null || echo "")
    [ -n "$wpdir" ] || wpdir=$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/reddot-wallpaper-dir" 2>/dev/null || true)
    [ -n "$wpdir" ] || wpdir="$HOME/reddot/wallpapers"
    dir="$wpdir/downloads"
    mkdir -p "$dir"

    case "$url" in
        https://go.moewalls.com/download.php*)
            fn=$(curl -fsI --max-time 20 -A "$UA" -e "https://moewalls.com/" "$url" \
                | grep -oiP 'filename=\K[^"\r\n;]+' | head -1 | tr -d '/\\')
            [ -n "$fn" ] || fn="moewalls-$(date +%s).mp4"
            out="$dir/$fn"
            curl -fsL --max-time 600 -A "$UA" -e "https://moewalls.com/" -o "$out" "$url" || exit 1
            [ -s "$out" ] || exit 1
            printf '%s\n' "$out"
            exit 0
            ;;
    esac

    tmp=$(mktemp "${TMPDIR:-/tmp}/ddg-wp.XXXXXX")
    trap 'rm -f "$tmp" "$tmp.out"' EXIT

    curl -fsL --max-time 60 -A "$UA" -e "https://duckduckgo.com/" -o "$tmp" "$url" || exit 1
    [ -s "$tmp" ] || exit 1

    export MAGICK_CONFIGURE_PATH="$(dirname "$0")/magick-policy"

    fmt=$(magick identify -format '%m' "${tmp}[0]" 2>/dev/null | head -1) || exit 1

    case "$fmt" in
        JPEG) ext=jpg ;;
        PNG)  ext=png ;;
        GIF)  ext=gif ;;
        WEBP) ext=webp ;;
        *)    ext=png ;;
    esac

    out="$dir/ddg-$(date +%s)-${RANDOM}.${ext}"

    if [ "$ext" = "png" ] && [ "$fmt" != "PNG" ]; then
        magick "${tmp}[0]" -strip "png:$tmp.out" 2>/dev/null || exit 1
        [ -s "$tmp.out" ] || exit 1
        mv "$tmp.out" "$out"
    else
        cp "$tmp" "$out"
    fi

    [ -s "$out" ] || exit 1
    printf '%s\n' "$out"
}

case "${1:-}" in
    search)   search "${2:-}" "${3:-all}" ;;
    download) download "${2:-}" ;;
    *)        printf '[]\n'; exit 0 ;;
esac
