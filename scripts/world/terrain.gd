class_name Terrain
extends StaticBody3D
## Generates the valley: a gentle village site, rolling farmland, a river, and a ring of mountains.

const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const LAYOUT_PATH := "res://data/village_layout.json"

const SIZE := 1600.0
const STEP := 4.0
const VILLAGE_RADIUS := 60.0
const VALLEY_RADIUS := 240.0
const MOUNTAIN_RADIUS := 640.0
const MOUNTAIN_HEIGHT := 170.0
const LANDSLIDE_CENTER := Vector2(40.0, -300.0)
const LANDSLIDE_EXTENT := Vector2(90.0, 130.0)
const LANDSLIDE_HEIGHT := 20.0
const LANDSLIDE_ROUGHNESS := 26.0
const LANDSLIDE_EDGE_NOISE := 0.3
const SCAR_HALF_WIDTH := 55.0
const SCAR_DEPTH := 14.0

const GRASS_COLOR := Color(0.24, 0.3, 0.15)
const LIGHT_GRASS_COLOR := Color(0.33, 0.37, 0.19)
const ROCK_COLOR := Color(0.38, 0.37, 0.36)
const RUBBLE_COLOR := Color(0.33, 0.28, 0.23)
const SNOW_COLOR := Color(0.85, 0.87, 0.9)
const WATER_DEEP_COLOR := Color(0.07, 0.17, 0.2)
const WATER_SHALLOW_COLOR := Color(0.2, 0.3, 0.27)

const HILL_HEIGHT := 20.0
## How much of the hills is left in the middle of the village, where they fade out.
const VILLAGE_HILLS := 0.12
const FLAT_CELL_SIZE := 32.0
const BUILDING_FLAT_MARGIN := 1.5
const BUILDING_FLAT_BLEND := 10.0
const FIELD_FLAT_BLEND := 20.0
const SPOT_FLAT_RADIUS := 2.0
const SPOT_FLAT_BLEND := 7.0
const ROAD_SPACING := 2.0
const ROAD_SHOULDER := 1.0
const ROAD_BLEND := 11.0
const ROAD_SMOOTH_SAMPLES := 14
const ROAD_SMOOTH_PASSES := 3
const RIVER_SPACING := 8.0
## How far either side of the river the terrain mesh is finer, so that the water's edge is smooth.
const RIVER_FINE_MARGIN := 1.0
## Past this distance from the village the river can only be seen from afar.
const RIVER_FINE_RADIUS := 560.0
const FINE_CELLS := 4
const WATER_OVERLAP := 0.75
const CHUNK_CELLS := 32
## More vertices than any chunk has, so that each chunk can mark the ones it has used.
const CHUNK_INDEX_RANGE := 1048576
const GROUP := "terrain"
## The speed left when wading at this depth or deeper.
const WADING_SPEED_FACTOR := 0.55
const WADING_FULL_DEPTH := 0.6

## The roads in the layout file's order.
var roads: Array[TerrainPath] = []
var river: TerrainPath
## The places kept free for future buildings, from the layout file.
var building_sites: Array = []

var _bank_width := 0.0
var _bank_height := 0.0
var _river_depth := 0.0
var _valley_width := 0.0
var _flat_cells: Dictionary = {}
var _rounded_hills: Array = []

var _hills := FastNoiseLite.new()
var _peaks := FastNoiseLite.new()
var _rubble := FastNoiseLite.new()
var _patches := FastNoiseLite.new()


func _init() -> void:
	_hills.seed = 1
	_hills.frequency = 0.0055
	_hills.fractal_octaves = 3
	_peaks.seed = 2
	_peaks.frequency = 0.004
	_peaks.fractal_octaves = 5
	_rubble.seed = 3
	_rubble.frequency = 0.04
	_rubble.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_rubble.fractal_octaves = 3
	_patches.seed = 4
	_patches.frequency = 0.02
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	_rounded_hills = layout["hills"]
	_add_flat_areas(layout)
	_add_roads(layout["roads"])
	_add_river(layout["river"])


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	var count := int(SIZE / STEP) + 1
	var heights := _sample_heights(count)
	_build_mesh(heights, count)
	_build_collision(heights, count)
	_build_water()


