extends SceneTree
## Performance regression check: measures the village from a fixed camera path and compares it with tests/perf_budgets.json.
##
## Run with: godot --headless --path . --script res://tests/perf_check.gd
##
## Options, after `--`:
##   --update-budgets   write the measured values (plus headroom) to tests/perf_budgets.json
##   --out=PATH         also write the measured metrics as JSON to PATH, to compare runs
##   --no-render        skip the measured frames even if a display is available
##   --gate-frame-time  also fail when frame times exceed their budgets (machine dependent)
##
## Headless Godot has a dummy renderer, so draw calls, primitives and frame time read zero. There
## the check counts what produces them: nodes, meshes, mesh surfaces (each is at least one draw call,
## plus one per shadow), MultiMesh instances, and triangles in the scene. Those are deterministic,
## so they are gated. With a display (e.g. `DISPLAY=:0 godot --path . --script res://tests/perf_check.gd`)
## the check also renders the path and reports real draw calls, primitives and frame times.
## Draw calls and primitives are gated against their budgets. Frame time depends on the machine,
## so it is only printed unless --gate-frame-time is given.

const BUDGETS_PATH := "res://tests/perf_budgets.json"
## Fraction added to the measured values when writing new budgets.
const HEADROOM := 0.10
## Rendered runs vary a little (the grass grows on worker threads), so they get more.
const RENDERED_HEADROOM := 0.25
## Metrics that are stable enough to gate in a rendered run. Counts of scene contents are only recorded there.
const RENDERED_GATED := ["draw_calls", "primitives"]
const SETTLE_FRAMES := 30
## Metrics of the fixed path searches, which are the same with or without a renderer.
const SEARCH_POINT := "path_search"
## Fixed searches (x, z of the start and the goal) of an enemy body: along the road, around the
## buildings, across the river, and out toward the forest. The grids are forgotten before each, so
## the cost includes checking every cell the search looks at (#142, #148, #227).
const SEARCHES := [
	{"name": "road_to_square", "from": Vector2(0.0, 60.0), "to": Vector2(0.0, -10.0)},
	{"name": "around_town_hall", "from": Vector2(-12.0, -20.0), "to": Vector2(12.0, -36.0)},
	{"name": "around_forge", "from": Vector2(8.0, 8.0), "to": Vector2(24.0, 20.0)},
]
## Another search goes over the first bridge, from this far before it to this far beyond it.
const BRIDGE_REACH := 12.0
const SEARCH_RADIUS := 0.4
const SEARCH_ARRIVE := 0.5
const MEASURED_FRAMES := 60
## Camera positions (x, z) at eye height, and the direction they look in, in degrees.
const PATH := [
	{"name": "road_entrance", "x": 0.0, "z": 60.0, "yaw": 0.0},
	{"name": "village_center", "x": 0.0, "z": -28.0, "yaw": 180.0},
	{"name": "village_across_river", "x": 30.0, "z": 5.0, "yaw": 90.0},
	{"name": "village_edge_forest", "x": -60.0, "z": -60.0, "yaw": 225.0},
]

var _failures := 0
var _gate_frame_time := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var update := "--update-budgets" in args
	_gate_frame_time = "--gate-frame-time" in args
	var render := DisplayServer.get_name() != "headless" and not "--no-render" in args
	var out_path := ""
	for arg in args:
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")

	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.show_menu = false
	scene.save_path = "user://perf_check_save.json"
	root.add_child(scene)
	for i in 90:
		await physics_frame
	var terrain: Terrain = scene.get_node("Terrain")
	var camera := Camera3D.new()
	camera.far = 600.0
	scene.add_child(camera)
	camera.make_current()

	var results := {"renderer": DisplayServer.get_name(), "rendered": render, "points": {}}
	for point: Dictionary in PATH:
		camera.global_position = Vector3(point["x"], terrain.height_at(point["x"], point["z"]) + 1.7, point["z"])
		camera.rotation = Vector3(0.0, deg_to_rad(point["yaw"]), 0.0)
		for i in SETTLE_FRAMES:
			await process_frame
		var metrics := _count_scene(scene, camera.global_position)
		if render:
			metrics.merge(await _measure_frames())
		results["points"][point["name"]] = metrics

	results["points"][SEARCH_POINT] = await _measure_searches(scene, terrain)

	print(JSON.stringify(results, "\t"))
	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(results, "\t") + "\n")
		file.close()

	if update:
		_write_budgets(results)
	else:
		_check_budgets(results)
	scene.queue_free()
	await process_frame
	print("perf check: %s" % ("FAILED" if _failures > 0 else "PASSED"))
	quit(1 if _failures > 0 else 0)


