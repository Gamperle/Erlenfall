extends SceneTree
## Run with: godot --headless --path . --script res://tests/smoke_test.gd

const TEST_SAVE := "user://smoke_test_save.json"
const TEST_OLD_SAVE := "user://smoke_test_old_save.json"
const TEST_SLOT_2 := "user://smoke_test_save_2.json"
const TEST_SLOT_3 := "user://smoke_test_save_3.json"
const TEST_SETTINGS := "user://smoke_test_settings.json"
const TEST_FLAGS_A := "user://smoke_test_flags_a.json"
const TEST_FLAGS_B := "user://smoke_test_flags_b.json"
## How far a prop model's lowest point may be from its base, in meters, before it visibly floats or sinks.
const PROP_GROUND_TOLERANCE := 0.1

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.remove_absolute(TEST_SAVE + SaveGame.BACKUP_SUFFIX)
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
	var stone_wall := ModelBuilder.stone_wall(8.0, 2.4, 0.6, 1)
	var wall_parts := stone_wall.find_children("*", "MeshInstance3D", true, false)
	var wall_bounds: AABB = wall_parts[0].mesh.get_aabb()
	_check(wall_parts.size() == 1 and wall_parts[0].mesh.get_surface_count() <= 3 and wall_bounds.size.x > 7.9 and wall_bounds.size.x < 8.1 and absf(wall_bounds.size.y - 2.4) < 0.15, "a code-built stone wall is one mesh of the size asked for")
	var same_wall := ModelBuilder.stone_wall(8.0, 2.4, 0.6, 1).find_children("*", "MeshInstance3D", true, false)[0]
	_check(same_wall.mesh.get_faces() == wall_parts[0].mesh.get_faces(), "the same seed builds the same wall")
	var palisade := ModelBuilder.palisade(6.0, 3.0, 1).find_children("*", "MeshInstance3D", true, false)
	_check(palisade.size() == 1 and absf(palisade[0].mesh.get_aabb().size.x - 6.0) < 0.1, "a code-built palisade is one mesh of the size asked for")
	stone_wall.free()
	same_wall.get_parent().get_parent().free()
	palisade[0].get_parent().get_parent().free()
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
	var dome: SkyDome = scene.get_node("SkyDome")
	var dome_param := func(hour: float, parameter: String) -> Variant:
		day_night.hour = hour
		day_night._apply()
		return dome.material_override.get_shader_parameter(parameter)
	_check(dome.material_override.shader != null and dome.material_override.shader.get_mode() == Shader.MODE_SPATIAL, "the sky dome has its shader")
	_check(dome_param.call(1.0, "star_visibility") == 1.0 and dome_param.call(12.0, "star_visibility") == 0.0, "stars show at night and not by day")
	_check(dome_param.call(19.0, "star_visibility") == 0.0 and dome_param.call(19.9, "star_visibility") > 0.0 and dome_param.call(21.0, "star_visibility") == 1.0, "stars fade in after sunset")
	_check(dome_param.call(1.0, "moon_visibility") > 0.9 and dome_param.call(12.0, "moon_visibility") == 0.0, "the moon shows at night only")
	var moon_dir: Vector3 = dome_param.call(0.0, "moon_direction")
	day_night._apply()
	_check(moon_dir.is_equal_approx(sun.basis.z), "the moon disc sits where the moonlight comes from")
	var night_cloud: Color = dome_param.call(1.0, "cloud_light_color")
	var day_cloud: Color = dome_param.call(12.0, "cloud_light_color")
	_check(night_cloud.v < 0.4 and day_cloud.v > 0.9, "clouds are tinted by the time of day")
	var cloud_before: Vector2 = dome_param.call(12.0, "cloud_offset")
	dome._process(10.0)
	_check(dome.material_override.get_shader_parameter("cloud_offset") != cloud_before, "clouds drift")
	dome.set_quality("low")
	_check(dome.material_override.get_shader_parameter("cloud_octaves") < SkyDome.CLOUD_OCTAVES["high"], "low graphics draw simpler clouds")
	var dome_source := FileAccess.get_file_as_string("res://shaders/sky_dome.gdshader")
	_check(dome_source.count("cloud_density(") == 2, "the sky shader samples the cloud noise once per pixel (a shifted second sample drew a streak, and costs the laptop)")
	dome.set_quality(Settings.graphics)
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
	_test_rubble_ground(terrain)
	await _test_hud(scene, player)
	await _test_map(scene, player)
	await _test_journal(scene, player)
	await _test_readables(scene, player)
	_test_character_models(player)
	_test_generated_props()
	_test_feature_flags()
	await _test_torch(player)
	await _test_ranged(scene, player)
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
	_test_crafting_parts(scene, player)
	await _test_story(scene, player)
	await _test_villager_routines(scene)
	await _test_combat(scene, player)
	await _test_enemy_types(scene, player)
	await _test_enemy_navigation(scene, player)
	await _test_enemy_crowds_and_bridges(scene, player)
	await _test_enemies_make_way(player)
	await _test_enemies_go_around_a_corridor(player)
	await _test_gathering_collision(scene, player)
	await _test_buried_mine(scene, player)
	await _test_walls(scene, player)
	await _test_forest(scene, player)
	await _test_player_fixes(scene, player)
	await _test_save_and_menu(scene, player, day_night)
	await _test_controller_navigation(scene, player)
	await _test_ambient_life(scene, day_night)
	await _test_weather(scene, day_night)
	await _test_grass_cost(scene)
	_test_surface_relief(scene)
	_test_grass_cell_edge(scene)
	await _test_settings(scene, player)
	_test_translations()
	await _test_key_bindings(scene)
	_test_dialogue_data()
	_test_dialogue_conditions()
	_test_data_validation()

	print("FAILED: %d" % _failures if _failures > 0 else "ALL PASSED")
	quit(1 if _failures > 0 else 0)


func _test_land_and_river(scene: Node, player: Player) -> void:
	var terrain: Terrain = scene.get_node("Terrain")
	var village: Village = scene.get_node("Village")
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Village.LAYOUT_PATH))

	_check(terrain.get_node("Water").mesh.get_surface_count() == 1, "the river has water")
	_check(terrain.river_clearance(0.0, 5.0) < 0.0, "the river runs through the village")
	_check(terrain.height_at(0.0, 5.0) < terrain.water_height(0.0, 5.0), "the river bed lies under the water")
	_check_water_ripples(terrain, player)
	var downhill := true
	for i in range(1, terrain.river.heights.size()):
		downhill = downhill and terrain.river.heights[i] <= terrain.river.heights[i - 1]
	_check(downhill, "the river only flows downhill")

	var misplaced := PackedStringArray()
	for list in ["buildings", "fields", "npcs", "enemies", "repair_sites", "beds", "stations", "resources", "readables"]:
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

	# The valley sides must not be steeper than the 45 degree limit the player can walk up (#126).
	var steepest_side := 0.0
	for x in range(-480, 481, 6):
		for z in range(-120, 400, 6):
			var clearance := terrain.river_clearance(x, z)
			if clearance > 0.0 and clearance < 30.0 and Vector2(x, z).length() < 480.0:
				steepest_side = maxf(steepest_side, _slope_degrees(terrain, x, z))
	_check(steepest_side < 45.0, "the river's valley sides can be climbed (steepest %.1f degrees)" % steepest_side)

	# The mountain walls east of the village, around the river's source, can be climbed too (#186).
	var steepest_wall := 0.0
	for x in range(200, 481, 4):
		for z in range(-300, 121, 4):
			if Vector2(x, z).length() < 480.0 and not terrain.is_on_landslide(x, z):
				steepest_wall = maxf(steepest_wall, _slope_degrees(terrain, x, z))
	_check(steepest_wall < 45.0, "the mountain walls east of the village can be climbed (steepest %.1f degrees)" % steepest_wall)

	# The river's west valley sides stay climbable far from the river too, where the land lies high (#340).
	var steepest_west := 0.0
	for x in range(-480, -199, 4):
		for z in range(150, 421, 4):
			if Vector2(x, z).length() < 480.0 and not terrain.is_on_landslide(x, z):
				steepest_west = maxf(steepest_west, _slope_degrees(terrain, x, z))
	_check(steepest_west < 45.0, "the river's west valley sides can be climbed (steepest %.1f degrees)" % steepest_west)

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
			# The rubble's cells are fine for another reason, and its ridges bend sharper than any grid (#137).
			if terrain.is_on_landslide(corner.x, corner.y) or terrain.is_on_landslide(corner.x + 8.0, corner.y + 8.0) or terrain.is_on_landslide(corner.x - 8.0, corner.y - 8.0):
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


## The landslide's rubble changes faster than 4 m cells can follow, so its cells are fine (#137).
# Without the fine cells the rubble was 1.6 m off at p95 and 5.3 m at worst; with them 0.36 and 1.6.
func _test_rubble_ground(terrain: Terrain) -> void:
	var points := PackedVector2Array()
	for x in range(-45, 130, 3):
		for z in range(-420, -180, 3):
			var at := Vector2(x + 0.7, z + 0.7)
			if terrain.is_on_landslide(at.x, at.y) and terrain.height_at(at.x, at.y) < 150.0:
				points.append(at)
	var ground := _seam_triangles(terrain, points)
	var errors: Array[float] = []
	for at in points:
		errors.append(absf(_visible_height(ground, at) - terrain.height_at(at.x, at.y)))
	errors.sort()
	var p95: float = errors[int(errors.size() * 0.95)]
	print("rubble ground: %d points, median %.3f, p95 %.3f, max %.3f m off" % [errors.size(), errors[errors.size() / 2], p95, errors[-1]])
	_check(errors.size() > 1000 and p95 < 0.5, "the landslide's rubble is drawn close to the true ground (%.3f m off at p95)" % p95)


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


func _test_map(scene: Node, player: Player) -> void:
	var controller: MapController = scene.get_node("MapController")
	var terrain: Terrain = scene.get_node("Terrain")
	var hud: HudLayout = scene.get_node("UI")
	var started := Time.get_ticks_msec()
	controller.finish_now()
	print("map picture waited %d ms" % (Time.get_ticks_msec() - started))
	var data := controller.data
	_check(controller.is_picture_ready() and data.texture != null and data.texture.get_width() == MapData.IMAGE_SIZE, "the map picture is drawn once at load")
	var image := data.image()
	var river_at := terrain.river.positions[terrain.river.positions.size() / 2]
	var river_pixel := (MapData.world_to_uv(river_at) * MapData.IMAGE_SIZE).floor()
	_check(_close_color(image.get_pixel(int(river_pixel.x), int(river_pixel.y)), MapData.WATER_COLOR), "the river is blue on the map")
	var road_at := terrain.roads[0].positions[terrain.roads[0].positions.size() / 2]
	var road_pixel := (MapData.world_to_uv(road_at) * MapData.IMAGE_SIZE).floor()
	_check(_close_color(image.get_pixel(int(road_pixel.x), int(road_pixel.y)), MapData.ROAD_COLOR), "a road is drawn on the map")
	var uv := MapData.world_to_uv(Vector2(-800.0, 800.0))
	_check(uv.is_equal_approx(Vector2(0.0, 1.0)) and MapData.uv_to_world(Vector2(0.5, 0.5)).is_equal_approx(Vector2.ZERO), "the map has north at the top and the world's middle at its center")
	_check(data.places.size() >= 11 and data.places.all(func(place: Dictionary) -> bool: return tr(place["name"]) != place["name"]), "every place on the map has a translated name")
	var forge: Dictionary = data.places.filter(func(place: Dictionary) -> bool: return place["id"] == "forge")[0]
	for place in data.places:
		place["discovered"] = false
	var far := Vector2(forge["position"]) + Vector2(500.0, 0.0)
	_check(not data.discover_near(far, 60.0) and not forge["discovered"], "faraway places stay undiscovered")
	_check(data.discover_near(forge["position"] + Vector2(10.0, 0.0), 60.0) and forge["discovered"], "walking near a place discovers it")
	await process_frame

	var minimap: Minimap = controller.minimap
	_check(minimap != null and minimap.get_parent() == hud, "the minimap is on the HUD")
	var region := minimap.visible_region()
	_check(region.size.x < MapData.IMAGE_SIZE and Rect2(Vector2.ZERO, Vector2.ONE * MapData.IMAGE_SIZE).encloses(region), "the minimap shows a part of the picture, inside it")
	minimap.player_position = Vector2(-790.0, 790.0)
	_check(Rect2(Vector2.ZERO, Vector2.ONE * MapData.IMAGE_SIZE).encloses(minimap.visible_region()), "the minimap stays inside the picture at the world's corner")
	minimap.player_position = Vector2.ZERO
	var health_bar: Control = scene.get_node("UI/HealthBar")
	var overlay: Control = scene.get_node("UI/PerformanceOverlay")
	var quest: Control = scene.get_node("UI/QuestLabel")
	var compass: Control = scene.get_node("UI/Compass")
	for width: float in [640.0, 889.0, 1152.0, 1600.0]:
		for text_size: float in [1.0, 1.5]:
			Settings.text_size = text_size
			hud.arrange_for(width)
			var width_label := "at width %d and text size %.1f" % [width, text_size]
			var minimap_rect := Rect2(minimap.offset_left, minimap.offset_top, minimap.offset_right - minimap.offset_left, minimap.offset_bottom - minimap.offset_top)
			var overlay_rect := Rect2(width + overlay.offset_left, overlay.offset_top, -overlay.offset_left + overlay.offset_right, overlay.offset_bottom - overlay.offset_top)
			var quest_rect := Rect2(width + quest.offset_left, quest.offset_top, quest.offset_right - quest.offset_left, 400.0)
			_check(minimap_rect.size.x == Minimap.side_for_text_size() and minimap_rect.position.y >= health_bar.offset_bottom, "the minimap sits below the health bar %s" % width_label)
			_check(not minimap_rect.intersects(overlay_rect) and not minimap_rect.intersects(compass.get_rect()), "the minimap clears the overlay and compass %s" % width_label)
			_check(not minimap_rect.intersects(quest_rect) and minimap_rect.end.x <= width, "the minimap clears the quest text %s" % width_label)
	Settings.text_size = 1.0
	hud.arrange()

	var world_map: WorldMap = controller.world_map
	_check(InputMap.has_action("map") and _has_key("map", KEY_M) and _has_joypad_button("map"), "the map opens with M or a controller button")
	_check(not world_map.is_open(), "the map starts closed")
	var press := InputEventAction.new()
	press.action = "map"
	press.pressed = true
	world_map._input(press)
	_check(world_map.is_open() and player.is_busy() and scene.get_tree().paused, "the map key opens the map and pauses the game")
	_check(is_equal_approx(world_map.view_center().distance_to(world_map.player_position), 0.0), "the map opens on the player")
	var zoom_before := world_map.zoom_level()
	world_map.zoom_by(2.0)
	_check(world_map.zoom_level() > zoom_before and world_map.span() < Terrain.SIZE / zoom_before, "zooming shows a smaller area")
	world_map.zoom_by(1000.0)
	world_map.pan(Vector2(5000.0, 5000.0))
	_check(world_map.zoom_level() == WorldMap.MAX_ZOOM and world_map.view_center().x <= MapData.half_extent() - world_map.span() / 2.0 + 0.01, "the map can't zoom or pan past its limits")
	await process_frame
	world_map._input(press)
	_check(not world_map.is_open() and not player.is_busy(), "the map key closes the map again")
	player.set_busy(true)
	_check(not world_map.can_open.call(), "the map doesn't open over a menu")
	player.set_busy(false)
	_check(tr("UI_MAP") == "Map", "the map is titled in English")
	TranslationServer.set_locale("de")
	_check(tr("UI_MAP") == "Karte" and tr("MAP_FORGE") == "Schmiede", "the map is translated to German")
	TranslationServer.set_locale("en")
	_check(MapMarkers.clamp_to_rect(Vector2(1000.0, 50.0), Rect2(0.0, 0.0, 100.0, 100.0), 5.0).x <= 95.0, "a faraway objective stays at the map's edge")


func _test_journal(scene: Node, player: Player) -> void:
	var journal: Journal = scene.get_node("Journal")
	var controller: MapController = scene.get_node("MapController")
	_check(FeatureFlags.enabled("journal") and journal != null and not journal.is_open(), "the journal starts closed")
	_check(InputMap.has_action("journal") and _has_key("journal", KEY_J) and _has_joypad_button("journal") and _has_key("map", KEY_M), "the journal opens with J or a controller button, and M still opens the map")
	_check(KeyBindings.ACTIONS.has("journal") and KeyBindings.HINTS.any(func(hint: Array) -> bool: return hint[0] == "journal"), "the journal key can be remapped and is on the controls line")

	# Tracking and the compass.
	var quests := QuestLog.new()
	var carried := Inventory.new()
	quests.start("arrival")
	quests.start("first_nails")
	_check(quests.objective_markers(carried).size() == 2 and quests.tracker_lines(carried).size() == 2, "without a pinned quest every active quest shows")
	_check(quests.track("first_nails") and quests.objective_markers(carried).size() == 1 and quests.tracker_lines(carried).size() == 1, "a pinned quest is the only one on the tracker and compass")
	_check(not quests.track("nonexistent_quest") and quests.tracked == "first_nails", "only a started, unfinished quest can be pinned")
	var saved_quests := quests.to_data()
	var restored := QuestLog.new()
	restored.load_data(saved_quests)
	_check(restored.tracked == "first_nails", "the pinned quest is saved")
	var old_data := saved_quests.duplicate()
	old_data.erase("tracked")
	restored.load_data(old_data)
	_check(restored.tracked == "" and restored.objective_markers(carried).size() == 2, "a save from before the journal tracks every quest")
	quests.untrack()
	_check(quests.tracked == "" and quests.tracker_lines(carried).size() == 2, "unpinning tracks every quest again")
	quests.track("arrival")
	quests.advance("arrival")
	quests.advance("arrival")
	_check(quests.is_done("arrival") and quests.tracker_lines(carried).size() == 1, "finishing the pinned quest shows the others again")
	var entries := quests.journal_entries(carried)
	_check(entries.size() == 2 and entries[0]["id"] == "first_nails" and entries[1]["done"] and entries[1]["objectives"].size() == 2 and entries[1]["objectives"].all(func(o: Dictionary) -> bool: return o["done"]), "the journal lists active quests first, then finished ones with their objectives")

	# Notes.
	var notes := JournalNotes.new()
	_check(notes.count() == 0 and notes.add("test_note", "UI_JOURNAL", "UI_JOURNAL_NO_MAP") and not notes.add("test_note", "x", "y") and notes.has("test_note"), "a note is added once")
	var restored_notes := JournalNotes.new()
	restored_notes.load_data(notes.to_data())
	restored_notes.load_data(restored_notes.to_data() + ["junk", { "id": 5 }])
	_check(restored_notes.count() == 1 and restored_notes.entries()[0]["title"] == "Journal", "notes are saved and damaged entries are skipped")

	# Saved in an optional key.
	var data := JSON.parse_string(JSON.stringify({ "notes": notes.to_data() })) as Dictionary
	var from_save := JournalNotes.new()
	from_save.load_data(data.get("notes", []))
	_check(from_save.has("test_note"), "notes survive a save file round trip")
	_check(not JSON.parse_string(JSON.stringify({ "version": 2 })).has("notes"), "an old save without notes is still valid input")

	# The screen.
	var press := InputEventAction.new()
	press.action = "journal"
	press.pressed = true
	journal._input(press)
	_check(journal.is_open() and player.is_busy() and scene.get_tree().paused, "the journal key opens the journal and pauses the game")
	_check(journal.current_tab() == Journal.TAB_QUESTS and journal.get_viewport().gui_get_focus_owner() != null, "the journal opens on the quests with something focused for a controller")
	await process_frame
	var quest_texts := _all_text(journal)
	_check(quest_texts.contains(tr("QUEST_ARRIVAL")) or quest_texts.contains(tr("QUEST_FIRST_NAILS")), "the quests tab lists the player's quests")
	journal.select_tab(Journal.TAB_MAP)
	await process_frame
	_check(journal.is_ancestor_of(controller.world_map._canvas) and not controller.world_map.is_open(), "the map tab shows the world map's own picture inside the journal")
	journal.select_tab(Journal.TAB_NOTES)
	_check(not journal.is_ancestor_of(controller.world_map._canvas) and controller.world_map.is_ancestor_of(controller.world_map._canvas), "leaving the map tab gives the picture back to the full-screen map")
	_check(_all_text(journal).contains(tr("UI_JOURNAL_NO_NOTES")), "the notes tab says so when there are no notes")
	player.notes.add("test_note", "UI_JOURNAL", "UI_JOURNAL_NO_MAP")
	journal.select_tab(Journal.TAB_NOTES)
	_check(not _all_text(journal).contains(tr("UI_JOURNAL_NO_NOTES")) and _all_text(journal).contains(tr("UI_JOURNAL_NO_MAP")), "a found note shows on the notes tab")
	player.notes.load_data([])
	var map_press := InputEventAction.new()
	map_press.action = "map"
	map_press.pressed = true
	journal._input(map_press)
	_check(journal.current_tab() == Journal.TAB_MAP and journal.is_open(), "the map key shows the map tab while the journal is open")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	journal._input(cancel)
	_check(not journal.is_open() and not player.is_busy() and not scene.get_tree().paused, "cancel closes the journal and resumes the game")
	player.set_busy(true)
	_check(not journal.can_open.call(), "the journal doesn't open over a menu")
	player.set_busy(false)
	TranslationServer.set_locale("de")
	_check(tr("UI_JOURNAL") == "Tagebuch" and tr("UI_JOURNAL_QUESTS") == "Aufgaben" and tr("ACTION_JOURNAL") == "Tagebuch", "the journal is translated to German")
	TranslationServer.set_locale("en")


