class_name AmbientLife
extends Node3D
## Small animated life that follows the time of day: birds that circle high above by day, butterflies
## over lush grass by day, and fireflies over lush grass and the river at night. Each kind is one
## MultiMesh, a single draw call with no shadows and no collision, and only the part around the camera
## is ever placed, so the cost stays the same however big the valley is. Graphics settings change how
## many of each are shown.

const GROUP := "ambient_life"
## Ground drier than this has no butterflies or fireflies. Lush grass is the low end of Surfaces.ground_dryness.
const LUSH_DRYNESS := 0.35
## How far from the camera the nearest and furthest small creatures settle.
const NEAR_RADIUS := 6.0
const FAR_RADIUS := 45.0
## A creature this far from the camera finds a new home near it.
const LEAVE_RADIUS := 60.0
const SETTLE_ATTEMPTS := 10
const RIVER_GLOW_DISTANCE := 6.0
const WANDER_RADIUS := 2.5
const BIRD_RADIUS := Vector2(55.0, 140.0)
const BIRD_HEIGHT := Vector2(28.0, 48.0)
const BIRD_COLOR := Color(0.08, 0.08, 0.1)
const BUTTERFLY_COLORS: Array[Color] = [Color(0.95, 0.75, 0.2), Color(0.95, 0.95, 0.9), Color(0.4, 0.6, 0.95), Color(0.9, 0.45, 0.2)]
const FIREFLY_COLOR := Color(0.75, 1.0, 0.3)
const FIREFLY_SIZE := 0.12
## Share of each kind's full count that is shown on each graphics level.
const SHARE_BY_GRAPHICS := { "low": 0.4, "medium": 0.7, "high": 1.0 }

var terrain: Terrain

var _time := 0.0
var _graphics := ""
var _day_night: DayNight
var _rng := RandomNumberGenerator.new()
var _birds := _Kind.new()
var _butterflies := _Kind.new()
var _fireflies := _Kind.new()


class _Kind:
	var node: MultiMeshInstance3D
	var multimesh: MultiMesh
	var anchors := PackedVector3Array()
	var phases := PackedFloat32Array()
	var settled: Array[bool] = []
	var shown := 0
	var full_count := 0


func _ready() -> void:
	add_to_group(GROUP)
	_rng.seed = 258
	if terrain == null:
		terrain = get_parent().terrain if get_parent() != null and "terrain" in get_parent() else null
	Surfaces.prepare_ground_dryness()
	_setup_kind(_birds, _bird_mesh(), _vertex_color_material(true), int(FeatureFlags.value("ambient_bird_count", 12)), "Birds")
	_setup_kind(_butterflies, _butterfly_mesh(), _vertex_color_material(true), int(FeatureFlags.value("ambient_butterfly_count", 30)), "Butterflies")
	_setup_kind(_fireflies, _firefly_mesh(), _firefly_material(), int(FeatureFlags.value("ambient_firefly_count", 50)), "Fireflies")
	for index in _birds.full_count:
		_birds.phases[index] = _rng.randf() * TAU
		var radius := _rng.randf_range(BIRD_RADIUS.x, BIRD_RADIUS.y)
		_birds.anchors[index] = Vector3(radius, _rng.randf_range(BIRD_HEIGHT.x, BIRD_HEIGHT.y), _rng.randf_range(0.04, 0.09) * (1.0 if _rng.randf() < 0.5 else -1.0))
	_apply_graphics()


func _process(delta: float) -> void:
	_time += delta
	if _graphics != Settings.graphics:
		_apply_graphics()
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		update_around(camera.global_position)


## The share of the day that is light, from 0 at night to 1 at midday.
func daylight() -> float:
	if _day_night == null or not is_instance_valid(_day_night):
		_day_night = get_tree().get_first_node_in_group(DayNight.GROUP) as DayNight
	return 1.0 if _day_night == null else _day_night.daylight()


## Moves everything for the current time around this point. Called every frame with the camera.
func update_around(center: Vector3) -> void:
	var light := daylight()
	var day_share := smoothstep(0.25, 0.7, light)
	var night_share := 1.0 - smoothstep(0.05, 0.4, light)
	_birds.node.visible = day_share > 0.0 and _birds.shown > 0
	_butterflies.node.visible = day_share > 0.0 and _butterflies.shown > 0
	_fireflies.node.visible = night_share > 0.0 and _fireflies.shown > 0
	if _birds.node.visible:
		_move_birds(center)
	if _butterflies.node.visible:
		_move_small(_butterflies, center, day_share, false)
	if _fireflies.node.visible:
		_move_small(_fireflies, center, night_share, true)


## How many of each kind are drawn right now, which is zero for the ones that sleep at this hour.
func drawn_counts() -> Dictionary:
	return {
		"birds": _birds.shown if _birds.node.visible else 0,
		"butterflies": _butterflies.shown if _butterflies.node.visible else 0,
		"fireflies": _fireflies.shown if _fireflies.node.visible else 0,
	}


func full_counts() -> Dictionary:
	return { "birds": _birds.full_count, "butterflies": _butterflies.full_count, "fireflies": _fireflies.full_count }


func _setup_kind(kind: _Kind, mesh: Mesh, material: Material, count: int, node_name: String) -> void:
	kind.full_count = maxi(count, 0)
	kind.anchors.resize(kind.full_count)
	kind.phases.resize(kind.full_count)
	kind.settled.resize(kind.full_count)
	kind.settled.fill(false)
	kind.multimesh = MultiMesh.new()
	kind.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	kind.multimesh.use_colors = true
	kind.multimesh.mesh = mesh
	kind.multimesh.instance_count = kind.full_count
	for index in kind.full_count:
		kind.multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		kind.phases[index] = _rng.randf() * TAU
	kind.node = MultiMeshInstance3D.new()
	kind.node.name = node_name
	kind.node.multimesh = kind.multimesh
	kind.node.material_override = material
	kind.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The creatures wander far from the node's origin, so the box that culls them has to be big.
	kind.node.extra_cull_margin = 16384.0
	add_child(kind.node)