func height_at(x: float, z: float) -> float:
	var height := _flattened_height(x, z)
	for road in roads:
		height = _along_road(road, height, x, z)
	return _along_river(height, x, z)


## How far a point lies from the river's bed and banks, which is below 0 inside them.
func river_clearance(x: float, z: float) -> float:
	var found := river.nearest(x, z)
	return found.x - found.z - _bank_width


## The height of the water at the nearest point of the river, or -INF far away from it.
func water_height(x: float, z: float) -> float:
	var found := river.nearest(x, z)
	return found.y if found.x < INF else -INF


## How much water slows someone whose feet are at this point. Bridges are above the water, and
## land beside the river can lie below the nearest water without being wet.
func wading_factor(feet: Vector3) -> float:
	var depth := water_height(feet.x, feet.z) - feet.y
	if depth <= 0.0 or river_clearance(feet.x, feet.z) >= 0.0:
		return 1.0
	return lerpf(1.0, WADING_SPEED_FACTOR, minf(depth / WADING_FULL_DEPTH, 1.0))


func _natural_height(x: float, z: float) -> float:
	var distance := Vector2(x, z).length()
	var fade := lerpf(VILLAGE_HILLS, 1.0, smoothstep(VILLAGE_RADIUS * 0.6, VILLAGE_RADIUS * 2.5, distance))
	var hills := _hills.get_noise_2d(x, z) * HILL_HEIGHT * fade
	for hill: Dictionary in _rounded_hills:
		var from_hill := Vector2(x, z).distance_to(Vector2(hill["x"], hill["z"]))
		if from_hill < hill["radius"]:
			hills += hill["height"] * (1.0 - smoothstep(0.0, hill["radius"], from_hill))
	var mountain := smoothstep(VALLEY_RADIUS, MOUNTAIN_RADIUS, distance)
	var peaks := mountain * mountain * (MOUNTAIN_HEIGHT + _peaks.get_noise_2d(x, z) * 110.0)
	return hills + peaks + _landslide_height(x, z)


func _flattened_height(x: float, z: float) -> float:
	var height := _natural_height(x, z)
	var areas: Variant = _flat_cells.get(_flat_cell_key(x, z))
	if areas != null:
		for area: PackedFloat32Array in areas:
			var distance := Vector2(x, z).distance_to(Vector2(area[0], area[1]))
			height = lerpf(area[2], height, smoothstep(area[3], area[3] + area[4], distance))
	return height


func _along_road(road: TerrainPath, height: float, x: float, z: float) -> float:
	var found := road.nearest(x, z)
	if found.x == INF:
		return height
	return lerpf(found.y, height, smoothstep(found.z + ROAD_SHOULDER, found.z + ROAD_BLEND, found.x))


## Cuts the bed and banks, and lowers or raises the land beside them to meet the banks' top.
func _along_river(height: float, x: float, z: float) -> float:
	var found := river.nearest(x, z)
	if found.x == INF:
		return height
	var edge := found.z + _bank_width
	var bank := smoothstep(found.z, edge, found.x)
	var channel := lerpf(found.y - _river_depth, found.y + _bank_height, bank)
	return lerpf(channel, height, smoothstep(edge, edge + _valley_width, found.x))