func _all_text(node: Node) -> String:
	var text := ""
	if node is Label or node is Button:
		text += node.text + "\n"
	for child in node.get_children():
		text += _all_text(child)
	return text


func _close_color(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.03


func _has_key(action: String, keycode: Key) -> bool:
	for input in InputMap.action_get_events(action):
		if input is InputEventKey and input.physical_keycode == keycode:
			return true
	return false


func _has_joypad_button(action: String) -> bool:
	return InputMap.action_get_events(action).any(func(input: InputEvent) -> bool: return input is InputEventJoypadButton)


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
	_test_input_device_prompts(scene)
	_test_input_glyphs(scene)
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
		# The model file itself, before data/prop_tuning.json, whose lifts are deliberate, such as a haystack set into the ground.
		_check(absf(meshes[0].get_aabb().position.y) < PROP_GROUND_TOLERANCE, file + " stands on the ground")
		prop.free()
	_check(count == 59, "all generated props are present")
	var tuner: Node = load("res://tools/prop_tuner/prop_tuner.tscn").instantiate()
	_check(tuner != null, "the prop tuner scene loads")
	tuner.free()
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/village_layout.json"))
	_check((layout["props"] as Array).size() == 57, "57 generated props are placed, and the anvil, furnace, and bed are separate")


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
	_test_mod_loader()


func _test_mod_loader() -> void:
	var dir := "user://smoke_test_mods"
	DirAccess.make_dir_recursive_absolute(dir.path_join("first"))
	DirAccess.make_dir_recursive_absolute(dir.path_join("second"))
	DirAccess.make_dir_recursive_absolute(dir.path_join("empty"))
	_check(ModLoader.flag_files(dir).is_empty(), "no load order means no mods")
	_write_flags(dir.path_join("first/feature_flags.json"), { "values": { "torch_burn_seconds": 5 } })
	_write_flags(dir.path_join("second/feature_flags.json"), { "values": { "torch_burn_seconds": 9 } })
	_write_flags(dir.path_join(ModLoader.LOAD_ORDER_FILE), { "mods": ["first", "second"] })
	var files := ModLoader.flag_files(dir)
	_check(files.size() == 2 and files[0].contains("first") and files[1].contains("second"), "mods come back in load order")
	FeatureFlags.load_layers(files)
	_check(FeatureFlags.value("torch_burn_seconds") == 9, "the last listed mod wins")
	_write_flags(dir.path_join(ModLoader.LOAD_ORDER_FILE), { "mods": ["second", "first"] })
	FeatureFlags.load_layers(ModLoader.flag_files(dir))
	_check(FeatureFlags.value("torch_burn_seconds") == 5, "reordering the list reorders the mods")
	_write_flags(dir.path_join(ModLoader.LOAD_ORDER_FILE), { "mods": ["../escape", "/abs", ".hidden", "a\\b", "empty", "missing", "first", "first"] })
	_check(ModLoader.flag_files(dir).size() == 1, "unsafe, missing, empty, and repeated mods are skipped")
	_check(ModLoader.is_safe_name("my_mod") and not ModLoader.is_safe_name("") and not ModLoader.is_safe_name(3), "mod names must be plain folder names")
	FeatureFlags.load_layers()
	for sub in ["first", "second", "empty"]:
		DirAccess.remove_absolute(dir.path_join(sub).path_join("feature_flags.json"))
		DirAccess.remove_absolute(dir.path_join(sub))
	DirAccess.remove_absolute(dir.path_join(ModLoader.LOAD_ORDER_FILE))
	DirAccess.remove_absolute(dir)


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


func _test_cooking(scene: Node, player: Player, ui: CraftingUI) -> void:
	var village: Village = scene.get_node("Village")
	var campfire := village.get_node_or_null("campfire") as CraftingStation
	_check(campfire != null and campfire.station_id == "campfire", "the village has a campfire station")
	_check(campfire.find_children("*", "CampfireFire", true, false).size() == 1, "the campfire has a flame")
	_check(CraftingData.skill_ids().has("cooking") and CraftingData.skill_name("cooking") != "SKILL_COOKING", "cooking is a skill with a name")
	_check(CraftingData.heal_amount("cooked_meat") > CraftingData.heal_amount("meat"), "cooked meat heals more than raw meat")
	player.inventory.add("meat", 2)
	player.inventory.add("berries", 5)
	player.inventory.add("healing_herb")
	var xp_before: int = player.skill_xp.get("cooking", 0)
	ui.open_station("campfire", "Campfire", player)
	ui.add_material("meat")
	ui.craft()
	_check(player.inventory.count("cooked_meat") == 1 and player.inventory.count("meat") == 1, "meat is cooked at the campfire")
	ui.add_material("berries")
	ui.add_material("berries")
	ui.add_material("berries")
	ui.craft()
	_check(player.inventory.count("berry_compote") == 1, "three berries make a compote")
	ui.add_material("meat")
	ui.add_material("berries")
	ui.add_material("berries")
	ui.add_material("healing_herb")
	ui.craft()
	_check(player.inventory.count("hearty_stew") == 1, "meat, berries, and a herb make a stew")
	_check(player.skill_xp.get("cooking", 0) > xp_before, "cooking gives practice")
	ui.close()
	player.health.damage(80.0)
	ui.open_inventory(player)
	ui.use_item("hearty_stew")
	_check(is_equal_approx(player.health.current, 80.0), "a stew heals")
	ui.close()
	player.health.restore()
	for item_id in ["cooked_meat", "berry_compote"]:
		player.inventory.remove(item_id)
	player.inventory.remove("berries", player.inventory.count("berries"))
	_write_flags(TEST_FLAGS_A, { "flags": { "cooking": false } })
	FeatureFlags.load_layers([TEST_FLAGS_A])
	_check(CraftingData.recipes_for("campfire").is_empty(), "cooking can be switched off")
	FeatureFlags.load_layers()
	DirAccess.remove_absolute(TEST_FLAGS_A)


func _test_healing(player: Player, ui: CraftingUI) -> void:
	player.inventory.add("healing_herb", 2)
	ui.open_station("furnace", "Furnace", player)
	ui.add_material("healing_herb")
	ui.add_material("healing_herb")
	ui.craft()
	_check(player.inventory.count("healing_potion") == 1 and player.inventory.count("healing_herb") == 0, "two herbs brew a healing potion")
	ui.close()

	player.inventory.add("berries")
	ui.open_inventory(player)
	_check(ui._use_row.get_child_count() == 2, "the inventory offers a button for each usable item")
	ui.use_item("healing_potion")
	_check(player.inventory.count("healing_potion") == 1, "a healing item isn't used up at full health")
	player.health.damage(80.0)
	ui.use_item("healing_potion")
	_check(is_equal_approx(player.health.current, 70.0) and player.inventory.count("healing_potion") == 0, "a healing potion heals and is used up")
	ui.use_item("berries")
	_check(is_equal_approx(player.health.current, 85.0) and player.inventory.count("berries") == 0, "berries heal when eaten")
	ui.use_item("berries")
	_check(is_equal_approx(player.health.current, 85.0), "an item that isn't carried does nothing")
	_check(ui._use_row.get_child_count() == 0, "used-up items lose their button")
	player.inventory.add("iron_ore")
	_check(not Healing.use_item(player, "iron_ore"), "an item without a use action can't be used")
	ui.close()

	FeatureFlags.load_layers()
	player.health.restore()
	player.health.damage(50.0)
	var before := player.health.current
	player._since_hit = 1000.0
	player._update_combat(1.0)
	_check(player.health.current > before, "health regenerates out of combat")
	player.health.damage(1.0)
	player._since_hit = 0.0
	before = player.health.current
	player._update_combat(1.0)
	_check(is_equal_approx(player.health.current, before), "health doesn't regenerate right after a hit")
	_write_flags(TEST_FLAGS_A, { "flags": { "health_regen": false, "healing_items": false } })
	FeatureFlags.load_layers([TEST_FLAGS_A])
	player._since_hit = 1000.0
	player._update_combat(1.0)
	_check(is_equal_approx(player.health.current, before), "regeneration can be switched off")
	player.inventory.add("berries")
	_check(not Healing.use_item(player, "berries"), "healing items can be switched off")
	FeatureFlags.load_layers()
	DirAccess.remove_absolute(TEST_FLAGS_A)
	player.inventory.remove("berries")
	player.inventory.remove("iron_ore")
	player.health.restore()


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
	_test_healing(player, ui)
	_test_cooking(scene, player, ui)

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

	_check(player.skill_xp.get("smithing", 0) > 0, "crafting gives practice")
	var skilled := HammerGame.new(3, 1.0, 0.03, 0.06)
	var plain := HammerGame.new(3, 1.0)
	_check(skilled.target_width > plain.target_width and skilled.speed < plain.speed, "skill widens the target and slows the marker")
	_check(CraftingData.skill_level("smithing", 0) == 1 and CraftingData.skill_level("smithing", 10) == 2, "practice raises the skill level")
	_check(CraftingData.skill_level("smithing", 100000) == CraftingData.skill_max_level("smithing"), "skill level stops at the highest")
	player.skill_xp.clear()
	_check(player.practice("smithing", 10) == 2 and player.practice("smithing", 1) == 0, "practice reports a rise only once")
	player.skill_xp.clear()
	var skill_of := func(recipe_id: String) -> String:
		for recipe: Dictionary in CraftingData.recipes_for("furnace") + CraftingData.recipes_for("anvil"):
			if recipe["id"] == recipe_id:
				return recipe.get("skill", "")
		return ""
	_check(skill_of.call("brew_healing_potion") == "alchemy" and skill_of.call("make_short_bow") == "carpentry" and skill_of.call("make_long_bow") == "carpentry" and skill_of.call("make_arrows") == "carpentry" and skill_of.call("make_torch") == "carpentry", "potions use alchemy and bows, arrows and torches carpentry")
	_check(skill_of.call("forge_sword") == "smithing" and skill_of.call("smelt_iron") == "smithing", "metal work stays smithing")
	TranslationServer.set_locale("de")
	_check(CraftingData.skill_name("alchemy") == "Alchemie" and CraftingData.skill_name("carpentry") == "Tischlerei", "the new skills have German names")
	TranslationServer.set_locale("en")
	_check(CraftingData.skill_name("carpentry") == "Carpentry", "the new skills have English names")
	_check(player.practice("carpentry", 10) == 2 and player.skill_xp.get("smithing", 0) == 0, "each skill is practised on its own")
	player.skill_xp.clear()
	var clumsy := HammerGame.new(2, 1.0)
	clumsy.marker = clamp(clumsy.target + 0.5, 0.0, 1.0) if clumsy.target < 0.5 else clumsy.target - 0.5
	clumsy.strike()
	_check(CraftingData.quality_for_score(clumsy.score()) == "crude", "bad forging gives crude quality")
	_check(CraftingData.find_recipe("anvil", {"coal": 1}).is_empty(), "unknown combinations match nothing")
	_check(CraftingData.item_name("iron_sword") != "ITEM_IRON_SWORD", "item names are translated")


func _test_crafting_parts(scene: Node, player: Player) -> void:
	var ui: CraftingUI = scene.get_node("CraftingUI")
	_check(CraftingData.part_slots("iron_sword") == ["grip", "blade"] and CraftingData.part_slots("iron_nails").is_empty(), "weapons have parts to choose and nails do not")
	_check(CraftingData.variant_key("iron_sword", {}) == "" and CraftingData.variant_key("iron_sword", {"blade": "straight", "grip": "oak"}) == "", "default parts add nothing to the item")
	_check(CraftingData.variant_key("iron_sword", {"grip": "ebony", "blade": "broad", "nonsense": "x"}) == "blade=broad,grip=ebony", "chosen parts are written in a fixed order")
	_check(CraftingData.variant_choices("iron_sword", "blade=gone,grip=ebony,junk") == {"grip": "ebony"}, "unknown parts in a save are ignored")
	_check(is_equal_approx(CraftingData.weapon_damage("iron_sword", "common", "blade=broad"), 22.0), "a broad blade hits harder")
	_check(is_equal_approx(CraftingData.weapon_damage("iron_sword", "common", "grip=ebony"), 20.0), "a grip changes the look only")
	var plain := CraftingData.item_model("iron_sword")
	var custom := CraftingData.item_model("iron_sword", "blade=broad,grip=ebony")
	var plain_blade: MeshInstance3D = plain.get_child(2)
	var custom_blade: MeshInstance3D = custom.get_child(2)
	_check(custom_blade.mesh.size.x > plain_blade.mesh.size.x, "a broad blade is wider")
	_check((custom.get_child(0).mesh.material as StandardMaterial3D).albedo_color != (plain.get_child(0).mesh.material as StandardMaterial3D).albedo_color, "an ebony grip is darker")
	_check(is_equal_approx(CraftingData.item_length("iron_sword"), custom_blade.position.y + custom_blade.mesh.size.y / 2.0), "parts keep the weapon's length")
	plain.free()
	custom.free()

	var inventory := Inventory.new()
	inventory.add("iron_sword", 1, "fine")
	inventory.add("iron_sword", 1, "fine", "blade=broad")
	inventory.add("iron_sword", 1, "fine", "blade=broad")
	_check(inventory.entries().size() == 2 and inventory.count("iron_sword") == 3, "different parts are different stacks")
	_check(inventory.best_weapon()["variant"] == "blade=broad", "the best weapon includes its parts")
	var restored := Inventory.new()
	restored.load_data(inventory.to_data())
	_check(restored.entries() == inventory.entries(), "stacks with parts survive saving")
	restored.load_data({ "iron_sword:fine": 2, "iron_dagger:": 1 })
	_check(restored.count("iron_sword") == 2 and restored.entries()[0]["variant"] == "", "saves from before parts still load")
	_check(restored.remove("iron_sword", 2) and restored.count("iron_sword") == 0, "stacks without parts are removed")
	inventory.remove("iron_sword", 3)
	_check(inventory.entries().is_empty(), "stacks with parts are removed")

	var carried := player.inventory.to_data()
	player.inventory.add("iron_ingot", 6)
	player.inventory.add("wood", 3)
	ui.open_station("anvil", "Anvil", player)
	ui.add_material("iron_ingot")
	ui.add_material("iron_ingot")
	ui.add_material("wood")
	_check(ui._parts.visible and ui._parts.get_child_count() == 4, "the crafting screen offers a choice per part")
	ui.choose_part("blade", "broad")
	ui.choose_part("grip", "bogus")
	ui.craft()
	while ui.is_forging():
		ui._game.marker = ui._game.target
		ui.strike()
	var forged := player.inventory.entries().filter(func(entry): return entry["id"] == "iron_sword")
	_check(forged.size() == 1 and forged[0]["variant"] == "blade=broad" and forged[0]["quality"] == "masterwork", "the chosen parts are kept on the forged weapon")
	_check(ui._inventory_label.text.contains(CraftingData.option_name("broad")), "the inventory names the parts: " + ui._inventory_label.text)
	ui.add_material("iron_ingot")
	ui.add_material("iron_ingot")
	ui.add_material("wood")
	ui.craft()
	ui.abandon_forging()
	ui.add_material("iron_ingot")
	ui.add_material("wood")
	_check(ui._parts.visible and ui._choices.is_empty(), "choices start from the defaults again")
	ui.close()
	player.inventory.load_data({})
	player.inventory.add("iron_sword", 1, "common", "blade=broad")
	player.inventory.add("iron_sword", 1, "common")
	player._update_weapon_model()
	_check(player._weapon.get_children().back().get_child(2).mesh.size.x > 0.06, "the hand holds the weapon with its parts")
	player.inventory.load_data(carried)
	player._update_weapon_model()

	_write_flags(TEST_FLAGS_A, { "flags": { "crafting_parts": false } })
	FeatureFlags.load_layers([TEST_FLAGS_A])
	_check(CraftingData.part_slots("iron_sword").is_empty(), "the flag turns part choices off")
	FeatureFlags.load_layers()


func _test_villager_routines(scene: Node) -> void:
	var village: Village = scene.get_node("Village")
	var routines: VillagerRoutines = village.get_node("VillagerRoutines")
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Village.LAYOUT_PATH))
	var ids := []
	for npc_data: Dictionary in layout["npcs"]:
		ids.append(npc_data["id"])
	var data := VillagerRoutines.load_routines()
	var problems := VillagerRoutines.problems(data, ids)
	_check(problems.is_empty(), "the villager routines are valid: %s" % [problems])
	_check(not VillagerRoutines.problems({ "nobody": [{ "from": 5.0 }, { "from": 4.0, "x": 1.0 }] }, ids).is_empty(), "invalid routines are reported")

	await _test_routine_legs(scene, village, data)

	var stops := [{ "from": 6.0, "id": "a" }, { "from": 18.0, "id": "b" }]
	_check(VillagerRoutines.active_stop(stops, 12.0)["id"] == "a", "a stop lasts until the next begins")
	_check(VillagerRoutines.active_stop(stops, 23.0)["id"] == "b", "the last stop runs on past midnight")
	_check(VillagerRoutines.active_stop(stops, 2.0)["id"] == "b", "and into the early morning")
	_check(VillagerRoutines.active_stop([], 2.0).is_empty(), "no stops, no stop")

	var bertram: Npc = village.get_node("bertram")
	var evening := VillagerRoutines.active_stop(data["bertram"], 19.0)
	var spot := Vector2(evening["x"], evening["z"])
	routines.set_process(false)
	routines.update(9.0)
	routines.update(9.1)
	_check(Vector2(bertram.position.x, bertram.position.z).is_equal_approx(bertram.home), "villagers stand at home by day")
	routines.update(18.4)
	routines.update(18.6)
	_check(bertram.is_processing(), "a villager sets off when their stop changes")
	_check(bertram.activity().is_empty(), "and stops what they were doing")
	# The walk goes by way of the places the stop names.
	var first := VillagerRoutines.route_of(evening)[0]
	var start := Vector2(bertram.position.x, bertram.position.z).distance_to(first)
	for i in 30:
		await process_frame
	_check(Vector2(bertram.position.x, bertram.position.z).distance_to(first) < start, "and walks towards it, by way of the places the stop names")
	_check(absf(bertram.position.y - village.terrain.height_at(bertram.position.x, bertram.position.z)) < 0.01, "following the ground")
	routines.update(6.5)
	_check(not bertram.is_processing() and Vector2(bertram.position.x, bertram.position.z).is_equal_approx(bertram.home), "a jump in time puts villagers straight at their places")
	await _test_routine_activities(village, routines)
	var absent := Npc.new()
	absent.setup({ "id": "absent", "name": "NPC_MAREK", "x": 0.0, "z": 0.0, "color": "#808080", "appears_when": { "flag": "nothing_yet" } })
	absent.apply_flags({})
	routines.add_villager(absent)
	routines._routines["absent"] = [{ "from": 0.0, "x": 5.0, "z": 5.0 }]
	routines.update(9.0)
	_check(not absent.is_processing() and not absent.is_available(), "a villager who has not arrived does not walk")
	routines._routines.erase("absent")
	routines._villagers.erase("absent")
	absent.free()
	routines.set_process(FeatureFlags.enabled("villager_routines"))


## Villagers work, sit and sleep at their stops, and go out of sight indoors (#223).
func _test_routine_activities(village: Village, routines: VillagerRoutines) -> void:
	_check(not VillagerRoutines.problems({ "bertram": [{ "from": 5.0, "activity": "juggle" }] }, ["bertram"]).is_empty(), "an unknown activity is reported")
	for activity: String in Npc.ACTIVITIES:
		for key: String in ["loop", "shot"]:
			var animation: StringName = Npc.ACTIVITIES[activity].get(key, &"")
			_check(animation.is_empty() or CharacterAnimations.library().has_animation(animation), "the %s animation of %s exists" % [animation, activity])
	var bertram: Npc = village.get_node("bertram")
	var greta: Npc = village.get_node("greta")
	routines.update(12.0)
	_check(bertram.activity() == "hammer" and greta.activity() == "sweep", "villagers do their work by day")
	for i in 4:
		bertram.activity_tick(0.5)
	_check(greta.visible and not greta.is_indoors(), "villagers are in sight while they work")
	routines.update(23.0)
	_check(bertram.activity() == "sleep" and is_equal_approx(bertram.get_child(0).rotation.x, PI / 2.0), "villagers lie down to sleep")
	_check(greta.is_indoors() and not greta.visible, "a villager goes out of sight indoors at night")
	await process_frame
	var shapes := greta.get_children().filter(func(c: Node) -> bool: return c is CollisionShape3D)
	_check(shapes.size() == 1 and shapes[0].disabled, "and cannot be bumped into or talked to there")
	routines.update(7.0)
	_check(greta.visible and not greta.is_indoors() and absf(bertram.get_child(0).rotation.x) < 0.01, "they come back out and get up in the morning")


