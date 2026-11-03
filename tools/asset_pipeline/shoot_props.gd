extends SceneTree
## Photographs placed props in the game, for checking a batch and for the pipeline's README.
## Run with a window, not headless: godot --path . --script res://tools/asset_pipeline/shoot_props.gd -- out_dir name x z distance height angle [...]
## Each shot looks at the ground at x, z from that distance and height above the ground. Angle 0 looks from the south (+z), 90 from the east.

const SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = SIZE
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.show_menu = false
	scene.save_path = "user://shoot_props_save.json"
	root.add_child(scene)
	await _frames(60)
	var day_night: DayNight = scene.get_node("DayNight")
	day_night.hour = 11.0
	day_night.set_process(false)
	day_night._apply()
	scene.get_node("UI").visible = false
	var terrain: Terrain = scene.get_node("Terrain")
	var camera := Camera3D.new()
	camera.fov = 50.0
	scene.add_child(camera)
	camera.make_current()
	for i in range(1, args.size(), 6):
		var target := Vector3(float(args[i + 1]), 0.0, float(args[i + 2]))
		target.y = terrain.height_at(target.x, target.z) + 0.8
		var distance := float(args[i + 3])
		var angle := deg_to_rad(float(args[i + 5]))
		var eye := target + Vector3(sin(angle), 0.0, cos(angle)) * distance
		eye.y = terrain.height_at(eye.x, eye.z) + float(args[i + 4])
		camera.look_at_from_position(eye, target)
		await _frames(20)
		root.get_texture().get_image().save_jpg(out_dir.path_join(args[i] + ".jpg"), 0.85)
		print("saved ", args[i])
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame
