extends SceneTree
## Shows each character in a folder in turn and takes screenshots from 8 angles around it.
## Saves each view, plus one sheet per character with all the views.
## Run from the project folder, with an optional animation library that has an "Idle" animation:
## godot --path . --script res://tools/character_pipeline/turntable.gd -- <models folder> <output folder> [animation library]

const ANGLES := 8
const VIEW_SIZE := Vector2i(480, 720)
const SHEET_COLUMNS := 4
const CAMERA_DISTANCE := 3.1
const CAMERA_HEIGHT := 0.95
const CAMERA_FOV := 40.0
const SETTLE_FRAMES := 5
## Applied to both the Spine and Chest bones.
const BACK_CORRECTION_DEGREES := 8.0
const ANGLE_NAMES: Array[String] = ["front", "front_left", "left", "back_left", "back", "back_right", "right", "front_right"]
const BACKGROUND := Color(0.5, 0.56, 0.6)
const FLOOR_COLOR := Color(0.35, 0.36, 0.35)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 2:
		push_error("Usage: -- <models folder> <output folder> [animation library]")
		quit(1)
		return
	var models := arguments[0]
	var output := arguments[1]
	DirAccess.make_dir_recursive_absolute(output)

	root.size = VIEW_SIZE
	var stage := _build_stage()
	var camera: Camera3D = stage.get_node("Camera")
	var library := _load_animations(arguments[2]) if arguments.size() > 2 else null

	var names := DirAccess.get_files_at(models)
	names.sort()
	var shown := 0
	for file_name in names:
		if not (file_name.ends_with(".glb") or file_name.ends_with(".gltf")):
			continue
		var person: Node3D = (load(models.path_join(file_name)) as PackedScene).instantiate()
		stage.add_child(person)
		_pose(person, library)
		await _shoot(file_name.get_basename(), camera, output)
		stage.remove_child(person)
		person.queue_free()
		shown += 1
	print("Saved %d characters to %s" % [shown, output])
	quit(0 if shown > 0 else 1)


## The camera circles the character, and the lights stay fixed on the camera so every view is lit the same way.
func _shoot(person_name: String, camera: Camera3D, output: String) -> void:
	var rows := ceili(float(ANGLES) / SHEET_COLUMNS)
	var sheet := Image.create(VIEW_SIZE.x * SHEET_COLUMNS, VIEW_SIZE.y * rows, false, Image.FORMAT_RGB8)
	for index in ANGLES:
		var angle := TAU * index / ANGLES
		camera.position = Vector3(sin(angle) * CAMERA_DISTANCE, CAMERA_HEIGHT, cos(angle) * CAMERA_DISTANCE)
		camera.rotation = Vector3(0.0, angle, 0.0)
		for frame in SETTLE_FRAMES:
			await process_frame
		await RenderingServer.frame_post_draw
		var view := root.get_texture().get_image()
		view.convert(Image.FORMAT_RGB8)
		view.save_png(output.path_join("%s_%d_%s.png" % [person_name, index, ANGLE_NAMES[index]]))
		var at := Vector2i(index % SHEET_COLUMNS * VIEW_SIZE.x, index / SHEET_COLUMNS * VIEW_SIZE.y)
		sheet.blit_rect(view, Rect2i(Vector2i.ZERO, VIEW_SIZE), at)
	sheet.save_png(output.path_join("%s_sheet.png" % person_name))
	print("%s: %d views" % [person_name, ANGLES])


func _pose(person: Node3D, library: AnimationLibrary) -> void:
	if library == null:
		return
	var player := AnimationPlayer.new()
	person.add_child(player)
	player.owner = person
	player.root_node = NodePath("..")
	player.add_animation_library("", library)
	player.play("Idle")
	player.seek(0.0, true)
	player.pause()


func _load_animations(path: String) -> AnimationLibrary:
	var source: Node = (load(path) as PackedScene).instantiate()
	var player: AnimationPlayer = source.find_child("AnimationPlayer", true, false)
	var library := _straightened(player.get_animation_library(""))
	source.free()
	return library


## Tilts the back in every animation, because transferred animations lean these bodies too far forward.
func _straightened(library: AnimationLibrary) -> AnimationLibrary:
	var result := AnimationLibrary.new()
	var correction := Quaternion(Vector3.RIGHT, deg_to_rad(-BACK_CORRECTION_DEGREES))
	for animation_name in library.get_animation_list():
		var animation: Animation = library.get_animation(animation_name).duplicate(true)
		for track in animation.get_track_count():
			var path := String(animation.track_get_path(track))
			if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D and (path.ends_with(":Spine") or path.ends_with(":Chest")):
				for key in animation.track_get_key_count(track):
					animation.track_set_key_value(track, key, correction * animation.track_get_key_value(track, key))
		result.add_animation(animation_name, animation)
	return result


func _build_stage() -> Node3D:
	var stage := Node3D.new()
	root.add_child(stage)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.55
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(12.0, 12.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = FLOOR_COLOR
	floor_mesh.material = floor_material
	var ground := MeshInstance3D.new()
	ground.mesh = floor_mesh
	stage.add_child(ground)

	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.fov = CAMERA_FOV
	camera.current = true
	stage.add_child(camera)

	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.7, 0.45, 0.0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	camera.add_child(light)
	return stage
