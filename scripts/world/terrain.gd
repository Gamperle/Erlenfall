class_name Terrain
extends StaticBody3D
## Generates the valley: a flat village site, rolling farmland, and a ring of mountains.

const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")

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

var _hills := FastNoiseLite.new()
var _peaks := FastNoiseLite.new()
var _rubble := FastNoiseLite.new()
var _patches := FastNoiseLite.new()


func _init() -> void:
	_hills.seed = 1
	_hills.frequency = 0.008
	_peaks.seed = 2
	_peaks.frequency = 0.004
	_peaks.fractal_octaves = 5
	_rubble.seed = 3
	_rubble.frequency = 0.04
	_rubble.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_rubble.fractal_octaves = 3
	_patches.seed = 4
	_patches.frequency = 0.02


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
			colors[index] = _color_at(x, z)

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
	mesh.surface_set_material(0, _ground_material())

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)


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
	color.a = 1.0 if is_on_landslide(x, z) and height_at(x, z) < 150.0 else 0.0
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
