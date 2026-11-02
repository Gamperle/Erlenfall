class_name Village
extends Node3D
## Places placeholder buildings, fields, and trees from a data file.

const LAYOUT_PATH := "res://data/village_layout.json"
const FOUNDATION_DEPTH := 3.0
const TRUNK_HEIGHT := 3.0
const TRUNK_RADIUS := 0.3
const TREE_HEIGHT := 12.0
const TREE_TIERS := 4
const CROWN_RADIUS := 2.6
const TRUNK_COLOR := Color(0.25, 0.17, 0.11)
const CROWN_COLOR := Color(0.09, 0.2, 0.11)
const CROWN_TIP_COLOR := Color(0.2, 0.34, 0.17)
const GRASS_BLADES := 7
const GRASS_BASE_COLOR := Color(0.17, 0.22, 0.1)
const GRASS_TIP_COLOR := Color(0.36, 0.4, 0.2)
const GRASS_ROAD_CLEARANCE := 3.0
const GRASS_BUILDING_CLEARANCE := 8.0
const MAX_TREE_HEIGHT := 90.0
const MAX_PLACEMENT_ATTEMPTS := 10
const ROAD_COLOR := Color(0.4, 0.32, 0.22)
const ROAD_LIFT := 0.12
const ROAD_SAMPLE_SPACING := 2.0
const BOULDER_COLOR := Color(0.36, 0.33, 0.3)
const BOULDER_LUMPINESS := 0.35
const WOOD_PILE_SHAPE := Vector3(1.0, 0.9, 1.5)

@export var terrain: Terrain

var _road_samples: Array[PackedVector2Array] = []
var _repairs: Array[Dictionary] = []
var _building_spots: Array[Vector2] = []


func _ready() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	for building: Dictionary in layout["buildings"]:
		_add_building(building)
		_building_spots.append(Vector2(building["x"], building["z"]))
	for field: Dictionary in layout["fields"]:
		_add_field(field)
	_add_roads(layout["roads"])
	_add_trees(layout["trees"], layout["fields"])
	_add_grass(layout["grass"], layout["fields"])
	_add_boulders(layout["boulders"])
	for npc_data: Dictionary in layout["npcs"]:
		var npc := Npc.new()
		npc.setup(npc_data)
		npc.position = _ground_position(npc_data["x"], npc_data["z"])
		add_child(npc)
	for enemy_data: Dictionary in layout["enemies"]:
		var enemy := Enemy.new()
		enemy.setup(enemy_data["type"], _ground_position(enemy_data["x"], enemy_data["z"]) + Vector3.UP * 0.2)
		add_child(enemy)
	for station: Dictionary in layout["stations"]:
		var crafting_station := CraftingStation.new()
		crafting_station.name = station["id"]
		crafting_station.station_id = station["id"]
		_add_box_interactable(crafting_station, station)
	for site: Dictionary in layout["repair_sites"]:
		var repair_site := RepairSite.new()
		repair_site.setup(site)
		_add_box_interactable(repair_site, site)
	for bed_data: Dictionary in layout["beds"]:
		_add_box_interactable(Bed.new(), bed_data)
	for resource: Dictionary in layout["resources"]:
		_add_resource(resource)


## Shows or hides repairs to match the story flags.
func apply_flags(flags: Dictionary) -> void:
	for repair in _repairs:
		var repaired: bool = flags.has(repair["flag"])
		repair["repaired"].visible = repaired
		repair["damaged"].visible = not repaired


func _add_box_interactable(node: Interactable, data: Dictionary) -> void:
	node.prompt_key = data["prompt"]
	node.position = _ground_position(data["x"], data["z"])
	node.rotation_degrees.y = data.get("rotation", 0.0)
	add_child(node)

	var size := Vector3(data["width"], data["height"], data["depth"])
	node.add_child(ModelBuilder.prop(data.get("model", ""), size))
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3.UP * (size.y / 2.0)
	node.add_child(collision)


