extends SceneTree
## Run with: godot --headless --path . --script res://tests/smoke_test.gd

const TEST_SAVE := "user://smoke_test_save.json"
const TEST_SLOT_2 := "user://smoke_test_save_2.json"
const TEST_SLOT_3 := "user://smoke_test_save_3.json"
const TEST_SETTINGS := "user://smoke_test_settings.json"
const TEST_FLAGS_A := "user://smoke_test_flags_a.json"
const TEST_FLAGS_B := "user://smoke_test_flags_b.json"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.remove_absolute(TEST_SETTINGS)
	Settings.path = TEST_SETTINGS
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.show_menu = false
	scene.save_path = TEST_SAVE
	root.add_child(scene)
	await _physics_frames(90)

	var terrain: Terrain = scene.get_node("Terrain")
	var player: Player = scene.get_node("Player")
	var day_night: DayNight = scene.get_node("DayNight")
	var village: Village = scene.get_node("Village")

	_check(absf(terrain.height_at(0.0, -28.0)) < 2.0, "village site stays low")
	_check(terrain.height_at(0.0, 600.0) > 60.0, "mountains surround the valley")
	_check(player.is_on_floor(), "player lands on terrain")
	_check(terrain.get_children().filter(func(child): return child is MeshInstance3D).size() > 100, "the terrain is split into chunks")
	var slowed_on_land := 0
	for z in range(-500, 500, 10):
		for x in range(-500, 500, 10):
			if terrain.river_clearance(x, z) >= 0.0 and terrain.wading_factor(Vector3(x, terrain.height_at(x, z), z)) < 1.0:
				slowed_on_land += 1
	_check(slowed_on_land == 0, "dry land doesn't slow anyone")
	var in_river := terrain.river.positions[terrain.river.positions.size() / 2]
	var river_floor := Vector3(in_river.x, terrain.height_at(in_river.x, in_river.y), in_river.y)
	_check(terrain.wading_factor(river_floor) == Terrain.WADING_SPEED_FACTOR, "wading through the river slows people down")
	_check(terrain.wading_factor(river_floor + Vector3.UP * 5.0) == 1.0, "a bridge over the river doesn't slow anyone")
	_check(absf(player.position.y - terrain.height_at(player.position.x, player.position.z)) < 1.0, "collision matches terrain")
	_check(village.get_node_or_null("forge") != null, "buildings load from data")
	# Every part is a draw call, and another for each shadow, so a building is one mesh per material.
	var building_parts := village.get_node("forge").find_children("*", "MeshInstance3D", true, false)
	var bridge_parts := village.get_node("Bridge").find_children("*", "MeshInstance3D", true, false)
	_check(building_parts.size() == 1 and building_parts[0].mesh.get_surface_count() <= 6 and bridge_parts.size() == 1, "buildings and bridges are joined into one mesh each")
	var bowl: MeshInstance3D = village.get_node("Props/bowl_1").find_children("*", "MeshInstance3D", true, false)[0]
	var door: MeshInstance3D = village.get_node("Props/door_3").find_children("*", "MeshInstance3D", true, false)[0]
	_check(bowl.visibility_range_end > 0.0 and door.visibility_range_end == 0.0, "only small props stop being drawn far away")
	_check(village.get_node("Roads").get_child_count() == 3, "roads load from data")
	_check(village.get_node("Boulders").get_child_count() > 0, "boulders have collision")
	_check(village.get_node("Boulders").get_child(0).shape is ConvexPolygonShape3D, "boulders collide with their real shape")
	_check(terrain.is_on_landslide(40.0, -300.0) and not terrain.is_on_landslide(0.0, 0.0), "landslide stays out of the village")

	var start := player.position
	Input.action_press("move_forward")
	await _physics_frames(120)
	Input.action_release("move_forward")
	_check(player.position.z < start.z - 3.0, "player walks forward")

	var before_toggle := player.first_person
	var event := InputEventAction.new()
	event.action = "toggle_camera"
	event.pressed = true
	Input.parse_input_event(event)
	await _physics_frames(5)
	_check(player.first_person != before_toggle, "camera mode switches")
	_check(not player.get_node("Body").visible, "body is hidden in first person")

	player.position = Vector3(0.0, 200.0, 900.0)
	await _physics_frames(2)
	_check(Vector2(player.position.x, player.position.z).length() <= Player.WORLD_RADIUS + 1.0, "player stays inside the world")

	day_night.hour = 12.0
	var noon := day_night.daylight()
	day_night.hour = 1.0
	var night := day_night.daylight()
	_check(noon == 1.0 and night == 0.0, "daylight follows the hour")
	var sun: DirectionalLight3D = scene.get_node("Sun")
	var sky_position := func(hour: float) -> Vector3:
		day_night.hour = hour
		day_night._apply()
		return sun.basis.z
	var morning: Vector3 = sky_position.call(DayNight.SUNRISE + 0.5)
	var midday: Vector3 = sky_position.call((DayNight.SUNRISE + DayNight.SUNSET) / 2.0)
	var evening: Vector3 = sky_position.call(DayNight.SUNSET - 0.5)
	_check(morning.x > 0.9 and morning.y > 0.0, "the sun rises in the east")
	_check(midday.y > 0.7 and midday.z > 0.5 and absf(midday.x) < 0.01, "the sun is high in the south at midday")
	_check(evening.x < -0.9 and evening.y > 0.0, "the sun sets in the west")
	day_night.hour = 9.0
	day_night._apply()

	for action in ["move_forward", "look_left", "jump", "sprint", "toggle_camera", "toggle_torch"]:
		var kinds := {}
		for input in InputMap.action_get_events(action):
			kinds[input.get_class()] = true
		_check(kinds.size() >= 1 and _has_joypad(kinds), "%s has a controller binding" % action)

	await _test_land_and_river(scene, player)
	await _test_river_collision(terrain, player)
	_test_terrain_seams(terrain)
	await _test_hud(scene, player)
	_test_character_models(player)
	_test_generated_props()
	_test_feature_flags()
	await _test_torch(player)
	var torch: Torch = player._torch
	day_night.hour = 12.0
	var noon_share := torch.light_share()
	day_night.hour = 1.0
	_check(torch.light_share() == 1.0 and noon_share < 0.5, "a torch's light is weak in daylight")
	player.inventory.add(Player.TORCH_ITEM)
	player.set_torch_lit(true)
	await process_frame
	await process_frame
	var flame: Node3D = torch.get_node("Flame") if torch.has_node("Flame") else torch.find_child("Flame", true, false)
	var flame_height := flame.scale.y
	for i in 5:
		await process_frame
	_check(torch._sparks.emitting and torch._smoke.emitting and flame.scale.y != flame_height, "a lit torch moves and gives off sparks and smoke")
	player.set_torch_lit(false)
	_check(not torch._sparks.emitting, "an unlit torch stops giving off sparks")
	player.inventory.remove(Player.TORCH_ITEM)
	day_night.hour = 9.0
	await _test_crafting(scene, player)
	await _test_story(scene, player)
	await _test_combat(scene, player)
	await _test_enemy_navigation(scene, player)
	await _test_enemy_crowds_and_bridges(scene, player)
	await _test_gathering_collision(scene, player)
	await _test_forest(scene, player)
	await _test_player_fixes(scene, player)
	await _test_save_and_menu(scene, player, day_night)
	await _test_grass_cost(scene)
	_test_grass_cell_edge(scene)
	await _test_settings(scene, player)
	_test_translations()

	print("FAILED: %d" % _failures if _failures > 0 else "ALL PASSED")
	quit(1 if _failures > 0 else 0)


func _test_land_and_river(scene: Node, player: Player) -> void:
	var terrain: Terrain = scene.get_node("Terrain")
	var village: Village = scene.get_node("Village")
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Village.LAYOUT_PATH))

	_check(terrain.get_node("Water").mesh.get_surface_count() == 1, "the river has water")
	_check(terrain.river_clearance(0.0, 5.0) < 0.0, "the river runs through the village")
	_check(terrain.height_at(0.0, 5.0) < terrain.water_height(0.0, 5.0), "the river bed lies under the water")
	var downhill := true
	for i in range(1, terrain.river.heights.size()):
		downhill = downhill and terrain.river.heights[i] <= terrain.river.heights[i - 1]
	_check(downhill, "the river only flows downhill")

	var misplaced := PackedStringArray()
	for list in ["buildings", "fields", "npcs", "enemies", "repair_sites", "beds", "stations", "resources"]:
		for spot: Dictionary in layout[list]:
			if terrain.river_clearance(spot["x"], spot["z"]) < 2.0 or _slope_degrees(terrain, spot["x"], spot["z"]) > 12.0:
				misplaced.append("%s (%s, %s)" % [list, spot["x"], spot["z"]])
	_check(misplaced.is_empty(), "everything stands clear of the river on level ground %s" % ", ".join(misplaced))
	var steepest_road := 0.0
	for road in terrain.roads:
		for at in road.positions:
			if terrain.river_clearance(at.x, at.y) > 0.0:
				steepest_road = maxf(steepest_road, _slope_degrees(terrain, at.x, at.y))
	_check(steepest_road < 20.0, "roads stay gentle (steepest %.1f degrees)" % steepest_road)

	_check(terrain.building_sites.size() == 2, "the assembly building and the fort each have a site")
	for site: Dictionary in terrain.building_sites:
		_test_building_site(terrain, site)
	for hill: Dictionary in layout["hills"]:
		var rise := terrain.height_at(hill["x"], hill["z"]) - terrain.height_at(hill["x"] + hill["radius"], hill["z"])
		_check(rise > 3.0, "a hill stands near the village at (%s, %s)" % [hill["x"], hill["z"]])

	# Headless runs can't read a MultiMesh back, so this checks the same repeatable placement.
	for plants: String in ["leaf_trees", "bushes"]:
		var spots: Array[Transform3D] = village._scatter(layout[plants], layout["fields"])
		var well_placed := spots.size() > int(layout[plants]["count"]) / 2
		for spot in spots:
			var at := spot.origin
			well_placed = well_placed and terrain.river_clearance(at.x, at.z) > 0.0 and absf(at.y - terrain.height_at(at.x, at.z)) < 0.01
			for building: Dictionary in layout["buildings"]:
				well_placed = well_placed and Vector2(at.x, at.z).distance_to(Vector2(building["x"], building["z"])) > 5.0
		_check(well_placed, "%s grow on the ground, clear of the river and buildings" % plants)
	_check(village.get_node("LeafTrees").get_child_count() > 1 and village.get_node("Bushes").get_child_count() > 1, "leaf trees and bushes are planted in chunks")

	_test_grass(terrain, village.get_node("Grass"), layout)

	var low := INF
	var high := -INF
	for i in 64:
		var at := Vector2.from_angle(TAU * i / 64.0) * 160.0
		low = minf(low, terrain.height_at(at.x, at.y))
		high = maxf(high, terrain.height_at(at.x, at.y))
	_check(high - low > 10.0, "the valley floor is hilly (%.1f m between low and high)" % (high - low))

	var bridge: Node3D = village.get_node("Bridge")
	_check(terrain.river_clearance(bridge.position.x, bridge.position.z) < 0.0, "a bridge stands where the road meets the river")
	var saved_position := player.position
	var pivot: Node3D = player.get_node("CameraPivot")
	pivot.rotation = Vector3.ZERO
	# The bridge on the road, then wading through the water beside the village.
	for x: float in [0.0, -32.0]:
		var south := 18.0
		player.position = Vector3(x, terrain.height_at(x, south) + 0.5, south)
		await _physics_frames(10)
		Input.action_press("move_forward")
		await _physics_frames(420)
		Input.action_release("move_forward")
		var crossed := player.position.z < south - 15.0 and terrain.river_clearance(player.position.x, player.position.z) > 0.0
		_check(crossed, "the player crosses the river at x=%.0f" % x)
	player.position = saved_position
	await _physics_frames(10)


