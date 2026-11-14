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
const LEAF_TRUNK_RADIUS := 0.38
const LEAF_TRUNK_HEIGHT := 6.5
const LEAF_COLOR := Color(0.13, 0.23, 0.08)
const LEAF_TIP_COLOR := Color(0.28, 0.38, 0.13)
const BUSH_COLOR := Color(0.07, 0.14, 0.06)
const BUSH_TIP_COLOR := Color(0.2, 0.3, 0.11)
const CLUMP_SIDES := 7
const CLUMP_RINGS := 4
const CLUMP_LUMPINESS := 0.18
const BUSH_CLUMPS := 4
const BUSH_SPREAD := 0.75
const PLANT_BUILDING_CLEARANCE := 11.0
const PLANT_SPOT_CLEARANCE := 4.0
const MAX_TREE_HEIGHT := 90.0
const MAX_PLACEMENT_ATTEMPTS := 10
const ROAD_COLOR := Color(0.4, 0.32, 0.22)
const ROAD_LIFT := 0.04
## A road is solid out to this share of its half width, then fades to nothing at ROAD_FEATHER, so its dirt thins out into the grass.
const ROAD_CORE := 0.55
const ROAD_FEATHER := 1.5
const RIVER_TREE_CLEARANCE := 4.0
const SITE_TREE_CLEARANCE := 4.0
const BRIDGE_OVERHANG := 1.5
const BRIDGE_WIDTH_MARGIN := 0.8
const BRIDGE_RISE := 0.9
const BRIDGE_LIFT := 0.06
const BOULDER_COLOR := Color(0.36, 0.33, 0.3)
const BOULDER_LUMPINESS := 0.35
## The longest piece of wall or palisade. Each piece is straight and level, so shorter ones follow the land.
const WALL_PIECE_LENGTH := 3.0
## How far a piece sinks below the lowest ground under it, so no gap shows on a slope.
const WALL_SINK := 0.35
## Pieces of a line are lengthened by this at each joint, so a bend leaves no gap.
const WALL_JOINT_OVERLAP := 0.12
const PROP_FOLDER := "res://assets/props/"
## Smaller props have no collision, so they never block the player.
const PROP_SOLID_SIZE := 0.6
const PLANT_CHUNK_SIZE := 128.0
const FOREST_ATTEMPTS_PER_TREE := 12
const STUMP_HEIGHT := 0.45
const STUMP_CUT_COLOR := Color(0.72, 0.58, 0.38)
## How far a chunk of trees is from the camera when it swaps to simpler meshes.
const PLANT_DETAIL_DISTANCE := 150.0
const FAR_FIR_TIERS := 2
const FAR_FIR_SIDES := 5
const BUSH_DRAW_DISTANCE := 450.0
## How far from the mine's plaza and its trail the landslide's loose boulders stay.
const MINE_BOULDER_MARGIN := 4.0
const WOOD_PILE_SHAPE := Vector3(1.0, 0.9, 1.5)

@export var terrain: Terrain

var _road_samples: Array[PackedVector2Array] = []
var _repairs: Array[Dictionary] = []
var _arrivals: Array[Npc] = []
var _building_spots: Array[Vector2] = []
var _busy_spots: Array[Vector2] = []
## What keeps the rain off: a footprint and height for each house roof and bridge deck (see RoofMap).
## roof_version changes whenever one is added or a roof is repaired, so the rain knows to redraw its map.
var roof_covers: Array[Dictionary] = []
var roof_version := 0