## Every leg of every routine, from one stop's place through the "via" places to the next, has to
## avoid buildings and water (#222).
func _test_routine_legs(_scene: Node, village: Village, data: Dictionary) -> void:
	var walker := CharacterBody3D.new()
	root.add_child(walker)
	# Villagers are solid, so they are put out of the way of the search.
	var villagers: Array[Npc] = []
	for child in village.get_children():
		if child is Npc:
			villagers.append(child)
			child.position.y -= 100.0
	await _physics_frames(2)
	EnemyPath.forget_all()
	var path := EnemyPath.new(walker, Npc.BODY_RADIUS)
	var legs := 0
	var bad := ""
	for id: String in data:
		var stops: Array = data[id]
		var home: Vector2 = village.get_node(id).home
		for i in stops.size():
			var previous: Dictionary = stops[(i + stops.size() - 1) % stops.size()]
			var stop: Dictionary = stops[i]
			var points: Array[Vector2] = [Vector2(previous["x"], previous["z"]) if previous.has("x") else home]
			points.append_array(VillagerRoutines.route_of(stop))
			points.append(Vector2(stop["x"], stop["z"]) if stop.has("x") else home)
			for j in points.size() - 1:
				if points[j].is_equal_approx(points[j + 1]):
					continue
				legs += 1
				var from := Vector3(points[j].x, village.walking_height(points[j].x, points[j].y) + 0.1, points[j].y)
				var to := Vector3(points[j + 1].x, village.walking_height(points[j + 1].x, points[j + 1].y) + 0.1, points[j + 1].y)
				if not path.is_line_clear(from, to):
					bad += " %s %s->%s" % [id, points[j], points[j + 1]]
	for villager in villagers:
		villager.position.y += 100.0
	EnemyPath.forget_all()
	_check(legs > 0, "there are routine legs to check")
	_check(bad.is_empty(), "villagers' walks avoid buildings and water:%s" % bad)
	walker.free()


func _test_story(scene: Node, player: Player) -> void:
	var ui: DialogueUI = scene.get_node("DialogueUI")
	var village: Village = scene.get_node("Village")
	var quests := player.quests

	_check(quests.current_objective("arrival") == "see_grandmother", "the first quest starts on its own")
	_check(quests.tracker_lines(player.inventory).size() == 1, "the tracker shows the active quest")

	var hedda: Npc = village.get_node("hedda")
	var hedda_model: Node3D = hedda.find_child("Model", true, false)
	var hedda_player: AnimationPlayer = hedda_model.get_node("Animations")
	_check(hedda_player.is_playing() and hedda_player.current_animation in ["Idle", "Sitting_Idle"], "a villager with a model plays its idle animation (or sits, by her routine)")
	_check(hedda_model.find_child("GeneralSkeleton", true, false) != null, "the model's skeleton is set up for shared animations")
	var casters := 0
	var shadows_only := 0
	for part: MeshInstance3D in hedda_model.find_children("*", "MeshInstance3D", true, false):
		if part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			casters += part.mesh.get_surface_count()
		elif part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			shadows_only += part.mesh.get_surface_count()
	_check(casters + shadows_only <= 6, "a villager casts its shadow with few draw calls (%d)" % (casters + shadows_only))
	_check(shadows_only == 1, "a villager's body casts its shadow from one surface")
	for villager: String in ["bertram", "mira", "greta", "brandt"]:
		_check(village.get_node(villager).find_child("Model", true, false) != null, "%s has a model" % villager)
	_check(not village.get_node("marek").visible and not village.get_node("marek").is_available(), "the peddler stays away while the roof leaks")
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
	_check(DialogueRunner.new("hedda", player).text_key() == "DLG_HEDDA_SEND_AGAIN", "grandmother repeats where the smith is")

	_talk(ui, "bertram", player, [0, 0, 0])
	_check(quests.is_done("arrival") and quests.current_objective("first_nails") == "make_nails", "the smith gives the nails quest")

	player.inventory.remove("iron_nails", player.inventory.count("iron_nails"))
	_talk(ui, "bertram", player, [0])
	_check(quests.current_objective("first_nails") == "make_nails" and not ui.is_open(), "the smith waits for the nails")
	var reminder := DialogueRunner.new("bertram", player)
	reminder.advance(1)
	_check(reminder.text_key() == "DLG_BERTRAM_ORE", "the smith explains again where the ore is")

	player.inventory.add("iron_nails", 4, "fine")
	var ingots := player.inventory.count("iron_ingot")
	_check(quests.tracker_lines(player.inventory)[0].contains("(4/4)"), "the tracker counts the nails")
	_talk(ui, "bertram", player, [0])
	_check(player.inventory.count("iron_nails") == 0, "the smith takes the nails")
	_check(player.inventory.count("iron_ingot") == ingots + 2, "the smith pays the player")
	_check(quests.current_objective("first_nails") == "tell_mayor", "the smith sends the player to the mayor")
	_check(DialogueRunner.new("hedda", player).text_key() == "DLG_HEDDA_MAYOR", "grandmother has advice about the mayor")

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
	var marek: Npc = village.get_node("marek")
	var oswin: Npc = village.get_node("oswin")
	_check(marek.visible and oswin.visible and marek.is_available(), "the repaired inn brings in the peddler and the old foreman")
	_check(DialogueRunner.new("marek", player).text_key() == "DLG_MAREK_ARRIVE", "the peddler talks about the inn")
	_check(quests.flags.has("mayor_annoyed"), "the player's choice is remembered")
	var cold := DialogueRunner.new("brandt", player)
	_check(cold.text_key() == "DLG_BRANDT_COLD", "the mayor reacts to the choice")
	_check(DialogueRunner.new("hedda", player).text_key() == "DLG_HEDDA_PROUD", "grandmother reacts to the finished quest")
	var topics := DialogueRunner.new("bertram", player)
	topics.advance(0)
	var answered := topics.text_key()
	topics.advance()
	var back_to_topics := topics.text_key()
	topics.advance(topics.choice_keys().size() - 1)
	_check(answered == "DLG_BERTRAM_FORGE" and back_to_topics == "DLG_BERTRAM_MORE" and topics.is_finished(), "villagers answer questions until the player says goodbye")
	cold.advance(1)
	_check(cold.text_key() == "DLG_BRANDT_MINE", "the mayor refuses to talk about the mine")


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

	# Goblins that wait to be spoken to would throw off the fights below, so only the talking test has it on.
	FeatureFlags._flags["enemy_talk"] = false
	await _test_sneaking(scene, player, enemy)
	FeatureFlags._flags["enemy_talk"] = true
	await _test_enemy_talk(scene, player)
	FeatureFlags._flags["enemy_talk"] = false
	await _test_stamina_costs(scene, player)
	await _test_heavy_swing(player)

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


func _test_stamina_costs(scene: Node, player: Player) -> void:
	await _physics_frames(20)
	var bar: ProgressBar = scene.get_node("UI/StaminaBar")
	_check(bar.visible, "the HUD shows a stamina bar")
	var from := player.global_position + Vector3(0.0, 0.0, -5.0)
	player.stamina = Player.MAX_STAMINA
	_check(player.spend_stamina(Player.DODGE_STAMINA_COST) and player.stamina == Player.MAX_STAMINA - Player.DODGE_STAMINA_COST, "spending stamina lowers it")
	_check(not player.spend_stamina(Player.MAX_STAMINA), "stamina can't be spent below zero")
	player._stamina_pause = 0.0
	player._update_stamina(1.0)
	_check(player.stamina > Player.MAX_STAMINA - Player.DODGE_STAMINA_COST, "stamina refills when idle")

	# A dodge needs stamina.
	player._dodge_cooldown = 0.0
	player.stamina = Player.DODGE_STAMINA_COST - 1.0
	player.dodge()
	_check(not player.is_dodging(), "a dodge fails without enough stamina")
	player.stamina = Player.MAX_STAMINA
	player.dodge()
	_check(player.is_dodging() and player.stamina == Player.MAX_STAMINA - Player.DODGE_STAMINA_COST, "a dodge costs stamina")
	player._dodge_time = 0.0
	player._dodge_cooldown = 0.0

	# Blocking a hit costs stamina, and a hit that is too strong breaks the block.
	Input.action_press("block")
	player.stamina = Player.MAX_STAMINA
	player.health.restore()
	player.take_hit(10.0, from)
	_check(player.stamina == Player.MAX_STAMINA - 10.0 * Player.BLOCK_STAMINA_PER_DAMAGE and player.health.current == 100.0 - 10.0 * Player.BLOCK_DAMAGE_FACTOR, "a blocked hit drains stamina")
	player.stamina = 5.0
	player.health.restore()
	player.take_hit(10.0, from)
	_check(player.stamina == 0.0 and not player.is_blocking() and player.health.current == 90.0, "with no stamina left the block breaks and the hit lands in full")
	player._block_broken = 0.0
	Input.action_release("block")

	# Sprinting drains stamina until the player is winded, and walking pace returns.
	Input.action_press("sprint")
	Input.action_press("move_forward")
	player.velocity = Vector3(0.0, 0.0, -Player.SPRINT_SPEED)
	player.stamina = 0.1
	player._stamina_pause = 0.0
	player._update_stamina(0.1)
	_check(player.stamina == 0.0 and not player.is_sprinting(), "running dry stops the sprint")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	player.velocity = Vector3.ZERO
	player._update_stamina(1.0)
	player._stamina_pause = 0.0
	player._update_stamina(1.0)
	_check(player.stamina > Player.SPRINT_RESUME_STAMINA, "stamina comes back after a rest")
	_check(not player._winded, "sprinting works again after a rest")

	# Without the flag nothing costs stamina.
	FeatureFlags._flags["stamina"] = false
	player.stamina = 0.0
	_check(player.spend_stamina(1000.0), "nothing costs stamina when the flag is off")
	player._update_stamina(0.1)
	_check(player.stamina == Player.MAX_STAMINA, "stamina stays full when the flag is off")
	FeatureFlags._flags["stamina"] = true
	player.stamina = Player.MAX_STAMINA
	player.health.restore()


func _test_heavy_swing(player: Player) -> void:
	var notices: Array[String] = []
	var listen := func(key: String): notices.append(key)
	player.notice.connect(listen)
	player._attack_cooldown = 0.0
	player.stamina = Player.MAX_STAMINA
	_check(not HeavySwing.is_charged(HeavySwing.charge_seconds() - 0.1) and HeavySwing.is_charged(HeavySwing.charge_seconds()), "a swing is heavy once the button was held long enough")
	_check(player.attack(true) and player._swing_heavy and player.stamina == Player.MAX_STAMINA - HeavySwing.stamina_cost(), "a heavy swing costs stamina")
	player._attack_cooldown = 0.0
	player._attack_windup = 0.0
	player.stamina = HeavySwing.stamina_cost() - 1.0
	_check(player.attack(true) and not player._swing_heavy and player.stamina == HeavySwing.stamina_cost() - 1.0 and notices == ["UI_TOO_TIRED_HEAVY"], "with too little stamina a heavy swing becomes a normal one")
	player._attack_cooldown = 0.0
	player._attack_windup = 0.0
	player.stamina = Player.MAX_STAMINA
	_check(player.attack() and not player._swing_heavy and player.stamina == Player.MAX_STAMINA, "a normal swing costs no stamina")
	player._attack_cooldown = 0.0
	player._attack_windup = 0.0
	FeatureFlags._flags["stamina"] = false
	player.stamina = 0.0
	_check(player.attack(true) and player._swing_heavy, "a heavy swing is free when the flag for stamina is off")
	FeatureFlags._flags["stamina"] = true
	player._attack_cooldown = 0.0
	player._attack_windup = 0.0
	FeatureFlags._flags["heavy_swing"] = false
	player.stamina = Player.MAX_STAMINA
	_check(player.attack(true) and not player._swing_heavy and player.stamina == Player.MAX_STAMINA, "nothing is heavy when the flag is off")
	FeatureFlags._flags["heavy_swing"] = true
	player._charge = -1.0
	player.notice.disconnect(listen)
	# A heavy swing lands later and recovers slower than a tap, and the charge shows while held.
	player._attack_cooldown = 0.0
	player.stamina = Player.MAX_STAMINA
	player.attack(true)
	_check(player._attack_windup == HeavySwing.windup_seconds() and HeavySwing.windup_seconds() > Player.ATTACK_WINDUP and is_equal_approx(player._attack_cooldown, Player.ATTACK_COOLDOWN * HeavySwing.recovery_factor()), "a heavy swing has a longer windup and recovery than a tap")
	player._attack_cooldown = 0.0
	player._attack_windup = 0.0
	player.attack(false)
	_check(player._attack_windup == Player.ATTACK_WINDUP and player._attack_cooldown == Player.ATTACK_COOLDOWN, "a tap keeps its short windup")
	player._attack_windup = 0.0
	var shown: Array[float] = []
	var watch := func(fraction: float): shown.append(fraction)
	player.charge_changed.connect(watch)
	Input.action_press("attack")
	player._charge = 0.0
	player._update_charge(HeavySwing.pose_delay_seconds() * 0.5)
	_check(shown.is_empty(), "a short press shows no charge")
	player._update_charge(HeavySwing.pose_delay_seconds())
	_check(shown.size() == 1 and shown[0] > 0.0 and shown[0] < 1.0, "a held button shows a growing charge")
	player._update_charge(HeavySwing.charge_seconds())
	_check(shown.back() == 1.0 and player._glow_left > 0.0, "a full charge shows full and flashes the body")
	Input.action_release("attack")
	player._update_charge(0.1)
	_check(shown.back() == -1.0 and player._charge < 0.0, "letting go clears the charge")
	player.charge_changed.disconnect(watch)
	var indicator := ChargeIndicator.new()
	indicator.set_charge(0.5)
	_check(indicator.visible and not indicator.full and is_equal_approx(indicator.fraction, 0.5), "the charge bar shows part of the charge")
	indicator.set_charge(1.0)
	_check(indicator.full, "the charge bar marks a full charge with a shape")
	indicator.set_charge(-1.0)
	_check(not indicator.visible, "the charge bar hides when nothing charges")
	indicator.free()
	player._attack_cooldown = 0.0
	player._attack_windup = 0.0
	player._glow_left = 0.0
	player._body_mesh.set_glow(Color.WHITE, 0.0)
	for key in ["UI_TOO_TIRED_HEAVY"]:
		TranslationServer.set_locale("de")
		var german := tr(key)
		TranslationServer.set_locale("en")
		_check(tr(key) != key and german != key and german != tr(key), "%s has English and German text" % key)
	player._attack_cooldown = 0.0
	player._attack_windup = 0.0
	player._swing_heavy = false
	player.stamina = Player.MAX_STAMINA


func _test_sneaking(scene: Node, player: Player, enemy: Enemy) -> void:
	enemy.revive()
	var normal_range := float(enemy._stats["aggro_range"])
	player.position = enemy.position + Vector3(0.0, 0.3, 8.0)
	# In daylight, in front of the enemy, so only the stance counts here (see _test_noticing_rules).
	var day_night := player.get_tree().get_first_node_in_group(DayNight.GROUP) as DayNight
	day_night.hour = 12.0
	enemy.rotation.y = PI
	Input.action_press("sneak")
	await _physics_frames(5)
	_check(player.is_sneaking(), "holding the sneak key sneaks")
	_check(is_equal_approx(enemy.notice_range(player), normal_range * float(FeatureFlags.value("sneak_notice_factor")) * float(FeatureFlags.value("still_notice_factor"))), "sneaking shortens the range goblins notice at")
	_check(enemy.state == Enemy.State.IDLE, "goblins don't notice a sneaking player at 8 m")
	var sneak_speed := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("sneak")
	await _physics_frames(5)
	_check(not player.is_sneaking() and is_equal_approx(enemy.notice_range(player), normal_range * float(FeatureFlags.value("still_notice_factor"))), "letting go of the key ends sneaking")
	_check(enemy.state != Enemy.State.IDLE, "goblins notice the same player at 8 m when not sneaking")
	_check(sneak_speed <= Player.WALK_SPEED * float(FeatureFlags.value("sneak_speed_factor")) + 0.01, "sneaking is slower than walking")

	# Turned off, the key does nothing.
	FeatureFlags._flags["sneaking"] = false
	Input.action_press("sneak")
	await _physics_frames(2)
	_check(not player.is_sneaking(), "the sneaking flag turns sneaking off")
	Input.action_release("sneak")
	FeatureFlags._flags["sneaking"] = true
	await _test_noticing_rules(scene, player, enemy, day_night)
	# Back to the start of the fight the next checks expect.
	enemy.revive()
	player.health.restore()
	player.position = enemy.position + Vector3(0.0, 0.3, 1.5)
	await _physics_frames(5)


## Goblins that noticed the player from afar wait to be spoken to. The conversation can calm them, or start the fight.
func _test_enemy_talk(scene: Node, player: Player) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Enemy.DATA_PATH))
	_check(data["goblin"].has("talk") and not data["wolf"].has("talk") and not data["goblin_brute"].has("talk"), "only goblins can be talked to")
	var terrain: Terrain = scene.get_node("Terrain")
	var spot := _flat_open_spot(terrain, player)
	var goblin := Enemy.new()
	scene.add_child(goblin)
	goblin.setup("goblin", spot)
	goblin.set_physics_process(false)
	var wolf := Enemy.new()
	scene.add_child(wolf)
	wolf.setup("wolf", spot + Vector3(20.0, 0.0, 0.0))
	wolf.set_physics_process(false)
	_check(wolf.talk == null and goblin.talk != null, "wolves have no way to be talked to")

	var talk := goblin.talk
	goblin.state = Enemy.State.CHASE
	_check(not talk.holds_back(10.0, 0.1) and not talk.is_available(), "a goblin far away keeps coming and can't be spoken to")
	_check(talk.holds_back(3.0, 0.1) and talk.is_available(), "a goblin that comes up to talking range waits and can be spoken to")
	_check(talk.prompt().contains(goblin.tr("ENEMY_GOBLIN")), "the prompt names the goblin")
	_check(not talk.holds_back(3.0, 10.0) and not talk.is_available(), "a goblin stops waiting after its wary time")

	goblin.state = Enemy.State.IDLE
	talk._process(0.1)
	goblin.state = Enemy.State.CHASE
	talk.holds_back(10.0, 0.1)
	FeatureFlags._flags["enemy_talk"] = false
	_check(not talk.holds_back(3.0, 0.1) and not talk.is_available(), "the enemy_talk flag turns talking off")
	FeatureFlags._flags["enemy_talk"] = true

	# The conversation: choices are hidden without their items, and calming stands the goblin down.
	player.inventory.remove("iron_scrap", player.inventory.count("iron_scrap"))
	var runner := DialogueRunner.new("enemy_goblin", player, talk)
	_check(runner.text_key() == "DLG_GOBLIN_HALT" and not runner.choice_keys().has("DLG_GOBLIN_CHOICE_PAY") and runner.choice_keys().has("DLG_GOBLIN_CHOICE_FRIEND") == player.quests.is_done("first_nails"), "paying and the village's friendship are only offered when they apply")
	player.inventory.add("iron_scrap", 2)
	runner = DialogueRunner.new("enemy_goblin", player, talk)
	var pay := runner.choice_keys().find("DLG_GOBLIN_CHOICE_PAY")
	_check(pay >= 0, "paying is offered with two iron scrap")
	runner.advance(pay)
	_check(talk.is_calm() and goblin.state == Enemy.State.IDLE and player.inventory.count("iron_scrap") == 0, "paying calms the goblin and costs the scrap")
	_check(not talk.is_available(), "a calmed goblin is not talked to again")
	# The calm is saved with the game, in an optional key, and old saves load without it (#329).
	var calm_data := goblin.to_data()
	_check(calm_data.has("calm_left") and calm_data["calm_left"] > 0.0, "a calmed goblin saves its remaining calm")
	var calm_before: float = talk.calm_left()
	talk.break_calm()
	goblin.load_data(calm_data)
	_check(talk.is_calm() and absf(talk.calm_left() - calm_before) < 0.5 and goblin.state == Enemy.State.IDLE, "loading restores a goblin's calm")
	var old_save := calm_data.duplicate()
	old_save.erase("calm_left")
	goblin.load_data(old_save)
	_check(goblin.state == Enemy.State.IDLE, "a save without a calm still loads")
	talk.restore_calm(calm_before)
	talk._process(0.0)
	var look_key := Settings.colour_vision
	var look_high := Settings.high_contrast
	_check(talk.cue() == "calm" and talk._cue.visible and talk._cue.text.contains("~") and talk._cue.text.contains(goblin.tr("TALK_CUE_CALM")), "a calmed goblin shows a calm cue with a shape and a word")
	var normal_color: Color = talk._cue.modulate
	Settings.colour_vision = "deuteranopia"
	talk._process(0.0)
	_check(talk._cue.modulate != normal_color, "the cue follows the colour vision mode")
	Settings.colour_vision = "off"
	Settings.high_contrast = true
	talk._process(0.0)
	_check(talk._cue.modulate == Color.WHITE and talk._cue.outline_size > 8, "the cue is plain white with a thick outline in high contrast")
	Settings.colour_vision = look_key
	Settings.high_contrast = look_high
	talk._process(0.0)
	talk.break_calm()
	talk._process(0.0)
	_check(talk.cue() == "" and not talk._cue.visible, "no cue shows once the calm is broken")
	goblin.state = Enemy.State.CHASE
	talk._reset()
	talk.holds_back(10.0, 0.1)
	talk.holds_back(3.0, 0.1)
	talk._process(0.0)
	_check(talk.cue() == "wait" and talk._cue.text.contains("?"), "a goblin waiting to be spoken to shows a cue")
	talk.break_calm()
	talk._reset()
	_check(not talk.is_calm(), "hitting a calmed goblin ends the calm")

	# A bluff that works sometimes: a low roll calms, a high roll starts the fight.
	for won in [true, false]:
		goblin.state = Enemy.State.CHASE
		talk._reset()
		runner = DialogueRunner.new("enemy_goblin", player, talk)
		runner.roll = func() -> float: return 0.0 if won else 0.99
		runner.advance(runner.choice_keys().find("DLG_GOBLIN_CHOICE_BLUFF"))
		if won:
			_check(runner.text_key() == "DLG_GOBLIN_BLUFF_OK" and talk.is_calm(), "a bluff that works calms the goblin")
		else:
			_check(runner.text_key() == "DLG_GOBLIN_BLUFF_FAIL" and not talk.is_calm() and not talk.is_available() and goblin.state == Enemy.State.CHASE, "a bluff that fails starts the fight")
	goblin.queue_free()
	wolf.queue_free()
	await _physics_frames(2)