## Compares the collision with the triangles on screen, across the river and its banks.
func _test_river_collision(terrain: Terrain, player: Player) -> void:
	var samples := PackedVector2Array()
	for i in range(0, terrain.river.positions.size() - 1):
		var here := terrain.river.positions[i]
		if here.length() > 500.0:
			continue
		var side := (terrain.river.positions[i + 1] - here).normalized().orthogonal()
		var reach := terrain.river.half_widths[i] + 9.0
		for step in int(reach * 2.0 / 0.9):
			samples.append(here + side * (step * 0.9 - reach))
	var ground := _visible_triangles(terrain, samples)
	var space := terrain.get_world_3d().direct_space_state
	var worst := 0.0
	var compared := 0
	for at in samples:
		var height := _visible_height(ground, at)
		if is_nan(height):
			continue
		var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, height + 20.0, at.y), Vector3(at.x, height - 20.0, at.y))
		var hit := space.intersect_ray(query)
		# Bridges and whatever else stands on the ground isn't part of this.
		if hit.is_empty() or hit["collider"] != terrain:
			continue
		compared += 1
		worst = maxf(worst, absf(hit["position"].y - height))
	_check(compared > samples.size() * 0.9, "the river's banks are compared with their collision (%d of %d)" % [compared, samples.size()])
	_check(worst < 0.01, "collision matches the visible ground along the river (%.3f m off)" % worst)

	# The capsule rests a little above a slope, by up to 0.09 m on the steepest banks.
	var saved_position := player.position
	var pivot: Node3D = player.get_node("CameraPivot")
	pivot.rotation = Vector3.ZERO
	var south := 18.0
	player.position = Vector3(-32.0, terrain.height_at(-32.0, south) + 0.5, south)
	await _physics_frames(10)
	var path := PackedVector2Array()
	var feet := PackedFloat32Array()
	Input.action_press("move_forward")
	for i in 420:
		await physics_frame
		if player.is_on_floor():
			path.append(Vector2(player.position.x, player.position.z))
			feet.append(player.position.y)
	Input.action_release("move_forward")
	var on_path := _visible_triangles(terrain, path)
	var highest := -INF
	var lowest := INF
	for i in path.size():
		var gap := feet[i] - _visible_height(on_path, path[i])
		if not is_nan(gap):
			highest = maxf(highest, gap)
			lowest = minf(lowest, gap)
	_check(player.position.z < south - 15.0, "the player wades across the fine collision")
	_check(highest < 0.15 and lowest > -0.02, "the player's feet stay on the visible ground (%.3f to %.3f m)" % [lowest, highest])
	player.position = saved_position
	await _physics_frames(10)


## The drawn triangles around these points, by 4 m cell. Reads only the chunks they fall in.
func _visible_triangles(terrain: Terrain, points: PackedVector2Array) -> Dictionary:
	var cells := {}
	for child in terrain.get_children():
		if not child is MeshInstance3D or child.name == "Water":
			continue
		var box: AABB = child.mesh.get_aabb()
		var used := false
		for point in points:
			if point.x >= box.position.x and point.x <= box.end.x and point.y >= box.position.z and point.y <= box.end.z:
				used = true
				break
		if not used:
			continue
		var arrays: Array = child.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, indices.size(), 3):
			var a := vertices[indices[t]]
			var b := vertices[indices[t + 1]]
			var c := vertices[indices[t + 2]]
			var key := _ground_cell((a.x + b.x + c.x) / 3.0, (a.z + b.z + c.z) / 3.0)
			if not cells.has(key):
				cells[key] = PackedVector3Array()
			cells[key].append_array(PackedVector3Array([a, b, c]))
	return cells


func _ground_cell(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / Terrain.STEP), floori(z / Terrain.STEP))


func _visible_height(cells: Dictionary, at: Vector2) -> float:
	var triangles: PackedVector3Array = cells.get(_ground_cell(at.x, at.y), PackedVector3Array())
	for t in range(0, triangles.size(), 3):
		var a := triangles[t]
		var b := triangles[t + 1]
		var c := triangles[t + 2]
		var area := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		var u := ((b.z - c.z) * (at.x - c.x) + (c.x - b.x) * (at.y - c.z)) / area
		var v := ((c.z - a.z) * (at.x - c.x) + (a.x - c.x) * (at.y - c.z)) / area
		if u >= -0.0001 and v >= -0.0001 and u + v <= 1.0001:
			return u * a.y + v * b.y + (1.0 - u - v) * c.y
	return NAN


## Where fine cells meet coarser ones, the ground follows its true height and bends little more than
## the true ground does, and the collision there still matches what is drawn.
func _test_terrain_seams(terrain: Terrain) -> void:
	var count := int(Terrain.SIZE / Terrain.STEP) + 1
	var row := count - 1
	var cells: PackedByteArray = terrain._fine_cells(count)
	var edge_points := PackedVector2Array()
	var crossings := PackedVector2Array()
	var inside_seam_cells := PackedVector2Array()
	for j in range(1, row - 1):
		for i in range(1, row - 1):
			var here := cells[j * row + i]
			var corner := Vector2(i * Terrain.STEP - Terrain.SIZE / 2.0, j * Terrain.STEP - Terrain.SIZE / 2.0)
			if corner.length() > 500.0:
				continue
			if here == Terrain.SEAM_CELL:
				for offset: Vector2 in [Vector2(0.6, 1.3), Vector2(2.1, 2.7), Vector2(3.4, 0.9)]:
					inside_seam_cells.append(corner + offset)
			for side: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var there := cells[(j + side.y) * row + i + side.x]
				if (here == Terrain.FINE_CELL) == (there == Terrain.FINE_CELL):
					continue
				var across := Vector2(side)
				var start := corner + across * Terrain.STEP
				for step in range(1, 8):
					edge_points.append(start + across.orthogonal().abs() * step * 0.5)
					crossings.append(across)
	var probes := PackedVector2Array()
	for k in edge_points.size():
		probes.append(edge_points[k] - crossings[k] * 0.5)
		probes.append(edge_points[k] + crossings[k] * 0.5)
	probes.append_array(inside_seam_cells)
	var ground := _seam_triangles(terrain, probes)
	var worst_error := 0.0
	var worst_bend := 0.0
	var true_normal := func(at: Vector2) -> Vector3:
		var h := 0.05
		return Vector3(terrain.height_at(at.x - h, at.y) - terrain.height_at(at.x + h, at.y), 2.0 * h, terrain.height_at(at.x, at.y - h) - terrain.height_at(at.x, at.y + h)).normalized()
	for k in edge_points.size():
		var at := edge_points[k]
		worst_error = maxf(worst_error, absf(_visible_height(ground, at) - terrain.height_at(at.x, at.y)))
		var before := _visible_normal(ground, at - crossings[k] * 0.5)
		var after := _visible_normal(ground, at + crossings[k] * 0.5)
		var true_bend: float = true_normal.call(at - crossings[k] * 0.5).angle_to(true_normal.call(at + crossings[k] * 0.5))
		worst_bend = maxf(worst_bend, rad_to_deg(before.angle_to(after) - true_bend))
	_check(edge_points.size() > 1000 and worst_error < 0.15, "fine terrain meets coarser terrain at the true height (%d points, %.3f m off)" % [edge_points.size(), worst_error])
	# Main bent up to 25 degrees more than the true ground at these seams, and coarse cells up to 108.
	_check(worst_bend < 18.0, "fine terrain bends little more than the true ground where it meets coarser terrain (%.1f degrees)" % worst_bend)
	var space := terrain.get_world_3d().direct_space_state
	var worst_collision := 0.0
	for at in inside_seam_cells:
		var height := _visible_height(ground, at)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, height + 20.0, at.y), Vector3(at.x, height - 20.0, at.y)))
		if not hit.is_empty() and hit["collider"] == terrain:
			worst_collision = maxf(worst_collision, absf(hit["position"].y - height))
	_check(inside_seam_cells.size() > 300 and worst_collision < 0.01, "collision matches the visible ground beside the fine terrain (%.3f m off)" % worst_collision)


## Like _visible_triangles, for many points: reads each chunk the points fall in.
func _seam_triangles(terrain: Terrain, points: PackedVector2Array) -> Dictionary:
	var chunk_size := Terrain.CHUNK_CELLS * Terrain.STEP
	var chunks := {}
	for point in points:
		chunks[Vector2i(floori((point.x + Terrain.SIZE / 2.0) / chunk_size), floori((point.y + Terrain.SIZE / 2.0) / chunk_size))] = true
	var cells := {}
	for child in terrain.get_children():
		if not child is MeshInstance3D or child.name == "Water":
			continue
		var middle: Vector3 = child.mesh.get_aabb().get_center()
		if not chunks.has(Vector2i(floori((middle.x + Terrain.SIZE / 2.0) / chunk_size), floori((middle.z + Terrain.SIZE / 2.0) / chunk_size))):
			continue
		var arrays: Array = child.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, indices.size(), 3):
			var a := vertices[indices[t]]
			var b := vertices[indices[t + 1]]
			var c := vertices[indices[t + 2]]
			var key := _ground_cell((a.x + b.x + c.x) / 3.0, (a.z + b.z + c.z) / 3.0)
			if not cells.has(key):
				cells[key] = PackedVector3Array()
			cells[key].append_array(PackedVector3Array([a, b, c]))
	return cells


func _visible_normal(cells: Dictionary, at: Vector2) -> Vector3:
	var triangles: PackedVector3Array = cells.get(_ground_cell(at.x, at.y), PackedVector3Array())
	for t in range(0, triangles.size(), 3):
		var a := triangles[t]
		var b := triangles[t + 1]
		var c := triangles[t + 2]
		var area := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		var u := ((b.z - c.z) * (at.x - c.x) + (c.x - b.x) * (at.y - c.z)) / area
		var v := ((c.z - a.z) * (at.x - c.x) + (a.x - c.x) * (at.y - c.z)) / area
		if u >= -0.0001 and v >= -0.0001 and u + v <= 1.0001:
			var normal := (b - a).cross(c - a).normalized()
			return -normal if normal.y < 0.0 else normal
	return Vector3.UP


