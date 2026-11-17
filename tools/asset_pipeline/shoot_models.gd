extends SceneTree
## Photographs single prop models up close on a grey backdrop, for comparing texture changes (#426).
## Run with a window, not headless:
##   godot --path . --script res://tools/asset_pipeline/shoot_models.gd -- out_dir bucket_1 bowl_1 [...]
## Each model is shot from the front-right and slightly above, filling the frame, one JPG per model.

const SIZE := Vector2i(900, 700)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = SIZE
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.45, 0.47, 0.5)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.75)
	environment.ambient_light_energy = 0.6
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	root.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	root.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 40.0
	root.add_child(camera)
	camera.make_current()
	for i in range(1, args.size()):
		var model: Node3D = (load("res://assets/props/%s.glb" % args[i]) as PackedScene).instantiate()
		root.add_child(model)
		var box := AABB()
		var first := true
		for mesh_instance in model.find_children("*", "MeshInstance3D", true, false):
			var part: AABB = mesh_instance.global_transform * (mesh_instance as MeshInstance3D).get_aabb()
			box = part if first else box.merge(part)
			first = false
		var center := box.get_center()
		var distance := box.size.length() * 1.15
		camera.look_at_from_position(center + Vector3(0.6, 0.45, 1.0).normalized() * distance, center)
		for j in 6:
			await process_frame
		root.get_texture().get_image().save_jpg(out_dir.path_join(args[i] + ".jpg"), 0.92)
		print("saved ", args[i])
		model.queue_free()
		await process_frame
	quit()