func _test_enemy_types(scene: Node, player: Player) -> void:
	var terrain := root.get_tree().get_first_node_in_group(Terrain.GROUP) as Terrain
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Enemy.DATA_PATH))
	_check(data.has("wolf") and data.has("goblin_brute"), "a wolf and a goblin brute exist")
	_check(float(data["wolf"]["speed"]) > float(data["goblin"]["speed"]) and float(data["wolf"]["health"]) < float(data["goblin"]["health"]), "wolves are fast and fragile")
	_check(float(data["goblin_brute"]["health"]) > float(data["goblin"]["health"]) and float(data["goblin_brute"]["damage"]) > float(data["goblin"]["damage"]), "goblin brutes are tougher than goblins")
	for type: String in data:
		var enemy: Enemy = null
		for node: Enemy in root.get_tree().get_nodes_in_group(Enemy.GROUP):
			if node.enemy_type == type:
				enemy = node
				break
		_check(enemy != null, "%s spawns in the world" % type)
		if enemy == null:
			continue
		_check(enemy.state == Enemy.State.IDLE and terrain.wading_factor(enemy.position) == 1.0, "%s waits on dry land" % type)
		enemy.take_hit(100000.0)
		_check(enemy.state == Enemy.State.DEAD and not enemy.visible, "%s can be defeated" % type)
		var saved := enemy.to_data()
		enemy.revive()
		enemy.load_data(saved)
		_check(enemy.state == Enemy.State.DEAD, "a defeated %s stays defeated after loading" % type)
		enemy.revive()
		var real_drops: Array = enemy._stats["drops"]
		var forced: Array = []
		for drop: Dictionary in real_drops:
			var always: Dictionary = drop.duplicate()
			always["chance"] = 1.0
			forced.append(always)
		enemy._stats["drops"] = forced
		var before := {}
		for drop: Dictionary in forced:
			before[drop["item"]] = player.inventory.count(drop["item"])
		enemy._give_drops()
		enemy._stats["drops"] = real_drops
		for drop: Dictionary in forced:
			_check(player.inventory.count(drop["item"]) > before[drop["item"]], "%s drops %s" % [type, drop["item"]])
	var wolf: Enemy = null
	for node: Enemy in root.get_tree().get_nodes_in_group(Enemy.GROUP):
		if node.enemy_type == "wolf":
			wolf = node
	_check(wolf._body is BeastModel, "wolves use a built animal model")
	_check(wolf.global_position.distance_to(player.global_position) > float(data["wolf"]["aggro_range"]), "wolves don't start next to the player")


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

	# A wall with a 1.0 m gap, set at several offsets so it lines up differently with the grid. The
	# search itself is checked, since a body pushing at a wall can slip through a gap it never planned for.
	var terrain: Terrain = scene.get_node("Terrain")
	var gaps_found := 0
	var gaps_missed := ""
	for step in 10:
		var offset := step * 0.05
		obstacles = Node3D.new()
		root.add_child(obstacles)
		var gap_at: float = offset + 3.0
		# The site's height is the camp's, so the walls are tall enough for the ground to rise and fall.
		var wall_at := Vector3(site.x, terrain.height_at(site.x, site.z), site.z)
		_add_test_box(obstacles, wall_at + Vector3(gap_at - 0.5 - 30.0, 0.0, 0.0), Vector3(60.0, 40.0, 0.6))
		_add_test_box(obstacles, wall_at + Vector3(gap_at + 0.5 + 30.0, 0.0, 0.0), Vector3(60.0, 40.0, 0.6))
		await _physics_frames(2)
		EnemyPath.forget_all()
		var start := site + Vector3(gap_at + 5.0, 0.0, -5.0)
		start.y = terrain.height_at(start.x, start.z) + 0.1
		var path := EnemyPath.new(enemy, enemy._stats["radius"])
		path.begin(start, site + Vector3(gap_at - 5.0, 0.0, 5.0), 0.5)
		while not path.advance():
			await physics_frame
		if path.reached:
			gaps_found += 1
		else:
			gaps_missed += " %.1f" % offset
		obstacles.free()
	_check(gaps_found == 10, "enemies plan their way through a 1.0 m gap however it lines up with the grid (missed at offsets:%s)" % gaps_missed)

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
	var enemies := _goblins()
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

	# Walking straight at the player, 8 m beside the bridge, it turns to the bridge before the river (#141).
	EnemyPath.forget_all()
	var beside_a: Vector3 = on_ground.call(-11.0, 8.0)
	var beside_b: Vector3 = on_ground.call(11.0, 8.0)
	enemy.revive()
	enemy._home = beside_a
	enemy.position = beside_a
	enemy.state = Enemy.State.CHASE
	player.position = beside_b
	wading = 0
	var nearest := INF
	for i in 1200:
		await physics_frame
		player.position = beside_b
		player.health.restore()
		var at := enemy.global_position
		if terrain.wading_factor(at) < 1.0:
			wading += 1
		if absf((at - bridge.global_position).dot(side)) > 3.0:
			nearest = minf(nearest, terrain.river_clearance(at.x, at.z))
		if enemy.state == Enemy.State.WINDUP:
			break
	_check(enemy.state == Enemy.State.WINDUP and wading == 0 and nearest > 0.5, "enemies turn to a bridge before they reach the river (%d frames wading, %.1f m from the river)" % [wading, nearest])

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


## The camp's three goblins walk side by side at a wall with one 1.2 m gap, and let each other through
## rather than push (#140).
func _test_enemies_make_way(player: Player) -> void:
	var enemies := _goblins()
	var home: Vector3 = enemies[0]._home
	var homes: Array[Vector3] = []
	var site := Vector3(home.x + 12.0, home.y, home.z + 12.0)
	var walls := Node3D.new()
	root.add_child(walls)
	_add_test_box(walls, site + Vector3(-7.8, 0.0, 0.0), Vector3(14.4, 6.0, 0.4))
	_add_test_box(walls, site + Vector3(7.8, 0.0, 0.0), Vector3(14.4, 6.0, 0.4))
	await _physics_frames(2)
	EnemyPath.forget_all()
	for i in enemies.size():
		var enemy: Enemy = enemies[i]
		homes.append(enemy._home)
		enemy.revive()
		enemy._home = site + Vector3((i - 1) * 1.2, 0.5, -4.5 if i == 1 else -4.0)
		enemy.position = enemy._home
		enemy.state = Enemy.State.CHASE
	var goal := site + Vector3(0.0, 0.5, 6.0)
	player.health.restore()
	player.position = goal
	var touching := 0
	var arrived := {}
	for i in 600:
		await physics_frame
		player.position = goal
		player.health.restore()
		for enemy: Enemy in enemies:
			if enemy.state != Enemy.State.CHASE:
				arrived[enemy] = true
			for c in enemy.get_slide_collision_count():
				var other := enemy.get_slide_collision(c).get_collider() as Enemy
				if other != null and other._moving and enemy._moving:
					touching += 1
					break
		if arrived.size() == enemies.size():
			break
	_check(arrived.size() == enemies.size() and touching <= 10, "goblins let each other through a gap (%d of %d through, %d frames touching)" % [arrived.size(), enemies.size(), touching])
	walls.free()
	for i in enemies.size():
		enemies[i]._home = homes[i]
		enemies[i].revive()
	EnemyPath.forget_all()
	await _physics_frames(1)

## The camp's three goblins walk one behind the other through a 16 m long corridor, 1.2 m wide, toward
## a player 2 m past its far end. The first attacks from the end, and the others take the way around
## the outside of the walls, about 20 m longer (#149).
func _test_enemies_go_around_a_corridor(player: Player) -> void:
	var enemies := _goblins()
	var home: Vector3 = enemies[0]._home
	var homes: Array[Vector3] = []
	var site := Vector3(home.x + 12.0, home.y, home.z + 12.0)
	var walls := Node3D.new()
	root.add_child(walls)
	_add_test_box(walls, site + Vector3(-0.8, 0.0, 0.0), Vector3(0.4, 6.0, 16.0))
	_add_test_box(walls, site + Vector3(0.8, 0.0, 0.0), Vector3(0.4, 6.0, 16.0))
	await _physics_frames(2)
	EnemyPath.forget_all()
	for i in enemies.size():
		var enemy: Enemy = enemies[i]
		homes.append(enemy._home)
		enemy.revive()
		enemy._home = site + Vector3(0.0, 0.5, -7.0 - i * 1.5)
		enemy.position = enemy._home
		enemy.state = Enemy.State.CHASE
	var goal := site + Vector3(0.0, 0.5, 10.0)
	player.health.restore()
	player.position = goal
	var arrived := {}
	for i in 2400:
		await physics_frame
		player.position = goal
		player.health.restore()
		for enemy: Enemy in enemies:
			if enemy.state != Enemy.State.CHASE:
				arrived[enemy] = true
		if arrived.size() == enemies.size():
			break
	_check(arrived.size() == enemies.size(), "goblins behind one attacking at a corridor's end go around the long way (%d of %d reached the player)" % [arrived.size(), enemies.size()])
	walls.free()
	for i in enemies.size():
		enemies[i]._home = homes[i]
		enemies[i].revive()
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


## The buried mine (#249): a blocked entrance on level ground, reachable from the road by walking and by enemy paths.
func _test_buried_mine(scene: Node, player: Player) -> void:
	var terrain: Terrain = scene.get_node("Terrain")
	var village: Village = scene.get_node("Village")
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Village.LAYOUT_PATH))
	var data: Dictionary = layout["mine"]
	var mine: Mine = village.get_node_or_null(data["id"])
	_check(mine != null and mine.get_node("Collision").get_child_count() > 10, "the buried mine stands at its place in the layout, with collision")
	# The cliff is a sculpted face (#307): irregular and low in triangles, not a few boxes.
	var cliff_mesh: ArrayMesh = (mine.get_node("Look/Mesh") as MeshInstance3D).mesh
	var cliff_triangles := 0
	for surface in cliff_mesh.get_surface_count():
		cliff_triangles += (cliff_mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_check(cliff_triangles > 1500 and cliff_triangles < 8000, "the mine's cliff is a sculpted face with few triangles (%d)" % cliff_triangles)
	var at := Vector2(data["x"], data["z"])
	_check(village.marker_position(data["id"]).distance_to(at) < 0.1 and village.landmark_positions() == [at], "the mine is a quest marker and a compass landmark")
	var steepest := 0.0
	for i in 16:
		for distance in range(0, int(data["plaza_radius"]) + 1, 3):
			var point := at + Vector2.from_angle(TAU * i / 16.0) * distance
			steepest = maxf(steepest, _slope_degrees(terrain, point.x, point.y))
	_check(steepest < 12.0, "the ground before the mine is level (steepest %.1f degrees)" % steepest)
	var trail: TerrainPath = terrain.roads[1]
	var trail_steepest := 0.0
	for point in trail.positions:
		trail_steepest = maxf(trail_steepest, _slope_degrees(terrain, point.x, point.y))
	_check(trail_steepest < 20.0 and trail.positions[trail.positions.size() - 1].distance_to(at) < float(data["plaza_radius"]), "a gentle trail leads from the road to the mine (steepest %.1f degrees)" % trail_steepest)
	_check(Compass.bearing_between(Vector2(0.0, 0.0), at) < 30.0 or Compass.bearing_between(Vector2(0.0, 0.0), at) > 330.0, "the mine lies to the north of the village")

	# The rubble blocks the opening: a player walking at it from the front stops outside the tunnel.
	var saved_position := player.position
	var front := mine.front_point()
	var stopped := 0
	for across: float in [-1.2, 0.0, 1.2]:
		var from: Vector3 = mine.global_transform * Vector3(across, 0.0, 6.0)
		from.y = terrain.height_at(from.x, from.z) + 0.1
		var motion: Vector3 = mine.global_basis * Vector3(0.0, 0.0, -9.0)
		var result := PhysicsTestMotionResult3D.new()
		var hit := PhysicsServer3D.body_test_motion(player.get_rid(), _motion_params(Transform3D(player.global_basis, from), motion), result)
		if hit and mine.to_local(from + result.get_travel()).z > 0.0 and result.get_travel().length() < 8.0:
			stopped += 1
	_check(stopped == 3, "rubble blocks the mine's opening (%d of 3 walks stopped)" % stopped)

	# Enemies plan a way from the start of the trail to the mine's front.
	var enemy: Enemy = root.get_tree().get_first_node_in_group(Enemy.GROUP)
	var home := enemy._home
	var others: Array[Enemy] = []
	for other: Enemy in root.get_tree().get_nodes_in_group(Enemy.GROUP):
		if other != enemy:
			others.append(other)
			other.process_mode = Node.PROCESS_MODE_DISABLED
			other.position.y -= 100.0
	var start := Vector3(12.0, terrain.height_at(12.0, -165.0) + 0.3, -165.0)
	var goal := Vector3(front.x, terrain.height_at(front.x, front.z) + 0.3, front.z)
	EnemyPath.forget_all()
	enemy.position = start
	await physics_frame
	var path := EnemyPath.new(enemy, enemy._stats["radius"])
	path.begin(start, goal, 0.5)
	while not path.advance():
		await physics_frame
	_check(path.reached, "enemies can find their way from the road to the mine's front")
	EnemyPath.forget_all()
	enemy._home = home
	enemy.revive()
	for other in others:
		other.process_mode = Node.PROCESS_MODE_INHERIT
		other.revive()
	player.position = saved_position
	await _physics_frames(10)


## The stone walls and the fort's palisade (#209): placed on gentle ground clear of roads and everything
## people use, solid, open at their gates, and cheap to draw.
func _test_walls(scene: Node, player: Player) -> void:
	var terrain: Terrain = scene.get_node("Terrain")
	var village: Village = scene.get_node("Village")
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Village.LAYOUT_PATH))
	var walls: Array = layout["walls"]
	var holder: Node = village.get_node("Walls")
	_check(walls.size() >= 5 and holder.get_child_count() == walls.size(), "every wall in the layout is built (%d)" % holder.get_child_count())
	var kinds := {}
	var surfaces := 0
	var bodies := 0
	for line in holder.get_children():
		var meshes := line.find_children("*", "MeshInstance3D", true, false)
		_check(meshes.size() == 1, "%s joins into one mesh" % line.name)
		surfaces += (meshes[0] as MeshInstance3D).mesh.get_surface_count()
		bodies += line.find_children("*", "CollisionShape3D", true, false).size()
	for wall: Dictionary in walls:
		kinds[wall["kind"]] = true
	_check(kinds.has("palisade") and kinds.has("stone_wall"), "both a palisade and stone walls are placed")
	_check(surfaces <= walls.size() * 8 and bodies > 20, "walls cost few draw calls (%d surfaces) and each piece is solid (%d)" % [surfaces, bodies])

	# Every sample along a wall stands on gentle ground, clear of roads, the river, buildings, and places people go.
	var places: Array[Vector2] = []
	for list in ["buildings", "npcs", "enemies", "repair_sites", "beds", "stations", "resources"]:
		for spot: Dictionary in layout[list]:
			places.append(Vector2(spot["x"], spot["z"]))
	var mine := Vector2(layout["mine"]["x"], layout["mine"]["z"])
	var problems := PackedStringArray()
	var steepest := 0.0
	for index in walls.size():
		var points: Array = walls[index]["points"]
		for j in points.size() - 1:
			var from := Vector2(points[j][0], points[j][1])
			var to := Vector2(points[j + 1][0], points[j + 1][1])
			for step in ceili(from.distance_to(to) / 0.5) + 1:
				var at := from.lerp(to, minf(1.0, step * 0.5 / from.distance_to(to)))
				steepest = maxf(steepest, _slope_degrees(terrain, at.x, at.y))
				if terrain.river_clearance(at.x, at.y) < 3.0 or at.distance_to(mine) < 20.0:
					problems.append("walls[%d] near the river or the mine at %s" % [index, at])
				for road in terrain.roads:
					var found: Vector3 = road.nearest(at.x, at.y)
					if found.x < found.z + 2.0:
						problems.append("walls[%d] on a road at %s" % [index, at])
				for place in places:
					if at.distance_to(place) < 6.0:
						problems.append("walls[%d] too close to %s" % [index, place])
	_check(steepest < 15.0, "walls stand on gentle ground (steepest %.1f degrees)" % steepest)
	_check(problems.is_empty(), "walls keep clear of roads, the river, and places: %s" % [problems.slice(0, 4)])

	# The palisade rings the wooden fort's flat top and leaves a gate wide enough for a cart on the village side.
	var fort: Dictionary
	for site: Dictionary in terrain.building_sites:
		if site["id"] == "wooden_fort":
			fort = site
	var center := Vector2(fort["x"], fort["z"])
	var ring: Array = walls.filter(func(wall: Dictionary) -> bool: return wall["kind"] == "palisade")[0]["points"]
	var ring_inside := true
	for point: Array in ring:
		ring_inside = ring_inside and Vector2(point[0], point[1]).distance_to(center) < float(fort["radius"])
	_check(ring_inside, "the palisade stands on the fort's flat top")
	var first := Vector2(ring[0][0], ring[0][1])
	var last := Vector2(ring[ring.size() - 1][0], ring[ring.size() - 1][1])
	var gate_dir := ((first + last) / 2.0 - center).normalized()
	_check(first.distance_to(last) >= 2.5 and gate_dir.dot((Vector2.ZERO - center).normalized()) > 0.9, "the palisade's gate is at least 2.5 m wide and faces the village (%.1f m)" % first.distance_to(last))
	# The gaps between stone walls of one field are gates too.
	var stone: Array = walls.filter(func(wall: Dictionary) -> bool: return wall["kind"] == "stone_wall")
	var gates := 0
	for a: Dictionary in stone:
		for b: Dictionary in stone:
			var end := Vector2(a["points"][a["points"].size() - 1][0], a["points"][a["points"].size() - 1][1])
			var begin := Vector2(b["points"][0][0], b["points"][0][1])
			if a != b and end.distance_to(begin) < 6.0:
				gates += 1
				_check(end.distance_to(begin) >= 2.2, "a stone wall's gate is wide enough to walk through (%.1f m)" % end.distance_to(begin))
	_check(gates >= 2, "field walls leave gates (%d)" % gates)

	# Solid in play: walking at the palisade stops short, walking through the gate does not.
	var saved_position := player.position
	var gate := (first + last) / 2.0
	var out_dir := gate_dir
	var wall_mid := Vector2(ring[4][0], ring[4][1]).lerp(Vector2(ring[5][0], ring[5][1]), 0.5)
	var wall_out := (wall_mid - center).normalized()
	var stops := [0, 0]
	var trials := [[wall_mid, wall_out], [gate, out_dir]]
	for i in 2:
		var edge: Vector2 = trials[i][0]
		var outward: Vector2 = trials[i][1]
		# From inside the fort outward, so the climb up the mound's slope can't be what stops the walk.
		var from := edge - outward * 3.0
		var from3 := Vector3(from.x, terrain.height_at(from.x, from.y) + 0.1, from.y)
		var motion := Vector3(outward.x, 0.0, outward.y) * 6.0
		var result := PhysicsTestMotionResult3D.new()
		var hit := PhysicsServer3D.body_test_motion(player.get_rid(), _motion_params(Transform3D(player.global_basis, from3), motion), result)
		stops[i] = 1 if hit and result.get_travel().length() < 5.0 else 0
	_check(stops[0] == 1, "the palisade stops a player walking at it")
	_check(stops[1] == 0, "a player walks through the palisade's gate")
	player.position = saved_position
	await _physics_frames(5)


