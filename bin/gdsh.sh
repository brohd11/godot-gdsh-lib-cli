#!/usr/bin/env bash
# gdsh-cli wrapper: runs gdsh headless in the enclosing Godot project, with the CLI installed in
# ~/.gdsh/cli by godot-gdsh-cli's install.sh. Godot binaries are registered in ~/.gdsh/executables
# (gdsh --register); $GODOT overrides the lookup.
set -o pipefail
gdsh_home=${GDSH_HOME:-$HOME/.gdsh}
cli=$gdsh_home/cli
registry=$gdsh_home/executables
usage="Usage: gdsh '<line>' | gdsh -f <file.gdsh> | gdsh --register [<godot>...] | gdsh --version | gdsh --help"
help="Usage: gdsh '<line>'                 run a gdsh line in the enclosing Godot project
       gdsh -f <file.gdsh>           run a gdsh script (starts with #!gdsh)
       gdsh --register [<godot>...]  record Godot binaries in ~/.gdsh/executables
       gdsh --version | --help

The line is gdsh syntax, as in the Editor Console, not bash: quote it so your shell
passes it whole. Blocks use braces:
  gdsh 'for f in \$(ls res://) { echo \"file: \$f\" }'
Output is plain text, so it pipes into your shell's tools:
  gdsh 'ls res://' | grep '/\$'"

drop_banner() { sed '1{/^Godot Engine v/{N;d;};}'; }

case $1 in
	-h|--help) echo "$help"; exit 0 ;;
	--version)
		[[ -f $cli/package.cfg ]] || { echo "gdsh: the CLI isn't installed in $cli" >&2; exit 1; }
		echo "gdsh-cli $(sed -n 's/^version="\(.*\)"/\1/p' "$cli/package.cfg")"
		exit 0 ;;
esac

if [[ $1 == --register ]]; then
	shift
	bins=("$@")
	if [[ ${#bins[@]} -eq 0 ]]; then
		[[ -n $GODOT ]] && bins+=("$GODOT")
		command -v godot > /dev/null && bins+=("$(command -v godot)")
		for app in /Applications/Godot*.app/Contents/MacOS/Godot; do
			[[ -x $app ]] && bins+=("$app")
		done
	fi
	[[ ${#bins[@]} -gt 0 ]] || { echo "gdsh: no Godot found; run: gdsh --register <path to godot>" >&2; exit 1; }
	# Godot loads a project.godot in its cwd (autoloads, extensions), so register from an empty dir.
	empty=$(mktemp -d)
	status=0
	for bin in "${bins[@]}"; do
		(cd "$empty" && "$bin" --headless --script "$cli/register.gd") | drop_banner || status=1
	done
	rmdir "$empty"
	exit $status
fi
[[ $# -gt 0 ]] || { echo "$usage" >&2; exit 1; }
[[ -f $cli/boot.gd ]] || { echo "gdsh: the CLI isn't installed in $cli" >&2; exit 1; }

proj=$PWD
while [[ $proj != / && ! -f $proj/project.godot ]]; do proj=$(dirname "$proj"); done
[[ -f $proj/project.godot ]] || { echo "gdsh: no project.godot above $PWD" >&2; exit 1; }

godot=$GODOT
if [[ -z $godot ]]; then
	ver=$(sed -n 's/^config\/features=PackedStringArray("\([0-9.]*\)".*/\1/p' "$proj/project.godot")
	want=""; grep -q '^config/features=.*"C#"' "$proj/project.godot" && want=-mono
	exact=""; other=""
	if [[ -n $ver && -f $registry ]]; then
		while IFS= read -r line || [[ -n $line ]]; do
			key=${line%%: *}; path=${line#*: }
			[[ $key == "godot-$ver."* && $path != "$line" ]] || continue
			mono=""; [[ $key == *-mono ]] && mono=-mono
			if [[ $mono == "$want" ]]; then exact=$path; else other=$path; fi
		done < "$registry"
	fi
	godot=${exact:-$other}
	if [[ -z $godot ]]; then
		echo "gdsh: no Godot ${ver:-(unknown version)} registered in $registry" >&2
		echo "  register one: gdsh --register <path to godot>" >&2
		exit 1
	fi
fi

if [[ $1 == -f ]]; then
	[[ -f $2 ]] || { echo "gdsh: no such file: $2" >&2; exit 1; }
	args=(-f "$(cd "$(dirname "$2")" && pwd)/$(basename "$2")")
else
	args=(-c "$*")
fi

# pipefail keeps Godot's exit code through the banner filter.
"$godot" --headless --path "$proj" --script "$cli/boot.gd" -- "${args[@]}" | drop_banner
