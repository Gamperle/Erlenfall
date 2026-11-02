class_name Forest
extends Node3D
## A dense stand of trees that an axe can fell. Trees regrow, so wood never runs out.
##
## There are too many trees for one node each, since the player checks every interactable on every
## frame. So the trees are drawn in batches, and one target moves to the tree the player faces.

const AXE_ITEM := "iron_axe"
const WOOD_ITEM := "wood"
const CHUNK_SIZE := 64.0
const LOOKUP_CELL := 8.0
const DETAIL_DISTANCE := 150.0
const STUMP_DISTANCE := 90.0
const COLLISION_RADIUS := 0.5
const COLLISION_HEIGHT := 6.0
const FALL_SECONDS := 1.3
const SINK_SECONDS := 1.0
const SINK_DEPTH := 2.0
## Trees don't pop up next to the player.
const REGROW_CLEARANCE := 12.0
const HIDDEN := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)


## What the player interacts with. It stands at the tree in front of them.
class ChopTarget:
	extends Interactable

	var forest: Forest

	func is_available() -> bool:
		return forest.has_target()

	func interact(player: Player) -> void:
		forest.chop(player)


var _strikes := 3
var _regrow_seconds := 600.0
var _wood_per_strike := 1
var _transforms: Array[Transform3D] = []
## For each tree: its batches, which draw it, and its place in them.
var _batches: Array[Array] = []
var _instance_index := PackedInt32Array()
var _collisions: Array[CollisionShape3D] = []
var _material: StandardMaterial3D
var _lookup: Dictionary = {}
## Tree number to strikes taken so far, and to seconds left until it grows back.
var _struck: Dictionary = {}
var _felled: Dictionary = {}
var _target_tree := -1
var _target: ChopTarget
var _player: Player


## Each transform stands for a tree, and `kinds` says which of `meshes` pairs of near and far meshes it uses.
func setup(data: Dictionary, transforms: Array[Transform3D], kinds: PackedByteArray, meshes: Array[Array], stump_mesh: Mesh, material: StandardMaterial3D, tints: PackedFloat32Array) -> void:
	_strikes = data["strikes"]
	_regrow_seconds = data["regrow_seconds"]
	_wood_per_strike = data["wood_per_strike"]
	_transforms = transforms
	_material = material
	_build_batches(kinds, meshes, stump_mesh, tints)
	_build_collision()
	for i in _transforms.size():
		var cell := _cell_of(_transforms[i].origin)
		if not _lookup.has(cell):
			_lookup[cell] = PackedInt32Array()
		_lookup[cell].append(i)
	_target = ChopTarget.new()
	_target.name = "ChopTarget"
	_target.forest = self
	_target.prompt_key = "PROMPT_CHOP_TREE"
	add_child(_target)


func tree_count() -> int:
	return _transforms.size()


func standing_count() -> int:
	return _transforms.size() - _felled.size()


func has_target() -> bool:
	return _target_tree >= 0


func target() -> Interactable:
	return _target


func tree_position(tree: int) -> Vector3:
	return _transforms[tree].origin


## Strikes the tree in front of the player. It takes an axe, and the swing sets the pace.
func chop(player: Player) -> void:
	if _target_tree < 0:
		return
	if player.inventory.count(AXE_ITEM) == 0:
		player.notice.emit("UI_NEED_AXE")
		return
	if not player.attack():
		return
	strike_tree(_target_tree, player)


## Public so tests can strike a chosen tree without waiting for a swing.
func strike_tree(tree: int, player: Player) -> void:
	player.inventory.add(WOOD_ITEM, _wood_per_strike)
	player.notice.emit(tr("UI_GOT_DROP") % [_wood_per_strike, CraftingData.item_name(WOOD_ITEM)])
	_struck[tree] = int(_struck.get(tree, 0)) + 1
	if _struck[tree] >= _strikes:
		_struck.erase(tree)
		_fell(tree)


func to_data() -> Dictionary:
	return { "struck": _struck.duplicate(), "felled": _felled.duplicate() }


func load_data(data: Dictionary) -> void:
	for tree: int in _felled.keys():
		_grow_back(tree)
	_struck.clear()
	# JSON turns the keys into text.
	for key: Variant in data.get("struck", {}):
		_struck[int(key)] = int(data["struck"][key])
	for key: Variant in data.get("felled", {}):
		var tree := int(key)
		if tree < _transforms.size():
			_felled[tree] = float(data["felled"][key])
			_set_tree_shown(tree, false)


func _physics_process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(Player.GROUP) as Player
		if _player == null:
			return
	_target_tree = _tree_in_front(_player)
	if _target_tree >= 0:
		_target.global_position = _transforms[_target_tree].origin