func _motion_params(from: Transform3D, motion: Vector3) -> PhysicsTestMotionParameters3D:
	var params := PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	return params


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
	player.skill_xp["smithing"] = 27
	player.skill_xp["alchemy"] = 9
	player.skill_xp["carpentry"] = 12
	scene.save_game()
	player.set_torch_lit(true)
	player.torch_burned_seconds = 12.0
	scene.save_game()

	# Quest changes autosave, which would overwrite the save this test wants to restore.
	scene._playing = false
	player.position += Vector3(5.0, 0.0, 5.0)
	player.inventory.add("coal", 7)
	player.known_recipes.clear()
	player.skill_xp.clear()
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
	_check(player.skill_xp.get("smithing", 0) == 27, "skill practice is restored")
	_check(player.skill_xp.get("alchemy", 0) == 9 and player.skill_xp.get("carpentry", 0) == 12, "alchemy and carpentry practice are restored")
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

	# Discovered map places are saved, and saves without them load with nothing discovered.
	var map_controller: MapController = scene.get_node("MapController")
	var map_data := map_controller.data
	map_controller.finish_now()
	map_data.load_discovered(["forge"])
	SaveGame.write(TEST_SAVE, player, day_night, village, map_data)
	map_data.load_discovered([])
	_check(SaveGame.apply(TEST_SAVE, player, day_night, village, map_data), "a save with discovered places loads")
	_check(map_data.discovered_ids() == ["forge"], "discovered places are restored")
	_check(map_data.places.any(func(place: Dictionary) -> bool: return place["id"] == "forge" and place["discovered"]), "a restored place shows as discovered")
	_check(map_data.discovered_count() == 1, "places not in the save stay undiscovered")
	var fresh_map := MapData.new()
	fresh_map.load_discovered(["forge", 5, "gone"])
	_check(fresh_map.discovered_ids() == ["forge", "gone"], "discovered places load before the map is drawn, ignoring bad entries")
	var no_places: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	no_places.erase("discovered_places")
	FileAccess.open(TEST_SAVE, FileAccess.WRITE).store_string(JSON.stringify(no_places))
	_check(SaveGame.apply(TEST_SAVE, player, day_night, village, map_data), "saves without discovered places still load")
	_check(map_data.discovered_count() == 0, "older saves start with nothing discovered")
	scene._playing = true

	DirAccess.remove_absolute(TEST_SAVE + SaveGame.BACKUP_SUFFIX)
	var damaged := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	damaged.store_string("{ not json")
	damaged.close()
	_check(not SaveGame.exists(TEST_SAVE), "a damaged save is ignored")
	_check(SaveGame.is_damaged(TEST_SAVE) and not SaveGame.has_backup(TEST_SAVE), "a damaged save without a backup is reported")
	_check(not SaveGame.apply(TEST_SAVE, player, day_night, village), "a damaged save doesn't load")

	# A checked-in version 1 save is upgraded when loaded.
	var fixture := FileAccess.get_file_as_string("res://tests/fixtures/save_v1.json")
	var old_file := FileAccess.open(TEST_OLD_SAVE, FileAccess.WRITE)
	old_file.store_string(fixture)
	old_file.close()
	_check(SaveGame.exists(TEST_OLD_SAVE) and not SaveGame.is_too_new(TEST_OLD_SAVE), "an old-format save counts as a save")
	_check(SaveGame.apply(TEST_OLD_SAVE, player, day_night, village), "an old-format fixture save loads")
	_check(is_equal_approx(player.health.current, 42.0) and player.inventory.count("coal") == 3, "the old-format fixture's contents are restored")
	_check(is_equal_approx(day_night.hour, 9.5), "the old-format fixture's time is restored")
	# A save from a newer build is reported, not loaded or lost.
	var new_data: Dictionary = JSON.parse_string(fixture)
	new_data["version"] = SaveGame.VERSION + 1
	var new_file := FileAccess.open(TEST_OLD_SAVE, FileAccess.WRITE)
	new_file.store_string(JSON.stringify(new_data))
	new_file.close()
	_check(SaveGame.is_too_new(TEST_OLD_SAVE) and not SaveGame.exists(TEST_OLD_SAVE), "a newer save is reported and not loaded")
	_check(not SaveGame.apply(TEST_OLD_SAVE, player, day_night, village), "a newer save doesn't load")
	menu.slot_paths = [TEST_OLD_SAVE, TEST_SLOT_2, TEST_SLOT_3]
	menu._open_load_slots()
	_check((menu._buttons.get_child(0) as Button).text.contains(tr("UI_SLOT_TOO_NEW")), "the load menu says a save is from a newer version")
	DirAccess.remove_absolute(TEST_OLD_SAVE)

	# Saving twice keeps the first save as the backup and leaves no temporary file.
	player.health.current = 77.0
	SaveGame.write(TEST_SAVE, player, day_night, village)
	player.health.current = 66.0
	SaveGame.write(TEST_SAVE, player, day_night, village)
	_check(not FileAccess.file_exists(TEST_SAVE + SaveGame.TEMP_SUFFIX), "saving leaves no temporary file")
	_check(SaveGame.has_backup(TEST_SAVE), "saving keeps the previous save as a backup")
	# A truncated slot is reported and the backup is loaded and restored.
	var good_text := FileAccess.get_file_as_string(TEST_SAVE)
	var truncated := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	truncated.store_string(good_text.left(good_text.length() / 2))
	truncated.close()
	_check(SaveGame.is_damaged(TEST_SAVE) and SaveGame.exists(TEST_SAVE), "a truncated save is reported and its backup offered")
	_check(SaveGame.apply(TEST_SAVE, player, day_night, village), "a truncated save loads its backup")
	_check(is_equal_approx(player.health.current, 77.0), "the backup holds the previous save")
	_check(not SaveGame.is_damaged(TEST_SAVE), "loading the backup repairs the slot")
	# A damaged slot never replaces a good backup.
	var garbage := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	garbage.store_string("{")
	garbage.close()
	SaveGame.write(TEST_SAVE, player, day_night, village)
	_check(SaveGame.has_backup(TEST_SAVE) and not SaveGame.is_damaged(TEST_SAVE), "a damaged save doesn't overwrite the backup")
	# The load menu says so.
	var broken := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	broken.store_string("{")
	broken.close()
	menu.slot_paths = [TEST_SAVE, TEST_SLOT_2, TEST_SLOT_3]
	menu._open_load_slots()
	_check((menu._buttons.get_child(0) as Button).text.contains(tr("UI_SLOT_DAMAGED_BACKUP")), "the load menu shows a damaged slot")
	_check(not (menu._buttons.get_child(0) as Button).disabled, "a damaged slot with a backup can be loaded")
	SaveGame.write(TEST_SAVE, player, day_night, village)

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
	DirAccess.remove_absolute(TEST_SLOT_2 + SaveGame.BACKUP_SUFFIX)
	DirAccess.remove_absolute(TEST_SLOT_3)
	DirAccess.remove_absolute(TEST_SLOT_3 + SaveGame.BACKUP_SUFFIX)
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
	DirAccess.remove_absolute(TEST_SAVE + SaveGame.BACKUP_SUFFIX)
	DirAccess.remove_absolute(TEST_SLOT_2)
	DirAccess.remove_absolute(TEST_SLOT_2 + SaveGame.BACKUP_SUFFIX)
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
	DirAccess.remove_absolute(TEST_SAVE + SaveGame.BACKUP_SUFFIX)


## Every screen can be used with a gamepad: it takes the focus when it opens, the d-pad reaches every
## control, accept presses and back goes back to where the player came from.
func _test_controller_navigation(scene: Node, player: Player) -> void:
	var menu: GameMenu = scene.get_node("GameMenu")
	menu.slot_paths = [TEST_SAVE, TEST_SLOT_2, TEST_SLOT_3]
	scene.save_game()
	var window := scene.get_viewport()
	var back := InputEventAction.new()
	back.action = "ui_cancel"
	back.pressed = true

	menu.open_title()
	await _physics_frames(3)
	_check(_focus_in(menu._panel) and _all_reachable(menu._panel), "the title menu takes the focus and the d-pad reaches every button")
	var load_button: Button = menu._buttons.get_child(1)
	load_button.pressed.emit()
	await _physics_frames(3)
	_check(_focus_in(menu._buttons) and _all_reachable(menu._buttons), "the load menu takes the focus and reaches every slot")
	menu._input(back)
	await _physics_frames(3)
	_check(window.gui_get_focus_owner() == load_button or (window.gui_get_focus_owner() as Button).text == tr("UI_LOAD_GAME"), "back from the slots returns to the button that opened them")
	menu._buttons.get_child(2).pressed.emit()
	menu._buttons.get_child(0).pressed.emit()
	await _physics_frames(3)
	_check(menu._confirming and _focus_in(menu._buttons) and _all_reachable(menu._buttons), "the overwrite warning takes the focus")
	menu._input(back)
	await _physics_frames(3)
	_check(menu._slot_screen and (window.gui_get_focus_owner() as Button).text.begins_with(tr("UI_SLOT").split("%")[0]), "back from the warning returns to the slot")
	menu._input(back)

	scene.open_pause_menu()
	await _physics_frames(3)
	_check(_focus_in(menu._panel) and _all_reachable(menu._panel), "the pause menu takes the focus")
	menu.open_settings(menu.open_pause)
	await _physics_frames(3)
	_check(_focus_in(menu._buttons) and _all_reachable(menu._buttons), "the settings take the focus and the d-pad reaches every setting")
	var slider: HSlider = null
	for row in menu._buttons.get_children():
		if row is HBoxContainer and row.get_child(1) is HSlider:
			slider = row.get_child(1)
			break
	slider.grab_focus()
	var before := slider.value
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	Input.parse_input_event(right)
	Input.flush_buffered_events()
	await _physics_frames(2)
	_check(slider.value > before, "a slider changes with left and right")
	menu.open_controls()
	await _physics_frames(3)
	_check(_focus_in(menu._controls) and _all_reachable(menu._controls), "the controls page takes the focus and the d-pad reaches every button")
	menu._input(back)
	await _physics_frames(3)
	_check((window.gui_get_focus_owner() as Button).text == tr("UI_CONTROLS_TITLE"), "back from the controls returns to the controls button")
	menu._input(back)
	await _physics_frames(3)
	_check((window.gui_get_focus_owner() as Button).text == tr("UI_SETTINGS"), "back from the settings returns to the settings button")
	var resumed := [false]
	menu.resume_chosen.connect(func() -> void: resumed[0] = true, CONNECT_ONE_SHOT)
	menu._input(back)
	_check(resumed[0], "back closes the pause menu")
	scene.resume()
	menu.close()

	var crafting: CraftingUI = scene.get_node("CraftingUI")
	player.inventory.add("berries")
	player.inventory.add("iron_ingot", 2)
	player.inventory.add("wood")
	crafting.open_inventory(player)
	await _physics_frames(3)
	_check(_focus_in(crafting._panel) and _all_reachable(crafting._panel), "the inventory takes the focus and reaches every button")
	crafting._input(back)
	_check(not crafting.is_open(), "back closes the inventory")
	crafting.open_station("anvil", "Anvil", player)
	await _physics_frames(3)
	_check(_focus_in(crafting._panel) and _all_reachable(crafting._panel), "a crafting station takes the focus and reaches every button")
	crafting.add_material("iron_ingot")
	crafting.add_material("iron_ingot")
	crafting.add_material("wood")
	await _physics_frames(3)
	_check(_focus_in(crafting._panel) and _all_reachable(crafting._panel), "choosing materials keeps the focus in reach")
	crafting.craft()
	_check(crafting.is_forging(), "the forging minigame starts")
	crafting._input(back)
	await _physics_frames(3)
	_check(not crafting.is_forging() and crafting.is_open() and _focus_in(crafting._panel), "back leaves the forging minigame and gives the focus back")
	crafting._input(back)
	_check(not crafting.is_open(), "back closes the crafting screen")

	var dialogue: DialogueUI = scene.get_node("DialogueUI")
	dialogue.open_conversation("bertram", "bertram", player)
	await _physics_frames(3)
	_check(_focus_in(dialogue._panel) and _all_reachable(dialogue._choices), "a conversation takes the focus and the d-pad reaches every reply")
	dialogue._input(back)
	_check(not dialogue.is_open() and not player.is_busy(), "back leaves a conversation")
	dialogue.open_conversation("bertram", "bertram", player)
	dialogue._runner._node["must_answer"] = true
	dialogue._input(back)
	_check(dialogue.is_open() and player.is_busy(), "back does not leave a line that needs an answer")
	while dialogue.is_open():
		dialogue.choose(0)

	var world_map: WorldMap = scene.get_node("MapController").world_map
	for action in ["map", "map_zoom_in", "map_zoom_out", "move_forward", "move_back", "move_left", "move_right"]:
		_check(InputMap.action_get_events(action).any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton or event is InputEventJoypadMotion), "the %s action has a gamepad input" % action)
	world_map.open()
	world_map._input(back)
	_check(not world_map.is_open() and not player.is_busy(), "back closes the map")
	DirAccess.remove_absolute(TEST_SAVE)
	DirAccess.remove_absolute(TEST_SAVE + SaveGame.BACKUP_SUFFIX)


## Whether the focus is on a control inside the given one.
func _focus_in(root: Node) -> bool:
	var owner := root.get_viewport().gui_get_focus_owner()
	return owner != null and root.is_ancestor_of(owner)


## Whether the d-pad can get from the focused control to every control under `root` that takes focus.
func _all_reachable(root: Node) -> bool:
	var wanted: Array[Control] = []
	_collect_focusable(root, wanted)
	var start := root.get_viewport().gui_get_focus_owner()
	if start == null or wanted.is_empty():
		return false
	var seen := {start: true}
	var queue: Array[Control] = [start]
	while not queue.is_empty():
		var current: Control = queue.pop_back()
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var next := current.find_valid_focus_neighbor(side)
			if next != null and not seen.has(next):
				seen[next] = true
				queue.append(next)
	for control in wanted:
		if not seen.has(control):
			print("not reachable by focus: ", control.get_path(), " ", control)
			return false
	return true


func _collect_focusable(node: Node, found: Array[Control]) -> void:
	for child in node.get_children():
		var control := child as Control
		if control != null and control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree() and not (control is BaseButton and control.disabled):
			found.append(control)
		_collect_focusable(child, found)


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
	for species in grass._meshes.size():
		whole_tris += grass._meshes[species].surface_get_array_len(0) / 3
	var far_tris: int = grass._far_mesh.surface_get_array_len(0) / 3
	_check(far_tris * 3 < whole_tris / grass._meshes.size(), "distant grass tufts cost far less (%d against %d triangles)" % [far_tris, whole_tris / grass._meshes.size()])

	grass._fit_detail(cell, cell_center)
	var multimesh := planted.multimeshes[0]
	_check(multimesh.visible_instance_count == multimesh.instance_count and planted.instances[0].visible, "grass around the camera is drawn whole")
	_check(planted.far_instance == null or not planted.far_instance.visible, "grass around the camera doesn't use the far tufts")
	grass._fit_detail(cell, cell_center + Vector2(160.0, 0.0))
	var total := 0
	for each in planted.multimeshes:
		total += each.instance_count
	_check(planted.far_instance != null and planted.far_instance.visible and planted.far_multimesh.instance_count == total, "distant grass puts every species in one multimesh")
	_check(planted.far_multimesh.visible_instance_count < total and not planted.instances[0].visible, "distant grass draws fewer, simpler tufts")
	grass._fit_detail(cell, cell_center + Vector2(600.0, 0.0))
	_check(not planted.group.visible, "grass beyond the draw distance isn't drawn")
	grass._fit_detail(cell, cell_center)
	_check(planted.group.visible and planted.instances[0].visible and not planted.far_instance.visible, "grass returns when the camera comes back")

	var distances: Array[float] = []
	for level in 3:
		menu._choose_graphics(level)
		distances.append(grass._draw_distance)
		_check(grass.tuft_share(GrassField.DRAW_DISTANCE * GrassField.EARLY_FADE - 1.0) == 1.0, "%s graphics keep all the grass nearby" % Settings.graphics)
		_check(grass.tuft_share(grass._draw_distance) == 0.0, "%s graphics draw no grass past the draw distance" % Settings.graphics)
	_check(distances[0] < distances[1] and distances[1] < distances[2], "lower graphics draw grass less far (%s)" % str(distances))
	_check(distances[2] == GrassField.DRAW_DISTANCE, "high graphics draw grass at full distance")


## Photo surfaces have relief maps, and high graphics darken corners on screen.
func _test_surface_relief(scene: Node) -> void:
	var missing := PackedStringArray()
	for pattern: int in Surfaces.PHOTOS:
		var material := Surfaces.get_material(pattern, Color.WHITE)
		var photos: Array = Surfaces.PHOTOS[pattern]
		for i in photos.size():
			var suffix := "" if i == 0 else "_%d" % (i + 1)
			var relief: Texture2D = material.get_shader_parameter("surface_relief" + suffix)
			if relief == null or relief.get_width() != (photos[i][0] as Texture2D).get_width():
				missing.append((photos[i][0] as Texture2D).resource_path.get_file())
	var terrain_material := (scene.get_node("Terrain") as Terrain)._ground_material()
	for photo: String in Terrain.RELIEF_PARAMETERS:
		if terrain_material.get_shader_parameter(Terrain.RELIEF_PARAMETERS[photo]) == null:
			missing.append(photo)
	_check(missing.is_empty(), "every photo surface has its relief map (missing: %s)" % ", ".join(missing))

	var menu: GameMenu = scene.get_node("GameMenu")
	var environment := (scene.get_node("WorldEnvironment") as WorldEnvironment).environment
	var previous := Settings.GRAPHICS_LEVELS.keys().find(Settings.graphics)
	var darkened: Array[bool] = []
	for level in 3:
		menu._choose_graphics(level)
		darkened.append(environment.ssao_enabled)
	menu._choose_graphics(previous)
	_check(darkened == [false, false, true], "only high graphics darken corners on screen (%s)" % str(darkened))