func _add_flat_areas(layout: Dictionary) -> void:
	# The largest areas come first, so the smaller ones inside them keep their own flat ground.
	building_sites = layout["building_sites"]
	for site: Dictionary in building_sites:
		_add_flat_area(site["x"], site["z"], site["radius"], site["blend"], site["rise"])
	for area: Dictionary in layout["flat_areas"]:
		_add_flat_area(area["x"], area["z"], area["radius"], area["blend"])
	for field: Dictionary in layout["fields"]:
		_add_flat_area(field["x"], field["z"], Vector2(field["width"], field["depth"]).length() / 2.0 + BUILDING_FLAT_MARGIN, FIELD_FLAT_BLEND)
	for building: Dictionary in layout["buildings"]:
		_add_flat_area(building["x"], building["z"], Vector2(building["width"], building["depth"]).length() / 2.0 + BUILDING_FLAT_MARGIN, BUILDING_FLAT_BLEND)
	for list in ["npcs", "enemies", "repair_sites", "beds", "stations", "resources"]:
		for spot: Dictionary in layout[list]:
			_add_flat_area(spot["x"], spot["z"], SPOT_FLAT_RADIUS, SPOT_FLAT_BLEND)


## Levels the ground around a point to the height it has so far, plus any rise.
func _add_flat_area(x: float, z: float, radius: float, blend: float, rise := 0.0) -> void:
	var area := PackedFloat32Array([x, z, _flattened_height(x, z) + rise, radius, blend])
	var reach := radius + blend
	for cell_z in range(floori((z - reach) / FLAT_CELL_SIZE), floori((z + reach) / FLAT_CELL_SIZE) + 1):
		for cell_x in range(floori((x - reach) / FLAT_CELL_SIZE), floori((x + reach) / FLAT_CELL_SIZE) + 1):
			var key := _flat_cell_key(cell_x * FLAT_CELL_SIZE, cell_z * FLAT_CELL_SIZE)
			if not _flat_cells.has(key):
				_flat_cells[key] = []
			_flat_cells[key].append(area)


func _flat_cell_key(x: float, z: float) -> int:
	return floori(x / FLAT_CELL_SIZE) * 4096 + floori(z / FLAT_CELL_SIZE)


func _add_roads(data: Array) -> void:
	for road: Dictionary in data:
		var half_width: float = road["width"] / 2.0
		var points := []
		for point: Array in road["points"]:
			points.append([point[0], point[1], 0.0, half_width])
		var path := TerrainPath.new(points, ROAD_SPACING, half_width + ROAD_BLEND)
		path.heights = _smoothed_road_heights(path.positions)
		roads.append(path)


## Follows the land along the road, but evens out its bumps so the road climbs steadily.
func _smoothed_road_heights(positions: PackedVector2Array) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	for position_2d in positions:
		heights.append(_flattened_height(position_2d.x, position_2d.y))
	for pass_number in ROAD_SMOOTH_PASSES:
		var evened := PackedFloat32Array()
		for i in heights.size():
			var total := 0.0
			for offset in range(-ROAD_SMOOTH_SAMPLES, ROAD_SMOOTH_SAMPLES + 1):
				total += heights[clampi(i + offset, 0, heights.size() - 1)]
			evened.append(total / (ROAD_SMOOTH_SAMPLES * 2 + 1))
		heights = evened
	return heights


func _add_river(data: Dictionary) -> void:
	_bank_width = data["bank_width"]
	_bank_height = data["bank_height"]
	_river_depth = data["depth"]
	_valley_width = data["valley_width"]
	var widest := 0.0
	for point: Array in data["points"]:
		widest = maxf(widest, point[3])
	river = TerrainPath.new(data["points"], RIVER_SPACING, widest + _bank_width + _valley_width)


## True on the debris field and on the bare scar the slide tore into the mountain above it.
func is_on_landslide(x: float, z: float) -> bool:
	var edge := 1.0 + _patches.get_noise_2d(x, z) * LANDSLIDE_EDGE_NOISE
	if _landslide_distance(x, z) < edge:
		return true
	return z < LANDSLIDE_CENTER.y and absf(x - LANDSLIDE_CENTER.x) < SCAR_HALF_WIDTH * edge