func _ready() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	for building: Dictionary in layout["buildings"]:
		_add_building(building)
		_building_spots.append(Vector2(building["x"], building["z"]))
	var mine_data: Dictionary = layout["mine"]
	_building_spots.append(Vector2(mine_data["x"], mine_data["z"]))
	for list: String in ["npcs", "enemies", "stations", "beds", "repair_sites", "resources"]:
		for spot: Dictionary in layout[list]:
			_busy_spots.append(Vector2(spot["x"], spot["z"]))
	for field: Dictionary in layout["fields"]:
		_add_field(field)
	_add_props(layout["props"], layout["buildings"])
	_add_walls(layout["walls"])
	_add_roads(layout["roads"])
	_add_trees(layout["trees"], layout["fields"])
	if FeatureFlags.enabled("forest"):
		_add_forest(layout["forest"], layout["fields"])
	var leaf_trees := _scatter(layout["leaf_trees"], layout["fields"])
	_add_multimesh(_leaf_tree_mesh(), leaf_trees, 0.0, _tint_random(layout["leaf_trees"]), _far_leaf_tree_mesh()).name = "LeafTrees"
	_add_tree_collision(leaf_trees)
	var bushes := _add_multimesh(_bush_mesh(), _scatter(layout["bushes"], layout["fields"]), 0.0, _tint_random(layout["bushes"]))
	bushes.name = "Bushes"
	_set_small_plants(bushes, BUSH_DRAW_DISTANCE)
	_add_grass(layout["grass"], layout["fields"])
	if FeatureFlags.enabled("ambient_life"):
		var ambient := AmbientLife.new()
		ambient.name = "AmbientLife"
		ambient.terrain = terrain
		add_child(ambient)
	_add_boulders(layout["boulders"], mine_data)
	var routines := VillagerRoutines.new()
	routines.name = "VillagerRoutines"
	add_child(routines)
	for npc_data: Dictionary in layout["npcs"]:
		var npc := Npc.new()
		npc.setup(npc_data)
		npc.position = _ground_position(npc_data["x"], npc_data["z"])
		npc.ground_height = walking_height
		add_child(npc)
		if not npc.arrival_flag.is_empty():
			_arrivals.append(npc)
			npc.apply_flags({})
		routines.add_villager(npc)
	for enemy_data: Dictionary in layout["enemies"]:
		var enemy := Enemy.new()
		enemy.setup(enemy_data["type"], _ground_position(enemy_data["x"], enemy_data["z"]) + Vector3.UP * 0.2)
		add_child(enemy)
	for station: Dictionary in layout["stations"]:
		var crafting_station := CraftingStation.new()
		crafting_station.name = station["id"]
		crafting_station.station_id = station["id"]
		if station.has("work_spot"):
			var spot: Array = station["work_spot"]
			crafting_station.work_spot = Vector3(spot[0], spot[1], spot[2])
		_add_box_interactable(crafting_station, station)
	for site: Dictionary in layout["repair_sites"]:
		var repair_site := RepairSite.new()
		repair_site.setup(site)
		repair_site.name = site["flag"]
		_add_box_interactable(repair_site, site)
	for bed_data: Dictionary in layout["beds"]:
		_add_box_interactable(Bed.new(), bed_data)
	for resource: Dictionary in layout["resources"]:
		_add_resource(resource)
	var mine := Mine.new()
	mine.setup(mine_data)
	mine.position = _ground_position(mine_data["x"], mine_data["z"])
	mine.rotation_degrees.y = mine_data["rotation"]
	add_child(mine)


## Returns what changes during play in the world, in the same order as the layout file.
func to_data() -> Dictionary:
	var enemies := []
	var resources := []
	for child in get_children():
		if child is Enemy:
			enemies.append(child.to_data())
		elif child is ResourceNode:
			resources.append(child.to_data())
	var result := { "enemies": enemies, "resources": resources }
	if has_node("Forest"):
		result["forest"] = (get_node("Forest") as Forest).to_data()
	return result


func load_data(data: Dictionary) -> void:
	var enemies: Array = data["enemies"]
	var resources: Array = data["resources"]
	for child in get_children():
		if child is Enemy and not enemies.is_empty():
			child.load_data(enemies.pop_front())
			var ground := terrain.height_at(child.position.x, child.position.z)
			if child.position.y < ground - SaveGame.BELOW_GROUND_MARGIN:
				child.position.y = ground
		elif child is ResourceNode and not resources.is_empty():
			child.load_data(resources.pop_front())
	if has_node("Forest"):
		(get_node("Forest") as Forest).load_data(data.get("forest", {}))


## Returns the x and z of each place the compass always points out, such as the buried mine.
func landmark_positions() -> Array[Vector2]:
	var places: Array[Vector2] = []
	for child in get_children():
		if child is Mine and child.landmark:
			places.append(Vector2(child.position.x, child.position.z))
	return places


## Returns the x and z of a quest marker: a villager, station, or repair site by name, or a pair of numbers.
func marker_position(marker: Variant) -> Vector2:
	if marker is String:
		var place: Node3D = get_node(marker)
		return Vector2(place.position.x, place.position.z)
	return Vector2(marker[0], marker[1])


