#!/bin/sh
# Backend-neutral tests for package-updates.sh using fake package managers.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
script="$here/../configs/hypr/scripts/package-updates.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
fails=0
ok() { echo "ok - $*"; }
fail() { echo "FAIL: $*" >&2; fails=$((fails + 1)); }

fake() {
    name=$1; shift
    printf '#!/bin/sh\n%s\n' "$*" > "$tmp/bin/$name"
    chmod +x "$tmp/bin/$name"
}

check_output() {
    label=$1; family=$2; needle=$3; shift 3
    out=$(PATH="$tmp/bin:$PATH" PACKAGE_UPDATES_FAMILY="$family" sh "$script" 2>&1)
    if printf '%s\n' "$out" | grep -q -- "$needle"; then ok "$label"; else fail "$label (missing $needle)"; fi
}

# Fedora/RPM through dnf's update exit code 100.
fake dnf 'printf "Last metadata expiration check\\nfoo.x86_64 1.2 updates\\nbar.noarch 2.0 updates\\n"; exit 100'
check_output 'fedora marks RPM backend' fedora '@@BACKEND:fedora@@'
check_output 'fedora lists RPM names' fedora '^foo$'
check_output 'fedora strips RPM arch' fedora '^bar$'
check_output 'fedora reports official ok' fedora '@@OK:official@@'

# openSUSE/RPM through zypper's table.
fake zypper 'printf "S | Repository | Name | Current | Available | Arch\\n--+------------+------+---------+-----------+-----\\nv | repo | zypper-pkg | 1 | 2 | x86_64\\n"'
check_output 'suse lists RPM name' suse '^zypper-pkg$'
check_output 'suse marks zypper backend' suse '@@BACKEND:suse@@'

# Arch via checkupdates, which refreshes a temporary database without root.
fake checkupdates 'printf "check-pkg 1.0 -> 1.1\n"; exit 0'
check_output 'arch uses checkupdates' arch '^check-pkg 1.0'

# Arch without checkupdates falls back to the cached pacman database.
rm "$tmp/bin/checkupdates"
fake pacman 'printf "pacman-pkg 1.0 -> 1.1\n"'
check_output 'arch lists pacman name' arch '^pacman-pkg 1.0'
check_output 'arch marks pacman backend' arch '@@BACKEND:arch@@'

# paru is accepted when yay is not installed.
fake paru 'printf "paru-pkg 1.0 -> 1.1\n"'
out=$(PATH="$tmp/bin" PACKAGE_UPDATES_FAMILY=arch /bin/sh "$script" 2>&1)
if printf '%s\n' "$out" | grep -q '^paru-pkg 1.0'; then ok 'arch lists paru name'; else fail 'arch lists paru name'; fi
if printf '%s\n' "$out" | grep -q '^@@OK:aur@@$'; then ok 'arch marks paru AUR ok'; else fail 'arch marks paru AUR ok'; fi

# Debian via apt.
fake apt 'printf "Listing...\\napt-pkg/stable 1.0 amd64 [upgradable]\\n"'
check_output 'debian lists apt name' debian '^apt-pkg$'
check_output 'debian marks apt backend' debian '@@BACKEND:debian@@'

if [ "$fails" -ne 0 ]; then
    echo "$fails test(s) failed" >&2
    exit 1
fi
echo "all tests passed"
