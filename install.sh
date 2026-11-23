#!/bin/sh
# Installs the gdsh CLI: the unpacked release into ~/.gdsh/cli, the `gdsh`
# wrapper into ~/.local/bin, then registers the Godot binaries it can find.
#   curl -fsSL https://raw.githubusercontent.com/brohd11/godot-gdsh-cli/main/install.sh | sh
#   sh install.sh [--from <zip>] [--dir <bin dir>] [--force] [--uninstall]
set -eu

URL=${GDSH_CLI_URL:-https://github.com/brohd11/godot-gdsh-cli/releases/latest/download/gdsh-cli.zip}
PKG=addons/_lib/gdsh_lib/cli
# Every wrapper carries this, so reinstall/uninstall only ever touch files this script wrote.
MARKER="gdsh-cli wrapper"

gdsh_home=${GDSH_HOME:-$HOME/.gdsh}
cli=$gdsh_home/cli
bin_dir=$HOME/.local/bin
from=""; force=0; uninstall=0

die() { echo "install.sh: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
	case $1 in
		--from) [ $# -ge 2 ] || die "--from needs a zip"; from=$2; shift ;;
		--dir) [ $# -ge 2 ] || die "--dir needs a path"; bin_dir=$2; shift ;;
		--force) force=1 ;;
		--uninstall) uninstall=1 ;;
		*) die "unknown argument: $1 (use --from <zip> --dir <bin dir> --force --uninstall)" ;;
	esac
	shift
done
wrapper=$bin_dir/gdsh

is_ours() { grep -q "$MARKER" "$1" 2>/dev/null; }

if [ $uninstall -eq 1 ]; then
	if [ -f "$wrapper" ]; then
		if is_ours "$wrapper"; then rm -f "$wrapper" && echo "Removed $wrapper"
		else echo "Left $wrapper: this script didn't write it." >&2; fi
	fi
	[ -d "$cli" ] && rm -rf "$cli" && echo "Removed $cli"
	echo "Kept $gdsh_home/executables and your commands."
	exit 0
fi

# Refuse before changing anything.
if [ -f "$wrapper" ] && [ $force -eq 0 ] && ! is_ours "$wrapper"; then
	die "$wrapper exists and wasn't written by this script; rerun with --force to replace it."
fi
command -v unzip > /dev/null || die "needs unzip"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
zip=$tmp/gdsh-cli.zip
if [ -n "$from" ]; then
	cp "$from" "$zip"
elif command -v curl > /dev/null; then
	curl -fsSL "$URL" -o "$zip" || die "download failed: $URL"
elif command -v wget > /dev/null; then
	wget -qO "$zip" "$URL" || die "download failed: $URL"
else
	die "needs curl or wget"
fi

# A relative-path export runs from anywhere, so the package dir is unpacked as-is.
unzip -q "$zip" -d "$tmp/zip" || die "can't unzip $zip"
stage=$tmp/zip/$PKG
[ -f "$stage/boot.gd" ] || die "not a gdsh-cli release: no $PKG/boot.gd in the zip"
mkdir -p "$gdsh_home"
rm -rf "$cli"
mv "$stage" "$cli"
echo "Installed $cli"

mkdir -p "$bin_dir"
cp "$cli/bin/gdsh.sh" "$wrapper"
chmod 755 "$wrapper"
echo "Installed $wrapper"

"$wrapper" --register || echo "Register a Godot binary: gdsh --register <path to godot>"

case ":$PATH:" in
	*":$bin_dir:"*) ;;
	*) printf '\n%s is not on PATH. Add it in your shell profile:\n  export PATH="%s:$PATH"\n' "$bin_dir" "$bin_dir" ;;
esac
