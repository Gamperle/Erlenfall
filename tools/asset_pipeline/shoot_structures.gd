extends SceneTree
## Photographs the code-built structures of StructureBuilder (#436) on a flat ground, from the front-right and the back-left.
## Run with a window, not headless:
##   godot --path . --script res://tools/asset_pipeline/shoot_structures.gd -- out_dir
## Writes one JPG per structure and angle.

const SIZE := Vector2i(900, 650)
## kind, width, depth, height, color, variant
const SHOTS: Array = [
	["smithy_forge_shed", 5.0, 3.6, 3.2, "#5f5852", 0],
	["lumber_shed", 7.0, 4.0, 3.0, "#6b5a45", 0],
	["sawmill_lean_to", 6.0, 4.0, 3.0, "#6b5a45", 0],
	["carpenter_workshop", 8.0, 6.0, 3.4, "#8a6f52", 0],
	["small_barn", 7.0, 5.5, 3.2, "#7a4a38", 0],
	["small_barn", 7.0, 5.5, 3.2, "#74503a", 1],
	["small_barn", 7.0, 5.5, 3.2, "#7d523c", 2],
	["granary", 3.6, 3.0, 3.2, "#6e5238", 0],
	["tool_shed", 2.4, 2.0, 2.1, "#6a5340", 0],
	["tool_shed", 2.4, 2.0, 2.1, "#5d4a38", 1],
	["ore_chute", 2.4, 5.0, 3.2, "#6a5340", 0],
	["rails", 0, 0, 0, "#000000", 0],
	["entrance", 0, 0, 0, "#000000", 0],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = SIZE
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.62, 0.72)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.75)
	environment.ambient_light_energy = 0.7
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	root.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := ModelBuilder.box(Vector3(60, 0.2, 60), Surfaces.Pattern.CROPS, Color(0.3, 0.4, 0.2), Vector3(0, -0.1, 0))
	root.add_child(ground)
	var camera := Camera3D.new()
	camera.fov = 45.0
	root.add_child(camera)
	camera.make_current()
	var index := 0
	for shot: Array in SHOTS:
		var model: Node3D
		if shot[0] == "rails":
			model = Node3D.new()
			var at := Transform3D.IDENTITY
			for turn: float in [0.0, 0.0, 0.35, 0.35, 0.0, -0.35, 0.0]:
				var piece := StructureBuilder.rail_track(turn)
				piece.transform = at
				model.add_child(piece)
				at = at * StructureBuilder.rail_end(turn)
		elif shot[0] == "entrance":
			model = StructureBuilder.mine_timber_entrance(4.0, 3.6)
			var rock := ModelBuilder.box(Vector3(14, 8, 3), Surfaces.Pattern.BOULDER, Color(0.36, 0.34, 0.32), Vector3(0, 4, -2))
			model.add_child(rock)
			model.add_child(ModelBuilder.box(Vector3(4, 3.6, 0.3), Surfaces.Pattern.BOULDER, Color(0.02, 0.02, 0.02), Vector3(0, 1.8, -0.4)))
		else:
			model = StructureBuilder.build(shot[0], shot[1], shot[2], shot[3], Color(shot[4]), shot[5])
		root.add_child(model)
		var box := AABB()
		var first := true
		for mesh_instance in model.find_children("*", "MeshInstance3D", true, false):
			var part: AABB = mesh_instance.global_transform * (mesh_instance as MeshInstance3D).get_aabb()
			box = part if first else box.merge(part)
			first = false
		box.position.y = maxf(box.position.y, 0.0)
		box.size.y = box.end.y - box.position.y
		var center := box.get_center()
		var distance := box.size.length() * 1.2
		var angles: Array = [Vector3(0.6, 0.4, 1.0), Vector3(-0.8, 0.5, -1.0)]
		for a in angles.size():
			camera.look_at_from_position(center + (angles[a] as Vector3).normalized() * distance, center)
			for j in 4:
				await process_frame
			var name := "%02d_%s_v%d_%d.jpg" % [index, shot[0], shot[5], a]
			root.get_texture().get_image().save_jpg(out_dir.path_join(name), 0.9)
			print("saved ", name)
		model.queue_free()
		await process_frame
		index += 1
	quit()