## Shows or hides repairs to match the story flags.
func apply_flags(flags: Dictionary) -> void:
	for repair in _repairs:
		var repaired: bool = flags.has(repair["flag"])
		repair["repaired"].visible = repaired
		repair["damaged"].visible = not repaired
		if repair["cover"]["active"] != repaired:
			repair["cover"]["active"] = repaired
			roof_version += 1
	for npc in _arrivals:
		npc.apply_flags(flags)


func _add_box_interactable(node: Interactable, data: Dictionary) -> void:
	node.prompt_key = data["prompt"]
	node.position = _ground_position(data["x"], data["z"])
	node.rotation_degrees.y = data.get("rotation", 0.0)
	add_child(node)

	var size := Vector3(data["width"], data["height"], data["depth"])
	if data.has("asset"):
		var model: Node3D = load(data["asset"]).instantiate()
		PropTuning.apply(model, String(data["asset"]).get_file().get_basename())
		node.add_child(model)
	else:
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
	var pattern: Surfaces.Pattern = Surfaces.Pattern.COAL if data["item"] == "coal" else Surfaces.Pattern.IRON_ORE
	mesh.surface_set_material(0, Surfaces.get_material(pattern, Color(data["color"])))
	var visual := _mesh_instance(mesh, Vector3.UP * (data["size"] * 0.4))
	visual.scale = Vector3.ONE * data["size"]
	node.setup(data, visual, _rock_shape(mesh, Basis.IDENTITY.scaled(visual.scale)), visual.position)


func _add_roads(roads: Array) -> void:
	var root := Node3D.new()
	root.name = "Roads"
	add_child(root)
	for i in roads.size():
		var samples := terrain.roads[i].positions
		_road_samples.append(samples)
		root.add_child(_road_mesh(samples, roads[i]["width"]))
		_add_bridges(samples, roads[i]["width"])


## Spans each stretch of road that crosses the river.
## How near the river a walker may be before a bridge deck could be under their feet.
const WALK_BRIDGE_DISTANCE := 3.0
## How far above the river bed a walker's feet can be, and how deep below the deck to look.
const WALK_RAY_ABOVE := 4.0
const WALK_RAY_BELOW := 1.0

## Where a walker's feet are at an x and a z: on the ground, or on a bridge deck over the river.
## Looking for the deck takes a ray, so only places near the river do it.
func walking_height(x: float, z: float) -> float:
	var ground := terrain.height_at(x, z)
	if terrain.river_clearance(x, z) > WALK_BRIDGE_DISTANCE:
		return ground
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, ground + WALK_RAY_ABOVE, z), Vector3(x, ground - WALK_RAY_BELOW, z))
	var skipped: Array[RID] = []
	for i in 4:
		query.exclude = skipped
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit["collider"] == terrain:
			break
		if hit["collider"] is StaticBody3D and not hit["collider"] is Npc and hit["normal"].y >= 0.7:
			return hit["position"].y
		skipped.append(hit["collider"].get_rid())
	return ground


func _add_bridges(samples: PackedVector2Array, road_width: float) -> void:
	var i := 0
	while i < samples.size():
		if terrain.river_clearance(samples[i].x, samples[i].y) >= 0.0:
			i += 1
			continue
		var first := i
		while i < samples.size() and terrain.river_clearance(samples[i].x, samples[i].y) < 0.0:
			i += 1
		var start := samples[maxi(first - 1, 0)]
		var end := samples[mini(i, samples.size() - 1)]
		var along := (end - start).normalized()
		start -= along * BRIDGE_OVERHANG
		end += along * BRIDGE_OVERHANG
		var height := (terrain.height_at(start.x, start.y) + terrain.height_at(end.x, end.y)) / 2.0
		var middle := (start + end) / 2.0
		var bridge := ModelBuilder.bridge(start.distance_to(end), road_width + BRIDGE_WIDTH_MARGIN, BRIDGE_RISE)
		bridge.name = "Bridge"
		bridge.position = Vector3(middle.x, height + BRIDGE_LIFT, middle.y)
		bridge.rotation.y = atan2(along.x, along.y)
		add_child(bridge, true)
		roof_covers.append({
			"center": middle, "half": Vector2((road_width + BRIDGE_WIDTH_MARGIN) / 2.0, start.distance_to(end) / 2.0),
			"yaw": bridge.rotation.y, "base": bridge.position.y, "rise": BRIDGE_RISE, "shape": "arch", "active": true,
		})
		roof_version += 1


