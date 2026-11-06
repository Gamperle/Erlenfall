extends Node3D
## Lays every generated prop out on flat ground beside a 2 m measuring pole, so their size can be
## judged against the player and corrected. Walk up to a prop to select it, then:
##   Up / Down       raise or lower it by 1 cm (with Ctrl: 10 cm)
##   Right / Left    make it 2% bigger or smaller (with Ctrl: 10%)
##   G               set it on the ground, so its lowest point touches it
##   Backspace       undo every correction to it
##   Escape          quit
## Every change is saved to data/prop_tuning.json at once, and the village uses it.
## Open tools/prop_tuner/prop_tuner.tscn in the editor and press F6, or run:
## godot --path . tools/prop_tuner/prop_tuner.tscn

const PROP_FOLDER := "res://assets/props/"
const COLUMNS := 8
const CELL := 5.0
const SELECT_DISTANCE := 3.5
const LIFT_STEP := 0.01
const SCALE_STEP := 1.02
const COARSE := 10
const POLE_HEIGHT := 2.0
const POLE_BAND := 0.25
const POLE_COLORS: Array[Color] = [Color(0.8, 0.15, 0.1), Color(0.95, 0.95, 0.9)]
const LABEL_COLOR := Color(1, 1, 1)
const SELECTED_COLOR := Color(1, 0.85, 0.2)
const GROUND_SIZE := 200.0

var _props: Array[Dictionary] = []
var _selected := -1

@onready var _player: Player = $Player
@onready var _info: Label = $UI/Info


func _ready() -> void:
	PropTuning.reload()
	_add_ground()
	var names: Array[String] = []
	for file in DirAccess.get_files_at(PROP_FOLDER):
		# Exported builds list the import files instead.
		var name := file.trim_suffix(".import")
		if name.ends_with(".glb") and not names.has(name.get_basename()):
			names.append(name.get_basename())
	names.sort()
	for i in names.size():
		var spot := Vector3((i % COLUMNS - (COLUMNS - 1) / 2.0) * CELL, 0.0, -(i / COLUMNS) * CELL - CELL)
		_add_prop(names[i], spot)
	_player.position = Vector3(0, 0.1, 2.0)
	_update_info()


func _process(_delta: float) -> void:
	var nearest := -1
	var best := SELECT_DISTANCE
	for i in _props.size():
		var distance := Vector2(_player.position.x, _player.position.z).distance_to(
			Vector2(_props[i]["spot"].x, _props[i]["spot"].z))
		if distance < best:
			best = distance
			nearest = i
	if nearest != _selected:
		_selected = nearest
		for i in _props.size():
			_props[i]["label"].modulate = SELECTED_COLOR if i == _selected else LABEL_COLOR
			# Only the selected label shows through other props.
			_props[i]["label"].no_depth_test = i == _selected
		_update_info()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().quit()
		return
	if _selected < 0 or not event is InputEventKey or not event.pressed:
		return
	var prop := _props[_selected]
	var entry := PropTuning.get_entry(prop["name"])
	var scale: float = entry["scale"]
	var lift: float = entry["lift"]
	var steps := COARSE if event.ctrl_pressed else 1
	match event.keycode:
		KEY_UP:
			lift += LIFT_STEP * steps
		KEY_DOWN:
			lift -= LIFT_STEP * steps
		KEY_RIGHT:
			scale *= pow(SCALE_STEP, steps)
		KEY_LEFT:
			scale /= pow(SCALE_STEP, steps)
		KEY_G:
			lift = -_bottom(prop["model"]) * scale
		KEY_BACKSPACE:
			scale = 1.0
			lift = 0.0
		_:
			return
	get_viewport().set_input_as_handled()
	PropTuning.set_entry(prop["name"], scale, lift)
	_place(prop)
	_update_info()


func _add_ground() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(GROUND_SIZE, 1.0, GROUND_SIZE)
	shape.position.y = -0.5
	ground.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = PlaneMesh.new()
	mesh.mesh.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	var material := StandardMaterial3D.new()
	material.albedo_texture = _grid_texture()
	material.uv1_scale = Vector3(GROUND_SIZE, GROUND_SIZE, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mesh.material_override = material
	ground.add_child(mesh)
	add_child(ground)


## A 1 m square with a darker line along two edges, so the ground shows a meter grid.
func _grid_texture() -> ImageTexture:
	var image := Image.create(64, 64, true, Image.FORMAT_RGB8)
	image.fill(Color(0.55, 0.6, 0.5))
	for i in 64:
		for line in 2:
			image.set_pixel(i, line, Color(0.3, 0.33, 0.28))
			image.set_pixel(line, i, Color(0.3, 0.33, 0.28))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _add_prop(name: String, spot: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = name
	holder.position = spot
	add_child(holder)
	var model: Node3D = load(PROP_FOLDER + name + ".glb").instantiate()
	holder.add_child(model)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_size = 12
	holder.add_child(label)
	holder.add_child(_pole(Vector3(CELL / 2.0 - 0.6, 0.0, 0.0)))
	var prop := { "name": name, "spot": spot, "model": model, "label": label }
	_props.append(prop)
	_place(prop)


func _pole(at: Vector3) -> Node3D:
	var pole := Node3D.new()
	pole.position = at
	for band in int(POLE_HEIGHT / POLE_BAND):
		var piece := MeshInstance3D.new()
		piece.mesh = BoxMesh.new()
		piece.mesh.size = Vector3(0.06, POLE_BAND, 0.06)
		piece.position.y = (band + 0.5) * POLE_BAND
		var material := StandardMaterial3D.new()
		material.albedo_color = POLE_COLORS[band % 2]
		piece.material_override = material
		pole.add_child(piece)
	return pole


## Applies the prop's saved correction and moves its label above it.
func _place(prop: Dictionary) -> void:
	var model: Node3D = prop["model"]
	model.position = Vector3.ZERO
	PropTuning.apply(model, prop["name"])
	var entry := PropTuning.get_entry(prop["name"])
	var top := (_top(model) * float(entry["scale"])) + float(entry["lift"])
	prop["label"].position.y = maxf(top, POLE_HEIGHT) + 0.4
	prop["label"].text = "%s\n%.2f x  %+.2f m" % [prop["name"], entry["scale"], entry["lift"]]


func _update_info() -> void:
	var text := "Walk up to a prop to select it.\nUp/Down: height 1 cm   Right/Left: size 2%   Ctrl: 10 times as much\nG: set on ground   Backspace: reset   Escape: quit\nThe pole is 2 m, in 25 cm bands. The ground grid is 1 m."
	if _selected >= 0:
		var prop := _props[_selected]
		var entry := PropTuning.get_entry(prop["name"])
		var height := (_top(prop["model"]) - _bottom(prop["model"])) * float(entry["scale"])
		var bottom := _bottom(prop["model"]) * float(entry["scale"]) + float(entry["lift"])
		text = "%s: %.0f%% size, %.2f m tall, lowest point %+.2f m\n\n%s" % [prop["name"], float(entry["scale"]) * 100.0, height, bottom, text]
	_info.text = text


## The lowest and highest points of a model at scale 1, from its meshes.
func _bottom(model: Node3D) -> float:
	return _mesh_bounds(model).position.y


func _top(model: Node3D) -> float:
	return _mesh_bounds(model).end.y


func _mesh_bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		# Relative to the model itself, so its own scale and lift don't count.
		var box: AABB = (model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