func _process(delta: float) -> void:
	for tree: int in _felled.keys():
		_felled[tree] -= delta
		if _felled[tree] <= 0.0 and (_player == null or _player.global_position.distance_to(_transforms[tree].origin) > REGROW_CLEARANCE):
			_grow_back(tree)


func _tree_in_front(player: Player) -> int:
	var at := player.global_position
	var forward := player.facing_direction()
	var reach := int(ceilf(Player.INTERACT_DISTANCE / LOOKUP_CELL))
	var center := _cell_of(at)
	var best := -1
	var best_distance := Player.INTERACT_DISTANCE
	for x in range(center.x - reach, center.x + reach + 1):
		for z in range(center.y - reach, center.y + reach + 1):
			for tree: int in _lookup.get(Vector2i(x, z), PackedInt32Array()):
				if _felled.has(tree):
					continue
				var offset := _transforms[tree].origin - at
				offset.y = 0.0
				var distance := offset.length()
				if distance < best_distance and forward.dot(offset.normalized()) > Player.INTERACT_FACING:
					best = tree
					best_distance = distance
	return best


func _cell_of(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / LOOKUP_CELL), floori(point.z / LOOKUP_CELL))


func _fell(tree: int) -> void:
	_felled[tree] = _regrow_seconds
	_set_tree_shown(tree, false)
	if tree == _target_tree:
		_target_tree = -1
	_play_fall(tree)


func _grow_back(tree: int) -> void:
	_felled.erase(tree)
	_set_tree_shown(tree, true)


func _set_tree_shown(tree: int, shown: bool) -> void:
	var transform := _transforms[tree] if shown else HIDDEN
	for batch: MultiMesh in _batches[tree]:
		batch.set_instance_transform(_instance_index[tree], transform)
	_collisions[tree].set_deferred("disabled", not shown)


## A copy of the tree tips over away from the player and sinks into the ground.
func _play_fall(tree: int) -> void:
	var batch: MultiMesh = _batches[tree][0]
	var falling := MeshInstance3D.new()
	falling.mesh = batch.mesh
	falling.material_override = _material
	falling.transform = _transforms[tree]
	add_child(falling)
	var start := _transforms[tree].basis
	var away := Vector3.RIGHT
	if _player != null:
		var offset := _transforms[tree].origin - _player.global_position
		offset.y = 0.0
		if offset.length_squared() > 0.01:
			away = offset.normalized()
	var axis := Vector3.UP.cross(away).normalized()
	var tween := falling.create_tween()
	tween.tween_method(func(angle: float) -> void: falling.basis = Basis(axis, angle) * start, 0.0, PI / 2.0 - 0.05, FALL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(falling, "position:y", falling.position.y - SINK_DEPTH, SINK_SECONDS)
	tween.tween_callback(falling.queue_free)


func _build_batches(kinds: PackedByteArray, meshes: Array[Array], stump_mesh: Mesh, tints: PackedFloat32Array) -> void:
	var chunks: Dictionary = {}
	_batches.resize(_transforms.size())
	_instance_index.resize(_transforms.size())
	for i in _transforms.size():
		var origin := _transforms[i].origin
		var key := Vector3i(floori(origin.x / CHUNK_SIZE), floori(origin.z / CHUNK_SIZE), kinds[i])
		if not chunks.has(key):
			chunks[key] = PackedInt32Array()
		chunks[key].append(i)
	for key: Vector3i in chunks:
		var trees: PackedInt32Array = chunks[key]
		var pair: Array = meshes[key.z]
		var near := _batch(trees, pair[0], tints, 0.0, DETAIL_DISTANCE)
		var far := _batch(trees, pair[1], tints, DETAIL_DISTANCE, 0.0)
		for n in trees.size():
			_batches[trees[n]] = [near, far]
			_instance_index[trees[n]] = n
	# Stumps stand under every tree, so felling one only has to hide the tree.
	_batch(PackedInt32Array(range(_transforms.size())), stump_mesh, tints, 0.0, STUMP_DISTANCE)
	(get_child(get_child_count() - 1) as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _batch(trees: PackedInt32Array, mesh: Mesh, tints: PackedFloat32Array, begin: float, end: float) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = trees.size()
	for n in trees.size():
		multimesh.set_instance_transform(n, _transforms[trees[n]])
		var tint := tints[trees[n]]
		multimesh.set_instance_color(n, Color(tint, tint, tint * 0.95))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = _material
	instance.visibility_range_begin = begin
	instance.visibility_range_end = end
	add_child(instance)
	return multimesh


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "TreeCollision"
	add_child(body)
	var shape := CylinderShape3D.new()
	shape.radius = COLLISION_RADIUS
	shape.height = COLLISION_HEIGHT
	for transform in _transforms:
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = transform.origin
		body.add_child(collision)
		_collisions.append(collision)
