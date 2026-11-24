extends RefCounted
## Runs a gdsh line headless, for boot.gd. Uses the project's gdsh when it has one, since
## unignored plugin cmd/ dirs are built against that copy, else the copy bundled in vendor/.
## Nothing preloads gdsh, so only the chosen copy loads.
## Offers the builtins, utils, settings, enabled plugins' cmd/ and the ~/.gdsh / res://.gdsh roots.
## Sources ~/.gdrc then res://.gdrc first (skipped when GDSH_NORC is set), with $GDSH_HOST = "cli".

## Kept as written on export, so it always names the project's copy.
const PROJECT_HOST = "res://addons/_lib/gdsh/src/core/host.gd" #! gdp-ignore
## Gathers gdsh on export and is rewritten to wherever it landed (relative to this file), so
## _bundled_root needn't know the vendor dir's name.
const _BUNDLE = "res://addons/_lib/gdsh/src/core/host.gd" #! gdp-dependency
## Below a gdsh copy's root (res:// or vendor/): its host, and utils beside it.
const _HOST_TAIL = "addons/_lib/gdsh/src/core/host.gd" #! gdp-ignore
const _UTILS_TAIL = "addons/_lib/gdsh_lib/utils/cmd" #! gdp-ignore
const _SETTINGS_TAIL = "addons/_lib/gdsh_lib/editor/cmd/settings/settings.gd" #! gdp-ignore

const USAGE = \
"Usage: boot.gd -- [--result DIR] -c '<line>' | -f <file.gdsh>
  -c        run a command line (pipes, quoting and variables work)
  -f        run a .gdsh script
  --result  write the command's stdout/stderr to DIR/stdout and DIR/stderr, apart from Godot's
            own logging (the gdsh binary passes it)
~/.gdrc and res://.gdrc are sourced first (their output shows too); set GDSH_NORC to skip them."


## args is `[--result DIR] -c <line>` or `[--result DIR] -f <file>`; returns the exit code.
static func run(args:PackedStringArray) -> int:
	var result := ""
	if args.size() >= 2 and args[0] == "--result":
		result = args[1]
		args = args.slice(2)
	if args.size() != 2 or args[0] not in ["-c", "-f"]:
		return _emit(result, "", USAGE, 1)

	var root = "res://" if ResourceLoader.exists(PROJECT_HOST) else _bundled_root()
	var Host = load(root + _HOST_TAIL)
	if Host == null:
		return _emit(result, "", "gdsh: no gdsh at " + root + _HOST_TAIL, 1)
	var utils = root + _UTILS_TAIL
	var dirs = [utils] if DirAccess.dir_exists_absolute(utils) else []
	var settings = root + _SETTINGS_TAIL
	var commands = {"settings": settings} if FileAccess.file_exists(settings) else {}
	# Host resolves the user roots (rebuilt against its gdsh), so a ctx can take its scopes.
	var host = Host.new({"default_dirs": true, "command_dirs": dirs, "commands": commands})
	var ctx = Host.Context.new("gdsh cli")
	ctx.scopes.merge(host.get_scopes(), true)
	ctx.variables["$GDSH_HOST"] = "cli"
	if OS.get_environment("GDSH_NORC").is_empty():
		for rc in _rc_files():
			await Host.Execute.source_file(rc, ctx)

	if args[0] == "-c":
		await Host.Execute.execute_command_multiline(args[1], ctx)
	else:
		await Host.Execute.source_file(args[1], ctx)

	return _emit(result, Host.Context.plain_text(ctx.stdout), Host.Context.plain_text(ctx.stderr), ctx.exit_code)


## ~/.gdrc then res://.gdrc, those that exist.
static func _rc_files() -> PackedStringArray:
	var files := PackedStringArray()
	var home = OS.get_environment("HOME")
	if home.is_empty():
		home = OS.get_environment("USERPROFILE")
	for path in ["" if home.is_empty() else home.path_join(".gdrc"), "res://.gdrc"]:
		if not path.is_empty() and FileAccess.file_exists(path):
			files.append(path)
	return files


## Prints out and err, or with a result dir writes them to its stdout and stderr files (both,
## even empty: the binary reads a missing file as a failed boot). Returns code.
static func _emit(result:String, out:String, err:String, code:int) -> int:
	if not out.is_empty() and not out.ends_with("\n"):
		out += "\n"
	if not err.is_empty() and not err.ends_with("\n"):
		err += "\n"
	if result.is_empty():
		printraw(out)
		if not err.is_empty():
			printerr(err.rstrip("\n"))
		return code
	for pair in [["stdout", out], ["stderr", err]]:
		var path:String = result.path_join(pair[0])
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			printerr("gdsh: can't write %s: %s" % [path, error_string(FileAccess.get_open_error())])
			return 1
		file.store_string(pair[1])
	return code


## The bundled copy's mirror of res:// (e.g. <pkg>/vendor/), from where _BUNDLE was rewritten to.
static func _bundled_root() -> String:
	var host = _BUNDLE
	if host.is_relative_path():
		# new(): a static func has no get_script().
		host = new().get_script().resource_path.get_base_dir().path_join(host).simplify_path()
	return host.trim_suffix(_HOST_TAIL)