## 0 at the center of the debris field, 1 at its edge.
func _landslide_distance(x: float, z: float) -> float:
	return ((Vector2(x, z) - LANDSLIDE_CENTER) / LANDSLIDE_EXTENT).length()


func _landslide_height(x: float, z: float) -> float:
	var rubble := _rubble.get_noise_2d(x, z) * 0.5 + 0.5
	var debris := 1.0 - smoothstep(0.0, 1.0, _landslide_distance(x, z))
	var across := 1.0 - smoothstep(SCAR_HALF_WIDTH * 0.4, SCAR_HALF_WIDTH, absf(x - LANDSLIDE_CENTER.x))
	var scar := across * smoothstep(0.0, 80.0, LANDSLIDE_CENTER.y - z)
	return debris * (LANDSLIDE_HEIGHT + rubble * LANDSLIDE_ROUGHNESS) - scar * SCAR_DEPTH * (0.5 + rubble)


func _sample_heights(count: int) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	heights.resize(count * count)
	for j in count:
		for i in count:
			heights[j * count + i] = height_at(i * STEP - SIZE / 2.0, j * STEP - SIZE / 2.0)
	return heights


func _build_mesh(heights: PackedFloat32Array, count: int) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	vertices.resize(heights.size())
	normals.resize(heights.size())
	colors.resize(heights.size())

	for j in count:
		for i in count:
			var index := j * count + i
			var x := i * STEP - SIZE / 2.0
			var z := j * STEP - SIZE / 2.0
			var left := heights[j * count + maxi(i - 1, 0)]
			var right := heights[j * count + mini(i + 1, count - 1)]
			var back := heights[maxi(j - 1, 0) * count + i]
			var front := heights[mini(j + 1, count - 1) * count + i]
			var normal := Vector3(left - right, 2.0 * STEP, back - front).normalized()
			vertices[index] = Vector3(x, heights[index], z)
			normals[index] = normal
			colors[index] = _color_at(x, z)

	var fine_cells := _fine_cells(count)
	var chunk_indices := _coarse_chunk_indices(fine_cells, count)
	_add_fine_cells(fine_cells, heights, count, vertices, normals, colors, chunk_indices)

	var material := _ground_material()
	var used_as := PackedInt32Array()
	used_as.resize(vertices.size())
	used_as.fill(-1)
	for chunk in chunk_indices.size():
		var indices: PackedInt32Array = chunk_indices[chunk]
		if indices.is_empty():
			continue
		_add_chunk_mesh(chunk, indices, vertices, normals, colors, used_as, material)


## Sorts the triangles of the ordinary cells into one list per chunk, leaving out the marked cells.
func _coarse_chunk_indices(fine_cells: PackedByteArray, count: int) -> Array[PackedInt32Array]:
	var row := count - 1
	var chunks_across := ceili(float(row) / CHUNK_CELLS)
	var chunk_indices: Array[PackedInt32Array] = []
	for chunk_z in chunks_across:
		for chunk_x in chunks_across:
			var indices := PackedInt32Array()
			indices.resize(CHUNK_CELLS * CHUNK_CELLS * 6)
			var cursor := 0
			for j in range(chunk_z * CHUNK_CELLS, mini((chunk_z + 1) * CHUNK_CELLS, row)):
				for i in range(chunk_x * CHUNK_CELLS, mini((chunk_x + 1) * CHUNK_CELLS, row)):
					if fine_cells[j * row + i] == 1:
						continue
					var a := j * count + i
					var b := a + 1
					var c := a + count
					var d := c + 1
					indices[cursor] = a
					indices[cursor + 1] = b
					indices[cursor + 2] = c
					indices[cursor + 3] = b
					indices[cursor + 4] = d
					indices[cursor + 5] = c
					cursor += 6
			indices.resize(cursor)
			chunk_indices.append(indices)
	return chunk_indices