## Runs the fixed searches and counts their work: the search steps (cells expanded), the cells
## checked against the physics world, and how many frames the step budget spreads each over.
func _measure_searches(scene: Node, terrain: Terrain) -> Dictionary:
	var walker := CharacterBody3D.new()
	scene.add_child(walker)
	var metrics := {}
	var total_steps := 0
	var searches: Array = SEARCHES.duplicate()
	var bridge := scene.get_node("Village").find_child("Bridge*", false, false) as Node3D
	var along := Vector2(sin(bridge.rotation.y), cos(bridge.rotation.y))
	var middle := Vector2(bridge.position.x, bridge.position.z)
	searches.append({"name": "over_bridge", "from": middle - along * BRIDGE_REACH, "to": middle + along * BRIDGE_REACH})
	for search: Dictionary in searches:
		EnemyPath.forget_all()
		var path := EnemyPath.new(walker, SEARCH_RADIUS)
		var from: Vector2 = search["from"]
		var to: Vector2 = search["to"]
		path.begin(Vector3(from.x, terrain.height_at(from.x, from.y) + 0.1, from.y), Vector3(to.x, terrain.height_at(to.x, to.y) + 0.1, to.y), SEARCH_ARRIVE)
		var frames := 1
		while not path.advance():
			await physics_frame
			frames += 1
		print("search %s reached %s steps %s" % [search["name"], path.reached, path._expanded])
		_check(path.reached, "the search %s reaches its goal" % search["name"])
		metrics["%s_steps" % search["name"]] = path._expanded
		metrics["%s_cells" % search["name"]] = path._cells.size()
		metrics["%s_frames" % search["name"]] = frames
		total_steps += path._expanded
	metrics["search_steps_total"] = total_steps
	EnemyPath.forget_all()
	walker.queue_free()
	return metrics


## Counts what the renderer will have to draw, from the scene itself.
func _count_scene(scene: Node, camera_at: Vector3) -> Dictionary:
	var meshes := 0
	var surfaces := 0
	var multimesh_nodes := 0
	var multimesh_instances := 0
	var triangles := 0
	var triangles_per_mesh := {}
	# The grass grows on worker threads and keeps cells from earlier camera positions, so what is
	# standing at a given moment varies. It is counted below from the seeded growth instead.
	var grass: GrassField = scene.get_node("Village/Grass")
	var nodes := 1 + scene.find_children("*", "", true, false).filter(func(node: Node) -> bool: return not grass.is_ancestor_of(node)).size()
	for node in scene.find_children("*", "VisualInstance3D", true, false):
		if grass.is_ancestor_of(node) or not (node as Node3D).is_visible_in_tree():
			continue
		if node is MeshInstance3D and node.mesh != null:
			meshes += 1
			surfaces += node.mesh.get_surface_count()
			triangles += _triangles_of(node.mesh, triangles_per_mesh)
		elif node is MultiMeshInstance3D and node.multimesh != null:
			var multimesh: MultiMesh = node.multimesh
			if multimesh.mesh == null:
				continue
			multimesh_nodes += 1
			var shown := multimesh.visible_instance_count if multimesh.visible_instance_count >= 0 else multimesh.instance_count
			multimesh_instances += shown
			surfaces += multimesh.mesh.get_surface_count()
			triangles += shown * _triangles_of(multimesh.mesh, triangles_per_mesh)
	var metrics := {
		"nodes": nodes,
		"mesh_instances": meshes,
		"mesh_surfaces": surfaces,
		"multimesh_nodes": multimesh_nodes,
		"multimesh_instances": multimesh_instances,
		"triangles": triangles,
	}
	metrics.merge(_grass_tufts(grass, Vector2(camera_at.x, camera_at.z)))
	return metrics