func _test_settings(scene: Node, player: Player) -> void:
	var menu: GameMenu = scene.get_node("GameMenu")
	var hedda: Npc = scene.get_node("Village/hedda")
	TranslationServer.set_locale("en")
	menu.open_pause()
	menu._buttons.get_child(1).pressed.emit()
	_check(menu._settings_open and menu._buttons.get_child_count() == 9 + AudioBuses.ALL.size(), "the pause menu opens the settings")

	menu._choose_language(2)
	await process_frame
	await process_frame
	_check(TranslationServer.get_locale() == "de" and menu._title.text == "Einstellungen", "choosing a language changes the menu")
	_check(scene.get_node("UI/ControlsLabel").text == KeyBindings.controls_hint() and hedda._label.text == tr(hedda.prompt_key), "choosing a language changes text already on screen")

	menu._choose_graphics(0)
	var sun: DirectionalLight3D = scene.get_node("Sun")
	_check(not sun.shadow_enabled and is_equal_approx(root.scaling_3d_scale, Settings.render_scale()), "low graphics take effect at once")
	menu._choose_graphics(1)
	_check(sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "medium graphics use fewer shadow levels")
	menu._choose_graphics(2)
	_check(sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and root.scaling_3d_scale == 1.0, "high graphics take effect at once")

	menu._choose_look_speed(2.0)
	menu._choose_text_size(2)
	menu._choose_dialogue_opacity(0.5)
	menu._choose_volume(0.25, AudioBuses.MUSIC)
	menu._choose_volume(0.0, AudioBuses.AMBIENCE)
	_check(AudioServer.get_bus_index(AudioBuses.EFFECTS) != -1 and AudioServer.get_bus_send(AudioServer.get_bus_index(AudioBuses.MUSIC)) == AudioBuses.MASTER, "the Music, Effects, and Ambience buses feed into Master")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AudioBuses.MUSIC)), linear_to_db(0.25)) and AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioBuses.AMBIENCE)), "a volume slider changes its bus at once")
	var test_player := AudioStreamPlayer.new()
	AudioBuses.route(test_player, AudioBuses.EFFECTS)
	_check(test_player.bus == AudioBuses.EFFECTS, "sound code can pick a bus")
	AudioBuses.route(test_player, "Nonsense")
	_check(test_player.bus == AudioBuses.MASTER, "an unknown bus falls back to Master")
	test_player.free()
	var dialogue_ui: DialogueUI = scene.get_node("DialogueUI")
	dialogue_ui.refresh_style()
	_check(ThemeDB.get_project_theme().default_font_size == roundi(Settings.BASE_FONT_SIZE * 1.5), "a larger text size scales the interface text")
	_check(dialogue_ui._speaker.get_theme_font_size("font_size") == roundi(DialogueUI.SPEAKER_FONT_SIZE * 1.5), "a larger text size scales the speaker's name")
	_check(scene.get_node("UI/QuestLabel").label_settings.font_size == 24, "a larger text size scales the quest text")
	_check(is_equal_approx(dialogue_ui._panel.self_modulate.a, 0.5), "the dialogue panel's opacity follows the setting")
	var theme := ThemeDB.get_project_theme()
	var health_pattern: BarPattern = scene.get_node("UI/HealthBar/Frame/Pattern")
	var stamina_pattern: BarPattern = scene.get_node("UI/StaminaBar/Frame/Pattern")
	_check(not health_pattern.visible and not stamina_pattern.visible and theme.get_stylebox("fill", "ProgressBar").modulate_color == Accessibility.PALETTES["off"]["health"], "the bars have no pattern with colour vision off")
	menu._choose_colour_vision(1)
	_check(Settings.colour_vision == "deuteranopia" and theme.get_stylebox("fill", "ProgressBar").modulate_color == Accessibility.PALETTES["deuteranopia"]["health"], "a colour vision mode recolors the health bar")
	_check(theme.get_stylebox("fill", "StaminaBar").modulate_color == Accessibility.PALETTES["deuteranopia"]["stamina"] and health_pattern.visible and stamina_pattern.visible, "a colour vision mode recolors the stamina bar and shows the bar patterns")
	for mode: String in Accessibility.MODES:
		var palette: Dictionary = Accessibility.PALETTES[mode]
		_check(palette["health"] != palette["stamina"] and palette["objective"] != palette["player"], "the %s palette tells the bars and markers apart" % mode)
	menu._choose_high_contrast(true)
	var label_settings: LabelSettings = scene.get_node("UI/QuestLabel").label_settings
	_check(Settings.high_contrast and label_settings.outline_size == Accessibility.HC_OUTLINE_SIZE and theme.get_color("font_color", "Label") == Accessibility.HC_TEXT_COLOR, "high contrast outlines the HUD text and whitens the menu text")
	_check(theme.get_stylebox("normal", "HudPlate").modulate_color == Accessibility.HC_PLATE_COLOR, "high contrast darkens the HUD plates")
	_check(is_equal_approx(dialogue_ui._panel.self_modulate.a, 1.0), "high contrast makes the dialogue panel opaque")
	_check(WorldMap.text_color() == Accessibility.HC_TEXT_COLOR and WorldMap.outline_size() == Accessibility.HC_OUTLINE_SIZE, "high contrast makes the world map text white with a thick outline")
	await _test_enemy_accessibility(scene)
	menu._choose_colour_vision(0)
	_check(Settings.high_contrast and stamina_pattern.visible, "high contrast shows the bar patterns on its own")
	menu._close_settings()
	_check(menu.is_open() and menu._title.text == tr("UI_PAUSED"), "leaving the settings returns to the pause menu")
	Settings.look_speed = 1.0
	Settings.language = ""
	Settings.graphics = "low"
	Settings.text_size = 1.0
	Settings.dialogue_opacity = 1.0
	Settings.load_saved()
	_check(Settings.language == "de" and Settings.look_speed == 2.0 and Settings.graphics == "high", "settings are remembered")
	_check(Settings.text_size == 1.5 and is_equal_approx(Settings.dialogue_opacity, 0.5), "the text size and dialogue opacity are remembered")
	_check(Settings.colour_vision == "off" and Settings.high_contrast, "high contrast is remembered")
	_check(is_equal_approx(Settings.volumes[AudioBuses.MUSIC], 0.25) and Settings.volumes[AudioBuses.AMBIENCE] == 0.0 and Settings.volumes[AudioBuses.MASTER] == Settings.DEFAULT_VOLUME, "volumes are remembered")
	var bad_vision := FileAccess.open(TEST_SETTINGS, FileAccess.WRITE)
	bad_vision.store_string('{"colour_vision": "rainbow", "high_contrast": "yes"}')
	bad_vision.close()
	Settings.load_saved()
	_check(Settings.colour_vision == "off" and not Settings.high_contrast, "invalid accessibility settings fall back to defaults")
	_check(theme.get_color("font_color", "Label") == Color(0.93, 0.88, 0.76, 1) and theme.get_stylebox("normal", "HudPlate").modulate_color == Color.WHITE, "turning high contrast off puts the theme's colors back")
	scene.get_node("UI").refresh_accessibility()
	dialogue_ui.refresh_style()
	_check(is_equal_approx(dialogue_ui._panel.self_modulate.a, Settings.dialogue_opacity) and WorldMap.outline_size() == 4, "turning high contrast off puts the dialogue opacity and map text back")
	_check(label_settings.outline_size == 4 and not health_pattern.visible, "turning high contrast off puts the HUD text and bars back")
	menu.close()
	player.set_busy(false)

	var bad_volumes := FileAccess.open(TEST_SETTINGS, FileAccess.WRITE)
	bad_volumes.store_string('{"volumes": {"Master": 7, "Music": "loud", "Effects": -1}}')
	bad_volumes.close()
	Settings.load_saved()
	_check(Settings.volumes[AudioBuses.MASTER] == 1.0 and Settings.volumes[AudioBuses.MUSIC] == Settings.DEFAULT_VOLUME and Settings.volumes[AudioBuses.EFFECTS] == 0.0, "volumes are checked when loaded")

	var damaged := FileAccess.open(TEST_SETTINGS, FileAccess.WRITE)
	damaged.store_string("not json")
	damaged.close()
	Settings.load_saved()
	_check(Settings.language == "" and Settings.look_speed == 1.0 and Settings.graphics == "high" and Settings.text_size == 1.0 and Settings.dialogue_opacity == 1.0 and Settings.volumes == Settings.default_volumes(), "damaged settings fall back to defaults")
	_check(ThemeDB.get_project_theme().default_font_size == Settings.BASE_FONT_SIZE, "default settings use the normal text size")
	Settings.path = Settings.DEFAULT_PATH
	DirAccess.remove_absolute(TEST_SETTINGS)
	TranslationServer.set_locale("en")


## Prompts show only the inputs of the device used last, follow remapped bindings, and switch at once.
func _test_input_device_prompts(scene: Node) -> void:
	TranslationServer.set_locale("en")
	KeyBindings.reset()
	InputDevice.active = KeyBindings.KEYBOARD
	var key := InputEventKey.new()
	key.pressed = true
	var button := InputEventJoypadButton.new()
	button.pressed = true
	var tiny_stick := InputEventJoypadMotion.new()
	tiny_stick.axis_value = 0.1
	var stick := InputEventJoypadMotion.new()
	stick.axis_value = 0.9
	_check(InputDevice.kind_for_event(key) == KeyBindings.KEYBOARD and InputDevice.kind_for_event(button) == KeyBindings.GAMEPAD and InputDevice.kind_for_event(stick) == KeyBindings.GAMEPAD and InputDevice.kind_for_event(tiny_stick) == "", "input events map to the device that made them, ignoring stick drift")

	var device: InputDevice
	for child in scene.get_children():
		if child is InputDevice:
			device = child
	_check(device != null, "the game listens for the input device")
	var controls: PromptLine = scene.get_node("UI/ControlsLabel")
	device.use(KeyBindings.KEYBOARD)
	_check(KeyBindings.label_for("interact") == "E" and controls.text.contains("E: use"), "the keyboard shows key prompts")
	device.use(KeyBindings.GAMEPAD)
	_check(KeyBindings.label_for("interact") == "X" and controls.text.contains("X: use") and not controls.text.contains("WASD"), "using the gamepad switches the controls line at once")

	var dialogue: DialogueUI = scene.get_tree().get_first_node_in_group(Npc.UI_GROUP)
	dialogue.refresh_prompts()
	_check(dialogue._hint.text == "X: choose", "the dialogue hint shows the gamepad input")
	device.use(KeyBindings.KEYBOARD)
	_check(dialogue._hint.text == "E: choose", "the dialogue hint switches back to the keyboard")
	var remapped := InputEventJoypadButton.new()
	remapped.button_index = JOY_BUTTON_Y
	KeyBindings.bind("interact", remapped)
	device.use(KeyBindings.GAMEPAD)
	_check(KeyBindings.label_for("interact") == "Y" and dialogue._hint.text == "Y: choose", "pad prompts follow remapped bindings")
	KeyBindings.reset()
	TranslationServer.set_locale("de")
	_check(tr("UI_DIALOGUE_HINT") != "UI_DIALOGUE_HINT" and tr("UI_DIALOGUE_HINT") != "%s: choose", "the dialogue hint is translated")
	TranslationServer.set_locale("en")
	device.use(KeyBindings.KEYBOARD)


## Prompts draw code-made glyphs for the active device, follow the settings, and fall back to plain text.
func _test_input_glyphs(scene: Node) -> void:
	TranslationServer.set_locale("en")
	KeyBindings.reset()
	var saved_size := Settings.text_size
	_check(FeatureFlags.enabled("input_glyphs"), "the input_glyphs flag is on by default")
	for kind in KeyBindings.KINDS:
		InputDevice.active = kind
		_check(PromptLine.plain_text(KeyBindings.controls_segments()) == KeyBindings.controls_hint(), "the glyph segments read as the plain controls line for %s" % kind)
		_check(PromptLine.plain_text(KeyBindings.segments_for("interact")) == KeyBindings.label_for("interact"), "the interact glyph reads as its plain text for %s" % kind)
	InputDevice.active = KeyBindings.KEYBOARD
	_check(InputGlyph.spec_for(KeyBindings.event_for("interact", KeyBindings.KEYBOARD))["shape"] == "key", "keys are drawn as rounded rectangles")
	_check(InputGlyph.spec_for(KeyBindings.event_for("interact", KeyBindings.GAMEPAD))["shape"] == "round", "face buttons are drawn as circles")
	var shapes := {}
	for index in [JOY_BUTTON_A, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_START, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_LEFT_STICK, 40]:
		var pad_button := InputEventJoypadButton.new()
		pad_button.button_index = index
		var spec := InputGlyph.spec_for(pad_button)
		shapes[spec["shape"]] = true
		_check(InputGlyph.can_draw(spec), "pad button %d has a drawable glyph" % index)
	_check(shapes.has("round") and shapes.has("bumper") and shapes.has("pill") and shapes.has("dpad"), "buttons, bumpers, the d-pad and other buttons use their own shapes")
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	var left_up := InputEventJoypadMotion.new()
	left_up.axis = JOY_AXIS_LEFT_Y
	left_up.axis_value = -1.0
	_check(InputGlyph.spec_for(trigger)["shape"] == "trigger" and InputGlyph.spec_for(left_up)["shape"] == "stick" and InputGlyph.spec_for(left_up)["dir"] == Vector2i.UP, "triggers and sticks have shapes, and a stick shows its direction")
	_check(not InputGlyph.can_draw({}) and not InputGlyph.can_draw({ "shape": "star", "text": "x" }) and not InputGlyph.can_draw({ "shape": "key", "text": "" }), "a spec that can't be drawn is refused")

	var line := PromptLine.new()
	scene.add_child(line)
	line.set_template("%s: %s", [KeyBindings.segments_for("interact"), "Open"])
	var glyph_count := 0
	for child in line.find_children("*", "InputGlyph", true, false):
		glyph_count += 1
	_check(glyph_count == 1 and line.text == "E: Open", "a prompt line draws a glyph for the key and keeps the plain text (%s)" % line.text)
	var glyph: InputGlyph = line.find_children("*", "InputGlyph", true, false)[0]
	var small := glyph.get_combined_minimum_size()
	Settings.text_size = 1.5
	line.label_settings = LabelSettings.new()
	line.label_settings.font_size = Settings.scaled_font_size(16)
	line.rebuild()
	glyph = line.find_children("*", "InputGlyph", true, false)[0]
	_check(glyph.get_combined_minimum_size().y > small.y, "glyphs grow with the text size")
	Settings.text_size = saved_size
	var wasd := InputGlyph.new({ "shape": "key", "text": "Space" }, 16)
	var short := InputGlyph.new({ "shape": "key", "text": "E" }, 16)
	_check(wasd.get_combined_minimum_size().x > short.get_combined_minimum_size().x and short.get_combined_minimum_size().x >= short.get_combined_minimum_size().y, "a long key name makes a wider key")

	var normal_a := Accessibility.glyph_look("A")
	var high_before := Settings.high_contrast
	var vision_before := Settings.colour_vision
	Settings.colour_vision = "deuteranopia"
	var vision_a := Accessibility.glyph_look("A")
	Settings.colour_vision = "off"
	Settings.high_contrast = true
	var high_a := Accessibility.glyph_look("A")
	Settings.high_contrast = high_before
	Settings.colour_vision = vision_before
	_check(normal_a["fill"] != vision_a["fill"] and vision_a["fill"] == Accessibility.glyph_look("")["fill"], "colour vision modes drop the face button colours")
	_check(high_a["fill"] == Accessibility.HC_INK_COLOR and high_a["border"] == Accessibility.HC_TEXT_COLOR and high_a["border_width"] > normal_a["border_width"], "high contrast draws black and white glyphs with a thicker border")

	var hud_line: PromptLine = scene.get_node("UI/ControlsLabel")
	hud_line.rebuild()
	var hud_glyphs := hud_line.find_children("*", "InputGlyph", true, false).size()
	_check(hud_glyphs > 5, "the controls line draws glyphs (%d)" % hud_glyphs)
	_write_flags(TEST_FLAGS_A, { "flags": { "input_glyphs": false } })
	FeatureFlags.load_layers([TEST_FLAGS_A])
	hud_line.rebuild()
	hud_glyphs = hud_line.find_children("*", "InputGlyph", true, false).size()
	_check(hud_glyphs == 0 and hud_line.text == KeyBindings.controls_hint(), "with input_glyphs off the line is plain text")
	FeatureFlags.load_layers()
	hud_line.rebuild()
	line.queue_free()
	InputDevice.active = KeyBindings.KEYBOARD


## Remapped controls take effect, ask before taking an input that is in use, are saved, and fall back when damaged.
func _test_key_bindings(scene: Node) -> void:
	Settings.path = TEST_SETTINGS
	TranslationServer.set_locale("en")
	KeyBindings.reset()
	InputDevice.active = KeyBindings.KEYBOARD
	var default_hint := KeyBindings.controls_hint()
	_check(default_hint.begins_with("WASD: walk") and default_hint.contains("E: use") and default_hint.contains("Left click: attack"), "the controls hint shows the default keyboard bindings (%s)" % default_hint)
	InputDevice.active = KeyBindings.GAMEPAD
	var pad_hint := KeyBindings.controls_hint()
	_check(pad_hint.begins_with("Left stick: walk") and pad_hint.contains("X: use") and pad_hint.contains("RT: attack") and not pad_hint.contains("WASD"), "the controls hint shows the default gamepad bindings (%s)" % pad_hint)
	InputDevice.active = KeyBindings.KEYBOARD
	var missing := PackedStringArray()
	for action in KeyBindings.ACTIONS:
		if not InputMap.has_action(action):
			missing.append(action)
		for key in ["ACTION_" + action.to_upper()]:
			if tr(key) == key:
				missing.append(key)
	_check(missing.is_empty(), "every remappable action exists and has a name (%s)" % ", ".join(missing))

	var menu: GameMenu = scene.get_node("GameMenu")
	menu.open_pause()
	menu._buttons.get_child(1).pressed.emit()
	menu._buttons.get_child(7 + AudioBuses.ALL.size()).pressed.emit()
	await process_frame
	var page: ControlsMenu = menu._controls
	_check(menu._title.text == tr("UI_CONTROLS_TITLE") and page != null, "the settings open the Controls page")
	_check(page.get_child_count() == KeyBindings.ACTIONS.size() + 3, "the Controls page lists every action, reset, and back")

	var key_u := InputEventKey.new()
	key_u.physical_keycode = KEY_U
	key_u.pressed = true
	page.listen("interact", KeyBindings.KEYBOARD)
	_check(page.offer(key_u) and KeyBindings.event_for("interact", KeyBindings.KEYBOARD).physical_keycode == KEY_U, "an input pressed while listening is bound")
	var press := InputEventKey.new()
	press.physical_keycode = KEY_U
	press.pressed = true
	_check(InputMap.action_get_events("interact").size() == 2, "the Input Map holds the new binding")
	_check(InputMap.event_is_action(press, "interact") and not InputMap.event_is_action(press, "inventory"), "the new key triggers its action")
	var old_key := InputEventKey.new()
	old_key.physical_keycode = KEY_E
	_check(not InputMap.event_is_action(old_key, "interact"), "the old key no longer triggers it")
	_check(KeyBindings.label_for("interact") == "U" and KeyBindings.controls_hint().contains("U: use"), "the controls hint shows the new binding")

	# Binding an input that another action uses asks first.
	var key_i := InputEventKey.new()
	key_i.physical_keycode = KEY_I
	key_i.pressed = true
	page.listen("jump", KeyBindings.KEYBOARD)
	page.offer(key_i)
	_check(page.is_asking() and KeyBindings.event_for("jump", KeyBindings.KEYBOARD).physical_keycode == KEY_SPACE, "an input in use asks before changing anything")
	page.answer_conflict(false)
	_check(not page.is_asking() and KeyBindings.event_for("inventory", KeyBindings.KEYBOARD).physical_keycode == KEY_I, "cancelling keeps both bindings")
	page.listen("jump", KeyBindings.KEYBOARD)
	page.offer(key_i)
	page.answer_conflict(true)
	_check(KeyBindings.event_for("jump", KeyBindings.KEYBOARD).physical_keycode == KEY_I and KeyBindings.event_for("inventory", KeyBindings.KEYBOARD).physical_keycode == KEY_SPACE, "swapping gives each action the other's input")

	# Gamepad inputs go in the gamepad slot.
	var pad_button := InputEventJoypadButton.new()
	pad_button.button_index = JOY_BUTTON_Y
	pad_button.pressed = true
	page.listen("attack", KeyBindings.GAMEPAD)
	page.offer(key_u)
	_check(KeyBindings.event_for("attack", KeyBindings.GAMEPAD) is InputEventJoypadMotion, "a key does not replace a gamepad input")
	page.offer(pad_button)
	_check(page.is_asking(), "a gamepad input in use asks too")
	page.answer_conflict(true)
	_check(KeyBindings.event_for("attack", KeyBindings.GAMEPAD) is InputEventJoypadButton and KeyBindings.event_for("toggle_camera", KeyBindings.GAMEPAD) is InputEventJoypadMotion, "gamepad inputs swap")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	page.listen("block", KeyBindings.KEYBOARD)
	page.offer(escape)
	_check(not page.is_listening(), "Esc stops listening")

	# A gamepad wait ends by itself, and back cancels the question about a used input.
	page.listen("attack", KeyBindings.GAMEPAD)
	page.wait(ControlsMenu.GAMEPAD_WAIT_SECONDS - 1.0)
	_check(page.is_listening(), "a gamepad wait goes on for a while")
	page.wait(1.0)
	_check(not page.is_listening(), "a gamepad wait ends by itself")
	page.listen("block", KeyBindings.KEYBOARD)
	page.wait(ControlsMenu.GAMEPAD_WAIT_SECONDS * 2.0)
	_check(page.is_listening(), "a keyboard wait does not time out")
	page.offer(escape)
	page.listen("jump", KeyBindings.GAMEPAD)
	page.offer(pad_button)
	var back := InputEventAction.new()
	back.action = "ui_cancel"
	back.pressed = true
	_check(page.is_asking() and page.offer(back) and not page.is_asking() and not page.is_listening(), "back on a gamepad cancels the question about a used input")

	# Saved, loaded, and reset.
	Settings.save()
	KeyBindings.reset()
	_check(KeyBindings.label_for("interact") == "E", "reset restores the default bindings")
	Settings.load_saved()
	_check(KeyBindings.label_for("interact") == "U" and KeyBindings.event_for("jump", KeyBindings.KEYBOARD).physical_keycode == KEY_I and KeyBindings.event_for("attack", KeyBindings.GAMEPAD) is InputEventJoypadButton, "bindings are remembered")
	page.reset_to_defaults()
	_check(KeyBindings.controls_hint() == default_hint and KeyBindings.event_for("jump", KeyBindings.KEYBOARD).physical_keycode == KEY_SPACE, "the reset button restores the defaults")

	# Damaged bindings fall back to the defaults, one input at a time where possible.
	var saved: Dictionary = KeyBindings.to_data()
	saved["interact"][KeyBindings.KEYBOARD] = { "type": "key", "code": "nonsense" }
	saved["jump"][KeyBindings.GAMEPAD] = { "type": "pad_button", "button": 999 }
	saved["sprint"] = "broken"
	saved["dodge"][KeyBindings.KEYBOARD] = { "type": "key", "code": KEY_N }
	saved["unknown_action"] = { "keyboard": { "type": "key", "code": KEY_N } }
	var damaged := FileAccess.open(TEST_SETTINGS, FileAccess.WRITE)
	damaged.store_string(JSON.stringify({ "graphics": "high", "bindings": saved }))
	damaged.close()
	Settings.load_saved()
	_check(KeyBindings.event_for("interact", KeyBindings.KEYBOARD).physical_keycode == KEY_E and KeyBindings.event_for("jump", KeyBindings.GAMEPAD) is InputEventJoypadButton and KeyBindings.event_for("sprint", KeyBindings.KEYBOARD).physical_keycode == KEY_SHIFT, "damaged bindings fall back to their defaults")
	_check(KeyBindings.event_for("dodge", KeyBindings.KEYBOARD).physical_keycode == KEY_N, "valid bindings next to damaged ones are kept")
	saved = KeyBindings.to_data()
	saved["jump"][KeyBindings.KEYBOARD] = saved["interact"][KeyBindings.KEYBOARD]
	damaged = FileAccess.open(TEST_SETTINGS, FileAccess.WRITE)
	damaged.store_string(JSON.stringify({ "bindings": saved }))
	damaged.close()
	Settings.load_saved()
	_check(KeyBindings.event_for("dodge", KeyBindings.KEYBOARD).physical_keycode == KEY_C, "bindings that share an input fall back to the defaults")
	damaged = FileAccess.open(TEST_SETTINGS, FileAccess.WRITE)
	damaged.store_string(JSON.stringify({ "bindings": [1, 2] }))
	damaged.close()
	Settings.load_saved()
	_check(KeyBindings.controls_hint() == default_hint, "bindings that aren't a dictionary fall back to the defaults")

	menu.close()
	Settings.path = Settings.DEFAULT_PATH
	DirAccess.remove_absolute(TEST_SETTINGS)
	KeyBindings.reset()


