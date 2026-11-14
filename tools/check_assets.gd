extends SceneTree
## Checks that every file under assets/ has a source and license row in ASSETS.md, and that
## every row names files that exist. Usage:
##   godot --headless --path . --script res://tools/check_assets.gd
## Run it after `godot --headless --path . --import`, which writes the textures that rows such as
## `assets/props/*.png` describe. Exits with 1 if anything is wrong.


func _init() -> void:
	var problems := AssetLedger.problems()
	for problem in problems:
		printerr(problem)
	print("%d problem(s) in ASSETS.md" % problems.size())
	quit(1 if not problems.is_empty() else 0)