## How many tufts grow within drawing distance of a point, and how many of them the game draws once
## each cell has fitted its distance band (a share of the tufts, and one tuft per cell far away). It
## is the same seeded growth and the same bands the game uses, so it is exact.
func _grass_tufts(grass: GrassField, center: Vector2) -> Dictionary:
	var tufts := 0
	var drawn := 0
	var reach := ceili(grass._draw_distance / GrassField.CELL_SIZE)
	var center_cell := Vector2i((center / GrassField.CELL_SIZE).floor())
	for x in range(center_cell.x - reach, center_cell.x + reach + 1):
		for y in range(center_cell.y - reach, center_cell.y + reach + 1):
			var cell := Vector2i(x, y)
			if grass._cell_nearest_distance(cell, center) < grass._draw_distance:
				var band := floori(maxf(grass._cell_nearest_distance(cell, center) - GrassField.DETAIL_UPDATE_STEP, 0.0) / GrassField.DETAIL_BAND)
				var distance := band * GrassField.DETAIL_BAND
				var share := grass.tuft_share(distance)
				var far := distance >= grass._far_distance
				var cell_tufts := 0
				for spots: Array in grass.grow_cell(cell):
					tufts += spots.size()
					cell_tufts += spots.size()
					if not far:
						drawn += ceili(spots.size() * share)
				if far:
					drawn += ceili(cell_tufts * share)
	return {"grass_tufts": tufts, "grass_tufts_drawn": drawn}


func _triangles_of(mesh: Mesh, cache: Dictionary) -> int:
	if not cache.has(mesh):
		var count := 0
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var indices = arrays[Mesh.ARRAY_INDEX]
			count += (indices.size() if indices != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
		cache[mesh] = count
	return cache[mesh]


## Real renderer numbers, only meaningful with a display.
func _measure_frames() -> Dictionary:
	var times: Array[float] = []
	var draw_calls := 0
	var primitives := 0
	var last := Time.get_ticks_usec()
	for i in MEASURED_FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		draw_calls = maxi(draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		primitives = maxi(primitives, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	times.sort()
	var total := 0.0
	for time in times:
		total += time
	return {
		"draw_calls": draw_calls,
		"primitives": primitives,
		"frame_ms_avg": snappedf(total / times.size(), 0.01),
		"frame_ms_p99": snappedf(times[mini(times.size() - 1, int(times.size() * 0.99))], 0.01),
	}


## Budgets are kept apart for headless and rendered runs, because the scene is not identical in both.
func _mode(results: Dictionary) -> String:
	return "rendered" if results["rendered"] else "headless"


## Metrics that depend on the machine and are not gated unless asked for.
func _is_timing(metric: String) -> bool:
	return metric.begins_with("frame_ms")


func _write_budgets(results: Dictionary) -> void:
	var mode := _mode(results)
	var all := {}
	if FileAccess.file_exists(BUDGETS_PATH):
		all = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS_PATH))
	var budgets: Dictionary = all.get(mode, {})
	for point_name: String in results["points"]:
		var point_budget: Dictionary = budgets.get(point_name, {})
		for metric: String in results["points"][point_name]:
			point_budget[metric] = ceili(results["points"][point_name][metric] * (1.0 + (RENDERED_HEADROOM if mode == "rendered" else HEADROOM)))
		budgets[point_name] = point_budget
	var file := FileAccess.open(BUDGETS_PATH, FileAccess.WRITE)
	all["headroom"] = {"headless": HEADROOM, "rendered": RENDERED_HEADROOM}
	all[mode] = budgets
	file.store_string(JSON.stringify(all, "\t", true) + "\n")
	file.close()
	print("%s budgets written to %s" % [mode, BUDGETS_PATH])


func _check_budgets(results: Dictionary) -> void:
	var budgets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BUDGETS_PATH)).get(_mode(results), {})
	for point_name: String in results["points"]:
		_check(budgets.has(point_name), "%s has a budget" % point_name)
		for metric: String in results["points"][point_name]:
			var limit = budgets.get(point_name, {}).get(metric)
			if limit == null or (_is_timing(metric) and not _gate_frame_time):
				continue
			if results["rendered"] and point_name != SEARCH_POINT and not _is_timing(metric) and not metric in RENDERED_GATED:
				continue
			var value = results["points"][point_name][metric]
			_check(value <= limit, "%s %s %s is within the budget of %s" % [point_name, metric, value, limit])


func _check(condition: bool, label: String) -> void:
	print("%s: %s" % ["ok" if condition else "FAIL", label])
	if not condition:
		_failures += 1
