class_name CharacterModel
extends Humanoid
## A rigged model that can stand in for the simple figure. Its origin is at its feet, and it faces -Z.

const IDLE := &"Idle"
const WALK := &"Walk"
const RUN := &"Sprint"
const CROUCH_IDLE := &"Crouch_Idle"
const CROUCH_WALK := &"Crouch_Fwd"
const WALK_SPEED_LIMIT := 4.5
const MOVING_SPEED := 0.2
const BLEND_SECONDS := 0.15
## Parts no larger than this (eyes, eyebrows) are too small to cast a visible shadow,
## or to be seen from far away.
const DETAIL_SIZE := 0.12
const DETAIL_RANGE := 20.0

## Replaces the idle animation, for example while holding a torch up or blocking.
var idle_override: StringName = &""
## Sneaking: crouches while standing, and walks in a crouch at `crouch_speed` times the usual pace.
var crouched := false
var crouch_speed := 0.8
## Straightens the back, neck, and shoulders.
var posture: PostureModifier
## How strongly the model glows is applied to a copy of each material.
var _surfaces: Array[StandardMaterial3D] = []
var _model: Node3D
var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _action_left := 0.0

## Meshes with their same-material surfaces joined, shared by every character of a model.
static var _joined_meshes := {}


func load_model(path: String) -> void:
	_model = (load(path) as PackedScene).instantiate()
	_model.name = "Model"
	# Models face +Z, and the game's characters face -Z.
	_model.rotation.y = PI
	add_child(_model)
	_skeleton = _model.find_child("GeneralSkeleton", true, false)
	_player = CharacterAnimations.play(_model, IDLE)
	posture = PostureModifier.new()
	add_modifier(posture)
	_join_surfaces()
	_copy_materials()
	_reduce_draw_calls()


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
	_player.speed_scale = 1.0
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
	var crouching := crouched and wanted != RUN and _player.has_animation(CROUCH_IDLE) and _player.has_animation(CROUCH_WALK)
	if crouching:
		wanted = CROUCH_WALK if speed > MOVING_SPEED else CROUCH_IDLE
	_player.speed_scale = crouch_speed if crouching and wanted == CROUCH_WALK else 1.0
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


## Surfaces that look the same (the body's skin, lips, nails and ears share one material)
## become one surface, which is one draw call instead of several.
func _join_surfaces() -> void:
	for mesh_instance: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_instance.mesh as ArrayMesh
		if mesh == null or mesh.get_surface_count() < 2 or mesh.get_blend_shape_count() > 0:
			continue
		if not _joined_meshes.has(mesh):
			_joined_meshes[mesh] = _join(mesh)
		mesh_instance.mesh = _joined_meshes[mesh]


func _join(mesh: ArrayMesh) -> ArrayMesh:
	var groups := {}
	for surface in mesh.get_surface_count():
		var key := _material_key(mesh.surface_get_material(surface))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(surface)
	if groups.size() == mesh.get_surface_count():
		return mesh
	var joined := ArrayMesh.new()
	for surfaces: Array in groups.values():
		var arrays: Array = mesh.surface_get_arrays(surfaces[0])
		for index in range(1, surfaces.size()):
			var more: Array = mesh.surface_get_arrays(surfaces[index])
			var offset := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			for kind in arrays.size():
				if kind == Mesh.ARRAY_INDEX:
					var indices: PackedInt32Array = more[kind]
					for i in indices.size():
						indices[i] += offset
					arrays[kind] = (arrays[kind] as PackedInt32Array) + indices
				elif arrays[kind] != null:
					arrays[kind] = _append(arrays[kind], more[kind])
		joined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		joined.surface_set_material(joined.get_surface_count() - 1, mesh.surface_get_material(surfaces[0]))
	joined.custom_aabb = mesh.get_aabb()
	return joined


func _append(first: Variant, second: Variant) -> Variant:
	var result = first
	result.append_array(second)
	return result


func _material_key(material: Material) -> String:
	var standard := material as StandardMaterial3D
	if standard == null:
		return str(material.get_instance_id())
	var textures: Array[String] = []
	for slot in BaseMaterial3D.TEXTURE_MAX:
		var texture := standard.get_texture(slot as BaseMaterial3D.TextureParam)
		textures.append(texture.resource_path if texture != null else "")
	return "%s|%s|%d|%d|%s|%s|%s|%s" % [textures, standard.albedo_color, standard.transparency, standard.cull_mode, standard.roughness, standard.metallic, standard.uv1_scale, standard.alpha_scissor_threshold]


func _copy_materials() -> void:
	for mesh_instance: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
			if material != null:
				mesh_instance.set_surface_override_material(surface, material)
				_surfaces.append(material)


## Every surface of every mesh is a draw call, and again in each shadow pass. Tiny parts skip
## their shadow and vanish in the distance, and the body casts its shadow from one surface
## instead of one each for its lips, nails and ears.
func _reduce_draw_calls() -> void:
	for mesh_instance: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_instance.mesh as ArrayMesh
		if mesh == null:
			continue
		if _largest(mesh.get_aabb().size) < DETAIL_SIZE:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh_instance.visibility_range_end = DETAIL_RANGE
		elif mesh.get_surface_count() > 1:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var caster := MeshInstance3D.new()
			caster.name = mesh_instance.name + "Shadow"
			var shadow_mesh := ArrayMesh.new()
			shadow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(0))
			shadow_mesh.custom_aabb = mesh.get_aabb()
			caster.mesh = shadow_mesh
			caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			mesh_instance.get_parent().add_child(caster)
			caster.skin = mesh_instance.skin
			caster.skeleton = caster.get_path_to(mesh_instance.get_node(mesh_instance.skeleton))


func _largest(size: Vector3) -> float:
	return maxf(size.x, maxf(size.y, size.z))
