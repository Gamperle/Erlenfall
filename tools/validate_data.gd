extends SceneTree
## Checks a data folder for mistakes. Usage:
##   godot --headless --path . --script res://tools/validate_data.gd -- [folder] [base folder]
## With no folder it checks the game's own data. For a mod, give its folder, and the game's data
## folder as the base so its references to the game's items and quests are understood.
## Exits with 1 if anything is wrong.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else DataValidator.DATA_DIR
	var base: String = args[1] if args.size() > 1 else ""
	var problems := DataValidator.validate_directory(dir, base)
	for problem in problems:
		printerr(problem)
	print("%d problem(s) in %s" % [problems.size(), dir])
	quit(1 if not problems.is_empty() else 0)
