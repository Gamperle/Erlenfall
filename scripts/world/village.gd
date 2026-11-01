class_name Village
extends Node3D
## Places placeholder buildings, fields, and trees from a data file.

const LAYOUT_PATH := "res://data/village_layout.json"
const FOUNDATION_DEPTH := 3.0
const ROOF_HEIGHT := 2.5
const TRUNK_HEIGHT := 3.0
const TRUNK_RADIUS := 0.3
const CROWN_HEIGHT := 9.0
const CROWN_RADIUS := 2.6
const ROOF_COLOR := Color(0.3, 0.2, 0.15)
const TRUNK_COLOR := Color(0.25, 0.17, 0.11)
const CROWN_COLOR := Color(0.12, 0.24, 0.14)
const MAX_TREE_HEIGHT := 90.0
const MAX_PLACEMENT_ATTEMPTS := 10
const ROAD_COLOR := Color(0.4, 0.32, 0.22)
const ROAD_LIFT := 0.12
const ROAD_SAMPLE_SPACING := 2.0
const BOULDER_COLOR := Color(0.36, 0.33, 0.3)
const BOULDER_LUMPINESS := 0.35

@export var terrain: Terrain

var _road_samples: Array[PackedVector2Array] = []


func _ready() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	for building: Dictionary in layout["buildings"]:
		_add_building(building)
	for field: Dictionary in layout["fields"]:
		_add_field(field)
	_add_roads(layout["roads"])
	_add_trees(layout["trees"], layout["fields"])
	_add_boulders(layout["boulders"])


func _add_roads(roads: Array) -> void:
	var root := Node3D.new()
	root.name = "Roads"
	add_child(root)
	for road: Dictionary in roads:
		var samples := _sample_road(road["points"])
		_road_samples.append(samples)
		root.add_child(_road_mesh(samples, road["width"]))


func _sample_road(points: Array) -> PackedVector2Array:
	var path := PackedVector2Array()
	for point: Array in points:
		path.append(Vector2(point[0], point[1]))

	var samples := PackedVector2Array()
	for i in path.size() - 1:
		var before := path[maxi(i - 1, 0)]
		var after := path[mini(i + 2, path.size() - 1)]
		var steps := ceili(path[i].distance_to(path[i + 1]) / ROAD_SAMPLE_SPACING)
		for step in steps:
			samples.append(path[i].cubic_interpolate(path[i + 1], before, after, float(step) / steps))
	samples.append(path[path.size() - 1])
	return samples


func _road_mesh(samples: PackedVector2Array, width: float) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3.UP)
	surface.set_color(ROAD_COLOR)
	for i in samples.size():
		var tangent := (samples[mini(i + 1, samples.size() - 1)] - samples[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-tangent.y, tangent.x)
		var half_width := width / 2.0 * (1.0 + sin(i * 0.37) * 0.1 + sin(i * 0.11) * 0.1)
		for edge: Vector2 in [samples[i] + side * half_width, samples[i] - side * half_width]:
			surface.add_vertex(Vector3(edge.x, terrain.height_at(edge.x, edge.y) + ROAD_LIFT, edge.y))
		if i > 0:
			var left := (i - 1) * 2
			for index in [left, left + 1, left + 2, left + 1, left + 3, left + 2]:
				surface.add_index(index)

	var material := _material(ROAD_COLOR)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _add_boulders(data: Dictionary) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = data["seed"]
	var body := StaticBody3D.new()
	body.name = "Boulders"
	add_child(body)

	var transforms: Array[Transform3D] = []
	for i in int(data["count"]):
		var angle := random.randf() * TAU
		var distance := sqrt(random.randf()) * 1.05
		var point := Terrain.LANDSLIDE_CENTER + Vector2.from_angle(angle) * Terrain.LANDSLIDE_EXTENT * distance
		# Squaring favors many small rocks over a few large ones.
		var size: float = lerpf(data["min_size"], data["max_size"], pow(random.randf(), 2.0))
		var stretch := Vector3(random.randf_range(0.8, 1.3), random.randf_range(0.6, 1.0), random.randf_range(0.8, 1.3))
		var basis := Basis.from_euler(Vector3(random.randf(), random.randf() * TAU, random.randf())).scaled(stretch * size)
		var at := _ground_position(point.x, point.y)
		transforms.append(Transform3D(basis, at))

		if size >= data["solid_size"]:
			var shape := SphereShape3D.new()
			shape.radius = size * 0.8
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.position = at
			body.add_child(collision)

	var mesh := _boulder_mesh()
	mesh.surface_set_material(0, _material(BOULDER_COLOR))
	_add_multimesh(mesh, transforms, 0.0)


## A sphere with lumps pushed in and out, flat-shaded so it reads as broken rock.
func _boulder_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 9
	sphere.rings = 5
	var arrays := sphere.get_mesh_arrays()
	var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	var lumps := FastNoiseLite.new()
	lumps.seed = 5
	lumps.frequency = 1.5

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, indices.size(), 3):
		var corners: Array[Vector3] = []
		for offset in 3:
			var vertex := source[indices[i + offset]]
			corners.append(vertex * (1.0 + lumps.get_noise_3dv(vertex) * BOULDER_LUMPINESS))
		surface.set_normal((corners[2] - corners[0]).cross(corners[1] - corners[0]).normalized())
		for corner in corners:
			surface.add_vertex(corner)
	return surface.commit()


