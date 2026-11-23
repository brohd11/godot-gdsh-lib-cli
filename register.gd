extends SceneTree
## Registers the running Godot binary in ~/.gdsh/executables under its version, so the gdsh
## wrapper can pick the one matching each project. Needs no project; run it from a dir without a
## project.godot, or Godot loads that project too:
##     <godot> --headless --script ~/.gdsh/cli/register.gd
## `gdsh --register [<godot>]` runs this.

const REGISTRY_FILE = "executables"


func _initialize() -> void:
	quit(0 if _register() else 1)


## Upserts `godot-<ver>[-mono]: <exe>`; one line per key.
func _register() -> bool:
	var info = Engine.get_version_info()
	var key = "godot-%d.%d.%d" % [info.major, info.minor, info.patch]
	if ClassDB.class_exists("CSharpScript"):
		key += "-mono"
	var exe = OS.get_executable_path()
	# The GUI exe doesn't hand a terminal its stdout; its _console sibling does.
	var console_exe = exe.get_basename() + "_console.exe"
	if OS.get_name() == "Windows" and not exe.ends_with("_console.exe") and FileAccess.file_exists(console_exe):
		exe = console_exe

	var home = OS.get_environment("GDSH_HOME")
	if home == "":
		home = OS.get_environment("USERPROFILE" if OS.get_name() == "Windows" else "HOME").path_join(".gdsh")
	var registry = home.path_join(REGISTRY_FILE)
	var lines:PackedStringArray = []
	if FileAccess.file_exists(registry):
		for line in FileAccess.get_file_as_string(registry).split("\n"):
			line = line.strip_edges()
			if line != "" and not line.begins_with(key + ": "):
				lines.append(line)
	lines.append(key + ": " + exe)

	var err = DirAccess.make_dir_recursive_absolute(home)
	var file = FileAccess.open(registry, FileAccess.WRITE) if err == OK else null
	if file == null:
		printerr("Can't write %s: %s" % [registry, error_string(err if err != OK else FileAccess.get_open_error())])
		return false
	file.store_string("\n".join(lines) + "\n")
	print("Registered %s: %s" % [key, exe])
	return true