## Every story, item, and villager name key must exist in both languages.
func _test_translations() -> void:
	var missing := PackedStringArray()
	var text := ""
	for path in ["dialogue", "quests", "crafting", "enemies", "village_layout"]:
		text += FileAccess.get_file_as_string("res://data/%s.json" % path)
	var pattern := RegEx.create_from_string("\"((?:DLG|OBJ|QUEST|ITEM|ENEMY|NPC)_[A-Z0-9_]+)\"")
	# Each language's own table, since the English fallback would hide a missing German line.
	for locale in ["en", "de"]:
		var translation: Translation = load("res://localization/strings.%s.translation" % locale)
		for found in pattern.search_all(text):
			if String(translation.get_message(found.get_string(1))).is_empty():
				missing.append("%s:%s" % [locale, found.get_string(1)])
	_check(missing.is_empty(), "all text is translated %s" % ", ".join(missing))


## Every villager has a fallback conversation, and every line leads to a line that exists.
func _test_dialogue_data() -> void:
	var dialogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DialogueRunner.DATA_PATH))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/village_layout.json"))
	var problems := PackedStringArray()
	for npc: Dictionary in layout["npcs"]:
		var conversations: Array = dialogue.get(npc["id"], [])
		if conversations.is_empty() or conversations[-1].has("when"):
			problems.append("%s has no fallback" % npc["id"])
	for npc_id: String in dialogue:
		for conversation: Dictionary in dialogue[npc_id]:
			var nodes: Dictionary = conversation["nodes"]
			var targets: Array = [conversation["start"]]
			for node: Dictionary in nodes.values():
				targets.append(node.get("next", ""))
				targets.append(node.get("choices_of", ""))
				for choice: Dictionary in node.get("choices", []):
					targets.append(choice.get("next", ""))
			for target: String in targets:
				if target != "" and not nodes.has(target):
					problems.append("%s leads to missing %s" % [npc_id, target])
	_check(problems.is_empty(), "dialogue data is complete %s" % ", ".join(problems))


## A line can play once with set_flag and not_flag, and a node can borrow another's choices.
func _test_dialogue_conditions() -> void:
	var player := Player.new()
	var saved := DialogueRunner._data
	DialogueRunner._data = { "npc": [
		{ "when": { "not_flag": "met" }, "start": "hello", "nodes": {
			"hello": { "text": "FIRST", "effects": [{ "type": "set_flag", "flag": "met" }] } } },
		{ "start": "menu", "nodes": {
			"menu": { "text": "MENU", "choices": [{ "text": "A", "next": "more" }, { "text": "BYE" }] },
			"more": { "text": "MORE", "choices_of": "menu" } } },
	] }
	var first := DialogueRunner.new("npc", player)
	_check(first.text_key() == "FIRST" and player.quests.flags.has("met"), "a not_flag line plays while the flag is unset")
	var again := DialogueRunner.new("npc", player)
	_check(again.text_key() == "MENU", "a not_flag line gives way once the flag is set")
	again.advance(0)
	_check(again.text_key() == "MORE" and again.choice_keys() == PackedStringArray(["A", "BYE"]), "a node can borrow another node's choices")
	again.advance(1)
	_check(again.is_finished(), "a borrowed choice list leads on as usual")
	DialogueRunner._data = saved
	player.free()


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


func _check_water_ripples(terrain: Terrain, player: Player) -> void:
	var material := terrain.get_node("Water").material_override as ShaderMaterial
	var before := player.global_position
	var saved_graphics := Settings.graphics
	Settings.graphics = "high"
	player.global_position = Vector3(0.0, terrain.water_height(0.0, 5.0) - 0.4, 5.0)
	_check(terrain._stir_water() == 1, "someone wading in the river ripples the water")
	_check(material.get_shader_parameter("wader_count") == 1, "the water shader is told about the wader")
	player.global_position = Vector3(300.0, terrain.height_at(300.0, 300.0) + 1.0, 300.0)
	_check(terrain._stir_water() == 0, "someone on dry land leaves the water still")
	Settings.graphics = "low"
	player.global_position = Vector3(0.0, terrain.water_height(0.0, 5.0) - 0.4, 5.0)
	_check(terrain._stir_water() == 0, "low graphics skips the ripples")
	Settings.graphics = saved_graphics
	player.global_position = before


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
	DirAccess.remove_absolute(TEST_SAVE + SaveGame.BACKUP_SUFFIX)

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


func _test_ranged(scene: Node, player: Player) -> void:
	_check(player.ranged_given and player.inventory.count("short_bow") == 1 and player.inventory.count("arrow") == 10, "a new game starts with a bow and arrows")
	_check(player.inventory.count("fire_flask") == 3, "a new game starts with fire flasks")
	_check(player.inventory.best_weapon_damage() == 0.0, "a bow is not a melee weapon")
	for action in ["shoot", "throw"]:
		var kinds := {}
		for input in InputMap.action_get_events(action):
			kinds[input.get_class()] = true
		_check(_has_joypad(kinds) and kinds.has("InputEventKey"), "%s has keyboard and controller bindings" % action)
	for projectile_id: String in Projectile.type_ids():
		var type := Projectile.stats(projectile_id)
		var complete := true
		for key in ["action", "requires_item", "ammo_item", "damage", "speed", "gravity", "lifetime", "radius", "splash_radius", "cooldown", "size", "color"]:
			complete = complete and type.has(key)
		_check(complete and CraftingData.item_name(type["ammo_item"]) != "", "%s is fully described by data" % projectile_id)

	# A stand-in enemy on open ground, which does not move.
	var terrain: Terrain = scene.get_node("Terrain")
	var spot := _flat_open_spot(terrain, player)
	_check(spot != Vector3.INF, "there is flat ground to test shooting on")
	var dummy := Enemy.new()
	scene.add_child(dummy)
	dummy.setup("goblin", spot)
	dummy.set_physics_process(false)
	await _physics_frames(2)
	var chest := spot + Vector3.UP * 0.8

	var arrow := Projectile.launch("arrow", chest + Vector3(0.0, 0.0, 6.0), Vector3.FORWARD)
	scene.add_child(arrow)
	var before := dummy.health.current
	await _physics_frames(20)
	_check(dummy.health.current == before - float(Projectile.stats("arrow")["damage"]), "an arrow hurts the enemy it hits")
	_check(not is_instance_valid(arrow) or arrow.is_queued_for_deletion(), "an arrow that hits an enemy is gone")

	before = dummy.health.current
	var wide := Projectile.launch("arrow", chest + Vector3(3.0, 0.0, 6.0), Vector3.FORWARD)
	scene.add_child(wide)
	await _physics_frames(20)
	_check(dummy.health.current == before, "an arrow that passes beside the enemy misses")
	wide.queue_free()

	var high := Projectile.launch("arrow", chest + Vector3(0.0, 2.0, 40.0), Vector3.FORWARD)
	scene.add_child(high)
	var start_y := high.position.y
	await _physics_frames(30)
	_check(high.position.y < start_y - 0.5, "arrows fall under gravity")
	high.queue_free()

	var into_ground := Projectile.launch("arrow", spot + Vector3(10.0, 3.0, 0.0), Vector3.DOWN)
	scene.add_child(into_ground)
	await _physics_frames(30)
	_check(into_ground.hit_something and into_ground.position.y < spot.y + 1.0, "an arrow stops in the ground")
	into_ground.queue_free()

	before = dummy.health.current
	var flask := Projectile.launch("fire_flask", spot + Vector3(0.0, 5.0, 2.0), Vector3.DOWN)
	scene.add_child(flask)
	await _physics_frames(30)
	_check(dummy.health.current == before - float(Projectile.stats("fire_flask")["damage"]), "a flask hurts an enemy near where it lands")
	before = dummy.health.current
	var far := Projectile.launch("fire_flask", spot + Vector3(20.0, 5.0, 0.0), Vector3.DOWN)
	scene.add_child(far)
	await _physics_frames(30)
	_check(dummy.health.current == before, "a flask doesn't hurt an enemy outside its splash")

	# Firing from the player.
	var arrows := player.inventory.count("arrow")
	_check(player.fire_ranged("shoot") and player.inventory.count("arrow") == arrows - 1, "shooting uses up an arrow")
	_check(not player.fire_ranged("shoot") and player.inventory.count("arrow") == arrows - 1, "shooting waits for the cooldown")
	_check(root.get_tree().get_nodes_in_group(Projectile.GROUP).size() > 0, "shooting launches a projectile")
	await _physics_frames(90)
	var flasks := player.inventory.count("fire_flask")
	_check(player.fire_ranged("throw") and player.inventory.count("fire_flask") == flasks - 1, "throwing uses up a flask")
	await _physics_frames(90)
	var notices: Array[String] = []
	player.notice.connect(func(key: String): notices.append(key))
	player.inventory.remove("short_bow")
	_check(not player.fire_ranged("shoot") and notices == ["UI_NEED_BOW"], "an arrow can't be shot without a bow")
	player.inventory.add("short_bow")
	var quiver := player.inventory.count("arrow")
	player.inventory.remove("arrow", quiver)
	_check(not player.fire_ranged("shoot") and notices.back() == "UI_NO_ARROW", "an empty quiver can't shoot")
	for key in ["UI_NEED_BOW", "UI_NO_ARROW", "UI_NO_FIRE_FLASK", "ITEM_SHORT_BOW", "ITEM_ARROW", "ITEM_FIRE_FLASK"]:
		TranslationServer.set_locale("de")
		var german := tr(key)
		TranslationServer.set_locale("en")
		_check(german != key and german != tr(key) and tr(key) != key, "%s has English and German text" % key)

	# Crafted bows and arrows.
	for recipe_id in ["make_arrows", "make_short_bow", "make_long_bow"]:
		var found := false
		for recipe in CraftingData.recipes_for("anvil"):
			found = found or recipe["id"] == recipe_id
		_check(found, "%s is an anvil recipe" % recipe_id)
	for key in ["ITEM_LONG_BOW", "SLOT_LIMB"]:
		TranslationServer.set_locale("de")
		var german_text := tr(key)
		TranslationServer.set_locale("en")
		_check(german_text != key and german_text != tr(key) and tr(key) != key, "%s has English and German text" % key)
	_check(CraftingData.ranged_multiplier("short_bow") == 1.0, "a plain short bow shoots at the base damage")
	_check(CraftingData.ranged_multiplier("long_bow") > 1.0, "a long bow hits harder than a short bow")
	_check(CraftingData.ranged_multiplier("short_bow", "fine") > CraftingData.ranged_multiplier("short_bow", "crude"), "a finer bow hits harder")
	_check(CraftingData.ranged_multiplier("arrow", "masterwork") > CraftingData.ranged_multiplier("arrow"), "a better arrow hits harder")
	var held := Inventory.new()
	held.add("arrow", 1, "crude")
	held.add("arrow", 1, "fine")
	_check(is_equal_approx(held.take_best_ranged("arrow"), CraftingData.ranged_multiplier("arrow", "fine")) and held.count("arrow") == 1, "the best arrow is used first")
	_check(held.take_best_ranged("arrow") > 0.0 and held.take_best_ranged("arrow") == 0.0, "an empty quiver gives no arrow")
	var weak_arrow := Projectile.launch("arrow", Vector3.ZERO, Vector3.FORWARD, null, 0.5)
	_check(is_equal_approx(weak_arrow.damage, float(Projectile.stats("arrow")["damage"]) * 0.5), "projectile damage follows the multiplier")
	weak_arrow.free()
	player.inventory.remove("short_bow")
	player.inventory.remove("arrow", player.inventory.count("arrow"))
	player.inventory.add("long_bow", 1, "fine")
	player.inventory.add("arrow", 3, "common")
	_check(player.fire_ranged("shoot") and player.inventory.count("arrow") == 2, "a crafted long bow shoots arrows")
	var shot: Projectile = root.get_tree().get_nodes_in_group(Projectile.GROUP).back()
	var expected := float(Projectile.stats("arrow")["damage"]) * CraftingData.ranged_multiplier("long_bow", "fine") * CraftingData.ranged_multiplier("arrow", "common")
	_check(is_equal_approx(shot.damage, expected), "the shot's damage comes from the bow and arrow quality")
	await _physics_frames(90)
	player.inventory.remove("long_bow")
	player.inventory.remove("arrow", player.inventory.count("arrow"))
	player.inventory.add("short_bow")

	_write_flags(TEST_FLAGS_A, { "flags": { "ranged_weapons": false } })
	FeatureFlags.load_layers([TEST_FLAGS_A])
	player.inventory.add("arrow", 2)
	_check(not player.fire_ranged("shoot") and player.inventory.count("arrow") == 2, "turning ranged weapons off stops shooting")
	FeatureFlags.load_layers()
	player.inventory.remove("arrow", 2)
	player.inventory.add("arrow", quiver)

	for projectile in root.get_tree().get_nodes_in_group(Projectile.GROUP):
		projectile.queue_free()
	dummy.remove_from_group(Enemy.GROUP)
	dummy.queue_free()
	await _physics_frames(2)


## Ground near the village that is level for 12 m around, away from the river, or Vector3.INF.
func _flat_open_spot(terrain: Terrain, player: Player) -> Vector3:
	for ring in range(0, 400, 10):
		for step in 16:
			var angle := TAU * step / 16.0
			var x := cos(angle) * ring
			var z := sin(angle) * ring
			var level := true
			for dx in [-12.0, 0.0, 12.0]:
				for dz in [-12.0, 0.0, 12.0]:
					level = level and absf(terrain.height_at(x + dx, z + dz) - terrain.height_at(x, z)) < 0.5 and terrain.river_clearance(x + dx, z + dz) > 5.0
			if level and not _blocked_above(terrain, Vector3(x, terrain.height_at(x, z), z)):
				return Vector3(x, terrain.height_at(x, z), z)
	return Vector3.INF


## Whether anything but the terrain stands within 12 m of this point at chest height, so that a shot there could be stopped.
func _blocked_above(terrain: Terrain, point: Vector3) -> bool:
	var space := terrain.get_world_3d().direct_space_state
	for offset in [Vector3(12, 0, 0), Vector3(-12, 0, 0), Vector3(0, 0, 12), Vector3(0, 0, -12)]:
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point + Vector3.UP + offset)
		if not space.intersect_ray(query).is_empty():
			return true
	return false


func _test_ambient_life(scene: Node, day_night: DayNight) -> void:
	var ambient: AmbientLife = scene.get_node_or_null("Village/AmbientLife")
	_check(ambient != null, "ambient life is added when its flag is on")
	if ambient == null:
		return
	var kinds := ambient.find_children("*", "MultiMeshInstance3D", false, false)
	_check(kinds.size() == 3, "birds, butterflies, and fireflies are one MultiMesh each")
	_check(ambient.find_children("*", "CollisionObject3D", true, false).is_empty() and kinds.all(func(kind): return kind.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), "ambient life has no collision and casts no shadows")
	var full := ambient.full_counts()
	_check(full["birds"] + full["butterflies"] + full["fireflies"] <= 150, "ambient life stays within its count budget")
	var player: Player = scene.get_node("Player")
	var saved_hour := day_night.hour
	var saved_graphics := Settings.graphics
	day_night.hour = 12.0
	ambient.update_around(player.global_position)
	var by_day := ambient.drawn_counts()
	_check(by_day["birds"] > 0 and by_day["butterflies"] > 0 and by_day["fireflies"] == 0, "birds and butterflies fly by day and fireflies sleep")
	day_night.hour = 0.0
	ambient.update_around(player.global_position)
	var by_night := ambient.drawn_counts()
	_check(by_night["birds"] == 0 and by_night["butterflies"] == 0 and by_night["fireflies"] > 0, "fireflies glow at night and the others sleep")
	var terrain: Terrain = scene.get_node("Terrain")
	var on_lush_ground := true
	for index in ambient._fireflies.shown:
		var home := ambient._fireflies.anchors[index]
		if ambient._fireflies.settled[index] and terrain.river_clearance(home.x, home.z) < 0.0:
			on_lush_ground = false
	_check(on_lush_ground, "fireflies never settle in the river")
	var lush := 0
	var settled := 0
	day_night.hour = 12.0
	ambient.update_around(player.global_position)
	for index in ambient._butterflies.shown:
		if ambient._butterflies.settled[index]:
			var home := ambient._butterflies.anchors[index]
			settled += 1
			if Surfaces.ground_dryness(home.x, home.z) <= AmbientLife.LUSH_DRYNESS:
				lush += 1
	_check(lush == settled, "butterflies stay over lush grass (%d of %d)" % [lush, settled])
	Settings.graphics = "low"
	await process_frame
	ambient._process(0.0)
	var low := ambient.drawn_counts()
	Settings.graphics = "high"
	ambient._process(0.0)
	var high := ambient.drawn_counts()
	_check(low["birds"] < high["birds"] and low["butterflies"] < high["butterflies"], "lower graphics show fewer creatures")
	Settings.graphics = saved_graphics
	ambient._process(0.0)
	day_night.hour = saved_hour


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


func _test_data_validation() -> void:
	var problems := DataValidator.validate_directory()
	_check(problems.is_empty(), "all data files are valid: %s" % [problems])
	var files := {}
	for file in DataValidator.FILES:
		files[file] = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + file))
	var broken := files.duplicate(true)
	broken["crafting.json"]["recipes"][6]["inputs"]["iron_ingott"] = 1
	broken["crafting.json"]["items"]["torch"].erase("name")
	broken["quests.json"]["arrival"]["objectives"][0]["marker"] = "nobody"
	broken["dialogue.json"]["hedda"][0]["when"]["objective"] = ["arrival", "see_nobody"]
	broken["dialogue.json"]["hedda"][0]["nodes"]["send"]["effects"][0]["quest"] = "no_quest"
	broken["dialogue.json"]["hedda"][0]["nodes"]["how_bad"]["next"] = "nowhere"
	broken["dialogue.json"]["stranger"] = []
	broken["enemies.json"]["goblin"]["drops"][0]["item"] = "gold"
	broken["enemies.json"]["goblin"]["health"] = "lots"
	broken["village_layout.json"]["enemies"][0]["type"] = "dragon"
	broken["villager_routines.json"]["bertram"][1].erase("z")
	broken["village_layout.json"]["mine"].erase("opening_width")
	broken["projectiles.json"]["arrow"]["ammo_item"] = "arrows"
	broken["crafting.json"]["items"]["berries"]["use"]["heal"] = 0
	broken["village_layout.json"]["walls"][0]["kind"] = "hedge"
	broken["notes.json"]["village_sign"]["type"] = "scroll"
	broken["notes.json"]["mine_notice"].erase("text")
	broken["village_layout.json"]["readables"][0]["note"] = "lost_note"
	broken["village_layout.json"]["readables"][1]["model"] = "tombstone"
	var found := DataValidator.new().validate_files(broken)
	for expected in [
		"crafting.json: recipes[forge_axe]", "crafting.json: items[torch]: missing \"name\"", "quests.json: [arrival].objectives[see_grandmother].marker: unknown marker place \"nobody\"",
		"dialogue.json: hedda[0].when.objective", "dialogue.json: hedda[0].nodes[send].effects[0].quest: unknown quest \"no_quest\"",
		"dialogue.json: hedda[0].nodes[how_bad].next", "dialogue.json: [stranger]: unknown villager", "enemies.json: [goblin].drops[0].item: unknown item \"gold\"",
		"enemies.json: [goblin].health", "village_layout.json: enemies[0].type", "village_layout.json: mine: missing \"opening_width\"", "villager_routines.json: [bertram][1]: a stop needs both", "projectiles.json: [arrow].ammo_item",
		"crafting.json: items[berries].use.heal", "notes.json: [village_sign].type", "notes.json: [mine_notice]: missing \"text\"",
		"village_layout.json: readables[lost_note].note: unknown text \"lost_note\"", "village_layout.json: readables[notice_board].model",
		"village_layout.json: walls[0].kind",
	]:
		_check(found.any(func(line: String) -> bool: return line.begins_with(expected) or line.contains(expected)), "the validator reports: %s" % expected + ("" if found.any(func(line: String) -> bool: return line.contains(expected)) else " (got %s)" % [found]))
	var empty := DataValidator.new().validate_files({ "quests.json": [] })
	_check(not empty.is_empty(), "a data file of the wrong kind is reported")


