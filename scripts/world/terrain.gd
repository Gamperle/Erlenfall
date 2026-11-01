class_name Terrain
extends StaticBody3D
## Generates the valley: a flat village site, rolling farmland, and a ring of mountains.

const SIZE := 1600.0
const STEP := 4.0
const VILLAGE_RADIUS := 60.0
const VALLEY_RADIUS := 240.0
const MOUNTAIN_RADIUS := 640.0
const MOUNTAIN_HEIGHT := 170.0
const LANDSLIDE_CENTER := Vector2(40.0, -300.0)
const LANDSLIDE_RADIUS := 90.0
const LANDSLIDE_HEIGHT := 28.0
const ROAD_HALF_WIDTH := 4.0

const GRASS_COLOR := Color(0.27, 0.36, 0.17)
const DIRT_COLOR := Color(0.36, 0.29, 0.2)
const ROCK_COLOR := Color(0.33, 0.32, 0.31)
const SNOW_COLOR := Color(0.85, 0.87, 0.9)

var _hills := FastNoiseLite.new()
var _peaks := FastNoiseLite.new()


func _init() -> void:
	_hills.seed = 1
	_hills.frequency = 0.008
	_peaks.seed = 2
	_peaks.frequency = 0.004
	_peaks.fractal_octaves = 5


func _ready() -> void:
	var count := int(SIZE / STEP) + 1
	var heights := _sample_heights(count)
	_build_mesh(heights, count)
	_build_collision(heights, count)


func height_at(x: float, z: float) -> float:
	var distance := Vector2(x, z).length()
	var hills := _hills.get_noise_2d(x, z) * 4.0 * smoothstep(VILLAGE_RADIUS, VILLAGE_RADIUS * 2.5, distance)
	var mountain := smoothstep(VALLEY_RADIUS, MOUNTAIN_RADIUS, distance)
	var peaks := mountain * mountain * (MOUNTAIN_HEIGHT + _peaks.get_noise_2d(x, z) * 110.0)
	return hills + peaks + _landslide_height(x, z)


func _landslide_height(x: float, z: float) -> float:
	var distance := Vector2(x, z).distance_to(LANDSLIDE_CENTER)
	var shape := 1.0 - smoothstep(0.0, LANDSLIDE_RADIUS, distance)
	return shape * (LANDSLIDE_HEIGHT + _peaks.get_noise_2d(z, x) * 14.0)


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
	var indices := PackedInt32Array()
	vertices.resize(heights.size())
	normals.resize(heights.size())
	colors.resize(heights.size())
	indices.resize((count - 1) * (count - 1) * 6)

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
			colors[index] = _color_at(x, z, heights[index], normal)

	var cursor := 0
	for j in count - 1:
		for i in count - 1:
			var a := j * count + i
			var b := a + 1
			var c := a + count
			var d := c + 1
			for index in [a, b, c, b, d, c]:
				indices[cursor] = index
				cursor += 1

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.surface_set_material(0, material)

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)


func _color_at(x: float, z: float, height: float, normal: Vector3) -> Color:
	if height > 190.0:
		return SNOW_COLOR
	var on_landslide := Vector2(x, z).distance_to(LANDSLIDE_CENTER) < LANDSLIDE_RADIUS * 0.8
	if on_landslide or normal.y < 0.8 or height > 110.0:
		return ROCK_COLOR
	if absf(x) < ROAD_HALF_WIDTH and z > -220.0 and z < 220.0:
		return DIRT_COLOR
	return GRASS_COLOR


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
