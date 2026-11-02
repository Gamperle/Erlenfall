class_name GrassField
extends Node3D
## Grows grass across the whole map, but only keeps the part around the camera. Each cell of
## ground always gets the same grass, and worker threads place it so that walking doesn't stutter.

const SHADER := preload("res://shaders/grass.gdshader")
const CELL_SIZE := 48.0
const FADE_START := 120.0
const DRAW_DISTANCE := 220.0
## Cells are kept a little longer than they are needed, so walking back and forth doesn't regrow them.
const KEEP_DISTANCE := DRAW_DISTANCE + CELL_SIZE * 2.0
const CELLS_PER_BATCH := 8
const ROAD_CLEARANCE := 3.0
const BUILDING_CLEARANCE := 8.0
const RIVER_CLEARANCE := 0.5
## Matches where the terrain shader starts to draw rock instead of grass.
const MIN_GROUND_FLATNESS := 0.82
const SLOPE_SAMPLE_DISTANCE := 1.0
const SPECIES_SPREAD := 0.45

var terrain: Terrain

var _data: Dictionary
var _fields: Array
var _road_samples: Array[PackedVector2Array]
var _building_spots: Array[Vector2]
var _max_height: float
var _thinning_height: float
var _attempts_per_cell: int
var _meshes: Array[ArrayMesh] = []
var _material: ShaderMaterial
var _clearings := FastNoiseLite.new()
var _planted: Dictionary = {}
var _batch: Array[Vector2i] = []
var _batch_results: Array = []
var _task := -1


func setup(terrain_node: Terrain, data: Dictionary, fields: Array, road_samples: Array[PackedVector2Array], building_spots: Array[Vector2]) -> void:
	terrain = terrain_node
	_data = data
	_fields = fields
	_road_samples = road_samples
	_building_spots = building_spots
	_max_height = data["max_height"]
	_thinning_height = data["thinning_height"]
	_attempts_per_cell = roundi(float(data["density"]) * CELL_SIZE * CELL_SIZE)
	Surfaces.prepare_ground_dryness()
	_clearings.seed = int(data["seed"]) + 1
	_clearings.frequency = 0.05
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("fade_start", FADE_START)
	_material.set_shader_parameter("fade_end", DRAW_DISTANCE)
	for species: Dictionary in data["species"]:
		_meshes.append(_tuft_mesh(species))


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var center := Vector2(camera.global_position.x, camera.global_position.z)
	if _task >= 0:
		if not WorkerThreadPool.is_group_task_completed(_task):
			return
		_finish_batch()
	_drop_far_cells(center)
	_start_batch(center)


func _exit_tree() -> void:
	if _task >= 0:
		_finish_batch()


## The tufts of one cell: for each species, where they stand. Runs on worker threads.
func grow_cell(cell: Vector2i) -> Array:
	var random := RandomNumberGenerator.new()
	random.seed = hash([int(_data["seed"]), cell.x, cell.y])
	var origin := Vector2(cell) * CELL_SIZE
	var roads := _nearby_road_points(origin)
	var spots: Array = []
	for species in _meshes.size():
		spots.append([] as Array[Transform3D])
	for i in _attempts_per_cell:
		var point := origin + Vector2(random.randf(), random.randf()) * CELL_SIZE
		var keep_chance := random.randf()
		var chosen := random.randf()
		var turn := random.randf() * TAU
		var scale_factor := random.randf_range(0.7, 1.3)
		var height := terrain.height_at(point.x, point.y)
		if keep_chance > _growth_chance(point, height) or not _is_clear_ground(point, height, roads):
			continue
		var species := _choose_species(point, chosen)
		var basis := Basis(Vector3.UP, turn).scaled(Vector3.ONE * scale_factor)
		spots[species].append(Transform3D(basis, Vector3(point.x, height, point.y)))
	return spots


func _start_batch(center: Vector2) -> void:
	var wanted: Array[Vector2i] = []
	var reach := ceili(DRAW_DISTANCE / CELL_SIZE)
	var center_cell := Vector2i((center / CELL_SIZE).floor())
	for x in range(center_cell.x - reach, center_cell.x + reach + 1):
		for y in range(center_cell.y - reach, center_cell.y + reach + 1):
			var cell := Vector2i(x, y)
			if not _planted.has(cell) and _cell_distance(cell, center) < DRAW_DISTANCE:
				wanted.append(cell)
	if wanted.is_empty():
		return
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _cell_distance(a, center) < _cell_distance(b, center))
	_batch = wanted.slice(0, CELLS_PER_BATCH)
	_batch_results.resize(_batch.size())
	_task = WorkerThreadPool.add_group_task(_grow_batch_cell, _batch.size())


func _grow_batch_cell(index: int) -> void:
	_batch_results[index] = grow_cell(_batch[index])


func _finish_batch() -> void:
	WorkerThreadPool.wait_for_group_task_completion(_task)
	_task = -1
	for i in _batch.size():
		_plant(_batch[i], _batch_results[i])


func _plant(cell: Vector2i, spots: Array) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = hash([cell.x, cell.y])
	var group := Node3D.new()
	add_child(group)
	_planted[cell] = group
	for species in spots.size():
		var transforms: Array = spots[species]
		if transforms.is_empty():
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = _meshes[species]
		multimesh.instance_count = transforms.size()
		for i in transforms.size():
			multimesh.set_instance_transform(i, transforms[i])
			var brightness := random.randf_range(0.8, 1.15)
			multimesh.set_instance_color(i, Color(brightness, brightness, brightness * 0.95))
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = _material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(instance)