func _apply_graphics() -> void:
	_graphics = Settings.graphics
	var share: float = SHARE_BY_GRAPHICS.get(_graphics, 1.0)
	for kind: _Kind in [_birds, _butterflies, _fireflies]:
		kind.shown = ceili(kind.full_count * share)
		kind.multimesh.visible_instance_count = kind.shown


func _move_birds(center: Vector3) -> void:
	for index in _birds.shown:
		var orbit := _birds.anchors[index]
		var angle := _birds.phases[index] + _time * orbit.z
		var flat := Vector2(center.x, center.z) + Vector2(cos(angle), sin(angle)) * orbit.x
		var height := _ground(flat.x, flat.y) + orbit.y + sin(_time * 0.4 + _birds.phases[index]) * 3.0
		# A bird flies along its circle, so it looks the way the circle turns.
		var heading := -angle if orbit.z > 0.0 else -angle + PI
		var flap := 0.25 + absf(sin(_time * 7.0 + _birds.phases[index] * 3.0)) * 0.75
		var basis := Basis(Vector3.UP, heading) * Basis.from_scale(Vector3(1.0, flap, 1.0))
		_birds.multimesh.set_instance_transform(index, Transform3D(basis, Vector3(flat.x, height, flat.y)))
		_birds.multimesh.set_instance_color(index, BIRD_COLOR)


func _move_small(kind: _Kind, center: Vector3, share: float, glows: bool) -> void:
	for index in kind.shown:
		if not kind.settled[index] or Vector2(kind.anchors[index].x - center.x, kind.anchors[index].z - center.z).length() > LEAVE_RADIUS:
			kind.settled[index] = _settle(kind, index, center, glows)
		if not kind.settled[index]:
			kind.multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		var phase := kind.phases[index]
		var home := kind.anchors[index]
		var t := _time * (0.45 if glows else 0.8) + phase
		var offset := Vector3(sin(t * 1.3) + sin(t * 0.7 + 2.0) * 0.6, sin(t * 0.9 + 1.0) * 0.4, cos(t * 1.1) + sin(t * 0.5) * 0.6) * (WANDER_RADIUS * 0.5)
		var at := home + offset
		at.y = _ground(at.x, at.z) + (0.7 if not glows else 0.9) + offset.y + 0.6
		if glows:
			# A firefly blinks slowly, and is only drawn while it glows.
			var glow := clampf(sin(_time * 1.6 + phase * 5.0) * 1.4, 0.0, 1.0) * share
			kind.multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * maxf(glow, 0.001)), at))
			kind.multimesh.set_instance_color(index, FIREFLY_COLOR)
		else:
			var heading := atan2(cos(t * 1.3) + cos(t * 0.7 + 2.0) * 0.5, -sin(t * 1.1))
			var flap := absf(cos(_time * 14.0 + phase * 4.0))
			var size := share * (0.8 + 0.4 * fmod(phase, 1.0))
			var basis := Basis(Vector3.UP, heading) * Basis.from_scale(Vector3(flap * size + 0.1 * size, size, size))
			kind.multimesh.set_instance_transform(index, Transform3D(basis, at))
			kind.multimesh.set_instance_color(index, BUTTERFLY_COLORS[index % BUTTERFLY_COLORS.size()])


## Looks for lush ground near the center, or for fireflies also the water's edge, and makes it this creature's home.
func _settle(kind: _Kind, index: int, center: Vector3, near_water: bool) -> bool:
	for attempt in SETTLE_ATTEMPTS:
		var angle := _rng.randf() * TAU
		var distance := lerpf(NEAR_RADIUS, FAR_RADIUS, sqrt(_rng.randf()))
		var x := center.x + cos(angle) * distance
		var z := center.z + sin(angle) * distance
		if terrain != null:
			var clearance := terrain.river_clearance(x, z)
			if clearance < 0.0:
				continue
			if clearance > RIVER_GLOW_DISTANCE or not near_water:
				if Surfaces.ground_dryness(x, z) > LUSH_DRYNESS:
					continue
		kind.anchors[index] = Vector3(x, 0.0, z)
		return true
	return false


func _ground(x: float, z: float) -> float:
	return terrain.height_at(x, z) if terrain != null else 0.0


func _vertex_color_material(double_sided: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	if double_sided:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _firefly_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.no_depth_test = false
	return material


## A flat wing pair that is a unit wide, so scaling it sideways flaps it.
func _wing_pair(span: float, chord: float, sweep: float, color: Color) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_color(color)
	for side in [-1.0, 1.0]:
		surface.add_vertex(Vector3.ZERO)
		surface.add_vertex(Vector3(side * span, 0.0, -chord * 0.5 - sweep))
		surface.add_vertex(Vector3(side * span, 0.0, chord * 0.5 - sweep))
	return surface.commit()


func _bird_mesh() -> ArrayMesh:
	return _wing_pair(0.6, 0.3, 0.1, Color.WHITE)


func _butterfly_mesh() -> ArrayMesh:
	return _wing_pair(0.12, 0.15, 0.0, Color.WHITE)


func _firefly_mesh() -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * FIREFLY_SIZE
	return mesh