func _test_grass(terrain: Terrain, grass: GrassField, layout: Dictionary) -> void:
	var species_seen: Dictionary = {}
	var cells_with_grass := 0
	var well_placed := true
	# Lines of cells from the village out to the mountains.
	var cells: Array[Vector2i] = []
	for i in 12:
		cells.append(Vector2i(i, i / 2))
		cells.append(Vector2i(-i, i))
		cells.append(Vector2i(i, -i))
	for cell in cells:
		var spots: Array = grass.grow_cell(cell)
		var count := 0
		for species in spots.size():
			count += spots[species].size()
			if not spots[species].is_empty():
				species_seen[species] = true
			for spot: Transform3D in spots[species]:
				var at := spot.origin
				well_placed = well_placed and terrain.river_clearance(at.x, at.z) > 0.0 and absf(at.y - terrain.height_at(at.x, at.z)) < 0.01
		if count > 0:
			cells_with_grass += 1
	_check(well_placed, "grass grows on the ground, clear of the river")
	_check(cells_with_grass > cells.size() / 2, "grass grows well beyond the village (%d of %d cells)" % [cells_with_grass, cells.size()])
	_check(species_seen.size() == layout["grass"]["species"].size(), "every grass species grows somewhere (%d)" % species_seen.size())
	_check(grass.grow_cell(Vector2i(3, 2)) == grass.grow_cell(Vector2i(3, 2)), "a cell always grows the same grass")
	var highest := -INF
	for x in range(-16, 16):
		for spots: Array in grass.grow_cell(Vector2i(x, 15)):
			for spot: Transform3D in spots:
				highest = maxf(highest, spot.origin.y)
	_check(highest < float(layout["grass"]["max_height"]), "grass stops below the high mountains")


func _test_building_site(terrain: Terrain, site: Dictionary) -> void:
	var center := Vector2(site["x"], site["z"])
	var top_low := INF
	var top_high := -INF
	var steepest := 0.0
	for i in 16:
		for radius: float in [site["radius"] / 2.0, site["radius"]]:
			var at := center + Vector2.from_angle(TAU * i / 16.0) * radius
			top_low = minf(top_low, terrain.height_at(at.x, at.y))
			top_high = maxf(top_high, terrain.height_at(at.x, at.y))
		for radius in range(int(site["radius"]), int(site["radius"] + site["blend"])):
			var at := center + Vector2.from_angle(TAU * i / 16.0) * radius
			steepest = maxf(steepest, _slope_degrees(terrain, at.x, at.y))
	_check(top_high - top_low < 0.5, "%s has a flat top" % site["id"])
	_check(terrain.height_at(center.x, center.y) > terrain.height_at(0.0, -28.0) + 5.0, "%s rises above the village" % site["id"])
	_check(center.length() - site["radius"] - site["blend"] < Terrain.VILLAGE_RADIUS, "%s's foot reaches the village" % site["id"])
	_check(steepest < 42.0, "%s can be climbed (steepest %.1f degrees)" % [site["id"], steepest])


func _slope_degrees(terrain: Terrain, x: float, z: float) -> float:
	var across := terrain.height_at(x + 1.0, z) - terrain.height_at(x - 1.0, z)
	var along := terrain.height_at(x, z + 1.0) - terrain.height_at(x, z - 1.0)
	return rad_to_deg(atan(Vector2(across, along).length() / 2.0))


func _test_hud(scene: Node, player: Player) -> void:
	var compass: Compass = scene.get_node("UI/Compass")
	var overlay: PerformanceOverlay = scene.get_node("UI/PerformanceOverlay")
	var pivot: Node3D = player.get_node("CameraPivot")
	pivot.rotation = Vector3.ZERO
	_check(is_equal_approx(player.heading_degrees(), 0.0), "facing -Z is north")
	pivot.rotation.y = -PI / 2.0
	_check(is_equal_approx(player.heading_degrees(), 90.0), "facing +X is east")
	compass.heading = 90.0
	_check(is_equal_approx(compass.offset_of(90.0), 0.0), "the faced direction is in the middle of the compass")
	_check(compass.offset_of(0.0) == -1.0 and compass.offset_of(180.0) == 1.0, "north is to the left when facing east")
	compass.heading = 350.0
	_check(is_equal_approx(compass.offset_of(10.0), 20.0 / Compass.VISIBLE_DEGREES), "the compass wraps around north")
	_check(is_equal_approx(Compass.bearing_between(Vector2.ZERO, Vector2(10.0, 0.0)), 90.0), "a place to the east has a bearing of 90 degrees")
	var quests := QuestLog.new()
	var carried := Inventory.new()
	quests.start("first_nails")
	var markers := quests.objective_markers(carried)
	var village: Village = scene.get_node("Village")
	_check(markers.size() == 1 and village.marker_position(markers[0]) == Vector2(40.0, -175.0), "the compass points to the ore for the nails")
	carried.add("iron_ingot")
	var anvil: Node3D = village.get_node("anvil")
	_check(village.marker_position(quests.objective_markers(carried)[0]) == Vector2(anvil.position.x, anvil.position.z), "the compass points to the anvil once there is iron")
	var all_quests: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(QuestLog.DATA_PATH))
	var unknown := PackedStringArray()
	for quest: Dictionary in all_quests.values():
		for objective: Dictionary in quest["objectives"]:
			for marker: Variant in [objective.get("marker"), objective.get("marker_when_carrying", {}).get("marker")]:
				if marker is String and village.get_node_or_null(marker) == null:
					unknown.append(marker)
	_check(unknown.is_empty(), "every quest marker names a real place %s" % ", ".join(unknown))
	compass.heading = 0.0
	compass.objective_bearings = PackedFloat32Array([90.0])
	compass.queue_redraw()
	pivot.rotation = Vector3.ZERO

	# Below the base width of 1152 the interface shrinks, so the top row never overlaps.
	_check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "the interface scales with the window")
	var health_bar: Control = scene.get_node("UI/HealthBar")
	var middle := 1152.0 / 2.0
	_check(health_bar.offset_right < middle + compass.offset_left, "the compass clears the health bar at the base width")
	_check(middle + compass.offset_right < 1152.0 + overlay.offset_left, "the compass clears the performance overlay at the base width")

	await _test_item_models(scene)
	await _test_interface_fit(scene)
	await _test_controls_hint(scene)
	await _test_ground_dryness()

	overlay.refresh()
	_check(overlay.visible and overlay.text.contains("FPS"), "the performance overlay shows measurements")
	TranslationServer.set_locale("de")
	_check(tr("UI_COMPASS_E") == "O", "east is translated on the compass")
	TranslationServer.set_locale("en")


func _test_character_models(player: Player) -> void:
	_check(player.get_node("Body") is CharacterModel, "the player uses a rigged model")
	_check(root.get_tree().get_first_node_in_group(Enemy.GROUP)._body is CharacterModel, "goblins use a rigged model")


