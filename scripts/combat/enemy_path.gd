class_name EnemyPath
extends RefCounted
## Finds a way around obstacles with a search on a small grid. The grid exists only where a search
## looks: each cell is checked against the physics world when first needed, and the answer is shared
## by all enemies for a few seconds. Searches share a budget of work per physics frame, and one that
## runs out carries on in the next frame. The budget counts steps rather than time, so a search
## takes the same number of frames on any machine.

const WALKABLE_SLOPE := 0.9
const SLOPE_SAMPLE_DISTANCE := 1.0
const PROBE_LIFT := 0.15
const PROBE_HEIGHT := 1.0
const PROBE_MARGIN := 0.02
const PROBE_RESULTS := 4
const LINE_SKIP_AT_START := 0.3
const LINE_MAX_LENGTH := 40.0
const START_SEARCH_CELLS := 2
## Checking a new cell against the physics world costs about three times as much as a search step.
const PROBE_COST := 3
## Slightly favors cells near the goal, which searches far fewer cells for a nearly as short path.
const HEURISTIC_WEIGHT := 1.2
const KEY_OFFSET := 1 << 15
const KEY_SHIFT := 16
const KEY_MASK := (1 << KEY_SHIFT) - 1
const DIAGONAL_COST := 1.4142
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

static var _grids: Dictionary = {}
static var _grids_expire_at := 0
static var _budget_frame := -1
static var _budget_used := 0

## The points to walk through after a finished search, without the starting point.
var waypoints := PackedVector2Array()
## Whether the last finished search got to the goal, rather than as near as it could.
var reached := false

var _terrain: Terrain
var _space: PhysicsDirectSpaceState3D
var _query := PhysicsShapeQueryParameters3D.new()
var _blocked: Dictionary
var _cell_size: float = FeatureFlags.value("enemy_path_cell_size")
var _max_nodes: int = FeatureFlags.value("enemy_path_max_nodes")

var _searching := false
var _goal := Vector2.ZERO
var _arrive_distance := 0.0
var _open_scores := PackedFloat32Array()
var _open_keys := PackedInt64Array()
var _costs: Dictionary = {}
var _came_from: Dictionary = {}
var _expanded := 0
var _best_key := -1
var _best_distance := INF


## The radius is that of the body.
func _init(body: CharacterBody3D, radius: float) -> void:
	_terrain = body.get_tree().get_first_node_in_group(Terrain.GROUP)
	_space = body.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius + PROBE_MARGIN
	capsule.height = maxf(PROBE_HEIGHT, capsule.radius * 2.0)
	_query.shape = capsule
	_query.collision_mask = body.collision_mask
	_query.exclude = [_terrain.get_rid()]
	if not _grids.has(radius):
		_grids[radius] = {}
	_blocked = _grids[radius]


func is_searching() -> bool:
	return _searching


func cancel() -> void:
	_searching = false


## Starts a search that ends within `arrive_distance` of the goal. Call `advance` until it's done.
func begin(from: Vector3, goal: Vector3, arrive_distance: float) -> void:
	_refresh_grids()
	_goal = Vector2(goal.x, goal.z)
	_arrive_distance = arrive_distance
	_open_scores.clear()
	_open_keys.clear()
	_costs.clear()
	_came_from.clear()
	_expanded = 0
	_best_key = -1
	_best_distance = INF
	_searching = true
	var start := _cell_of(Vector2(from.x, from.z))
	if not _is_blocked(start):
		_add_open(start, -1, 0.0)
		return
	# The middle of the body's own cell can be inside something when it's pressed against it.
	for x in range(-START_SEARCH_CELLS, START_SEARCH_CELLS + 1):
		for z in range(-START_SEARCH_CELLS, START_SEARCH_CELLS + 1):
			var cell := start + Vector2i(x, z)
			if not _is_blocked(cell):
				_add_open(cell, -1, Vector2(x, z).length())


## Does search work until it finishes, which returns true, or the frame's budget runs out.
func advance() -> bool:
	var budget: int = FeatureFlags.value("enemy_path_budget_steps")
	while _spend(0) < budget:
		_spend(1)
		if _expand():
			_searching = false
			return true
	return false


## Whether the body fits along a straight line. The start is skipped, because something the body is
## pressed against can reach into its cell, and `skip_end` does the same for a goal.
func is_line_clear(from: Vector3, to: Vector3, skip_end := 0.0) -> bool:
	_refresh_grids()
	var start := Vector2(from.x, from.z)
	var end := Vector2(to.x, to.z)
	var length := start.distance_to(end)
	if length > LINE_MAX_LENGTH:
		return false
	var along := LINE_SKIP_AT_START
	while along < length - skip_end:
		if _is_blocked(_cell_of(start.lerp(end, along / length))):
			return false
		along += _cell_size / 2.0
	return true


## Forgets what is known about the cells around a point, where the body ran into something.
func forget_around(point: Vector3, distance: float) -> void:
	var center := _cell_of(Vector2(point.x, point.z))
	var cells := ceili(distance / _cell_size)
	for x in range(-cells, cells + 1):
		for z in range(-cells, cells + 1):
			_blocked.erase(_key(center + Vector2i(x, z)))