## Signs, notes, and books in the world (#268): data, placement, the reading panel, and the journal.
func _test_readables(scene: Node, player: Player) -> void:
	var village: Village = scene.get_node("Village")
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Village.LAYOUT_PATH))
	var texts := Readables.all()
	_check(FeatureFlags.enabled("readables") and texts.size() >= 5, "there are at least five readable texts")
	var placed := {}
	var every_text_has_both_languages := true
	var types_known := true
	for note_id: String in texts:
		var entry: Dictionary = texts[note_id]
		types_known = types_known and Readables.TYPES.has(entry["type"])
		for key: String in [entry["title"], entry["text"]]:
			TranslationServer.set_locale("en")
			var english := TranslationServer.translate(key)
			TranslationServer.set_locale("de")
			var german := TranslationServer.translate(key)
			every_text_has_both_languages = every_text_has_both_languages and english != key and german != key and english != german
	TranslationServer.set_locale("en")
	_check(every_text_has_both_languages and types_known, "every readable has a title and text in English and German, and a known kind")
	for spot: Dictionary in layout["readables"]:
		placed[spot["note"]] = true
		var node := village.get_node_or_null(String(spot["note"])) as Readable
		_check(node != null and node.note_id == spot["note"] and node.is_in_group(Interactable.GROUP), "the readable %s stands in the world and can be used" % spot["note"])
	_check(placed.size() == texts.size() and placed.size() >= 5, "every text is placed in the village")
	_check(placed.has("grandfather_letter") and placed.has("notice_board") and placed.has("village_sign") and placed.has("mine_notice"), "the first set includes the village sign, the notice board, the mine note, and Grandfather's letter")
	var types := {}
	for note_id: String in texts:
		types[texts[note_id]["type"]] = true
	_check(types.size() == 3, "there are signs, notes, and books")
	var sign_node: Readable = village.get_node("village_sign")
	_check(sign_node.prompt() == "Read the sign" and (village.get_node("grandfather_letter") as Readable).prompt() == "Read the note" and (village.get_node("village_chronicle") as Readable).prompt() == "Read the book", "each kind of readable has its own prompt")
	_check(sign_node.find_children("*", "MeshInstance3D", true, false).size() == 1 and sign_node.find_children("*", "CollisionShape3D", true, false).size() == 1, "a readable is built in code as one mesh with a collision shape")
	for model: String in ModelBuilder.READABLE_MODELS:
		var built := ModelBuilder.readable(model, Village.READABLE_SIZES[model])
		_check(built.find_children("*", "MeshInstance3D", true, false).size() >= 1, "the %s model is built" % model)
		built.free()

	# Reading.
	var ui: ReadingUI = scene.get_node("ReadingUI")
	var saved_text_size := Settings.text_size
	player.notes.load_data([])
	player.quests.flags.erase("read_grandfather_letter")
	_check(ui != null and not ui.is_open(), "the reading panel starts closed")
	(village.get_node("grandfather_letter") as Readable).interact(player)
	await process_frame
	_check(ui.is_open() and player.is_busy() and scene.get_tree().paused, "using a letter opens the reading panel and pauses the game")
	_check(_all_text(ui).contains("Anselm") and _all_text(ui).contains(tr("NOTE_GRANDFATHER_LETTER_TITLE")), "the panel shows the title and the text")
	_check(ui.get_viewport().gui_get_focus_owner() != null and ui.is_ancestor_of(ui.get_viewport().gui_get_focus_owner()), "the close button has the focus, so a controller can close the panel")
	_check(player.notes.has("grandfather_letter") and player.notes.count() == 1, "the first reading adds the text to the journal's notes")
	_check(player.quests.flags.has("read_grandfather_letter"), "a text can set a story flag")
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	ui._input(down)
	var read_again := InputEventAction.new()
	read_again.action = "interact"
	read_again.pressed = true
	ui._input(read_again)
	_check(not ui.is_open() and not player.is_busy() and not scene.get_tree().paused, "the interact key closes the panel and resumes the game")
	(village.get_node("grandfather_letter") as Readable).interact(player)
	_check(ui.is_open() and player.notes.count() == 1, "reading again doesn't add the note twice")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	ui._input(cancel)
	_check(not ui.is_open() and not scene.get_tree().paused, "cancel closes the panel")
	ui.open_note("village_sign", player)
	ui._close_button.pressed.emit()
	_check(not ui.is_open() and player.notes.count() == 2, "the close button closes the panel, and a sign is noted too")
	ui.open_note("no_such_text", player)
	_check(not ui.is_open() and not player.is_busy(), "an unknown text opens nothing")

	# Text size and high contrast follow the settings.
	Settings.text_size = 1.5
	ui.open_note("notice_board", player)
	_check(ui._title.get_theme_font_size("font_size") == Settings.scaled_font_size(ReadingUI.TITLE_FONT_SIZE), "the panel follows the text size setting")
	ui.close()
	Settings.text_size = saved_text_size
	var saved_contrast := Settings.high_contrast
	Settings.high_contrast = true
	Accessibility.apply_theme()
	ui.open_note("notice_board", player)
	_check(ui._text.theme_type_variation == &"InkLabel" and ui._text.get_theme_color("font_color").get_luminance() < 0.2, "high contrast draws the text in plain black ink on the page")
	ui.close()
	Settings.high_contrast = saved_contrast
	Accessibility.apply_theme()

	# The journal shows what was read, in the language chosen, and it survives a save.
	var journal: Journal = scene.get_node("Journal")
	journal.open()
	journal.select_tab(Journal.TAB_NOTES)
	_check(_all_text(journal).contains(tr("NOTE_VILLAGE_SIGN_TITLE")) and _all_text(journal).contains(tr("NOTE_GRANDFATHER_LETTER_TITLE")), "the journal's notes tab lists what was read")
	journal.close()
	var restored := JournalNotes.new()
	restored.load_data(JSON.parse_string(JSON.stringify(player.notes.to_data())))
	_check(restored.count() == player.notes.count() and restored.has("grandfather_letter"), "read texts survive a save")
	TranslationServer.set_locale("de")
	_check(restored.entries().any(func(note: Dictionary) -> bool: return note["title"] == "Ein Brief von Großvater"), "a read text shows in German when the language changes")
	TranslationServer.set_locale("en")
	player.notes.load_data([])
	player.quests.flags.erase("read_grandfather_letter")


func _test_rain_cover(scene: Node, weather: Weather) -> void:
	var camera := scene.get_viewport().get_camera_3d()
	_check(camera != null, "there is a camera to keep the rain dry under a roof")
	if camera == null:
		return
	var spot := Vector3(2000.0, 500.0, 2000.0)
	var roof := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 0.3, 6.0)
	shape.shape = box
	roof.add_child(shape)
	roof.position = spot + Vector3(0.0, 3.0, 0.0)
	scene.add_child(roof)
	await scene.get_tree().physics_frame
	await scene.get_tree().physics_frame
	_check(weather.is_covered(spot), "a roof overhead covers the spot under it")
	_check(not weather.is_covered(spot + Vector3(20.0, 0.0, 0.0)), "open ground beside the roof is not covered")
	_check(not weather.is_covered(spot + Vector3(0.0, 4.0, 0.0)), "above the roof is not covered")
	var saved_transform := camera.global_transform
	camera.global_position = spot
	weather.set_state("rain")
	weather._cover_timer = 0.0
	for step in 20:
		weather._update_cover(0.2)
	_check(weather.cover == 1.0 and not weather.rain_particles().emitting, "the rain stops under a roof")
	camera.global_position = spot + Vector3(20.0, 0.0, 0.0)
	weather._cover_timer = 0.0
	for step in 20:
		weather._update_cover(0.2)
	_check(weather.cover == 0.0 and weather.rain_particles().emitting, "the rain comes back in the open")
	camera.global_transform = saved_transform
	roof.queue_free()
	weather._push()


## Seen from outside, rain must stop at roofs and bridge decks (#312): the rain shader reads a coarse map.
func _test_rain_roofs(scene: Node, weather: Weather) -> void:
	var terrain: Terrain = scene.get_node("Terrain")
	var village: Village = scene.get_node("Village")
	weather.refresh_roofs()
	var hall_top := weather.roof_height_at(0.0, -28.0)
	var hall_floor := terrain.height_at(0.0, -28.0)
	_check(hall_top > hall_floor + 6.0 and hall_top < hall_floor + 6.0 + ModelBuilder.ROOF_HEIGHT + 0.01, "rain stops at the town hall roof (%.1f over %.1f)" % [hall_top, hall_floor])
	_check(weather.roof_height_at(0.0, -34.0) < hall_top and weather.roof_height_at(0.0, -34.0) > hall_floor + 6.0 or weather.roof_height_at(0.0, -34.0) == RoofMap.NONE, "the roof slopes down to its eaves")
	_check(weather.roof_height_at(0.0, -10.0) == RoofMap.NONE and weather.roof_height_at(300.0, 300.0) == RoofMap.NONE, "open ground has no roof over it")
	_check(weather.roof_height_at(-36.0, 28.0) == RoofMap.NONE, "a ruined house keeps no rain off")
	var bridge_covers := village.roof_covers.filter(func(cover: Dictionary) -> bool: return cover["shape"] == "arch")
	_check(not bridge_covers.is_empty(), "bridges are in the rain map")
	for cover: Dictionary in bridge_covers:
		var middle: Vector2 = cover["center"]
		_check(weather.roof_height_at(middle.x, middle.y) > cover["base"], "rain stops at a bridge deck")
	_check(weather.roof_height_at(25.0, -14.0) == RoofMap.NONE, "the inn's broken roof lets the rain in")
	village.apply_flags({ "inn_roof_repaired": true })
	weather.refresh_roofs()
	_check(weather.roof_height_at(25.0, -14.0) > terrain.height_at(25.0, -14.0) + 5.0, "a repaired roof keeps the rain off")
	village.apply_flags({})
	weather.refresh_roofs()
	_check(weather.roof_height_at(25.0, -14.0) == RoofMap.NONE, "the map follows the roof back to broken")
	# The mine's mouth and the goblin tents keep the rain off too (#337).
	var mine: Mine = village.find_children("*", "Mine", true, false)[0]
	var mine_cover := mine.roof_cover()
	var mouth: Vector2 = mine_cover["center"]
	_check(village.roof_covers.has(mine_cover) and weather.roof_height_at(mouth.x, mouth.y) > float(mine_cover["base"]) - 0.01, "rain stops over the mine mouth")
	_check(weather.roof_height_at(mouth.x, mouth.y + 12.0) == RoofMap.NONE, "the plaza in front of the mine is open sky")
	var tent_covers := village.roof_covers.filter(func(cover: Dictionary) -> bool: return cover["shape"] == "ridge" and cover["rise"] > 0.0 and not cover.has("repaired_by_flag") and (cover["center"] as Vector2).distance_to(Vector2(117.0, -152.0)) < 20.0)
	_check(tent_covers.size() == 2, "the goblin tents are in the rain map")
	for cover: Dictionary in tent_covers:
		var tent: Vector2 = cover["center"]
		_check(weather.roof_height_at(tent.x, tent.y) > cover["base"], "rain stops at a goblin tent")
	var drop_material: ShaderMaterial = weather.rain_particles().draw_pass_1.material
	_check(drop_material.get_shader_parameter("roof_size") == weather._roof_map.size, "the rain shader gets the roof map")


func _test_weather(scene: Node, day_night: DayNight) -> void:
	var weather: Weather = scene.get_node_or_null("Weather")
	_check(weather != null and FeatureFlags.enabled("weather"), "weather is added when its flag is on")
	if weather == null:
		return
	var sun: DirectionalLight3D = scene.get_node("Sun")
	var dome: SkyDome = scene.get_node("SkyDome")
	var environment: Environment = scene.get_node("WorldEnvironment").environment
	var saved_hour := day_night.hour
	day_night.hour = 12.0
	weather.set_state("clear")
	day_night._apply()
	var clear_energy := sun.light_energy
	var clear_fog := environment.fog_density
	var clear_coverage: float = dome.material_override.get_shader_parameter("cloud_coverage")
	var clear_top: Color = environment.sky.sky_material.sky_top_color
	_check(weather.rain_particles().emitting == false, "no rain falls under a clear sky")
	weather.set_state("rain")
	day_night._apply()
	_check(sun.light_energy < clear_energy * 0.5, "rain dims the sun")
	_check(environment.fog_density > clear_fog, "rain thickens the fog")
	_check(dome.material_override.get_shader_parameter("cloud_coverage") > clear_coverage, "rain thickens the clouds")
	_check(environment.sky.sky_material.sky_top_color.v < clear_top.v, "rain darkens the sky")
	_check(weather.rain_particles().emitting, "rain falls in the rain")
	_check(scene.get_node("Village/Grass")._material.get_shader_parameter("wind_strength") > 0.6, "the wind shakes the grass in the rain")
	await _test_rain_cover(scene, weather)
	_test_rain_roofs(scene, weather)
	var rain_nodes := weather.find_children("*", "GPUParticles3D", true, false)
	_check(rain_nodes.size() == 1 and weather.get_child_count() == 1, "rain is one particle system")
	weather.set_quality("low")
	var low_amount: int = weather.rain_particles().amount
	weather.set_quality("high")
	_check(low_amount < weather.rain_particles().amount, "lower graphics draw less rain")
	weather.set_quality(Settings.graphics)
	# The weather blends instead of jumping.
	weather.set_state("clear", false)
	weather.update(1.0)
	_check(weather.rain < 1.0 and weather.rain > 0.0 and weather.overcast > 0.0, "weather blends smoothly")
	for step in 40:
		weather.update(1.0)
	_check(weather.rain == 0.0 and weather.overcast == 0.0, "weather settles into the new state")
	# Every state leads somewhere, at every roll.
	var leads_on := true
	for from: String in Weather.STATES:
		for roll in [0.0, 0.3, 0.7, 1.0]:
			leads_on = leads_on and Weather.STATES.has(Weather.pick_next(from, roll)) and Weather.pick_next(from, roll) != from
	_check(leads_on, "weather always changes to another known state")
	# The weather is saved and loaded.
	weather.set_state("rain")
	var player: Player = scene.get_node("Player")
	var village: Village = scene.get_node("Village")
	SaveGame.write(TEST_SAVE, player, day_night, village)
	weather.set_state("clear")
	_check(SaveGame.apply(TEST_SAVE, player, day_night, village) and weather.state == "rain" and weather.rain == 1.0, "the weather is saved and loaded")
	weather.load_data({})
	_check(weather.state == "rain", "a save without weather leaves it as it is")
	weather.set_state("clear")
	day_night.hour = saved_hour
	day_night._apply()


## The camp's goblins, which the movement tests use. Other enemy types live elsewhere.
func _goblins() -> Array[Node]:
	var result: Array[Node] = []
	for node in root.get_tree().get_nodes_in_group(Enemy.GROUP):
		if node.enemy_type == "goblin":
			result.append(node)
	return result


## The enemy's health bar and wind-up warning don't depend on color, and follow the palette.
func _test_enemy_accessibility(scene: Node) -> void:
	var enemy := Enemy.new()
	enemy.setup("goblin", Vector3(0.0, 100.0, 0.0))
	scene.add_child(enemy)
	var saved_mode := Settings.colour_vision
	Settings.colour_vision = "off"
	var plain := Enemy.bar_image(0.5)
	Settings.colour_vision = "protanopia"
	var coloured := Enemy.bar_image(0.5)
	Settings.colour_vision = saved_mode
	var inner_y := Enemy.BAR_PIXELS.y / 2
	_check(plain.get_pixel(0, inner_y) == Enemy.BAR_FRAME_COLOR and plain.get_pixel(Enemy.BAR_PIXELS.x / 2, 1) == Enemy.BAR_TICK_COLOR, "the enemy health bar has a frame and ticks")
	_check(coloured.get_pixel(3, 1) != plain.get_pixel(3, 1) or coloured.get_pixel(4, 1) != plain.get_pixel(4, 1), "the enemy health bar follows the colour vision palette")
	_check(Enemy.bar_image(1.0).get_pixel(Enemy.BAR_PIXELS.x - 3, 3) != Enemy.bar_image(0.0).get_pixel(Enemy.BAR_PIXELS.x - 3, 3), "the enemy health bar fill shows how much health is left without color")
	enemy.state = Enemy.State.WINDUP
	enemy._update_color(0.016)
	_check(enemy._warning.visible, "an enemy winding up shows a warning mark")
	enemy.state = Enemy.State.IDLE
	enemy._update_color(0.016)
	_check(not enemy._warning.visible, "the warning mark goes away after the wind-up")
	_check(Accessibility.color("warning") != Accessibility.color("enemy"), "the warning and the enemy bar differ in color")
	for mode: String in Accessibility.MODES:
		_check(Accessibility.PALETTES[mode]["warning"] != Accessibility.PALETTES[mode]["enemy"], "the %s palette tells the wind-up warning from the enemy bar" % mode)
	enemy.free()
	await process_frame


## The noticing rules, the sneak look, and the visibility indicator (#207).
func _test_noticing_rules(scene: Node, player: Player, enemy: Enemy, day_night: DayNight) -> void:
	var base := float(enemy._stats["aggro_range"])
	enemy.revive()
	player.position = enemy.position + Vector3(0.0, 0.3, 8.0)
	enemy.rotation.y = PI
	day_night.hour = 12.0
	await _physics_frames(3)
	enemy.state = Enemy.State.IDLE
	var standing := Noticing.player_factor(player)
	_check(is_equal_approx(standing, float(FeatureFlags.value("still_notice_factor"))), "standing still in daylight is noticed from the still share of the range")
	_check(is_equal_approx(Noticing.facing_factor(Vector3.FORWARD, Vector3.FORWARD), 1.0), "an enemy facing the player notices in full")
	_check(is_equal_approx(Noticing.facing_factor(Vector3.FORWARD, Vector3.BACK), float(FeatureFlags.value("notice_back_factor"))), "from behind an enemy notices less far")
	_check(Noticing.facing_factor(Vector3.FORWARD, Vector3(1.0, 0.0, -0.2)) == 1.0, "the side of the front cone still counts as seen")

	# Looking away: noticed from less far, so not at 8 m.
	enemy.rotation.y = 0.0
	_check(is_equal_approx(enemy.notice_range(player), base * standing * float(FeatureFlags.value("notice_back_factor"))), "an enemy facing away notices a standing player from less far")
	_check(enemy.notice_range(player) < 8.0, "a goblin facing away doesn't notice a player 8 m behind it")
	# Right next to it, it hears them whichever way it faces.
	player.position = enemy.position + Vector3(0.0, 0.3, 2.0)
	_check(is_equal_approx(Noticing.enemy_factor(enemy, player), 1.0), "closer than the close range an enemy notices from any side")
	player.position = enemy.position + Vector3(0.0, 0.3, 8.0)
	enemy.rotation.y = PI

	# Something solid in the way.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 10.0, 0.5)
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = 1
	enemy.get_parent().add_child(wall)
	wall.global_position = enemy.global_position + Vector3(0.0, 1.0, 4.0)
	await _physics_frames(2)
	_check(Noticing.is_blocked(enemy, player), "a wall between them blocks the view")
	_check(is_equal_approx(Noticing.enemy_factor(enemy, player), float(FeatureFlags.value("notice_blocked_factor"))), "a blocked view shortens the noticing range")
	wall.queue_free()
	await _physics_frames(2)
	_check(not Noticing.is_blocked(enemy, player), "the view is clear again without the wall")

	# Light: dark at night, and a lit torch shows.
	day_night.hour = 1.0
	var dark := Noticing.light_factor(player)
	player.torch_lit = true
	var lit := Noticing.light_factor(player)
	player.torch_lit = false
	day_night.hour = 12.0
	_check(is_equal_approx(dark, float(FeatureFlags.value("night_notice_factor"))), "the night makes the player harder to see")
	_check(lit > dark and lit > 1.0 - 0.001, "a lit torch makes the player easier to see at night")
	player.torch_lit = true
	_check(Noticing.light_factor(player) < lit, "a torch shows less in daylight")
	player.torch_lit = false

	# The indicator and the sneak look.
	Input.action_press("sneak")
	await _physics_frames(5)
	var indicator := (scene.get_node("UI") as HudLayout).visibility_indicator
	_check(indicator != null and indicator.visible, "the visibility indicator shows while sneaking")
	_check(Noticing.level(player) == 0, "a standing sneaking player in daylight is hidden")
	Input.action_press("move_forward")
	await _physics_frames(30)
	_check(Noticing.level(player) == 1, "a sneaking player on the move is cautious")
	if player._body_mesh is CharacterModel:
		var model := player._body_mesh as CharacterModel
		_check(model.crouched and model._player.current_animation == CharacterModel.CROUCH_WALK, "sneaking walks in a crouch")
		_check(model._player.speed_scale < 1.0, "the crouch walk cycle is slower")
	Input.action_release("move_forward")
	await _physics_frames(30)
	if player._body_mesh is CharacterModel:
		_check((player._body_mesh as CharacterModel)._player.current_animation == CharacterModel.CROUCH_IDLE, "a standing sneaking player crouches")
	Input.action_release("sneak")
	await _physics_frames(5)
	_check(not indicator.visible, "the visibility indicator hides when not sneaking")
	for new_level in 3:
		indicator.update_from(new_level, 0.5)
		for high_contrast in [false, true]:
			Settings.high_contrast = high_contrast
			indicator.queue_redraw()
			await _physics_frames(1)
	Settings.high_contrast = false
	_check(tr("UI_SNEAK_SEEN") != "UI_SNEAK_SEEN", "the indicator words are translated")
	_check(indicator.level_color(0) != indicator.level_color(2), "the indicator levels differ in colour")
	Settings.colour_vision = "deuteranopia"
	_check(indicator.level_color(0) != indicator.level_color(2), "the indicator levels differ in colour for colour vision modes")
	Settings.colour_vision = "off"

	# The rules turn off, leaving only the sneak factor.
	FeatureFlags._flags["noticing_rules"] = false
	enemy.rotation.y = 0.0
	_check(is_equal_approx(enemy.notice_range(player), base), "with the rules off, a standing player is noticed from the full range")
	FeatureFlags._flags["noticing_rules"] = true
	enemy.rotation.y = PI