func _add_resource(data: Dictionary) -> void:
	var node := ResourceNode.new()
	node.position = _ground_position(data["x"], data["z"])
	add_child(node)

	if data["item"] == "wood":
		var pile := BoxShape3D.new()
		pile.size = WOOD_PILE_SHAPE * data["size"]
		node.setup(data, ModelBuilder.wood_pile(data["size"]), pile, Vector3.UP * (pile.size.y / 2.0))
		return
	var mesh := _boulder_mesh()
	mesh.surface_set_material(0, _material(Color(data["color"])))
	var visual := _mesh_instance(mesh, Vector3.UP * (data["size"] * 0.4))
	visual.scale = Vector3.ONE * data["size"]
	node.setup(data, visual, _rock_shape(mesh, Basis.IDENTITY.scaled(visual.scale)), visual.position)


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

	var material := Surfaces.get_material(Surfaces.Pattern.ROAD, ROAD_COLOR)
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

	var mesh := _boulder_mesh()
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
			var collision := CollisionShape3D.new()
			collision.shape = _rock_shape(mesh, basis)
			collision.position = at
			body.add_child(collision)

	mesh.surface_set_material(0, _material(BOULDER_COLOR))
	_add_multimesh(mesh, transforms, 0.0)


## A convex shape that fits the mesh. The basis is built in, because collision shapes can't be stretched.
func _rock_shape(mesh: ArrayMesh, basis: Basis) -> ConvexPolygonShape3D:
	var shape := mesh.create_convex_shape()
	shape.points = Transform3D(basis, Vector3.ZERO) * shape.points
	return shape


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

	var width: float = data["width"]
	var depth: float = data["depth"]
	var height: float = data["height"]
	var ruined: bool = data.get("ruined", false)
	var walls := ModelBuilder.house_walls(Vector3(width, height, depth), Color(data["color"]), ruined)
	body.add_child(walls)

	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height + FOUNDATION_DEPTH, depth)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3.UP * (height - FOUNDATION_DEPTH) / 2.0
	body.add_child(collision)

	if ruined:
		var fallen := ModelBuilder.damaged_roof(width, depth, height - 1.0)
		body.add_child(fallen)
		return
	var full_roof := ModelBuilder.house_roof(width, depth, height)
	body.add_child(full_roof)
	if data.has("repaired_by_flag"):
		full_roof.name = "RepairedRoof"
		var damaged := ModelBuilder.damaged_roof(width, depth, height)
		body.add_child(damaged)
		_repairs.append({ "flag": data["repaired_by_flag"], "repaired": full_roof, "damaged": damaged })
	else:
		body.add_child(ModelBuilder.chimney(width, depth, height))


func _add_field(data: Dictionary) -> void:
	var size := Vector3(data["width"], 1.0, data["depth"])
	var field := ModelBuilder.box(size, Surfaces.Pattern.CROPS, Color(data["color"]), _ground_position(data["x"], data["z"]))
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

	_add_multimesh(_fir_mesh(), transforms, 0.0, random)

	_add_tree_collision(transforms)


## A fir tree built as one mesh: a trunk under overlapping tiers of drooping branches.
func _fir_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = 21
	_add_cone(surface, TRUNK_RADIUS, 0.1, 0.0, TREE_HEIGHT * 0.6, 6, TRUNK_COLOR, TRUNK_COLOR, jitter, 0.0)
	for tier in TREE_TIERS:
		var progress := float(tier) / (TREE_TIERS - 1)
		var radius := lerpf(CROWN_RADIUS, CROWN_RADIUS * 0.35, progress)
		var bottom := lerpf(TRUNK_HEIGHT, TREE_HEIGHT * 0.72, progress)
		var top := bottom + lerpf(TREE_HEIGHT * 0.32, TREE_HEIGHT * 0.28, progress)
		var edge := CROWN_COLOR.lerp(CROWN_TIP_COLOR, progress)
		_add_cone(surface, radius, 0.0, bottom, top, 9, edge.darkened(0.35), edge, jitter, radius * 0.18)
	surface.generate_normals()
	return surface.commit()