func _add_building(data: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = data["id"]
	body.position = _ground_position(data["x"], data["z"])
	body.rotation_degrees.y = data["rotation"]
	add_child(body)

	var wall_height: float = data["height"] + FOUNDATION_DEPTH
	var size := Vector3(data["width"], wall_height, data["depth"])
	var center := Vector3.UP * (wall_height / 2.0 - FOUNDATION_DEPTH)
	body.add_child(_mesh_instance(_box(size, Color(data["color"])), center))

	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = center
	body.add_child(collision)

	if not data.get("ruined", false):
		var roof := PrismMesh.new()
		roof.size = Vector3(data["width"] + 1.0, ROOF_HEIGHT, data["depth"] + 1.0)
		roof.material = _material(ROOF_COLOR)
		var roof_position: Vector3 = Vector3.UP * (data["height"] + ROOF_HEIGHT / 2.0)
		body.add_child(_mesh_instance(roof, roof_position))


func _add_field(data: Dictionary) -> void:
	var size := Vector3(data["width"], 1.0, data["depth"])
	var field := _mesh_instance(_box(size, Color(data["color"])), _ground_position(data["x"], data["z"]))
	field.rotation_degrees.y = data["rotation"]
	add_child(field)


func _add_trees(data: Dictionary, fields: Array) -> void:
	var transforms: Array[Transform3D] = []
	var random := RandomNumberGenerator.new()
	random.seed = data["seed"]
	for i in int(data["count"]):
		for attempt in MAX_PLACEMENT_ATTEMPTS:
			var angle := random.randf() * TAU
			var radius := random.randf_range(data["min_radius"], data["max_radius"])
			var point := Vector2.from_angle(angle) * radius
			if _is_tree_allowed(point, data, fields):
				var scale_factor := random.randf_range(0.8, 1.4)
				var basis := Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * scale_factor)
				transforms.append(Transform3D(basis, _ground_position(point.x, point.y)))
				break

	var trunk := CylinderMesh.new()
	trunk.top_radius = TRUNK_RADIUS
	trunk.bottom_radius = TRUNK_RADIUS
	trunk.height = TRUNK_HEIGHT
	trunk.material = _material(TRUNK_COLOR)
	_add_multimesh(trunk, transforms, TRUNK_HEIGHT / 2.0)

	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = CROWN_RADIUS
	crown.height = CROWN_HEIGHT
	crown.material = _material(CROWN_COLOR)
	_add_multimesh(crown, transforms, TRUNK_HEIGHT + CROWN_HEIGHT / 2.0 - 1.0)

	_add_tree_collision(transforms)


func _is_tree_allowed(point: Vector2, data: Dictionary, fields: Array) -> bool:
	for samples in _road_samples:
		for sample in samples:
			if point.distance_to(sample) < data["road_clearance"]:
				return false
	if terrain.height_at(point.x, point.y) > MAX_TREE_HEIGHT:
		return false
	if terrain.is_on_landslide(point.x, point.y):
		return false
	for field: Dictionary in fields:
		if point.distance_to(Vector2(field["x"], field["z"])) < data["field_clearance"]:
			return false
	return true


func _add_multimesh(mesh: Mesh, transforms: Array[Transform3D], height_offset: float) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		var offset := transforms[i].basis * (Vector3.UP * height_offset)
		multimesh.set_instance_transform(i, transforms[i].translated(offset))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	add_child(instance)


func _add_tree_collision(transforms: Array[Transform3D]) -> void:
	var body := StaticBody3D.new()
	body.name = "TreeCollision"
	add_child(body)
	var shape := CylinderShape3D.new()
	shape.radius = TRUNK_RADIUS * 1.5
	shape.height = TRUNK_HEIGHT * 2.0
	for tree in transforms:
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = tree.origin
		body.add_child(collision)


func _ground_position(x: float, z: float) -> Vector3:
	return Vector3(x, terrain.height_at(x, z), z)


func _box(size: Vector3, color: Color) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	box.material = _material(color)
	return box


func _mesh_instance(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material
