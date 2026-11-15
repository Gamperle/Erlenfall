extends SceneTree
## Memory check: loads and frees the main scene repeatedly, then plays a few minutes of simulated
## time, and fails when static memory, object count or orphan nodes grow past a small budget (#256).
##
## Run with: godot --headless --path . --script res://tests/memory_check.gd
##
## Options, after `--`:
##   --loads=N     how many load/free cycles to run after the warm-up load (default 5)
##   --minutes=N   minutes of simulated play time at the end (default 2, after a 40 second warm-up)
##
## The first load is a warm-up: caches, shaders and resources fill up once and stay. Each later
## load must return to the warm-up baseline, within the budgets below. A real leak grows with every
## load, so it trips them, while noise does not. Objects and orphan nodes are exact counts and
## repeat from run to run, so their budgets are tight. Static memory moves with the allocator, so it
## gets more room. Change a budget only with a reason in the pull request.

## Allowed growth in object count and orphan nodes, per load cycle.
const MAX_OBJECTS_PER_LOAD := 50
const MAX_ORPHANS_PER_LOAD := 0
## Allowed growth of static memory, per load cycle, in bytes.
const MAX_STATIC_PER_LOAD := 4 * 1024 * 1024
## Allowed total growth over the long play session, measured after the warm-up above.
const MAX_OBJECTS_PLAY := 500
const MAX_ORPHANS_PLAY := 0
const MAX_STATIC_PLAY := 16 * 1024 * 1024
## Frames each loaded scene runs before it is freed, long enough for the world to start streaming in.
const LOAD_FRAMES := 900
## Simulated seconds before the long run is measured. Streaming adds about 1200 objects in this time.
const PLAY_WARMUP_SECONDS := 40.0

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var loads := 5
	var minutes := 2.0
	for arg in args:
		if arg.begins_with("--loads="):
			loads = int(arg.trim_prefix("--loads="))
		elif arg.begins_with("--minutes="):
			minutes = float(arg.trim_prefix("--minutes="))

	await _load_and_free()
	var baseline := _sample("after warm-up load")
	var previous := baseline
	for i in loads:
		await _load_and_free()
		var now := _sample("after load %d" % (i + 2))
		_gate("load %d" % (i + 2), previous, now, MAX_OBJECTS_PER_LOAD, MAX_ORPHANS_PER_LOAD, MAX_STATIC_PER_LOAD)
		previous = now
	_gate("all loads", baseline, previous, MAX_OBJECTS_PER_LOAD * loads, MAX_ORPHANS_PER_LOAD, MAX_STATIC_PER_LOAD * loads)

	var scene := _make_scene()
	# The village keeps streaming in (grass, chunks) for the first half minute, so count from after that.
	for i in int(PLAY_WARMUP_SECONDS * Engine.physics_ticks_per_second):
		await physics_frame
	var start := _sample("play start")
	var frames := int(minutes * 60.0 * Engine.physics_ticks_per_second)
	for i in frames:
		await physics_frame
		if i % 1800 == 1799:
			_sample("play %.1f min" % ((i + 1) / 3600.0))
	var end := _sample("play end (%.1f min)" % minutes)
	_gate("play session", start, end, MAX_OBJECTS_PLAY, MAX_ORPHANS_PLAY, MAX_STATIC_PLAY)
	scene.queue_free()
	await physics_frame

	if _failures > 0:
		print("MEMORY CHECK FAILED (%d)" % _failures)
		quit(1)
	else:
		print("MEMORY CHECK PASSED")
		quit(0)


func _make_scene() -> Node:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.show_menu = false
	scene.save_path = "user://memory_check_save.json"
	root.add_child(scene)
	return scene


func _load_and_free() -> void:
	var scene := _make_scene()
	for i in LOAD_FRAMES:
		await physics_frame
	scene.queue_free()
	# Let deferred frees and the grass worker threads finish before counting.
	for i in 10:
		await physics_frame


func _sample(label: String) -> Dictionary:
	var s := {
		"static": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
	}
	print("%s: static %.1f MB, objects %d, nodes %d, orphan nodes %d" % [label, s["static"] / 1048576.0, s["objects"], s["nodes"], s["orphans"]])
	return s


func _gate(label: String, from: Dictionary, to: Dictionary, max_objects: int, max_orphans: int, max_static: int) -> void:
	var d_obj: int = to["objects"] - from["objects"]
	var d_orph: int = to["orphans"] - from["orphans"]
	var d_static: int = to["static"] - from["static"]
	if d_obj > max_objects:
		_fail("%s: objects grew by %d (budget %d)" % [label, d_obj, max_objects])
	if d_orph > max_orphans:
		_fail("%s: orphan nodes grew by %d (budget %d)" % [label, d_orph, max_orphans])
	if d_static > max_static:
		_fail("%s: static memory grew by %.1f MB (budget %.1f MB)" % [label, d_static / 1048576.0, max_static / 1048576.0])


func _fail(message: String) -> void:
	push_error("FAIL " + message)
	print("FAIL " + message)
	_failures += 1