## Gives a chunk its own mesh with only the vertices it uses, so it can be culled on its own.
func _add_chunk_mesh(chunk: int, indices: PackedInt32Array, vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, used_as: PackedInt32Array, material: ShaderMaterial) -> void:
	var chunk_vertices := PackedVector3Array()
	var chunk_normals := PackedVector3Array()
	var chunk_colors := PackedColorArray()
	var first_of_chunk := chunk * CHUNK_INDEX_RANGE
	for position_in_list in indices.size():
		var index := indices[position_in_list]
		if used_as[index] < first_of_chunk:
			used_as[index] = first_of_chunk + chunk_vertices.size()
			chunk_vertices.append(vertices[index])
			chunk_normals.append(normals[index])
			chunk_colors.append(colors[index])
		indices[position_in_list] = used_as[index] - first_of_chunk

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = chunk_vertices
	arrays[Mesh.ARRAY_NORMAL] = chunk_normals
	arrays[Mesh.ARRAY_COLOR] = chunk_colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)


## Marks the cells near the river. Each row of the result holds count - 1 cells.
func _fine_cells(count: int) -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize((count - 1) * (count - 1))
	for j in count - 1:
		for i in count - 1:
			var x := (i + 0.5) * STEP - SIZE / 2.0
			var z := (j + 0.5) * STEP - SIZE / 2.0
			if river_clearance(x, z) < RIVER_FINE_MARGIN and Vector2(x, z).length() < RIVER_FINE_RADIUS:
				cells[j * (count - 1) + i] = 1
	return cells


## Gives each marked cell its own smaller grid. Where a cell meets a coarse one, its edge stays
## straight along the coarse cell's edge, so no crack opens between them.
func _add_fine_cells(cells: PackedByteArray, heights: PackedFloat32Array, count: int, vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, chunk_indices: Array[PackedInt32Array]) -> void:
	var size := STEP / FINE_CELLS
	var row := count - 1
	# Neighboring vertices and cells ask for the same points, and working out a height is slow.
	var known_heights: Dictionary = {}
	var fine_height := func(fine_x: int, fine_z: int) -> float:
		var key := fine_z * 65536 + fine_x
		if not known_heights.has(key):
			known_heights[key] = height_at(fine_x * size - SIZE / 2.0, fine_z * size - SIZE / 2.0)
		return known_heights[key]
	var is_fine := func(i: int, j: int) -> bool:
		return i >= 0 and j >= 0 and i < row and j < row and cells[j * row + i] == 1
	for j in row:
		for i in row:
			if cells[j * row + i] == 0:
				continue
			var near_north: bool = is_fine.call(i, j - 1)
			var near_south: bool = is_fine.call(i, j + 1)
			var near_west: bool = is_fine.call(i - 1, j)
			var near_east: bool = is_fine.call(i + 1, j)
			var corner_nw := heights[j * count + i]
			var corner_ne := heights[j * count + i + 1]
			var corner_sw := heights[(j + 1) * count + i]
			var corner_se := heights[(j + 1) * count + i + 1]
			var first := vertices.size()
			var cell_indices := PackedInt32Array()
			for sub_z in FINE_CELLS + 1:
				for sub_x in FINE_CELLS + 1:
					var x := i * STEP - SIZE / 2.0 + sub_x * size
					var z := j * STEP - SIZE / 2.0 + sub_z * size
					var across := float(sub_x) / FINE_CELLS
					var down := float(sub_z) / FINE_CELLS
					var fine_x := i * FINE_CELLS + sub_x
					var fine_z := j * FINE_CELLS + sub_z
					var height: float = fine_height.call(fine_x, fine_z)
					if sub_z == 0 and not near_north:
						height = lerpf(corner_nw, corner_ne, across)
					elif sub_z == FINE_CELLS and not near_south:
						height = lerpf(corner_sw, corner_se, across)
					elif sub_x == 0 and not near_west:
						height = lerpf(corner_nw, corner_sw, down)
					elif sub_x == FINE_CELLS and not near_east:
						height = lerpf(corner_ne, corner_se, down)
					vertices.append(Vector3(x, height, z))
					normals.append(Vector3(fine_height.call(fine_x - 1, fine_z) - fine_height.call(fine_x + 1, fine_z), 2.0 * size, fine_height.call(fine_x, fine_z - 1) - fine_height.call(fine_x, fine_z + 1)).normalized())
					colors.append(_color_at(x, z))
			for sub_z in FINE_CELLS:
				for sub_x in FINE_CELLS:
					var a := first + sub_z * (FINE_CELLS + 1) + sub_x
					var b := a + 1
					var c := a + FINE_CELLS + 1
					var d := c + 1
					cell_indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
			var chunk: int = j / CHUNK_CELLS * ceili(float(row) / CHUNK_CELLS) + i / CHUNK_CELLS
			chunk_indices[chunk].append_array(cell_indices)