func _test_generated_props() -> void:
	var files := DirAccess.get_files_at("res://assets/props")
	var count := 0
	for file in files:
		if not file.ends_with(".glb"):
			continue
		count += 1
		var scene: PackedScene = load("res://assets/props/" + file)
		var prop := scene.instantiate()
		var meshes := prop.find_children("*", "MeshInstance3D", true, false)
		_check(meshes.size() == 1, file + " has one mesh")
		var size: Vector3 = meshes[0].get_aabb().size
		_check(size.length() > 0.2 and maxf(size.x, maxf(size.y, size.z)) < 2.6, file + " has a believable size")
		_check(meshes[0].mesh.get_surface_count() == 1 and (meshes[0].mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture != null, file + " is textured")
		prop.free()
	_check(count == 40, "all generated props are present")
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/village_layout.json"))
	_check((layout["props"] as Array).size() == 39, "39 generated props are placed, and the anvil is a station")


func _test_feature_flags() -> void:
	_check(FeatureFlags.enabled("torch_recipe"), "an aggregate of enabled flags is on")
	_check(not FeatureFlags.enabled("torch_burns_out"), "an aggregate with a disabled flag is off")

	_write_flags(TEST_FLAGS_A, { "flags": { "torch_burn_time_enabled": true, "test_not": { "not": "torches" }, "test_nested": { "any": [false, { "all": ["torches", "test_not"] }, "torch_recipe"] }, "test_loop": { "all": ["test_loop"] } }, "values": { "torch_burn_seconds": 5 } })
	_write_flags(TEST_FLAGS_B, { "flags": { "torch_burn_time_enabled": false }, "values": { "torch_burn_seconds": 9 } })
	FeatureFlags.load_layers([TEST_FLAGS_A])
	_check(FeatureFlags.enabled("torch_burns_out"), "a mod's flag changes an aggregate")
	_check(not FeatureFlags.enabled("test_not") and FeatureFlags.enabled("test_nested"), "aggregates can be negated and nested")
	_check(FeatureFlags.value("torch_burn_seconds") == 5, "a mod overrides a value")
	FeatureFlags.load_layers([TEST_FLAGS_A, TEST_FLAGS_B])
	_check(not FeatureFlags.enabled("torch_burns_out") and FeatureFlags.value("torch_burn_seconds") == 9, "the last mod in the load order wins")
	FeatureFlags.load_layers([TEST_FLAGS_B, TEST_FLAGS_A])
	_check(FeatureFlags.enabled("torch_burns_out") and FeatureFlags.value("torch_burn_seconds") == 5, "swapping the load order swaps the winner")
	_check(not FeatureFlags.enabled("test_loop"), "a flag that depends on itself counts as off")
	_check(not FeatureFlags.enabled("test_missing"), "an unknown flag counts as off")

	_write_flags(TEST_FLAGS_A, { "flags": { "torch_crafting_enabled": false } })
	FeatureFlags.load_layers([TEST_FLAGS_A])
	_check(CraftingData.find_recipe("furnace", { "wood": 1, "coal": 1 }).is_empty(), "a disabled flag removes a recipe")
	FeatureFlags.load_layers()
	_check(not CraftingData.find_recipe("furnace", { "wood": 1, "coal": 1 }).is_empty(), "the torch recipe is on by default")


func _test_torch(player: Player) -> void:
	_check(player.inventory.count("torch") == 1, "a new game starts with a torch")
	player.give_starting_items()
	_check(player.inventory.count("torch") == 1, "the starting torch is only given once")

	player.toggle_torch()
	_check(player.torch_lit, "the torch lights")
	await _physics_frames(30)
	_check(player.torch_lit and player.inventory.count("torch") == 1, "by default a torch burns forever")

	_write_flags(TEST_FLAGS_A, { "flags": { "torch_burn_time_enabled": true }, "values": { "torch_burn_seconds": 0.1 } })
	FeatureFlags.load_layers([TEST_FLAGS_A])
	await _physics_frames(30)
	_check(not player.torch_lit and player.inventory.count("torch") == 0, "with a burn time, a torch burns out and is used up")
	player.toggle_torch()
	_check(not player.torch_lit, "no torch means no light")
	FeatureFlags.load_layers()
	player.inventory.add("torch")
	DirAccess.remove_absolute(TEST_FLAGS_A)
	DirAccess.remove_absolute(TEST_FLAGS_B)


func _write_flags(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _test_crafting(scene: Node, player: Player) -> void:
	var ui: CraftingUI = scene.get_node("CraftingUI")
	var village: Village = scene.get_node("Village")

	var furnace: CraftingStation = village.get_node("furnace")
	var pivot: Node3D = player.get_node("CameraPivot")
	pivot.rotation = Vector3.ZERO
	player.position = furnace.position + Vector3(0.0, 0.5, 2.5)
	await _physics_frames(10)
	_check(player.interact_target == furnace, "player can target a station")

	var ore_node: ResourceNode = null
	for child in village.get_children():
		if child is ResourceNode and child.item_id == "iron_ore":
			ore_node = child
			break
	for i in ore_node.uses:
		ore_node.interact(player)
	_check(player.inventory.count("iron_ore") == ore_node.uses, "gathering adds items")
	_check(not ore_node.is_available(), "gathering spots run out")
	player.inventory.add("coal", 2)
	player.inventory.add("wood", 1)

	player.interact()
	_check(ui.is_open(), "furnace opens the crafting screen")
	ui.add_material("wood")
	ui.craft()
	_check(player.inventory.count("wood") == 1, "a failed experiment costs nothing")
	ui.clear_selection()
	ui.add_material("iron_ore")
	ui.add_material("iron_ore")
	ui.add_material("coal")
	ui.craft()
	_check(player.inventory.count("iron_ingot") == 1, "smelting makes an ingot")
	var torches := player.inventory.count("torch")
	player.inventory.add("wood", 1)
	ui.add_material("wood")
	ui.add_material("coal")
	ui.craft()
	_check(player.inventory.count("torch") == torches + 1, "wood and coal make a torch")
	_check(player.known_recipes.has("make_torch"), "the torch recipe is discovered")
	_check(player.known_recipes.has("smelt_iron"), "smelting is discovered")
	ui.close()
	_check(not ui.is_open(), "crafting screen closes")

	ui.open_station("anvil", "Anvil", player)
	ui.add_material("iron_ingot")
	ui.add_material("wood")
	ui.craft()
	_check(ui.is_forging(), "forging starts the minigame")
	while ui.is_forging():
		ui._game.marker = ui._game.target
		ui.strike()
	var made := player.inventory.entries().filter(func(entry): return entry["id"] == "iron_dagger")
	_check(made.size() == 1 and made[0]["quality"] == "masterwork", "perfect forging gives masterwork")
	ui.close()

	player.inventory.add("iron_ingot", 2)
	player.inventory.add("wood", 1)
	var ingots := player.inventory.count("iron_ingot")
	var wood := player.inventory.count("wood")
	ui.open_station("anvil", "Anvil", player)
	ui.add_material("iron_ingot")
	ui.add_material("iron_ingot")
	ui.add_material("wood")
	ui.craft()
	ui.abandon_forging()
	_check(not ui.is_forging() and ui.is_open(), "forging can be abandoned")
	_check(player.inventory.count("iron_ingot") == ingots - 1 and player.inventory.count("wood") == wood - 1, "abandoning saves half the materials")
	ui.close()

	var clumsy := HammerGame.new(2, 1.0)
	clumsy.marker = clamp(clumsy.target + 0.5, 0.0, 1.0) if clumsy.target < 0.5 else clumsy.target - 0.5
	clumsy.strike()
	_check(CraftingData.quality_for_score(clumsy.score()) == "crude", "bad forging gives crude quality")
	_check(CraftingData.find_recipe("anvil", {"coal": 1}).is_empty(), "unknown combinations match nothing")
	_check(CraftingData.item_name("iron_sword") != "ITEM_IRON_SWORD", "item names are translated")


func _test_story(scene: Node, player: Player) -> void:
	var ui: DialogueUI = scene.get_node("DialogueUI")
	var village: Village = scene.get_node("Village")
	var quests := player.quests

	_check(quests.current_objective("arrival") == "see_grandmother", "the first quest starts on its own")
	_check(quests.tracker_lines(player.inventory).size() == 1, "the tracker shows the active quest")

	var hedda: Npc = village.get_node("hedda")
	var hedda_model: Node3D = hedda.find_child("Model", true, false)
	var hedda_player: AnimationPlayer = hedda_model.get_node("Animations")
	_check(hedda_player.is_playing() and hedda_player.current_animation == "Idle", "a villager with a model plays its idle animation")
	_check(hedda_model.find_child("GeneralSkeleton", true, false) != null, "the model's skeleton is set up for shared animations")
	for villager: String in ["bertram", "mira", "greta", "brandt"]:
		_check(village.get_node(villager).find_child("Model", true, false) != null, "%s has a model" % villager)
	var pivot: Node3D = player.get_node("CameraPivot")
	pivot.rotation = Vector3.ZERO
	player.position = hedda.position + Vector3(0.0, 0.5, 2.0)
	await _physics_frames(10)
	_check(player.interact_target == hedda, "player can target a villager")
	var was_first_person := player.first_person
	player.first_person = false
	player._apply_camera_mode()
	player.interact()
	await _physics_frames(2)
	_check(ui.is_open() and player.is_busy(), "talking opens the dialogue screen")
	var toward_player := (player.global_position - hedda.global_position).normalized()
	_check((-hedda.global_basis.z).dot(toward_player) > 0.9, "a villager turns to face the player when talked to")
	_check(_framing_test(player, hedda), "the villager and the camera face each other, with the player aside")
	player.first_person = was_first_person
	player._apply_camera_mode()
	ui.choose(1)
	ui.choose(0)
	_check(quests.current_objective("arrival") == "see_smith", "grandmother sends the player to the smith")
	ui.choose(0)
	_check(not ui.is_open() and not player.is_busy(), "the conversation ends")

	_talk(ui, "bertram", player, [0, 0, 0])
	_check(quests.is_done("arrival") and quests.current_objective("first_nails") == "make_nails", "the smith gives the nails quest")

	player.inventory.remove("iron_nails", player.inventory.count("iron_nails"))
	_talk(ui, "bertram", player, [0])
	_check(quests.current_objective("first_nails") == "make_nails", "the smith waits for the nails")

	player.inventory.add("iron_nails", 4, "fine")
	var ingots := player.inventory.count("iron_ingot")
	_check(quests.tracker_lines(player.inventory)[0].contains("(4/4)"), "the tracker counts the nails")
	_talk(ui, "bertram", player, [0])
	_check(player.inventory.count("iron_nails") == 0, "the smith takes the nails")
	_check(player.inventory.count("iron_ingot") == ingots + 2, "the smith pays the player")
	_check(quests.current_objective("first_nails") == "tell_mayor", "the smith sends the player to the mayor")

	_talk(ui, "brandt", player, [1, 0])
	_check(quests.current_objective("first_nails") == "repair_roof", "the mayor leads to the roof repair")
	var site: RepairSite = null
	for child in village.get_children():
		if child is RepairSite:
			site = child
	var inn := village.get_node("inn")
	var repaired_roof: Node3D = inn.get_node("RepairedRoof")
	var damaged_roof: Node3D = inn.get_node("DamagedRoof")
	_check(damaged_roof.visible and not repaired_roof.visible, "the inn starts with a damaged roof")
	_check(site.is_available(), "the repair is available during its objective")
	site.interact(player)
	_check(quests.is_done("first_nails"), "repairing the roof completes the quest")
	_check(repaired_roof.visible and not damaged_roof.visible, "the repair shows on the inn")
	_check(not site.is_available(), "the repair can't be repeated")
	_check(DialogueRunner.new("greta", player).text_key() == "DLG_GRETA_GRATEFUL", "the innkeeper thanks the player")
	_check(quests.flags.has("mayor_annoyed"), "the player's choice is remembered")
	var cold := DialogueRunner.new("brandt", player)
	_check(cold.text_key() == "DLG_BRANDT_COLD", "the mayor reacts to the choice")
	_check(DialogueRunner.new("hedda", player).text_key() == "DLG_HEDDA_PROUD", "grandmother reacts to the finished quest")


func _test_combat(scene: Node, player: Player) -> void:
	var fresh := Inventory.new()
	_check(fresh.best_weapon_damage() == 0.0, "no weapon means no weapon damage")
	fresh.add("iron_sword", 1, "crude")
	fresh.add("iron_dagger", 1, "masterwork")
	_check(fresh.best_weapon_damage() == 16.0, "the strongest weapon and quality are used")
	fresh.add("wood", 4)
	fresh.lose_materials(0.25)
	_check(fresh.count("wood") == 3 and fresh.count("iron_sword") == 1, "only materials are lost")

	var enemy: Enemy = null
	for node in root.get_tree().get_nodes_in_group(Enemy.GROUP):
		enemy = node
		break
	_check(enemy != null and enemy.state == Enemy.State.IDLE, "goblins wait at their camp")

	var pivot: Node3D = player.get_node("CameraPivot")
	pivot.rotation = Vector3.ZERO
	player.health.restore()
	player.position = enemy.position + Vector3(0.0, 0.3, 1.5)
	await _physics_frames(5)
	_check(enemy.state != Enemy.State.IDLE, "goblins notice a nearby player")

	# Hold block through the goblin's attack.
	Input.action_press("block")
	await _physics_frames(90)
	Input.action_release("block")
	_check(player.health.current == 100.0 - 12.0 * 0.2, "blocking reduces a goblin's hit")

	player.health.restore()
	player.dodge()
	player.take_hit(50.0, enemy.global_position)
	_check(player.is_dodging() and player.health.current == 100.0, "dodging avoids damage")
	await _physics_frames(60)

	player.health.restore()
	player.position = enemy.position + Vector3(0.0, 0.3, 1.5)
	pivot.rotation = Vector3.ZERO
	var before := enemy.health.current
	player.attack()
	await _physics_frames(20)
	_check(enemy.health.current < before, "an attack hurts the goblin")
	enemy.state = Enemy.State.RECOVER
	enemy._timer = 1.0
	var hit_from := enemy.global_position
	enemy.take_hit(0.0, hit_from + Vector3(0.0, 0.0, 1.0))
	_check(enemy._sparks.emitting, "a hit throws sparks")
	await _physics_frames(10)
	_check(enemy.global_position.z < hit_from.z - 0.1, "a hit pushes the goblin away")
	while enemy.state != Enemy.State.DEAD:
		enemy.take_hit(1000.0)
	await _physics_frames(2)
	_check(not enemy.visible, "a defeated goblin disappears")
	var scrap_before := player.inventory.count("iron_scrap")
	var always_drop: Dictionary = enemy._stats["drops"][0].duplicate()
	var real_drops: Array = enemy._stats["drops"]
	always_drop["chance"] = 1.0
	enemy._stats["drops"] = [always_drop]
	enemy._give_drops()
	enemy._stats["drops"] = real_drops
	_check(player.inventory.count("iron_scrap") > scrap_before, "defeated enemies drop materials")
	_check(not CraftingData.find_recipe("furnace", {"iron_scrap": 3, "coal": 1}).is_empty(), "dropped scrap can be smelted")

	player.inventory.add("coal", 4)
	var coal := player.inventory.count("coal")
	player.take_hit(1000.0, player.global_position)
	await _physics_frames(2)
	_check(player.health.current == 100.0, "death restores health")
	_check(scene._fade_overlay.modulate.a > 0.9, "death fades from black")
	_check(scene._hurt_overlay.modulate.a > 0.5, "being hit flashes the screen")
	_check(player.global_position.distance_to(Vector3(-12.0, player.global_position.y, 30.0)) < 2.0, "death returns the player to the village")
	_check(player.inventory.count("coal") < coal, "death costs some materials")
	_check(enemy.visible and enemy.state != Enemy.State.DEAD, "enemies return after the player dies")

	player.health.restore()
	player.position = enemy.position + Vector3(0.0, 0.3, 4.0)
	await _physics_frames(5)
	var chasing := enemy.state
	var screen: CraftingUI = scene.get_node("CraftingUI")
	screen.open_inventory(player)
	_check(root.get_tree().paused, "menus pause the world")
	await _physics_frames(30)
	_check(chasing != Enemy.State.IDLE and enemy.state == chasing, "enemies don't lose the player during a menu")
	screen.close()
	_check(not root.get_tree().paused, "closing a menu resumes the world")
	enemy.revive()

	var home := enemy._home
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(10.0, 6.0, 1.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	root.add_child(wall)
	wall.global_position = enemy.global_position + Vector3(0.0, 2.0, 4.0)
	player.health.restore()
	player.position = enemy.position + Vector3(0.0, 0.5, 8.0)
	for i in 480:
		await physics_frame
		player.health.restore()
		if enemy.state == Enemy.State.WINDUP:
			break
	_check(enemy.state == Enemy.State.WINDUP, "enemies find their way around a wall")
	wall.queue_free()
	var inn: Node3D = scene.get_node("Village/inn")
	enemy.revive()
	enemy._home = inn.position + Vector3(-9.0, 0.5, 0.0)
	enemy.position = enemy._home
	player.position = inn.position + Vector3(9.0, 0.5, 0.0)
	enemy.state = Enemy.State.CHASE
	for i in 900:
		await physics_frame
		player.health.restore()
		if enemy.state == Enemy.State.WINDUP:
			break
	_check(enemy.state == Enemy.State.WINDUP, "enemies find their way around a building")
	enemy._home = home
	enemy.revive()
	await _physics_frames(1)


func _test_enemy_navigation(scene: Node, player: Player) -> void:
	var enemy: Enemy = root.get_tree().get_first_node_in_group(Enemy.GROUP)
	var home := enemy._home
	var site := Vector3(home.x + 12.0, home.y, home.z + 12.0)
	# The other goblins would chase the player too, and block the gaps while they attack.
	var others: Array[Enemy] = []
	for other: Enemy in root.get_tree().get_nodes_in_group(Enemy.GROUP):
		if other != enemy:
			others.append(other)
			other.process_mode = Node.PROCESS_MODE_DISABLED
			other.position.y -= 100.0

	# A prop just off a wall, leaving a notch.
	var obstacles := Node3D.new()
	root.add_child(obstacles)
	_add_test_box(obstacles, site, Vector3(14.0, 6.0, 1.0))
	_add_test_box(obstacles, site + Vector3(-1.0, 0.0, -1.45), Vector3(1.2, 6.0, 1.0))
	await _physics_frames(2)
	_check(await _enemy_reaches(enemy, site + Vector3(0.0, 0.5, -5.0), site + Vector3(0.0, 0.5, 5.0), player, 900), "enemies get out of a notch a prop leaves against a wall")
	obstacles.free()

	# A dense stand of trunks, with gaps a little wider than a body and a grid cell together.
	obstacles = Node3D.new()
	root.add_child(obstacles)
	for x in range(-6, 7):
		for z in range(-6, 7):
			_add_test_box(obstacles, site + Vector3(x * 1.6, 0.0, z * 1.6), Vector3(0.4, 6.0, 0.4))
	await _physics_frames(2)
	_check(await _enemy_reaches(enemy, site + Vector3(-1.0, 0.5, -12.0), site + Vector3(1.0, 0.5, 12.0), player, 1200), "enemies find their way through dense trees")
	obstacles.free()

	# With no way in, the enemy gets as near as it can.
	obstacles = Node3D.new()
	root.add_child(obstacles)
	var ring := [[Vector3(0.0, 0.0, 4.0), Vector3(9.0, 6.0, 1.0)], [Vector3(0.0, 0.0, -4.0), Vector3(9.0, 6.0, 1.0)], [Vector3(4.0, 0.0, 0.0), Vector3(1.0, 6.0, 9.0)], [Vector3(-4.0, 0.0, 0.0), Vector3(1.0, 6.0, 9.0)]]
	for part: Array in ring:
		_add_test_box(obstacles, site + part[0], part[1])
	await _physics_frames(2)
	var reached := await _enemy_reaches(enemy, site + Vector3(0.0, 0.5, -9.0), site + Vector3(0.0, 0.5, 0.0), player, 300)
	_check(not reached and enemy.global_position.distance_to(site) < 8.0, "enemies wait as near as they can get to a player they can't reach")
	obstacles.free()

	enemy._home = home
	enemy.revive()
	for other in others:
		other.process_mode = Node.PROCESS_MODE_INHERIT
		other.revive()
	EnemyPath.forget_all()
	await _physics_frames(1)

	var door: Node = scene.get_node("Village/Props/door_3")
	_check(door.get_children().any(func(child: Node) -> bool: return child is CollisionShape3D), "the inn's door is solid")


## Uses the camp's goblins away from their camp: one chases, and another stands still in a gap.
func _test_enemy_crowds_and_bridges(scene: Node, player: Player) -> void:
	var enemies := root.get_tree().get_nodes_in_group(Enemy.GROUP)
	var enemy: Enemy = enemies[0]
	var blocker: Enemy = enemies[1]
	var home := enemy._home
	for other: Enemy in enemies:
		if other != enemy:
			other.process_mode = Node.PROCESS_MODE_DISABLED
			other.position.y -= 100.0

	var terrain: Terrain = scene.get_node("Terrain")
	var bridge: Node3D = scene.get_node("Village").get_children().filter(func(child: Node) -> bool: return child.name.begins_with("Bridge"))[0]
	var along := bridge.global_basis.z
	var side := bridge.global_basis.x
	var on_ground := func(along_bridge: float, beside: float) -> Vector3:
		var point: Vector3 = bridge.global_position + along * along_bridge + side * beside
		return Vector3(point.x, terrain.height_at(point.x, point.z) + 0.5, point.z)
	var hit := terrain.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(bridge.global_position + Vector3.UP * 3.0, bridge.global_position + Vector3.DOWN * 3.0))
	var deck: Vector3 = hit["position"] + Vector3.UP * 0.1
	var bank_a: Vector3 = on_ground.call(-11.0, 2.5)
	var bank_b: Vector3 = on_ground.call(11.0, 2.5)
	var beside_end: Vector3 = on_ground.call(11.0, 3.5)
	for trip: Array in [[bank_a, bank_b, "enemies plan a way over a bridge rather than through the river"], [deck, beside_end, "an enemy on a bridge plans its way along the deck"]]:
		EnemyPath.forget_all()
		enemy.revive()
		enemy.position = trip[0]
		await physics_frame
		var path := EnemyPath.new(enemy, enemy._stats["radius"])
		path.begin(trip[0], trip[1], float(enemy._stats["attack_range"]) * Enemy.ARRIVE_FRACTION)
		while not path.advance():
			await physics_frame
		var off_deck := 0
		for point in path.waypoints:
			var from_middle := Vector3(point.x, bridge.global_position.y, point.y) - bridge.global_position
			if terrain.river_clearance(point.x, point.y) < 0.0 and absf(from_middle.dot(side)) > 1.6:
				off_deck += 1
		_check(path.reached and off_deck == 0, "%s (%d points off the deck)" % [trip[2], off_deck])

	EnemyPath.forget_all()
	enemy.revive()
	enemy._home = bank_a
	enemy.position = bank_a
	enemy.state = Enemy.State.CHASE
	player.health.restore()
	player.position = bank_b
	var wading := 0
	for i in 900:
		await physics_frame
		player.position = bank_b
		player.health.restore()
		if terrain.wading_factor(enemy.global_position) < 1.0:
			wading += 1
		if enemy.state == Enemy.State.WINDUP:
			break
	_check(enemy.state == Enemy.State.WINDUP and wading == 0, "enemies cross the river by the bridge (%d frames wading)" % wading)

	# The blocker stands in a gap as if it were attacking. A disabled body would leave the physics world.
	var site := Vector3(home.x + 12.0, home.y, home.z + 12.0)
	blocker.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	var stand_in := func(at: Vector3) -> void:
		blocker.revive()
		blocker.position = at
		blocker.state = Enemy.State.WINDUP
		blocker._moving = false
	var walls := Node3D.new()
	root.add_child(walls)
	_add_test_box(walls, site + Vector3(-5.6, 0.0, 0.0), Vector3(10.0, 6.0, 0.4))
	_add_test_box(walls, site + Vector3(3.0, 0.0, 0.0), Vector3(4.8, 6.0, 0.4))
	_add_test_box(walls, site + Vector3(10.7, 0.0, 0.0), Vector3(7.2, 6.0, 0.4))
	stand_in.call(site + Vector3(0.0, 0.3, 0.0))
	await physics_frame
	_check(await _enemy_reaches(enemy, site + Vector3(0.0, 0.5, -6.0), site + Vector3(0.0, 0.5, 1.5), player, 900), "enemies take another gap when another enemy blocks the nearest one")
	walls.free()

	# The only way in is blocked, so the enemy waits behind without pushing, and goes on once it's free.
	walls = Node3D.new()
	root.add_child(walls)
	for part: Array in [[Vector3(0.0, 0.0, 4.0), Vector3(9.0, 6.0, 1.0)], [Vector3(4.0, 0.0, 0.0), Vector3(1.0, 6.0, 9.0)], [Vector3(-4.0, 0.0, 0.0), Vector3(1.0, 6.0, 9.0)], [Vector3(-2.65, 0.0, -4.0), Vector3(3.7, 6.0, 1.0)], [Vector3(2.65, 0.0, -4.0), Vector3(3.7, 6.0, 1.0)]]:
		_add_test_box(walls, site + part[0], part[1])
	var gap := site + Vector3(0.0, 0.0, -4.0)
	stand_in.call(gap + Vector3.UP * 0.3)
	await physics_frame
	var inside := site + Vector3(0.0, 0.5, -2.5)
	var reached := await _enemy_reaches(enemy, site + Vector3(0.0, 0.5, -10.0), inside, player, 300)
	var pushes := 0
	var moved := 0.0
	var last := enemy.global_position
	for i in 180:
		await physics_frame
		player.position = inside
		player.health.restore()
		for c in enemy.get_slide_collision_count():
			if enemy.get_slide_collision(c).get_collider() == blocker:
				pushes += 1
		moved += Vector2(enemy.global_position.x - last.x, enemy.global_position.z - last.z).length()
		last = enemy.global_position
	_check(not reached and pushes == 0 and moved < 0.1 and enemy.global_position.distance_to(gap) < 2.0, "enemies wait behind another enemy that blocks the only way (%d pushes, %.2f m moved)" % [pushes, moved])
	blocker.position.y -= 100.0
	reached = false
	for i in 300:
		await physics_frame
		player.position = inside
		player.health.restore()
		if enemy.state == Enemy.State.WINDUP:
			reached = true
			break
	_check(reached, "a waiting enemy goes on once the way is free")
	walls.free()

	blocker.disable_mode = CollisionObject3D.DISABLE_MODE_REMOVE
	enemy._home = home
	enemy.revive()
	for other: Enemy in enemies:
		other.process_mode = Node.PROCESS_MODE_INHERIT
		other.revive()
	EnemyPath.forget_all()
	await _physics_frames(1)


func _add_test_box(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	parent.add_child(body)
	body.global_position = at


func _enemy_reaches(enemy: Enemy, from: Vector3, to: Vector3, player: Player, frames: int) -> bool:
	EnemyPath.forget_all()
	enemy.revive()
	enemy._home = from
	enemy.position = from
	player.health.restore()
	player.position = to
	enemy.state = Enemy.State.CHASE
	for i in frames:
		await physics_frame
		player.position = to
		player.health.restore()
		if enemy.state == Enemy.State.WINDUP:
			return true
	return false


func _test_forest(scene: Node, player: Player) -> void:
	var forest: Forest = scene.get_node("Village/Forest")
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/village_layout.json"))
	var data: Dictionary = layout["forest"]
	_check(forest.tree_count() > int(data["count"]) * 0.8, "the forest is dense (%d trees)" % forest.tree_count())
	var center := Vector2(data["x"], data["z"])
	var well_placed := true
	for tree in forest.tree_count():
		var at := forest.tree_position(tree)
		well_placed = well_placed and Vector2(at.x, at.z).distance_to(center) <= float(data["radius"]) and absf(at.y - scene.get_node("Terrain").height_at(at.x, at.z)) < 0.01
	_check(well_placed, "forest trees stand on the ground inside the forest")

	var saved_position := player.position
	var saved_items := player.inventory.to_data()
	var tree_at := forest.tree_position(0)
	player.position = tree_at + player.facing_direction() * -2.5 + Vector3.UP * 0.2
	await _physics_frames(3)
	_check(player.interact_target == forest.target() and forest.has_target(), "the player can aim at a forest tree")
	player.inventory.load_data({})
	var messages: Array[String] = []
	var on_notice := func(text: String) -> void: messages.append(text)
	player.notice.connect(on_notice)
	player.interact()
	_check(player.inventory.count("wood") == 0 and messages.has("UI_NEED_AXE"), "chopping without an axe gives nothing and says why")
	player.inventory.add("iron_axe")
	var standing := forest.standing_count()
	var target_tree := forest._target_tree
	player._attack_cooldown = 0.0
	player.interact()
	_check(player.inventory.count("wood") == 1, "an axe strike gives wood")
	player.interact()
	_check(player.inventory.count("wood") == 1, "swings set the pace of chopping")
	player.notice.disconnect(on_notice)
	forest.strike_tree(target_tree, player)
	_check(forest.standing_count() == standing, "a tree takes several strikes")
	forest.strike_tree(target_tree, player)
	_check(forest.standing_count() == standing - 1 and player.inventory.count("wood") == int(data["strikes"]), "enough strikes fell the tree")
	await _physics_frames(3)
	_check(forest._target_tree != target_tree, "a felled tree can't be chopped again")

	var saved: Dictionary = JSON.parse_string(JSON.stringify(forest.to_data()))
	forest.load_data({})
	_check(forest.standing_count() == standing, "an old save without a forest has every tree standing")
	forest.load_data(saved)
	_check(forest.standing_count() == standing - 1, "felled trees are saved")
	player.position = saved_position
	await _physics_frames(1)
	forest._felled[target_tree] = 0.0
	await _physics_frames(2)
	_check(forest.standing_count() == standing, "felled trees grow back")
	player.inventory.load_data(saved_items)


func _test_gathering_collision(scene: Node, player: Player) -> void:
	var spot: ResourceNode = null
	for node in scene.get_node("Village").get_children():
		if node is ResourceNode and node.item_id == "wood":
			spot = node
			break
	var saved_position := player.position
	var toward_spot := Vector3(0.0, 0.0, 1.0)
	player.position = spot.position - toward_spot * 2.0 + Vector3.UP * 0.2
	await _physics_frames(1)
	_check(player.test_move(player.global_transform, toward_spot * 2.0), "a gathering spot blocks the player")
	for i in spot.uses:
		spot.interact(player)
	await _physics_frames(2)
	_check(not player.test_move(player.global_transform, toward_spot * 2.0), "a used-up gathering spot doesn't block the player")
	spot._respawn()
	await _physics_frames(2)
	_check(player.test_move(player.global_transform, toward_spot * 2.0), "a regrown gathering spot blocks the player again")
	player.position = saved_position
	await _physics_frames(1)


func _test_interface_fit(scene: Node) -> void:
	_check(InterfaceScale.factor_for(Vector2(1152.0, 648.0), Vector2(1152.0, 648.0), 0.9) == 1.0, "the base window size lays out the interface at full size")
	_check(InterfaceScale.factor_for(Vector2(1920.0, 1080.0), Vector2(1152.0, 648.0), 0.9) == 1.0, "large windows keep stretching the interface")
	_check(is_equal_approx(InterfaceScale.factor_for(Vector2(800.0, 600.0), Vector2(1152.0, 648.0), 0.9) * 800.0 / 1152.0, 0.9), "text in a small window stays at the smallest readable scale")

	var hud: HudLayout = scene.get_node("UI")
	var compass: Control = scene.get_node("UI/Compass")
	var health_bar: Control = scene.get_node("UI/HealthBar")
	var overlay: Control = scene.get_node("UI/PerformanceOverlay")
	var quest: Control = scene.get_node("UI/QuestLabel")
	for width: float in [711.0, 889.0, 1151.0]:
		hud.arrange_for(width)
		var health_end := health_bar.offset_right
		var overlay_start := width + overlay.offset_left
		_check(compass.offset_bottom < overlay.offset_top and compass.offset_bottom < health_bar.offset_top, "the compass has its own row at width %d" % width)
		_check(health_end < overlay_start, "the health bar clears the performance overlay at width %d" % width)
		_check(width + quest.offset_left >= 0.0 and quest.offset_top >= overlay.offset_bottom, "the quest text fits below the overlay at width %d" % width)
	hud.arrange()

	var theme := ThemeDB.get_project_theme()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		_check(theme.get_stylebox(state, "Button") is StyleBoxTexture, "buttons have a texture when %s" % state)
	_check_contrast(theme, "font_color", "Label", "panel", "PanelContainer", "text on panels")
	_check_contrast(theme, "font_color", "InkLabel", "panel", "ParchmentPanel", "text on parchment")
	_check_contrast(theme, "font_color", "Button", "normal", "Button", "text on buttons")

	# A window too small for a menu scrolls it, with every panel staying inside the window.
	var window := scene.get_window()
	var old_size := window.size
	window.size = Vector2i(1152, 648)
	await process_frame
	await process_frame
	_check(is_equal_approx(window.content_scale_factor, 1.0), "the base window size has no extra interface scale")
	window.size = Vector2i(640, 360)
	await process_frame
	await process_frame
	_check(window.content_scale_factor > 1.0, "a small window raises the interface scale")
	var menu: GameMenu = scene.get_node("GameMenu")
	menu.slot_paths = [TEST_SAVE, TEST_SLOT_2, TEST_SLOT_3]
	menu.open_title()
	for i in 5:
		await process_frame
	_check(window.get_visible_rect().encloses(menu._panel.get_global_rect()), "the menu stays inside a small window")
	menu.close()
	window.size = old_size
	await process_frame
	await process_frame


func _test_item_models(scene: Node) -> void:
	var player: Player = scene.get_node("Player")
	var weapon: Node3D = player._weapon
	var carried := player.inventory.to_data()
	player.inventory.load_data({})
	await process_frame
	_check(weapon.get_child_count() == 0, "empty hands hold no weapon")
	player.inventory.add("iron_dagger")
	await process_frame
	_check(weapon.get_child_count() == 1, "a crafted weapon shows in the hand")
	player.inventory.add("iron_sword", 1, "fine")
	await process_frame
	_check(weapon.get_child_count() == 1 and player.inventory.best_weapon_id() == "iron_sword", "the hand holds the strongest weapon")
	player.inventory.load_data(carried)
	await process_frame

	var anvil: CraftingStation = scene.get_node("Village/anvil")
	root.get_tree().call_group(CraftingStation.STATION_GROUP, "show_made", "anvil", "iron_axe")
	_check(anvil._made_model != null and anvil._made_model.get_parent() == anvil, "a forged weapon lies on the anvil")
	var axe := anvil._made_model
	root.get_tree().call_group(CraftingStation.STATION_GROUP, "show_made", "furnace", "iron_ingot")
	_check(anvil._made_model == axe, "things made elsewhere stay off the anvil")
	root.get_tree().call_group(CraftingStation.STATION_GROUP, "show_made", "anvil", "iron_nails")
	await process_frame
	_check(not is_instance_valid(axe) and anvil._made_model != null, "the newest item replaces the last one")
	anvil.show_made("anvil", "torch")
	await process_frame
	_check(anvil._made_model == null, "items with no model leave the anvil empty")


func _test_controls_hint(scene: Node) -> void:
	var label: Control = scene.get_node("UI/ControlsLabel")
	_check(label.modulate.a == 1.0, "the controls show when play starts")
	scene.open_pause_menu()
	_check(label.modulate.a == 1.0, "the controls show in the pause menu")
	scene.resume()
	await create_timer(scene.FADE_SECONDS + 0.2).timeout
	_check(is_zero_approx(label.modulate.a), "the controls fade after the pause menu")
	scene.open_pause_menu()
	_check(label.modulate.a == 1.0, "the controls come back in the pause menu")
	scene.resume()


func _test_ground_dryness() -> void:
	var texture := Surfaces.noise_texture()
	if texture.get_image() == null:
		await texture.changed
	var image := texture.get_image()
	image.clear_mipmaps()
	image.convert(Image.FORMAT_L8)
	Surfaces.prepare_ground_dryness()
	_check(image.get_data() == Surfaces._noise_values, "grass reads the same noise as the ground shader")
	var dry := 0
	var lush := 0
	for i in 400:
		var value := Surfaces.ground_dryness(i * 7.3, i * -11.1)
		dry += 1 if value > 0.8 else 0
		lush += 1 if value < 0.2 else 0
	_check(dry > 20 and lush > 20, "the ground has dry and lush areas (%d, %d)" % [dry, lush])


func _check_contrast(theme: Theme, color_name: String, color_type: String, box_name: String, box_type: String, what: String) -> void:
	var image: Image = (theme.get_stylebox(box_name, box_type) as StyleBoxTexture).texture.get_image()
	image = image.duplicate()
	if image.is_compressed():
		image.decompress()
	image.resize(1, 1, Image.INTERPOLATE_BILINEAR)
	var ratio := _contrast(theme.get_color(color_name, color_type), image.get_pixel(0, 0))
	_check(ratio >= 4.5, "%s are readable, contrast %.1f" % [what, ratio])


func _contrast(a: Color, b: Color) -> float:
	var lighter := maxf(_luminance(a), _luminance(b))
	var darker := minf(_luminance(a), _luminance(b))
	return (lighter + 0.05) / (darker + 0.05)


func _luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b


func _test_save_and_menu(scene: Node, player: Player, day_night: DayNight) -> void:
	var menu: GameMenu = scene.get_node("GameMenu")
	var village: Village = scene.get_node("Village")
	var full_roof: Node3D = village.get_node("inn/RepairedRoof")

	scene.save_game()
	_check(SaveGame.exists(TEST_SAVE), "the game saves")
	var saved_position := player.position
	var saved_coal := player.inventory.count("coal")
	var recipes := player.known_recipes.size()
	player.set_torch_lit(true)
	player.torch_burned_seconds = 12.0
	scene.save_game()

	# Quest changes autosave, which would overwrite the save this test wants to restore.
	scene._playing = false
	player.position += Vector3(5.0, 0.0, 5.0)
	player.inventory.add("coal", 7)
	player.known_recipes.clear()
	player.health.current = 1.0
	player.set_torch_lit(false)
	player.torch_burned_seconds = 0.0
	player.torch_given = false
	player.quests.load_data({ "stages": {}, "flags": [] })
	_check(not full_roof.visible, "the roof depends on saved flags")
	day_night.hour = 3.0

	_check(SaveGame.apply(TEST_SAVE, player, day_night, village), "the game loads")
	_check(player.position.is_equal_approx(saved_position), "position is restored")
	var below_ground := JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE)) as Dictionary
	below_ground["position"][1] = -500.0
	FileAccess.open(TEST_SAVE, FileAccess.WRITE).store_string(JSON.stringify(below_ground))
	SaveGame.apply(TEST_SAVE, player, day_night, village)
	_check(player.position.y > -100.0, "a save from below today's ground comes back above it")
	player.position = saved_position
	scene.save_game()
	_check(player.inventory.count("coal") == saved_coal, "inventory is restored")
	_check(player.known_recipes.size() == recipes, "recipes are restored")
	_check(player.health.current == 100.0, "health is restored")
	_check(player.torch_lit and player.torch_burned_seconds == 12.0 and player.torch_given, "the torch is restored")
	player.set_torch_lit(false)
	_check(player.quests.is_done("first_nails") and player.quests.flags.has("mayor_annoyed"), "quests and choices are restored")
	_check(full_roof.visible, "the repaired roof is restored")
	_check(day_night.hour != 3.0, "the time of day is restored")
	var enemy := _first_of(village, Enemy) as Enemy
	var spot := _first_of(village, ResourceNode) as ResourceNode
	for i in spot.uses:
		spot.interact(player)
	while enemy.state != Enemy.State.DEAD:
		enemy.take_hit(1000.0)
	scene.save_game()
	var saved_scrap := player.inventory.count("iron_scrap")
	enemy.revive()
	spot._respawn()

	_check(SaveGame.apply(TEST_SAVE, player, day_night, village), "the world loads")
	_check(player.inventory.count("iron_scrap") == saved_scrap, "loading doesn't repeat an enemy's drops")
	_check(enemy.state == Enemy.State.DEAD and not enemy.visible, "a defeated enemy stays defeated after loading")
	_check(enemy._timer > 0.0, "a defeated enemy still returns later")
	_check(not spot.is_available() and spot._respawn_left > 0.0, "an emptied gathering spot stays empty after loading")
	enemy.revive()
	spot._respawn()
	var old_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	old_save.erase("world")
	FileAccess.open(TEST_SAVE, FileAccess.WRITE).store_string(JSON.stringify(old_save))
	_check(SaveGame.apply(TEST_SAVE, player, day_night, village), "saves without world data still load")
	_check(enemy.state != Enemy.State.DEAD, "older saves leave enemies alone")
	scene._playing = true

	var damaged := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	damaged.store_string("{ not json")
	damaged.close()
	_check(not SaveGame.exists(TEST_SAVE), "a damaged save is ignored")
	_check(not SaveGame.apply(TEST_SAVE, player, day_night, village), "a damaged save doesn't load")

	player.health.current = 50.0
	day_night.hour = 22.0
	scene.sleep()
	_check(player.health.current == 100.0 and day_night.hour == 7.0, "sleeping heals and passes the night")
	_check(SaveGame.exists(TEST_SAVE), "sleeping saves the game")

	scene.open_pause_menu()
	_check(menu.is_open() and player.is_busy() and paused, "the pause menu pauses the game")
	scene.resume()
	_check(not menu.is_open() and not player.is_busy() and not paused, "resuming unpauses the game")
	menu.slot_paths = [TEST_SAVE, TEST_SLOT_2, TEST_SLOT_3]
	DirAccess.remove_absolute(TEST_SLOT_2)
	DirAccess.remove_absolute(TEST_SLOT_3)
	scene.save_game()
	menu.open_title()
	_check(menu._asset_note.is_visible_in_tree(), "the title menu notes AI-generated assets")
	TranslationServer.set_locale("de")
	_check(menu._asset_note.get_child(0).atr(menu._asset_note.get_child(0).text) == tr("UI_AI_ASSETS_NOTE"), "the AI asset note follows the language")
	TranslationServer.set_locale("en")
	_check(menu.is_open(), "the title menu opens")
	var started := [""]
	var loaded := [""]
	var on_new_game := func(path: String) -> void: started[0] = path
	var on_continue := func(path: String) -> void: loaded[0] = path
	menu.new_game_chosen.connect(on_new_game)
	menu.continue_chosen.connect(on_continue)
	var scene_new: Callable = scene._on_new_game_chosen
	var scene_continue: Callable = scene._on_continue_chosen
	menu.new_game_chosen.disconnect(scene_new)
	menu.continue_chosen.disconnect(scene_continue)

	menu._buttons.get_child(0).pressed.emit()
	_check(loaded[0] == TEST_SAVE, "continue loads the latest save")
	menu._buttons.get_child(2).pressed.emit()
	_check(menu._slot_screen and menu._buttons.get_child_count() == SaveGame.SLOTS + 1, "new game offers the save slots")
	menu._buttons.get_child(0).pressed.emit()
	_check(started[0] == "" and menu._confirming, "a used slot asks before being overwritten")
	menu._buttons.get_child(0).pressed.emit()
	_check(started[0] == "" and menu._slot_screen, "going back keeps the save")
	menu._buttons.get_child(0).pressed.emit()
	menu._buttons.get_child(1).pressed.emit()
	_check(started[0] == TEST_SAVE, "confirming starts a new game in that slot")
	started[0] = ""
	menu.open_title()
	menu._buttons.get_child(2).pressed.emit()
	menu._buttons.get_child(1).pressed.emit()
	_check(started[0] == TEST_SLOT_2, "an empty slot starts at once")

	menu.open_title()
	menu._buttons.get_child(1).pressed.emit()
	var empty_slot: Button = menu._buttons.get_child(1)
	_check(empty_slot.disabled and not menu._buttons.get_child(0).disabled, "only used slots can be loaded")
	loaded[0] = ""
	menu._buttons.get_child(0).pressed.emit()
	_check(loaded[0] == TEST_SAVE, "loading uses the chosen slot")

	scene.save_path = TEST_SLOT_2
	scene.save_game()
	var older := FileAccess.get_modified_time(TEST_SAVE)
	if FileAccess.get_modified_time(TEST_SLOT_2) == older:
		OS.delay_msec(1100)
		scene.save_game()
	_check(SaveGame.latest(menu.slot_paths) == TEST_SLOT_2 and SaveGame.exists(TEST_SAVE), "saving goes to the current slot and leaves the others")
	scene.save_path = TEST_SAVE
	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.remove_absolute(TEST_SLOT_2)
	menu.open_title()
	_check(not menu._asset_note.get_parent() == null and menu._buttons.get_child_count() == 3, "with no saves, the title offers new game, settings, and quit")
	started[0] = ""
	menu._buttons.get_child(0).pressed.emit()
	_check(started[0] == TEST_SAVE, "with no save, new game starts at once")
	menu.new_game_chosen.disconnect(on_new_game)
	menu.continue_chosen.disconnect(on_continue)
	menu.new_game_chosen.connect(scene_new)
	menu.continue_chosen.connect(scene_continue)
	menu.close()
	DirAccess.remove_absolute(TEST_SAVE)


func _talk(ui: DialogueUI, npc_id: String, player: Player, answers: Array) -> void:
	ui.open_conversation(npc_id, npc_id, player)
	for answer: int in answers:
		ui.choose(answer)


func _test_grass_cost(scene: Node) -> void:
	var grass: GrassField = scene.get_node("Village/Grass")
	var menu: GameMenu = scene.get_node("GameMenu")
	await _physics_frames(30)
	var cell: Vector2i = grass._planted.keys()[0]
	var planted: GrassField.PlantedCell = grass._planted[cell]
	var cell_center := (Vector2(cell) + Vector2(0.5, 0.5)) * GrassField.CELL_SIZE

	var whole_tris := 0
	var far_tris := 0
	for species in grass._meshes.size():
		whole_tris += grass._meshes[species].surface_get_array_len(0) / 3
		far_tris += grass._far_meshes[species].surface_get_array_len(0) / 3
	_check(far_tris * 3 < whole_tris, "distant grass tufts cost far less (%d against %d triangles)" % [far_tris, whole_tris])

	grass._fit_detail(cell, cell_center)
	var multimesh := planted.multimeshes[0]
	_check(multimesh.visible_instance_count == multimesh.instance_count and multimesh.mesh == grass._meshes[planted.species[0]], "grass around the camera is drawn whole")
	grass._fit_detail(cell, cell_center + Vector2(160.0, 0.0))
	_check(multimesh.visible_instance_count < multimesh.instance_count and multimesh.mesh == grass._far_meshes[planted.species[0]], "distant grass draws fewer, simpler tufts")
	grass._fit_detail(cell, cell_center + Vector2(600.0, 0.0))
	_check(not planted.group.visible, "grass beyond the draw distance isn't drawn")
	grass._fit_detail(cell, cell_center)
	_check(planted.group.visible and multimesh.mesh == grass._meshes[planted.species[0]], "grass returns when the camera comes back")

	var distances: Array[float] = []
	for level in 3:
		menu._choose_graphics(level)
		distances.append(grass._draw_distance)
		_check(grass.tuft_share(GrassField.DRAW_DISTANCE * GrassField.EARLY_FADE - 1.0) == 1.0, "%s graphics keep all the grass nearby" % Settings.graphics)
		_check(grass.tuft_share(grass._draw_distance) == 0.0, "%s graphics draw no grass past the draw distance" % Settings.graphics)
	_check(distances[0] < distances[1] and distances[1] < distances[2], "lower graphics draw grass less far (%s)" % str(distances))
	_check(distances[2] == GrassField.DRAW_DISTANCE, "high graphics draw grass at full distance")


func _test_settings(scene: Node, player: Player) -> void:
	var menu: GameMenu = scene.get_node("GameMenu")
	var hedda: Npc = scene.get_node("Village/hedda")
	TranslationServer.set_locale("en")
	menu.open_pause()
	menu._buttons.get_child(1).pressed.emit()
	_check(menu._settings_open and menu._buttons.get_child_count() == 4, "the pause menu opens the settings")

	menu._choose_language(2)
	await process_frame
	await process_frame
	_check(TranslationServer.get_locale() == "de" and menu._title.text == "Einstellungen", "choosing a language changes the menu")
	_check(scene.get_node("UI/ControlsLabel").text == tr("UI_CONTROLS") and hedda._label.text == tr(hedda.prompt_key), "choosing a language changes text already on screen")

	menu._choose_graphics(0)
	var sun: DirectionalLight3D = scene.get_node("Sun")
	_check(not sun.shadow_enabled and is_equal_approx(root.scaling_3d_scale, Settings.render_scale()), "low graphics take effect at once")
	menu._choose_graphics(1)
	_check(sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "medium graphics use fewer shadow levels")
	menu._choose_graphics(2)
	_check(sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and root.scaling_3d_scale == 1.0, "high graphics take effect at once")

	menu._choose_look_speed(2.0)
	menu._close_settings()
	_check(menu.is_open() and menu._title.text == tr("UI_PAUSED"), "leaving the settings returns to the pause menu")
	Settings.look_speed = 1.0
	Settings.language = ""
	Settings.graphics = "low"
	Settings.load_saved()
	_check(Settings.language == "de" and Settings.look_speed == 2.0 and Settings.graphics == "high", "settings are remembered")
	menu.close()
	player.set_busy(false)

	var damaged := FileAccess.open(TEST_SETTINGS, FileAccess.WRITE)
	damaged.store_string("not json")
	damaged.close()
	Settings.load_saved()
	_check(Settings.language == "" and Settings.look_speed == 1.0 and Settings.graphics == "high", "damaged settings fall back to defaults")
	Settings.path = Settings.DEFAULT_PATH
	DirAccess.remove_absolute(TEST_SETTINGS)
	TranslationServer.set_locale("en")


## Every story and item key must exist in both languages.
func _test_translations() -> void:
	var missing := PackedStringArray()
	var text := FileAccess.get_file_as_string("res://data/dialogue.json") + FileAccess.get_file_as_string("res://data/quests.json") + FileAccess.get_file_as_string("res://data/crafting.json") + FileAccess.get_file_as_string("res://data/enemies.json")
	var pattern := RegEx.create_from_string("\"((?:DLG|OBJ|QUEST|ITEM|ENEMY)_[A-Z_]+)\"")
	for locale in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for found in pattern.search_all(text):
			if TranslationServer.translate(found.get_string(1)) == found.get_string(1):
				missing.append("%s:%s" % [locale, found.get_string(1)])
	TranslationServer.set_locale("en")
	_check(missing.is_empty(), "all text is translated %s" % ", ".join(missing))


func _first_of(parent: Node, type: Variant) -> Node:
	for child in parent.get_children():
		if is_instance_of(child, type):
			return child
	return null


## The villager faces the player, and on screen they don't overlap.
func _framing_test(player: Player, npc: Npc) -> bool:
	var to_player := (player.global_position - npc.global_position) * Vector3(1.0, 0.0, 1.0)
	to_player = to_player.normalized()
	var faces: bool = (-npc.global_basis.z).dot(to_player) > 0.99
	var camera: Camera3D = player.get_node("CameraPivot/SpringArm/Camera")
	var view := camera.global_transform.affine_inverse()
	var npc_view: Vector3 = view * (npc.global_position + Vector3.UP)
	var player_view: Vector3 = view * (player.global_position + Vector3.UP)
	return faces and npc_view.x / -npc_view.z > player_view.x / -player_view.z + 0.1


func _has_joypad(kinds: Dictionary) -> bool:
	return kinds.has("InputEventJoypadButton") or kinds.has("InputEventJoypadMotion")


func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, label: String) -> void:
	print("%s: %s" % ["ok" if condition else "FAIL", label])
	if not condition:
		_failures += 1