func _drop_far_cells(center: Vector2) -> void:
	for cell: Vector2i in _planted.keys():
		if _cell_distance(cell, center) > KEEP_DISTANCE:
			_planted[cell].queue_free()
			_planted.erase(cell)


func _cell_distance(cell: Vector2i, center: Vector2) -> float:
	return ((Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE).distance_to(center)


func _nearby_road_points(origin: Vector2) -> PackedVector2Array:
	var area := Rect2(origin, Vector2.ONE * CELL_SIZE).grow(ROAD_CLEARANCE)
	var points := PackedVector2Array()
	for samples in _road_samples:
		for sample in samples:
			if area.has_point(sample):
				points.append(sample)
	return points


## Grass thins out on the way up the mountains, and leaves small clearings everywhere.
func _growth_chance(point: Vector2, height: float) -> float:
	var clearing := smoothstep(-0.45, -0.05, _clearings.get_noise_2d(point.x, point.y))
	return clearing * (1.0 - smoothstep(_thinning_height, _max_height, height))


func _is_clear_ground(point: Vector2, height: float, roads: PackedVector2Array) -> bool:
	if terrain.is_on_landslide(point.x, point.y) or terrain.river_clearance(point.x, point.y) < RIVER_CLEARANCE:
		return false
	var rise_x := terrain.height_at(point.x + SLOPE_SAMPLE_DISTANCE, point.y) - height
	var rise_z := terrain.height_at(point.x, point.y + SLOPE_SAMPLE_DISTANCE) - height
	var slope := Vector2(rise_x, rise_z) / SLOPE_SAMPLE_DISTANCE
	if 1.0 / sqrt(1.0 + slope.length_squared()) < MIN_GROUND_FLATNESS:
		return false
	for road_point in roads:
		if point.distance_squared_to(road_point) < ROAD_CLEARANCE * ROAD_CLEARANCE:
			return false
	for building in _building_spots:
		if point.distance_squared_to(building) < BUILDING_CLEARANCE * BUILDING_CLEARANCE:
			return false
	for field: Dictionary in _fields:
		if point.distance_to(Vector2(field["x"], field["z"])) < float(field["width"]) * 0.65:
			return false
	return true


## Species grow in drifts: each suits the ground's level of dryness, and riverside species grow only by the water.
func _choose_species(point: Vector2, chosen: float) -> int:
	var dryness := Surfaces.ground_dryness(point.x, point.y)
	var by_river := terrain.river_clearance(point.x, point.y) < float(_data["riverside_distance"])
	var scores := PackedFloat32Array()
	var total := 0.0
	for species: Dictionary in _data["species"]:
		var score := 0.0
		if species.get("riverside", false):
			score = float(species["weight"]) if by_river else 0.0
		else:
			score = float(species["weight"]) * maxf(1.0 - absf(dryness - float(species["dryness"])) / SPECIES_SPREAD, 0.02)
		scores.append(score)
		total += score
	var left := chosen * total
	for i in scores.size():
		left -= scores[i]
		if left <= 0.0:
			return i
	return 0


func _tuft_mesh(species: Dictionary) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3.UP)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = hash(species["name"])
	var base := Color(species["base"])
	var tip := Color(species["tip"])
	var width := float(species["width"])
	for blade in int(species["blades"]):
		var angle := jitter.randf() * TAU
		var side := Vector3.RIGHT.rotated(Vector3.UP, angle)
		var lean := Vector3.FORWARD.rotated(Vector3.UP, angle + jitter.randf_range(-0.6, 0.6)) * jitter.randf_range(0.3, 1.0) * float(species["lean"])
		var foot := Vector3(jitter.randf_range(-1.0, 1.0), 0.0, jitter.randf_range(-1.0, 1.0)) * float(species["spread"])
		var height := jitter.randf_range(species["height"][0], species["height"][1])
		_add_blade(surface, foot, side * width, lean, height, base, tip)
		if species.get("seed_heads", false):
			_add_seed_head(surface, foot + lean + Vector3.UP * height, side, Color(species["seed_color"]))
	return surface.commit()


## A blade that bends over: a wide lower part, and a narrower upper part ending in a point.
func _add_blade(surface: SurfaceTool, foot: Vector3, half_width: Vector3, lean: Vector3, height: float, base: Color, tip: Color) -> void:
	var middle := foot + lean * 0.3 + Vector3.UP * height * 0.6
	var top := foot + lean + Vector3.UP * height
	var middle_color := base.lerp(tip, 0.6)
	var corners: Array = [
		[foot - half_width, base], [foot + half_width, base], [middle + half_width * 0.7, middle_color],
		[foot - half_width, base], [middle + half_width * 0.7, middle_color], [middle - half_width * 0.7, middle_color],
		[middle - half_width * 0.7, middle_color], [middle + half_width * 0.7, middle_color], [top, tip],
	]
	for corner: Array in corners:
		surface.set_color(corner[1])
		surface.add_vertex(corner[0])


func _add_seed_head(surface: SurfaceTool, at: Vector3, side: Vector3, color: Color) -> void:
	var low := at + Vector3.DOWN * 0.03
	var high := at + Vector3.UP * 0.1
	surface.set_color(color)
	for corner: Vector3 in [low, at + side * 0.022, high, low, high, at - side * 0.022]:
		surface.add_vertex(corner)
