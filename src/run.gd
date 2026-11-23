extends RefCounted
## Runs a gdsh line headless, for boot.gd. Uses the project's gdsh when it has one, since
## unignored plugin cmd/ dirs are built against that copy, else the copy bundled in vendor/.
## Nothing preloads gdsh, so only the chosen copy loads.
## Offers the builtins, utils, enabled plugins' cmd/ and the ~/.gdsh / res://.gdsh roots.

## Kept as written on export, so it always names the project's copy.
const PROJECT_HOST = "res://addons/_lib/gdsh/src/core/host.gd" #! gdp-ignore
## Only gathers gdsh into vendor/ on export; the copy is found from this file (_bundled_root).
const _BUNDLE = "res://addons/_lib/gdsh/src/core/host.gd" #! gdp-dependency
## Below a gdsh copy's root (res:// or vendor/): its host, and utils beside it.
const _HOST_TAIL = "addons/_lib/gdsh/src/core/host.gd" #! gdp-ignore
const _UTILS_TAIL = "addons/_lib/gdsh_lib/utils/cmd" #! gdp-ignore

const USAGE = \
"Usage: gdsh '<line>' | gdsh -f <file.gdsh>
  -c  run a command line (pipes, quoting and variables work)
  -f  run a .gdsh script"


## args is `-c <line>` or `-f <file>`; returns the exit code.
static func run(args:PackedStringArray) -> int:
	if args.size() != 2 or args[0] not in ["-c", "-f"]:
		printerr(USAGE)
		return 1

	var root = "res://" if ResourceLoader.exists(PROJECT_HOST) else _bundled_root()
	var Host = load(root + _HOST_TAIL)
	if Host == null:
		printerr("gdsh: no gdsh at " + root + _HOST_TAIL)
		return 1
	var utils = root + _UTILS_TAIL
	var dirs = [utils] if DirAccess.dir_exists_absolute(utils) else []
	# Host resolves the user roots (rebuilt against its gdsh), so a ctx can take its scopes.
	var host = Host.new({"default_dirs": true, "command_dirs": dirs})
	var ctx = Host.Context.new("gdsh cli")
	ctx.scopes.merge(host.get_scopes(), true)

	if args[0] == "-c":
		await Host.Execute.execute_command_multiline(args[1], ctx)
	else:
		await Host.Execute.source_file(args[1], ctx)

	var out:String = Host.Context.plain_text(ctx.stdout)
	var err:String = Host.Context.plain_text(ctx.stderr)
	if not out.is_empty():
		printraw(out if out.ends_with("\n") else out + "\n")
	if not err.is_empty():
		printerr(err.rstrip("\n"))
	return ctx.exit_code


## The package's vendor/ dir, which mirrors res:// (<pkg>/src/run.gd -> <pkg>/vendor/).
static func _bundled_root() -> String:
	# new(): a static func has no get_script().
	var pkg = new().get_script().resource_path.get_base_dir().get_base_dir()
	return pkg.path_join("vendor") + "/"