## Adds an open cone. The jitter makes its lower rim uneven, like branch tips.
func _add_cone(surface: SurfaceTool, bottom_radius: float, top_radius: float, bottom: float, top: float, sides: int, bottom_color: Color, top_color: Color, jitter: RandomNumberGenerator, roughness: float) -> void:
	var rim: Array[Vector3] = []
	for side in sides:
		var angle := TAU * side / sides
		var radius := bottom_radius + jitter.randf_range(-roughness, roughness)
		rim.append(Vector3(cos(angle) * radius, bottom + jitter.randf_range(-roughness, roughness), sin(angle) * radius))
	for side in sides:
		var next := (side + 1) % sides
		var angle_a := TAU * side / sides
		var angle_b := TAU * next / sides
		var tip_a := Vector3(cos(angle_a) * top_radius, top, sin(angle_a) * top_radius)
		var tip_b := Vector3(cos(angle_b) * top_radius, top, sin(angle_b) * top_radius)
		for corner: Array in [[rim[side], bottom_color], [tip_a, top_color], [rim[next], bottom_color], [rim[next], bottom_color], [tip_a, top_color], [tip_b, top_color]]:
			surface.set_color(corner[1])
			surface.add_vertex(corner[0])


func _add_grass(data: Dictionary, fields: Array) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = data["seed"]
	var transforms: Array[Transform3D] = []
	for i in int(data["count"]):
		var point := Vector2.from_angle(random.randf() * TAU) * sqrt(random.randf()) * float(data["radius"])
		if not _is_clear_ground(point, fields):
			continue
		var scale_factor := random.randf_range(0.7, 1.3)
		var basis := Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * scale_factor)
		transforms.append(Transform3D(basis, _ground_position(point.x, point.y)))

	var instance := _add_multimesh(_grass_tuft_mesh(), transforms, 0.0, random)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _is_clear_ground(point: Vector2, fields: Array) -> bool:
	if terrain.is_on_landslide(point.x, point.y):
		return false
	for samples in _road_samples:
		for i in range(0, samples.size(), 4):
			if point.distance_squared_to(samples[i]) < GRASS_ROAD_CLEARANCE * GRASS_ROAD_CLEARANCE:
				return false
	for building: Vector2 in _building_spots:
		if point.distance_squared_to(building) < GRASS_BUILDING_CLEARANCE * GRASS_BUILDING_CLEARANCE:
			return false
	for field: Dictionary in fields:
		if point.distance_to(Vector2(field["x"], field["z"])) < float(field["width"]) * 0.65:
			return false
	return true


func _grass_tuft_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3.UP)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = 22
	for blade in GRASS_BLADES:
		var direction := Vector3.RIGHT.rotated(Vector3.UP, jitter.randf() * TAU) + Vector3.FORWARD * jitter.randf_range(-0.2, 0.2)
		surface.set_color(GRASS_BASE_COLOR)
		surface.add_vertex(direction * -0.04)
		surface.set_color(GRASS_BASE_COLOR)
		surface.add_vertex(direction * 0.04)
		surface.set_color(GRASS_TIP_COLOR)
		surface.add_vertex(direction * jitter.randf_range(0.0, 0.15) + Vector3.UP * jitter.randf_range(0.18, 0.36))
	return surface.commit()


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


func _add_multimesh(mesh: Mesh, transforms: Array[Transform3D], height_offset: float, tint_random: RandomNumberGenerator = null) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = tint_random != null
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		var offset := transforms[i].basis * (Vector3.UP * height_offset)
		multimesh.set_instance_transform(i, transforms[i].translated(offset))
		if tint_random != null:
			var brightness := tint_random.randf_range(0.8, 1.15)
			multimesh.set_instance_color(i, Color(brightness, brightness, brightness * 0.95))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	if tint_random != null:
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.roughness = 1.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		instance.material_override = material
	add_child(instance)
	return instance


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