## The axe shows while chopping (#121) and hits with its own damage (#134), and a player inside the ground comes back up (#125).
func _test_player_fixes(scene: Node, player: Player) -> void:
	var terrain: Terrain = scene.get_node("Terrain")
	var village: Village = scene.get_node("Village")
	var day_night: DayNight = scene.get_node("DayNight")
	var forest: Forest = scene.get_node("Village/Forest")
	var saved_position := player.position
	var saved_items := player.inventory.to_data()
	var saved_forest: Dictionary = JSON.parse_string(JSON.stringify(forest.to_data()))

	player.inventory.load_data({})
	player.inventory.add("iron_sword")
	player.inventory.add(Forest.AXE_ITEM)
	# The forest test chopped a moment ago.
	var seconds: float = FeatureFlags.value("axe_in_hand_seconds")
	await _physics_frames(ceili(seconds * Engine.physics_ticks_per_second) + 5)
	_check(player.item_in_hand() == "iron_sword", "the strongest weapon is in hand")
	_check(player.swing_damage() == 20.0, "a swing hits with the sword in hand")
	player.position = forest.tree_position(0) + player.facing_direction() * -2.5 + Vector3.UP * 0.2
	await _physics_frames(3)
	player._attack_cooldown = 0.0
	player.interact()
	_check(player.item_in_hand() == Forest.AXE_ITEM, "chopping puts the axe in hand, even with a sword carried")
	_check(player.swing_damage() == 16.0, "a chopping swing hits with the axe, not the sword")
	await _physics_frames(ceili(seconds * Engine.physics_ticks_per_second) + 5)
	_check(player.item_in_hand() == "iron_sword", "after chopping the sword comes back")
	forest.load_data(saved_forest)
	player.inventory.load_data(saved_items)

	# Beside the river, where the ground collides exactly where it is drawn.
	var i := terrain.river.positions.size() / 3
	var here := terrain.river.positions[i]
	var side := (terrain.river.positions[i + 1] - here).normalized().orthogonal()
	var bank := here + side * (terrain.river.half_widths[i] + 3.0)
	var dry := Vector2(150.0, 150.0)
	for at: Vector2 in [bank, dry]:
		for depth: float in [0.2, 0.8, 3.0]:
			player.position = Vector3(at.x, terrain.height_at(at.x, at.y) - depth, at.y)
			player.velocity = Vector3.ZERO
			await _physics_frames(30)
			_check(not _under_ground(terrain, player), "a player %.1f m inside the ground at (%.0f, %.0f) comes back up" % [depth, at.x, at.y])

	var ground := terrain.height_at(bank.x, bank.y)
	player.position = Vector3(bank.x, ground - 0.8, bank.y)
	SaveGame.write(TEST_SAVE, player, day_night, village)
	player.position = saved_position
	SaveGame.apply(TEST_SAVE, player, day_night, village)
	player.velocity = Vector3.ZERO
	await _physics_frames(30)
	_check(not _under_ground(terrain, player), "a save from inside the ground loads on top of it")
	DirAccess.remove_absolute(TEST_SAVE)

	# A roof overhead never lifts anyone, buried or not.
	var roof := Node3D.new()
	root.add_child(roof)
	_add_test_box(roof, Vector3(bank.x, ground + 2.4, bank.y), Vector3(4.0, 0.4, 4.0))
	await _physics_frames(2)
	for depth: float in [-0.05, 0.8]:
		player.position = Vector3(bank.x, ground - depth, bank.y)
		player.velocity = Vector3.ZERO
		await _physics_frames(30)
		var how := "buried" if depth > 0.0 else "standing"
		_check(not _under_ground(terrain, player) and player.position.y < ground + 1.0, "a roof overhead doesn't lift a %s player onto it" % how)
	roof.free()

	# Wading under the bridge keeps the player in the water.
	var bridge: Node3D = village.get_node("Bridge")
	var under := Vector2(bridge.position.x, bridge.position.z)
	var bed := terrain.height_at(under.x, under.y)
	player.position = Vector3(under.x, bed + 0.05, under.y)
	player.velocity = Vector3.ZERO
	await _physics_frames(30)
	_check(not _under_ground(terrain, player) and player.position.y < bed + 0.3, "wading under the bridge stays in the water (%.2f m above the bed)" % (player.position.y - bed))
	player.position = saved_position
	player.velocity = Vector3.ZERO
	await _physics_frames(10)


