#!/bin/sh
#
# reddot bootstrap.
#
# Thin entrypoint for `curl -fsSL .../install.sh | bash`. It does the bare
# minimum to get the real installer running on a fresh machine: detect the
# distro family (so it knows the package manager), make sure git and rustc
# are present, fetch the rice, then hand the whole flow to the Python installer.
# The wizard, the package logic and the config deploy all live in
# installer/reddot_install.py, not here.

set -e

REPO_URL="https://github.com/SrRenks/reddot.git"
DIR="${XDG_DATA_HOME:-$HOME/.local/share}/reddot"

# os-release ID / ID_LIKE tokens per family, mirroring installer/distro.py so the
# bootstrap picks the same package manager the Python installer expects.
ARCH_IDS="arch cachyos endeavouros manjaro garuda artix arcolinux archcraft rebornos athena blackarch archbang crystal snigdha parabola obarun arch32 hyperbola steamos omarchy xerolinux archman biglinux ctlos tromjaro bluestar arkane blendos acreetionos mabox"
DEBIAN_IDS="debian ubuntu linuxmint pop elementary zorin raspbian"
FEDORA_IDS="fedora nobara rhel centos rocky almalinux"
SUSE_IDS="suse opensuse sles sled tumbleweed leap"
GENTOO_IDS="gentoo funtoo calculate pentoo redcore"

say()  { printf '%s\n' "$*"; }
step() { printf '\n:: %s\n' "$*"; }
die()  { printf 'reddot: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

in_list() {
	case " $2 " in
	*" $1 "*) return 0 ;;
	esac
	return 1
}

# Map os-release ID/ID_LIKE onto arch/debian/fedora/suse/gentoo, ID first then ID_LIKE,
# first matching token wins. Same order as distro.family_from_os_release. Runs in
# a subshell (command substitution) so sourcing os-release stays contained.
detect_family() {
	[ -r /etc/os-release ] || { echo unknown; return 0; }
	# shellcheck disable=SC1091
	. /etc/os-release 2>/dev/null || true
	for tok in $(printf '%s %s' "${ID:-}" "${ID_LIKE:-}" | tr '[:upper:]' '[:lower:]'); do
		in_list "$tok" "$ARCH_IDS" && { echo arch; return 0; }
		in_list "$tok" "$DEBIAN_IDS" && { echo debian; return 0; }
		in_list "$tok" "$FEDORA_IDS" && { echo fedora; return 0; }
		in_list "$tok" "$SUSE_IDS" && { echo suse; return 0; }
		in_list "$tok" "$GENTOO_IDS" && { echo gentoo; return 0; }
	done
	echo unknown
}

# Run a command as root. sudo (or doas, common on Gentoo) reads its password
# straight from the controlling terminal, so this still works when the script
# itself is piped in from curl.
run_root() {
	if [ "$(id -u)" -eq 0 ]; then
		"$@"
		return
	fi
	for su in sudo doas; do
		have "$su" || continue
		if [ -e /dev/tty ]; then "$su" "$@" </dev/tty; else "$su" "$@"; fi
		return
	done
	die "need root to install packages; run as root or install sudo or doas first"
}

# git + rustc are what the Rust installer needs. Install them with the family's
# manager only when something is actually missing. Python is no longer the
# install prerequisite; it remains only as a rollout fallback on boxes that
# already carry it.
ensure_deps() {
	have git && have rustc && return 0
	step "Installing git and rustc"
	# Refresh metadata first; a fresh debian/fedora/suse box can ship an empty
	# package list, so the git+rustc bootstrap fails before the real installer
	# is reached. Best-effort (|| true) so one stale repo never blocks the install.
	case "$1" in
	arch) run_root pacman -Syu --needed --noconfirm git rust ;;
	debian) run_root apt-get update || true; run_root apt-get install -y git rustc ;;
	fedora) run_root dnf makecache || true; run_root dnf install -y git rust cargo ;;
	suse) run_root zypper --non-interactive refresh || true; run_root zypper --non-interactive install git rust cargo ;;
	gentoo) run_root emerge --noreplace dev-vcs/git dev-lang/rust-bin ;;
	*) die "no supported package manager (arch/debian/fedora/suse/gentoo); install git and rustc yourself, then re-run" ;;
	esac
	if ! have git || ! have rustc; then
		die "git and rustc are still missing after the install step"
	fi
}

