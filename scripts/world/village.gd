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

@export var terrain: Terrain


func _ready() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	for building: Dictionary in layout["buildings"]:
		_add_building(building)
	for field: Dictionary in layout["fields"]:
		_add_field(field)
	_add_trees(layout["trees"], layout["fields"])


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
	if absf(point.x) < data["road_clearance"]:
		return false
	if terrain.height_at(point.x, point.y) > MAX_TREE_HEIGHT:
		return false
	if point.distance_to(Terrain.LANDSLIDE_CENTER) < Terrain.LANDSLIDE_RADIUS:
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
