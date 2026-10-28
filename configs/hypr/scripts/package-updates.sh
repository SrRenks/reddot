#!/bin/sh
# Read-only package update probe. The UI parses the @@ markers; no package
# manager is invoked with write privileges. Supports Arch, Fedora/RHEL (dnf),
# openSUSE (zypper) and Debian/Ubuntu (apt), plus optional AUR and Flatpak.
set -u

# A package manager can hold its database lock during an upgrade. Keep the
# read-only probe from leaving the UI in "checking" forever.
limit() {
    if command -v timeout >/dev/null 2>&1; then
        timeout 25 "$@"
    else
        "$@"
    fi
}

family=${PACKAGE_UPDATES_FAMILY:-}
case "$family" in
    arch|fedora|suse|debian) ;;
    *)
        if command -v pacman >/dev/null 2>&1; then
            family=arch
        elif command -v dnf >/dev/null 2>&1; then
            family=fedora
        elif command -v dnf5 >/dev/null 2>&1; then
            family=fedora
        elif command -v zypper >/dev/null 2>&1; then
            family=suse
        elif command -v apt-get >/dev/null 2>&1; then
            family=debian
        else
            family=unknown
        fi
        ;;
esac
printf '@@BACKEND:%s@@\n' "$family"

printf '@@OFFICIAL@@\n'
case "$family" in
    arch)
        # checkupdates refreshes a temporary sync database without root. When it
        # is absent, pacman -Qu still answers from the cached databases.
        if command -v checkupdates >/dev/null 2>&1; then
            out=$(limit checkupdates 2>/dev/null); rc=$?
            [ -n "$out" ] && printf '%s\n' "$out"
            if [ "$rc" -eq 0 ] || [ "$rc" -eq 2 ]; then printf '@@OK:official@@\n'; else printf '@@ERR:official@@\n'; fi
        else
            out=$(limit pacman -Qu 2>/dev/null); rc=$?
            [ -n "$out" ] && printf '%s\n' "$out"
            if [ "$rc" -le 1 ]; then printf '@@OK:official@@\n'; else printf '@@ERR:official@@\n'; fi
        fi
        ;;
    fedora)
        pm=dnf
        command -v dnf >/dev/null 2>&1 || pm=dnf5
        out=$(limit $pm -q check-update 2>/dev/null); rc=$?
        if [ -n "$out" ]; then
            printf '%s\n' "$out" | awk '$1 ~ /\.[^.]+$/ && NF >= 2 { n=$1; sub(/\.[^.]+$/, "", n); print n }'
        fi
        if [ "$rc" -eq 0 ] || [ "$rc" -eq 100 ]; then printf '@@OK:official@@\n'; else printf '@@ERR:official@@\n'; fi
        ;;
    suse)
        out=$(limit zypper --non-interactive list-updates 2>/dev/null)
        if [ -n "$out" ]; then
            printf '%s\n' "$out" | awk -F'|' '/^[[:space:]]*v[[:space:]]*\|/ { n=$3; gsub(/^[[:space:]]+|[[:space:]]+$/, "", n); if (n != "") print n }'
        fi
        printf '@@OK:official@@\n'
        ;;
    debian)
        out=$(limit apt list --upgradable 2>/dev/null)
        if [ -n "$out" ]; then
            printf '%s\n' "$out" | awk -F/ '/^[[:alnum:]][^ ]*\// { print $1 }'
        fi
        printf '@@OK:official@@\n'
        ;;
    *)
        printf '@@ERR:official@@\n'
        ;;
esac

printf '@@AUR@@\n'
if [ "$family" = arch ]; then
    if command -v yay >/dev/null 2>&1; then
        out=$(limit yay -Qua 2>/dev/null); rc=$?
        [ -n "$out" ] && printf '%s\n' "$out"
        if [ "$rc" -le 1 ]; then printf '@@OK:aur@@\n'; else printf '@@ERR:aur@@\n'; fi
    elif command -v paru >/dev/null 2>&1; then
        out=$(limit paru -Qua 2>/dev/null); rc=$?
        [ -n "$out" ] && printf '%s\n' "$out"
        if [ "$rc" -le 1 ]; then printf '@@OK:aur@@\n'; else printf '@@ERR:aur@@\n'; fi
    else
        printf '@@MISSING:aur@@\n'
    fi
else
    printf '@@MISSING:aur@@\n'
fi

printf '@@FLATPAK@@\n'
if command -v flatpak >/dev/null 2>&1; then
    out=$(limit flatpak remote-ls --updates --columns=application 2>/dev/null); rc=$?
    [ -n "$out" ] && printf '%s\n' "$out"
    if [ "$rc" -eq 0 ]; then printf '@@OK:flatpak@@\n'; else printf '@@ERR:flatpak@@\n'; fi
else
    printf '@@MISSING:flatpak@@\n'
fi