fetch() {
	mkdir -p "$(dirname "$DIR")"
	if [ -d "$DIR/.git" ]; then
		step "Updating Reddot in $DIR"
		git -C "$DIR" pull --ff-only || say "  could not fast-forward, using the current checkout"
	else
		step "Cloning Reddot into $DIR"
		git clone --depth 1 "$REPO_URL" "$DIR"
	fi
}

# True when a flag is among the forwarded installer args.
has_flag() {
	flag="$1"; shift
	case " $* " in
	*" $flag "*) return 0 ;;
	esac
	return 1
}

main() {
	say "Preparing installer interface..."
	[ "$(uname -s)" = Linux ] || die "reddot only installs on Linux"

	# A box that already carries the managed deploy updates through the in-app
	# updater, not through a full re-install; re-running the one-liner is almost
	# always someone looking for "how do I update". --reinstall forces the wizard.
	if [ -f "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/.reddot-managed" ] \
		&& ! has_flag --reinstall "$@" && ! has_flag --uninstall "$@"; then
		say "Reddot is already installed."
		say "  Update:       open Settings > Updates in the pill, or run: reddot update"
		say "  Re-install:   curl -fsSL https://raw.githubusercontent.com/SrRenks/reddot/e14g7/install.sh | sh -s -- --reinstall"
		say "  Uninstall:    reddot uninstall"
		exit 0
	fi

	fam="$(detect_family)"
	if [ "$fam" = unknown ]; then
		say "Note: this distro is not a supported family (arch/debian/fedora/suse/gentoo)."
		say "No packages will be installed; configs deploy at your own risk."
	fi

	ensure_deps "$fam"
	fetch

	# Prefer the Rust entry point when a toolchain is available. It currently
	# implements the quickstart flow; the Python installer stays as the rollout
	# fallback for interactive/reinstall/uninstall flows.
	rust_ok=0
	if have rustc; then
		if "$DIR/tools/build-rust.sh" "$HOME/.local/bin" >/dev/null 2>&1; then
			if has_flag --uninstall "$@"; then
				rust_args="--uninstall --source $DIR/configs --config-root ${XDG_CONFIG_HOME:-$HOME/.config} --bin-dir $HOME/.local/bin"
			else
				rust_args="--source $DIR/configs --config-root ${XDG_CONFIG_HOME:-$HOME/.config} --bin-dir $HOME/.local/bin"
				has_flag --quickstart "$@" && rust_args="--quickstart $rust_args"
			fi
			has_flag --dry-run "$@" && rust_args="$rust_args --dry-run" || rust_args="$rust_args --apply"
			has_flag --full "$@" && rust_args="$rust_args --full"
			has_flag --no-deps "$@" && rust_args="$rust_args --no-deps"
			has_flag --sddm "$@" && rust_args="$rust_args --sddm"
			has_flag --grub "$@" && rust_args="$rust_args --grub"
			has_flag --brave "$@" && rust_args="$rust_args --brave"
			has_flag --no-fish "$@" && rust_args="$rust_args --no-fish"
			"$HOME/.local/bin/reddot-install" $rust_args || exit $?
			rust_ok=1
		fi
	fi
	[ "$rust_ok" -eq 1 ] || die "Rust installer could not be built; refusing to fall back to Python"

	# The Python installer owns ~/.config. The TLP and ThinkPad helpers, the
	# polkit rule, the AC/BAT policy and the user-level tools live outside it;
	# install them last so a config-only run never points at a missing helper.
	if ! has_flag --dry-run "$@" && ! has_flag --uninstall "$@" \
		&& ! has_flag --skip-extras "$@"; then
		step "Installing Reddot extras"
		run_root "$DIR/tools/install-extras.sh"
	fi
}

main "$@"
