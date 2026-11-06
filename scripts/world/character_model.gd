class_name CharacterModel
extends Humanoid
## A rigged model that can stand in for the simple figure. Its origin is at its feet, and it faces -Z.

const IDLE := &"Idle"
const WALK := &"Walk"
const RUN := &"Sprint"
const WALK_SPEED_LIMIT := 4.5
const MOVING_SPEED := 0.2
const BLEND_SECONDS := 0.15

## Replaces the idle animation, for example while holding a torch up or blocking.
var idle_override: StringName = &""
## How strongly the model glows is applied to a copy of each material.
var _surfaces: Array[StandardMaterial3D] = []
var _model: Node3D
var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _action_left := 0.0


func load_model(path: String) -> void:
	_model = (load(path) as PackedScene).instantiate()
	_model.name = "Model"
	# Models face +Z, and the game's characters face -Z.
	_model.rotation.y = PI
	add_child(_model)
	_skeleton = _model.find_child("GeneralSkeleton", true, false)
	_player = CharacterAnimations.play(_model, IDLE)
	add_modifier(PostureModifier.new())
	_copy_materials()


## Adds something that adjusts the skeleton after the animations.
func add_modifier(modifier: SkeletonModifier3D) -> void:
	_skeleton.add_child(modifier)


func right_hand() -> Node3D:
	return _attach(&"RightHand")


func left_hand() -> Node3D:
	return _attach(&"LeftHand")


## Plays an animation once, then returns to moving or standing.
## A duration fits it to that time, and a start skips that share of its beginning.
func play_action(animation_name: StringName, duration := 0.0, start := 0.0) -> void:
	var length := _player.get_animation(animation_name).length
	var seconds := duration if duration > 0.0 else length
	_player.play(animation_name, BLEND_SECONDS, length * (1.0 - start) / seconds)
	_player.seek(length * start)
	_action_left = seconds


func animate(speed: float, delta: float) -> void:
	if _action_left > 0.0:
		_action_left -= delta
		return
	var wanted := idle_override if idle_override != &"" else IDLE
	if speed > WALK_SPEED_LIMIT:
		wanted = RUN
	elif speed > MOVING_SPEED:
		wanted = WALK
	if _player.current_animation != wanted:
		_player.play(wanted, BLEND_SECONDS)


func set_glow(color: Color, amount: float) -> void:
	for material in _surfaces:
		material.emission_enabled = amount > 0.0
		material.emission = color
		material.emission_energy_multiplier = amount


func _attach(bone: StringName) -> Node3D:
	var attachment := _skeleton.get_node_or_null(String(bone)) as BoneAttachment3D
	if attachment == null:
		attachment = BoneAttachment3D.new()
		attachment.name = bone
		attachment.bone_name = bone
		_skeleton.add_child(attachment)
	return attachment


func _copy_materials() -> void:
	for mesh_instance: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
			if material != null:
				mesh_instance.set_surface_override_material(surface, material)
				_surfaces.append(material)