## Whether the ground's own collision lies above the player's feet, by more than 0.3 m.
func _under_ground(terrain: Terrain, player: Player) -> bool:
	var feet := player.global_position
	var query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 30.0, feet + Vector3.UP * 0.3)
	query.exclude = [player.get_rid()]
	var space := terrain.get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	while not hit.is_empty() and hit["collider"] != terrain:
		query.exclude = query.exclude + [hit["rid"]]
		hit = space.intersect_ray(query)
	return not hit.is_empty() or feet.y < terrain.height_at(feet.x, feet.z) - 20.0


func _test_grass_cell_edge(scene: Node) -> void:
	var grass: GrassField = scene.get_node("Village/Grass")
	var cell := Vector2i(10, 10)
	var origin := Vector2(cell) * GrassField.CELL_SIZE
	var half := GrassField.CELL_SIZE * 0.5
	# The camera stands just inside the draw distance from the cell's near edge, but its center is further out.
	var near := origin + Vector2(-grass._draw_distance + 5.0, half)
	_check(grass._cell_nearest_distance(cell, near) < grass._draw_distance, "a cell's near edge is inside the draw distance")
	_check(grass._cell_nearest_distance(cell, origin + Vector2(half, half)) == 0.0, "a camera inside a cell is no distance from it")
	for planted: GrassField.PlantedCell in grass._planted.values():
		planted.group.queue_free()
	grass._planted.clear()
	if grass._task >= 0:
		grass._finish_batch()
	for i in 400:
		grass._start_batch(near)
		if grass._task < 0:
			break
		grass._finish_batch()
	_check(grass._planted.has(cell), "a cell whose near edge is inside the draw distance is planted")
	_check(not grass._planted.has(cell + Vector2i(1, 0)), "a cell whose near edge is outside the draw distance is left out")