## Treats a point as blocked for now, since a body that fits on paper couldn't get through there.
func mark_blocked(point: Vector2) -> void:
	_blocked[_key(_cell_of(point))] = true


func _expand() -> bool:
	if _open_keys.is_empty() or _expanded >= _max_nodes:
		_finish(_best_key)
		return true
	var score := _open_scores[0]
	var key := _pop_open()
	var cell := _cell_from_key(key)
	var cost: float = _costs[key]
	var distance := _center_of(cell).distance_to(_goal)
	if score > cost + distance * HEURISTIC_WEIGHT / _cell_size + 0.001:
		return false
	_expanded += 1
	if distance < _best_distance:
		_best_distance = distance
		_best_key = key
	if distance <= _arrive_distance:
		_finish(key)
		return true
	for offset in NEIGHBORS:
		var next := cell + offset
		var step_cost := 1.0
		if offset.x != 0 and offset.y != 0:
			if _is_blocked(cell + Vector2i(offset.x, 0)) or _is_blocked(cell + Vector2i(0, offset.y)):
				continue
			step_cost = DIAGONAL_COST
		if _is_blocked(next):
			continue
		var next_cost := cost + step_cost
		if next_cost < _costs.get(_key(next), INF):
			_add_open(next, key, next_cost)
	return false


func _finish(end_key: int) -> void:
	waypoints.clear()
	reached = _best_distance <= _arrive_distance
	var key := end_key
	while key != -1:
		waypoints.append(_center_of(_cell_from_key(key)))
		key = _came_from[key]
	waypoints.reverse()


func _is_blocked(cell: Vector2i) -> bool:
	var key := _key(cell)
	var known: Variant = _blocked.get(key)
	if known != null:
		return known
	_spend(PROBE_COST)
	var blocked := _probe(_center_of(cell))
	_blocked[key] = blocked
	return blocked


## Terrain too steep to walk up counts, and so does anything solid but other characters, who move.
func _probe(point: Vector2) -> bool:
	var height := _terrain.height_at(point.x, point.y)
	var rise_x := _terrain.height_at(point.x + SLOPE_SAMPLE_DISTANCE, point.y) - height
	var rise_z := _terrain.height_at(point.x, point.y + SLOPE_SAMPLE_DISTANCE) - height
	if Vector2(rise_x, rise_z).length() / SLOPE_SAMPLE_DISTANCE > WALKABLE_SLOPE:
		return true
	var capsule: CapsuleShape3D = _query.shape
	var center := height + PROBE_LIFT + capsule.height / 2.0
	_query.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, center, point.y))
	for hit: Dictionary in _space.intersect_shape(_query, PROBE_RESULTS):
		if not hit["collider"] is CharacterBody3D:
			return true
	return false


func _add_open(cell: Vector2i, from_key: int, cost: float) -> void:
	var key := _key(cell)
	_costs[key] = cost
	_came_from[key] = from_key
	var score := cost + _center_of(cell).distance_to(_goal) * HEURISTIC_WEIGHT / _cell_size
	_open_scores.append(score)
	_open_keys.append(key)
	var at := _open_keys.size() - 1
	while at > 0:
		var parent := (at - 1) / 2
		if _open_scores[parent] <= score:
			break
		_swap_open(at, parent)
		at = parent


func _pop_open() -> int:
	var top := _open_keys[0]
	var last := _open_keys.size() - 1
	_swap_open(0, last)
	_open_keys.resize(last)
	_open_scores.resize(last)
	var at := 0
	while true:
		var smallest := at
		for child: int in [at * 2 + 1, at * 2 + 2]:
			if child < last and _open_scores[child] < _open_scores[smallest]:
				smallest = child
		if smallest == at:
			break
		_swap_open(at, smallest)
		at = smallest
	return top


func _swap_open(a: int, b: int) -> void:
	var score := _open_scores[a]
	var key := _open_keys[a]
	_open_scores[a] = _open_scores[b]
	_open_keys[a] = _open_keys[b]
	_open_scores[b] = score
	_open_keys[b] = key


func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / _cell_size), floori(point.y / _cell_size))


func _center_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2.ONE * 0.5) * _cell_size


func _key(cell: Vector2i) -> int:
	return ((cell.x + KEY_OFFSET) << KEY_SHIFT) | (cell.y + KEY_OFFSET)


func _cell_from_key(key: int) -> Vector2i:
	return Vector2i((key >> KEY_SHIFT) - KEY_OFFSET, (key & KEY_MASK) - KEY_OFFSET)


## Adds to the work done in this physics frame, and returns the total so far.
static func _spend(steps: int) -> int:
	var frame := Engine.get_physics_frames()
	if frame != _budget_frame:
		_budget_frame = frame
		_budget_used = 0
	_budget_used += steps
	return _budget_used


static func forget_all() -> void:
	for grid: Dictionary in _grids.values():
		grid.clear()


## Things in the world can change, such as a gathering spot being used up.
static func _refresh_grids() -> void:
	var now := Engine.get_physics_frames()
	if now < _grids_expire_at:
		return
	forget_all()
	_grids_expire_at = now + roundi(float(FeatureFlags.value("enemy_path_cache_seconds")) * Engine.physics_ticks_per_second)