func _road_mesh(samples: PackedVector2Array, width: float) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3.UP)
	var solid := Color(ROAD_COLOR, 1.0)
	var faded := Color(ROAD_COLOR, 0.0)
	var was_over_river := false
	for i in samples.size():
		var tangent := (samples[mini(i + 1, samples.size() - 1)] - samples[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-tangent.y, tangent.x)
		var half_width := width / 2.0 * (1.0 + sin(i * 0.37) * 0.1 + sin(i * 0.11) * 0.1)
		# Four vertices across: outer left, inner left, inner right, outer right.
		for column: Array in [[ROAD_FEATHER, faded], [ROAD_CORE, solid], [-ROAD_CORE, solid], [-ROAD_FEATHER, faded]]:
			var edge: Vector2 = samples[i] + side * half_width * column[0]
			surface.set_color(column[1])
			surface.add_vertex(Vector3(edge.x, terrain.height_at(edge.x, edge.y) + ROAD_LIFT, edge.y))
		# The road stops at the river, and a bridge carries it over.
		var over_river := terrain.river_clearance(samples[i].x, samples[i].y) < 0.0
		if i > 0 and not over_river and not was_over_river:
			for column in 3:
				var left := (i - 1) * 4 + column
				for index in [left, left + 1, left + 4, left + 1, left + 5, left + 4]:
					surface.add_index(index)
		was_over_river = over_river

	var material := Surfaces.get_material(Surfaces.Pattern.ROAD, ROAD_COLOR)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _add_boulders(data: Dictionary, mine: Dictionary) -> void:
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
		# The mine's plaza and the trail to it stay clear.
		if point.distance_to(Vector2(mine["x"], mine["z"])) < float(mine["plaza_radius"]) + MINE_BOULDER_MARGIN or _is_on_road(point, MINE_BOULDER_MARGIN):
			continue
		var at := _ground_position(point.x, point.y)
		transforms.append(Transform3D(basis, at))

		if size >= data["solid_size"]:
			var collision := CollisionShape3D.new()
			collision.shape = _rock_shape(mesh, basis)
			collision.position = at
			body.add_child(collision)

	mesh.surface_set_material(0, Surfaces.get_material(Surfaces.Pattern.BOULDER, BOULDER_COLOR))
	_add_multimesh(mesh, transforms, 0.0)


func _is_on_road(point: Vector2, margin: float) -> bool:
	for road in terrain.roads:
		var found := road.nearest(point.x, point.y)
		if found.x < found.z + margin:
			return true
	return false


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

	# The parts that never change are joined into one mesh. A roof that gets repaired stays apart.
	if ruined:
		walls.add_child(ModelBuilder.damaged_roof(width, depth, height - 1.0))
	elif data.has("repaired_by_flag"):
		var full_roof := ModelBuilder.house_roof(width, depth, height)
		full_roof.name = "RepairedRoof"
		body.add_child(full_roof)
		var damaged := ModelBuilder.damaged_roof(width, depth, height)
		body.add_child(damaged)
		_repairs.append({ "flag": data["repaired_by_flag"], "repaired": full_roof, "damaged": damaged, "cover": _add_roof_cover(data, body, false) })
	else:
		walls.add_child(ModelBuilder.house_roof(width, depth, height))
		walls.add_child(ModelBuilder.chimney(width, depth, height))
		_add_roof_cover(data, body, true)
	ModelBuilder.merged(walls)


## Notes where a house roof keeps the rain off, and returns that entry so a repair can switch it on.
func _add_roof_cover(data: Dictionary, body: Node3D, active: bool) -> Dictionary:
	var cover := {
		"center": Vector2(body.position.x, body.position.z),
		"half": Vector2(data["width"] + ModelBuilder.ROOF_OVERHANG, data["depth"] + ModelBuilder.ROOF_OVERHANG) / 2.0,
		"yaw": body.rotation.y, "base": body.position.y + float(data["height"]), "rise": ModelBuilder.ROOF_HEIGHT,
		"shape": "ridge", "active": active,
	}
	roof_covers.append(cover)
	roof_version += 1
	return cover


## Places the generated props. "building" makes x and z relative to that building, and "on"
## sets a prop on top of an earlier one, with x and z as the offset from its center.
func _add_props(props: Array, buildings: Array) -> void:
	var building_transforms := {}
	for building: Dictionary in buildings:
		var angle := deg_to_rad(float(building["rotation"]))
		building_transforms[building["id"]] = Transform2D(-angle, Vector2(building["x"], building["z"]))
	var root := Node3D.new()
	root.name = "Props"
	add_child(root)
	var placed := {}
	for data: Dictionary in props:
		var body := StaticBody3D.new()
		body.name = data["model"]
		var heading: float = data.get("rotation", 0.0)
		var offset := Vector2(data["x"], data["z"])
		var at: Vector3
		if data.has("on"):
			var below: Dictionary = placed[data["on"]]
			at = below["position"] + Vector3(offset.x, below["height"], offset.y)
		else:
			var point := offset
			if data.has("building"):
				point = building_transforms[data["building"]] * offset
				heading += _building_heading(buildings, data["building"])
			at = _ground_position(point.x, point.y)
		body.position = at + Vector3.UP * float(data.get("lift", 0.0))
		body.rotation_degrees = Vector3(data.get("tilt", 0.0), heading, 0.0)
		root.add_child(body)

		var model: Node3D = load(PROP_FOLDER + data["model"] + ".glb").instantiate()
		PropTuning.apply(model, data["model"])
		body.add_child(model)
		var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
		# In the body's space, so the tuned scale and lift count for collision and for props set on top.
		var bounds: AABB = (body.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		placed[data["model"]] = { "position": at, "height": bounds.end.y }
		_busy_spots.append(Vector2(at.x, at.z))
		# Small props are specks from far away, and drawing them and their shadows costs as much as a house.
		if bounds.get_longest_axis_size() < PROP_SOLID_SIZE:
			mesh.visibility_range_end = FeatureFlags.value("small_prop_draw_distance", 80.0)
		if not data.has("tilt") and not data.has("on") and bounds.get_longest_axis_size() >= PROP_SOLID_SIZE:
			var shape := BoxShape3D.new()
			shape.size = bounds.size
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.position = bounds.get_center()
			body.add_child(collision)


## Builds the walls and palisades. Each entry is a line of "points" ([x, z] pairs, open at the ends
## for gates) that gets cut into short straight pieces with a collider each. The pieces of one entry
## join into a single mesh, so a whole palisade costs a few draw calls.
func _add_walls(walls: Array) -> void:
	var root := Node3D.new()
	root.name = "Walls"
	add_child(root)
	for i in walls.size():
		var data: Dictionary = walls[i]
		var line := Node3D.new()
		line.name = "%s_%d" % [data["kind"], i]
		root.add_child(line)
		var points: Array = data["points"]
		var piece_index := 0
		for j in points.size() - 1:
			var from := Vector2(points[j][0], points[j][1])
			var to := Vector2(points[j + 1][0], points[j + 1][1])
			var count := maxi(1, ceili(from.distance_to(to) / WALL_PIECE_LENGTH))
			for k in count:
				var start := from.lerp(to, float(k) / count)
				var end := from.lerp(to, float(k + 1) / count)
				var joined_start := k > 0 or j > 0
				var joined_end := k < count - 1 or j < points.size() - 2
				line.add_child(_wall_piece(data, start, end, joined_start, joined_end, int(data["seed"]) + piece_index))
				piece_index += 1
				_busy_spots.append((start + end) / 2.0)
		ModelBuilder.merged(line)


func _wall_piece(data: Dictionary, start: Vector2, end: Vector2, joined_start: bool, joined_end: bool, seed_value: int) -> StaticBody3D:
	var along := end - start
	var middle := (start + end) / 2.0
	var low := minf(terrain.height_at(start.x, start.y), minf(terrain.height_at(end.x, end.y), terrain.height_at(middle.x, middle.y)))
	var high := maxf(terrain.height_at(start.x, start.y), maxf(terrain.height_at(end.x, end.y), terrain.height_at(middle.x, middle.y)))
	var height: float = data["height"] + (high - low) + WALL_SINK
	var length := along.length() + (WALL_JOINT_OVERLAP if joined_start else 0.0) + (WALL_JOINT_OVERLAP if joined_end else 0.0)
	var piece: StaticBody3D
	if data["kind"] == "palisade":
		piece = ModelBuilder.palisade(length, height, seed_value)
	else:
		piece = ModelBuilder.stone_wall(length, height, data.get("thickness", 0.6), seed_value)
	var direction := along.normalized()
	# The piece grows evenly from its middle, so shift it when only one end is lengthened.
	var shift := ((WALL_JOINT_OVERLAP if joined_end else 0.0) - (WALL_JOINT_OVERLAP if joined_start else 0.0)) / 2.0
	var center := middle + direction * shift
	piece.position = Vector3(center.x, low - WALL_SINK, center.y)
	piece.rotation.y = atan2(-direction.y, direction.x)
	return piece


func _building_heading(buildings: Array, id: String) -> float:
	for building: Dictionary in buildings:
		if building["id"] == id:
			return building["rotation"]
	return 0.0


func _add_field(data: Dictionary) -> void:
	var size := Vector3(data["width"], 1.0, data["depth"])
	var field := ModelBuilder.box(size, Surfaces.Pattern.CROPS, Color(data["color"]), _ground_position(data["x"], data["z"]))
	field.rotation_degrees.y = data["rotation"]
	add_child(field)


func _add_trees(data: Dictionary, fields: Array) -> void:
	var transforms := _scatter(data, fields)
	_add_multimesh(_fir_mesh(TREE_TIERS, 9), transforms, 0.0, _tint_random(data), _fir_mesh(FAR_FIR_TIERS, FAR_FIR_SIDES))
	_add_tree_collision(transforms)


## Trees close together in a rough circle, thinning toward its edge.
func _add_forest(data: Dictionary, fields: Array) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = data["seed"]
	var center := Vector2(data["x"], data["z"])
	var spacing := float(data["spacing"])
	var taken: Dictionary = {}
	var transforms: Array[Transform3D] = []
	var kinds := PackedByteArray()
	var tints := PackedFloat32Array()
	var attempts := int(data["count"]) * FOREST_ATTEMPTS_PER_TREE
	for attempt in attempts:
		if transforms.size() >= int(data["count"]):
			break
		# Without the square root, trees would crowd the middle. The power thins the edge.
		var point := center + Vector2.from_angle(random.randf() * TAU) * float(data["radius"]) * pow(random.randf(), 0.6)
		var cell := Vector2i((point / spacing).floor())
		if _is_spot_taken(taken, cell, point, spacing) or not _is_tree_allowed(point, data, fields):
			continue
		taken[cell] = point
		var scale_factor := random.randf_range(0.8, 1.4)
		var basis := Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * scale_factor)
		transforms.append(Transform3D(basis, _ground_position(point.x, point.y)))
		kinds.append(1 if random.randf() < float(data["leaf_share"]) else 0)
		tints.append(random.randf_range(0.8, 1.15))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var meshes: Array[Array] = [[_fir_mesh(TREE_TIERS, 9), _fir_mesh(FAR_FIR_TIERS, FAR_FIR_SIDES)], [_leaf_tree_mesh(), _far_leaf_tree_mesh()]]
	var forest := Forest.new()
	forest.name = "Forest"
	add_child(forest)
	forest.setup(data, transforms, kinds, meshes, _stump_mesh(), material, tints)


func _is_spot_taken(taken: Dictionary, cell: Vector2i, point: Vector2, spacing: float) -> bool:
	for x in range(cell.x - 1, cell.x + 2):
		for y in range(cell.y - 1, cell.y + 2):
			var other: Variant = taken.get(Vector2i(x, y))
			if other != null and point.distance_to(other) < spacing:
				return true
	return false


## What's left of a felled tree: a short trunk with a pale cut on top.
func _stump_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var jitter := RandomNumberGenerator.new()
	_add_cone(surface, TRUNK_RADIUS * 1.15, TRUNK_RADIUS, 0.0, STUMP_HEIGHT, 7, TRUNK_COLOR, TRUNK_COLOR, jitter, 0.0)
	_add_cone(surface, TRUNK_RADIUS, 0.0, STUMP_HEIGHT, STUMP_HEIGHT + 0.02, 7, STUMP_CUT_COLOR, STUMP_CUT_COLOR, jitter, 0.0)
	surface.generate_normals()
	return surface.commit()


## Separate from the placement, so that adding plants never changes where others stand.
func _tint_random(data: Dictionary) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = int(data["seed"]) + 1
	return random


## Picks random allowed spots in a ring around the village, with varied turns and sizes.
func _scatter(data: Dictionary, fields: Array) -> Array[Transform3D]:
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
	return transforms


## A broad tree: a trunk under a few overlapping clumps of leaves.
func _leaf_tree_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = 23
	_add_cone(surface, LEAF_TRUNK_RADIUS, 0.14, 0.0, LEAF_TRUNK_HEIGHT, 6, TRUNK_COLOR, TRUNK_COLOR, jitter, 0.0)
	_add_clump(surface, Vector3(0.0, 7.6, 0.0), Vector3(3.3, 2.6, 3.3), LEAF_COLOR, LEAF_TIP_COLOR, jitter)
	_add_clump(surface, Vector3(2.2, 6.3, 0.7), Vector3(2.2, 1.7, 2.2), LEAF_COLOR, LEAF_TIP_COLOR, jitter)
	_add_clump(surface, Vector3(-1.8, 6.5, 1.4), Vector3(2.1, 1.7, 2.1), LEAF_COLOR, LEAF_TIP_COLOR, jitter)
	_add_clump(surface, Vector3(-0.6, 6.2, -2.1), Vector3(2.3, 1.6, 2.3), LEAF_COLOR, LEAF_TIP_COLOR, jitter)
	surface.generate_normals()
	return surface.commit()


## The same tree as seen from far away: one big clump of leaves on a thin trunk.
func _far_leaf_tree_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = 23
	_add_cone(surface, LEAF_TRUNK_RADIUS, 0.14, 0.0, LEAF_TRUNK_HEIGHT, 3, TRUNK_COLOR, TRUNK_COLOR, jitter, 0.0)
	_add_clump(surface, Vector3(0.0, 7.0, 0.0), Vector3(4.2, 3.1, 4.2), LEAF_COLOR, LEAF_TIP_COLOR, jitter)
	surface.generate_normals()
	return surface.commit()


## A few low clumps of leaves with no trunk.
func _bush_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = 24
	for clump in BUSH_CLUMPS:
		var angle := TAU * clump / BUSH_CLUMPS + jitter.randf_range(-0.4, 0.4)
		var out := 0.0 if clump == 0 else jitter.randf_range(0.5, 1.0) * BUSH_SPREAD
		var size := jitter.randf_range(0.4, 0.6)
		var height := size * 0.7 + (0.35 if clump == 0 else jitter.randf_range(0.0, 0.2))
		_add_clump(surface, Vector3(cos(angle) * out, height, sin(angle) * out), Vector3(size, size * 0.85, size), BUSH_COLOR, BUSH_TIP_COLOR, jitter)
	surface.generate_normals()
	return surface.commit()


## Adds an uneven ball of leaves, darker underneath and lighter on top.
func _add_clump(surface: SurfaceTool, center: Vector3, size: Vector3, bottom_color: Color, top_color: Color, jitter: RandomNumberGenerator) -> void:
	var rings: Array[PackedVector3Array] = []
	for ring in CLUMP_RINGS - 1:
		var up := PI * (float(ring + 1) / CLUMP_RINGS - 0.5)
		var points := PackedVector3Array()
		for side in CLUMP_SIDES:
			var around := TAU * side / CLUMP_SIDES
			var lump := 1.0 + jitter.randf_range(-CLUMP_LUMPINESS, CLUMP_LUMPINESS)
			points.append(center + Vector3(cos(up) * cos(around), sin(up), cos(up) * sin(around)) * size * lump)
		rings.append(points)
	var bottom := center + Vector3.DOWN * size.y
	var top := center + Vector3.UP * size.y
	var add := func(corner: Vector3) -> void:
		surface.set_color(bottom_color.lerp(top_color, clampf((corner.y - bottom.y) / (top.y - bottom.y), 0.0, 1.0)))
		surface.add_vertex(corner)
	for side in CLUMP_SIDES:
		var next := (side + 1) % CLUMP_SIDES
		for corner: Vector3 in [bottom, rings[0][side], rings[0][next], top, rings[rings.size() - 1][next], rings[rings.size() - 1][side]]:
			add.call(corner)
		for ring in rings.size() - 1:
			var low: PackedVector3Array = rings[ring]
			var high: PackedVector3Array = rings[ring + 1]
			for corner: Vector3 in [low[side], high[side], low[next], low[next], high[side], high[next]]:
				add.call(corner)


## A fir tree built as one mesh: a trunk under overlapping tiers of drooping branches.
func _fir_mesh(tiers: int, sides: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = 21
	_add_cone(surface, TRUNK_RADIUS, 0.1, 0.0, TREE_HEIGHT * 0.6, mini(sides, 6), TRUNK_COLOR, TRUNK_COLOR, jitter, 0.0)
	for tier in tiers:
		var progress := float(tier) / (tiers - 1)
		var radius := lerpf(CROWN_RADIUS, CROWN_RADIUS * 0.35, progress)
		var bottom := lerpf(TRUNK_HEIGHT, TREE_HEIGHT * 0.72, progress)
		var top := bottom + lerpf(TREE_HEIGHT * 0.32, TREE_HEIGHT * 0.28, progress)
		var edge := CROWN_COLOR.lerp(CROWN_TIP_COLOR, progress)
		_add_cone(surface, radius, 0.0, bottom, top, sides, edge.darkened(0.35), edge, jitter, radius * 0.18)
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
	var grass := GrassField.new()
	grass.name = "Grass"
	grass.setup(terrain, data, fields, _road_samples, _building_spots)
	add_child(grass)


func _is_tree_allowed(point: Vector2, data: Dictionary, fields: Array) -> bool:
	for samples in _road_samples:
		for sample in samples:
			if point.distance_to(sample) < data["road_clearance"]:
				return false
	if terrain.height_at(point.x, point.y) > data.get("max_height", MAX_TREE_HEIGHT):
		return false
	for building: Vector2 in _building_spots:
		if point.distance_to(building) < PLANT_BUILDING_CLEARANCE:
			return false
	for spot: Vector2 in _busy_spots:
		if point.distance_to(spot) < PLANT_SPOT_CLEARANCE:
			return false
	if terrain.is_on_landslide(point.x, point.y) or terrain.river_clearance(point.x, point.y) < RIVER_TREE_CLEARANCE:
		return false
	for site: Dictionary in terrain.building_sites:
		if point.distance_to(Vector2(site["x"], site["z"])) < float(site["radius"]) + float(site["blend"]) + SITE_TREE_CLEARANCE:
			return false
	for field: Dictionary in fields:
		if point.distance_to(Vector2(field["x"], field["z"])) < data["field_clearance"]:
			return false
	return true


## Splits the instances into chunks by area, so that Godot can skip the ones out of view.
func _add_multimesh(mesh: Mesh, transforms: Array[Transform3D], height_offset: float, tint_random: RandomNumberGenerator = null, far_mesh: Mesh = null) -> Node3D:
	var chunks: Dictionary = {}
	for transform in transforms:
		var key := Vector2i((transform.origin / PLANT_CHUNK_SIZE).floor().x, (transform.origin / PLANT_CHUNK_SIZE).floor().z)
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(transform)

	var material: StandardMaterial3D = null
	if tint_random != null:
		material = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.roughness = 1.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var group := Node3D.new()
	add_child(group)
	for chunk: Array in chunks.values():
		# The far version is filled in the same pass, since a MultiMesh's buffer can't always be read back.
		var multimeshes: Array[MultiMesh] = [_new_multimesh(mesh, chunk.size(), tint_random != null)]
		if far_mesh != null:
			multimeshes.append(_new_multimesh(far_mesh, chunk.size(), tint_random != null))
		for i in chunk.size():
			var transform: Transform3D = chunk[i]
			var offset := transform.basis * (Vector3.UP * height_offset)
			var brightness := tint_random.randf_range(0.8, 1.15) if tint_random != null else 1.0
			for multimesh in multimeshes:
				multimesh.set_instance_transform(i, transform.translated(offset))
				if tint_random != null:
					multimesh.set_instance_color(i, Color(brightness, brightness, brightness * 0.95))
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimeshes[0]
		instance.material_override = material
		group.add_child(instance)
		if far_mesh != null:
			_add_far_version(instance, multimeshes[1])
	return group


## Beyond the distance, a chunk swaps to the simpler mesh, which has the same places and tints.
func _new_multimesh(mesh: Mesh, count: int, tinted: bool) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = tinted
	multimesh.mesh = mesh
	multimesh.instance_count = count
	return multimesh


func _add_far_version(near: MultiMeshInstance3D, far_multimesh: MultiMesh) -> void:
	near.visibility_range_end = PLANT_DETAIL_DISTANCE
	var far := MultiMeshInstance3D.new()
	far.multimesh = far_multimesh
	far.material_override = near.material_override
	far.visibility_range_begin = PLANT_DETAIL_DISTANCE
	near.add_child(far)


## Small plants don't cast shadows, and stop being drawn at this distance, where they are specks.
func _set_small_plants(group: Node3D, draw_distance: float) -> void:
	for instance: MultiMeshInstance3D in group.get_children():
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = draw_distance


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