func _ground_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	material.set_shader_parameter("detail_noise", Surfaces.noise_texture())
	material.set_shader_parameter("grass_texture", preload("res://assets/textures/grass.jpg"))
	material.set_shader_parameter("rock_texture", preload("res://assets/textures/rock.jpg"))
	material.set_shader_parameter("snow_texture", preload("res://assets/textures/snow.jpg"))
	material.set_shader_parameter("rubble_texture", preload("res://assets/textures/rubble.jpg"))
	material.set_shader_parameter("rubble_color", RUBBLE_COLOR)
	material.set_shader_parameter("rock_color", ROCK_COLOR)
	material.set_shader_parameter("snow_color", SNOW_COLOR)
	return material


func _color_at(x: float, z: float) -> Color:
	var color := GRASS_COLOR.lerp(LIGHT_GRASS_COLOR, _patches.get_noise_2d(x, z) * 0.5 + 0.5)
	var on_rubble := is_on_landslide(x, z) and height_at(x, z) < 150.0
	color.a = 1.0 if on_rubble or river_clearance(x, z) < -_bank_width * 0.25 else 0.0
	return color


func _build_collision(heights: PackedFloat32Array, count: int) -> void:
	# Height map spacing is fixed at 1 m, so the shape is scaled uniformly to match STEP.
	var scaled_heights := PackedFloat32Array()
	scaled_heights.resize(heights.size())
	for index in heights.size():
		scaled_heights[index] = heights[index] / STEP

	var shape := HeightMapShape3D.new()
	shape.map_width = count
	shape.map_depth = count
	shape.map_data = scaled_heights

	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.scale = Vector3.ONE * STEP
	add_child(collision)


## A ribbon of water that reaches into the banks, so the land decides where its edge shows.
func _build_water() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	var count := river.positions.size()
	for i in count:
		var center := river.positions[i]
		var tangent := (river.positions[mini(i + 1, count - 1)] - river.positions[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-tangent.y, tangent.x)
		var half_width := river.half_widths[i] + _bank_width * WATER_OVERLAP
		if i > 0:
			along += center.distance_to(river.positions[i - 1])
		for edge: float in [-1.0, 1.0]:
			var at := center + side * half_width * edge
			surface.set_normal(Vector3.UP)
			surface.set_tangent(Plane(side.x, 0.0, side.y, 1.0))
			surface.set_uv(Vector2(edge * half_width, along))
			surface.add_vertex(Vector3(at.x, river.heights[i], at.y))
		if i > 0:
			var left := (i - 1) * 2
			for index in [left, left + 2, left + 1, left + 1, left + 2, left + 3]:
				surface.add_index(index)

	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("detail_noise", Surfaces.noise_texture())
	material.set_shader_parameter("deep_color", WATER_DEEP_COLOR)
	material.set_shader_parameter("shallow_color", WATER_SHALLOW_COLOR)

	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = surface.commit()
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
