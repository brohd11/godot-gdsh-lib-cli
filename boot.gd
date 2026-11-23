extends SceneTree
## Entry point of the gdsh CLI, installed unpacked in ~/.gdsh/cli (a relative-path export, so it
## runs from outside the project):
##     godot --headless --path <project> --script ~/.gdsh/cli/boot.gd -- -c '<line>' | -f <file.gdsh>

const Run = preload("res://addons/_lib/gdsh_lib/cli/src/run.gd")


func _initialize() -> void:
	# root isn't inside the tree during _initialize, so node lookups would error.
	await process_frame
	quit(await Run.run(OS.get_cmdline_user_args()))
