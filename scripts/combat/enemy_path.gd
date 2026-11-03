class_name EnemyPath
extends RefCounted
## Finds a way around obstacles with a search on a small grid. The grid exists only where a search
## looks: each cell is checked against the physics world when first needed, and the answer is shared
## by all enemies for a few seconds. Searches share a budget of work per physics frame, and one that
## runs out carries on in the next frame. The budget counts steps rather than time, so a search
## takes the same number of frames on any machine.
##
## A cell can have more than one floor, such as a bridge deck above a river bed, so a search step is
## a cell and one of its floors. Two floors connect when the step between them is low enough to walk.
## Other enemies that stand still can be passed in as a crowd, which is avoided only by this search.

const WALKABLE_SLOPE := 0.9
const SLOPE_SAMPLE_DISTANCE := 1.0
const PROBE_LIFT := 0.15
const PROBE_HEIGHT := 1.0
const PROBE_MARGIN := 0.02
const PROBE_RESULTS := 4
## Floors are looked for from this far above the terrain. The village bridge's deck is 2.5 m above
## the river bed.
const FLOOR_SEARCH_HEIGHT := 3.0
const FLOOR_SEARCH_DEPTH := 0.5
## Steeper surfaces, such as a roof, aren't floors.
const FLOOR_MIN_NORMAL_Y := 0.7
const MAX_FLOORS := 3
const MAX_RAYS := 6
const RAY_RESTART := 0.01
## The highest step up onto, or down from, something that isn't the same surface, such as the end of
## a bridge deck. A higher step, such as onto a crate, counts as a wall.
const LEDGE_HEIGHT := 0.15
const SLOPE_STEP_MARGIN := 0.05
## How far a body's feet can be from a floor and still stand on it.
const START_HEIGHT_TOLERANCE := 0.6
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
const FLOOR_BITS := 2
const FLOOR_MASK := (1 << FLOOR_BITS) - 1
## Each floor is stored as its height, how much a step onto it costs (more in water), and a number
## for what it is part of (0 for the terrain).
const FLOOR_STRIDE := 3
const DIAGONAL_COST := 1.4142
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

static var _grids: Dictionary = {}
static var _surfaces: Dictionary = {}
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
var _ray := PhysicsRayQueryParameters3D.new()
var _cells: Dictionary
var _cell_size: float = FeatureFlags.value("enemy_path_cell_size")
var _max_nodes: int = FeatureFlags.value("enemy_path_max_nodes")
var _water_cost: float = FeatureFlags.value("enemy_path_water_cost")
var _slope_step := WALKABLE_SLOPE * _cell_size + SLOPE_STEP_MARGIN
var _diagonal_slope_step := WALKABLE_SLOPE * _cell_size * DIAGONAL_COST + SLOPE_STEP_MARGIN
var _straight := PackedInt32Array([-1, -1, -1, -1])
var _crowd := PackedVector3Array()
var _crowd_clearance := PackedFloat32Array()

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
	_ray.collision_mask = body.collision_mask
	_ray.hit_back_faces = false
	if not _grids.has(radius):
		_grids[radius] = {}
	_cells = _grids[radius]


func is_searching() -> bool:
	return _searching


func cancel() -> void:
	_searching = false


## Other bodies to keep clear of, with how near the middle of this body may come to each. Used by
## the searches and line checks that follow, until it's set again.
func set_crowd(points: PackedVector3Array, clearances: PackedFloat32Array) -> void:
	_crowd = points
	_crowd_clearance = clearances


func crowd_size() -> int:
	return _crowd.size()


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
	# The body may stand among the crowd, such as right behind someone it bumped into.
	var start := _cell_of(Vector2(from.x, from.z))
	var floor_index := _floor_near(start, from.y, false)
	if floor_index >= 0:
		_add_open(start, floor_index, -1, 0.0)
		return
	# The middle of the body's own cell can be inside something when it's pressed against it. A cell
	# two away only counts when the one between is free, so a start isn't on the far side of a wall
	# or of someone in the crowd.
	for x in range(-START_SEARCH_CELLS, START_SEARCH_CELLS + 1):
		for z in range(-START_SEARCH_CELLS, START_SEARCH_CELLS + 1):
			var offset := Vector2i(x, z)
			var cell := start + offset
			floor_index = _floor_near(cell, from.y)
			var between := start + offset / 2
			if floor_index >= 0 and (between == start or _floor_near(between, from.y) >= 0):
				_add_open(cell, floor_index, -1, Vector2(offset).length())


## Does search work until it finishes, which returns true, or the frame's budget runs out.
func advance() -> bool:
	var budget: int = FeatureFlags.value("enemy_path_budget_steps")
	while _spend(0) < budget:
		_spend(1)
		if _expand():
			_searching = false
			return true
	return false


## Whether the body can walk along a straight line at full speed, so water counts as in the way. The
## start is skipped, because something the body is pressed against can reach into its cell, and
## `skip_end` does the same for a goal.
func is_line_clear(from: Vector3, to: Vector3, skip_end := 0.0) -> bool:
	_refresh_grids()
	var start := Vector2(from.x, from.z)
	var end := Vector2(to.x, to.z)
	var length := start.distance_to(end)
	if length > LINE_MAX_LENGTH:
		return false
	var cell := _cell_of(start)
	var floor_index := _floor_near(cell, from.y, false)
	var along := LINE_SKIP_AT_START
	while along < length - skip_end:
		var next := _cell_of(start.lerp(end, along / length))
		if floor_index < 0:
			# The body's own cell can be blocked when it's pressed against something.
			floor_index = _floor_near(next, from.y)
		elif next != cell:
			var here := _floors(cell)
			floor_index = _step_to(here[floor_index * FLOOR_STRIDE], here[floor_index * FLOOR_STRIDE + 2], cell, next)
		cell = next
		if floor_index < 0 or _floors(cell)[floor_index * FLOOR_STRIDE + 1] > 1.0:
			return false
		along += _cell_size / 2.0
	return true


## Whether the floor at a point, the one nearest its height, is water.
func is_wet(point: Vector3) -> bool:
	_refresh_grids()
	var cell := _cell_of(Vector2(point.x, point.z))
	var floor_index := _floor_near(cell, point.y, false, INF)
	return floor_index >= 0 and _floors(cell)[floor_index * FLOOR_STRIDE + 1] > 1.0


## Forgets what is known about the cells around a point, where the body ran into something.
func forget_around(point: Vector3, distance: float) -> void:
	var center := _cell_of(Vector2(point.x, point.z))
	var cells := ceili(distance / _cell_size)
	for x in range(-cells, cells + 1):
		for z in range(-cells, cells + 1):
			_cells.erase(_key(center + Vector2i(x, z)))


## Treats a point as blocked for now, since a body that fits on paper couldn't get through there.
func mark_blocked(point: Vector2) -> void:
	_cells[_key(_cell_of(point))] = PackedFloat64Array()


func _expand() -> bool:
	if _open_keys.is_empty() or _expanded >= _max_nodes:
		_finish(_best_key)
		return true
	var score := _open_scores[0]
	var node := _pop_open()
	var cell := _cell_from_key(node >> FLOOR_BITS)
	var floor_index := node & FLOOR_MASK
	var cost: float = _costs[node]
	var distance := _center_of(cell).distance_to(_goal)
	if score > cost + distance * HEURISTIC_WEIGHT / _cell_size + 0.001:
		return false
	# Another body can have marked the cell blocked since it was added.
	var here := _floors(cell)
	if floor_index * FLOOR_STRIDE >= here.size():
		return false
	var height := here[floor_index * FLOOR_STRIDE]
	var surface := here[floor_index * FLOOR_STRIDE + 2]
	_expanded += 1
	if distance < _best_distance:
		_best_distance = distance
		_best_key = node
	if distance <= _arrive_distance:
		_finish(node)
		return true
	# The four straight steps come first, and a diagonal step needs both of the ones beside it.
	for i in NEIGHBORS.size():
		var offset := NEIGHBORS[i]
		var next := cell + offset
		var step_cost := 1.0
		var next_floor := -1
		if i < 4:
			next_floor = _step_to(height, surface, cell, next)
			_straight[i] = next_floor
		else:
			if _straight[0 if offset.x > 0 else 1] < 0 or _straight[2 if offset.y > 0 else 3] < 0:
				continue
			step_cost = DIAGONAL_COST
			next_floor = _step_to(height, surface, cell, next)
		if next_floor < 0:
			continue
		var next_cost := cost + step_cost * _floors(next)[next_floor * FLOOR_STRIDE + 1]
		if next_cost < _costs.get(_node_key(next, next_floor), INF):
			_add_open(next, next_floor, node, next_cost)
	return false


func _finish(end_key: int) -> void:
	waypoints.clear()
	reached = _best_distance <= _arrive_distance
	var key := end_key
	while key != -1:
		waypoints.append(_center_of(_cell_from_key(key >> FLOOR_BITS)))
		key = _came_from[key]
	waypoints.reverse()


## The floor of the next cell, beside this one, that the body can walk onto from a floor at this
## height and of this surface, or -1.
func _step_to(height: float, surface: float, cell: Vector2i, next: Vector2i) -> int:
	var slope_step := _diagonal_slope_step if next.x != cell.x and next.y != cell.y else _slope_step
	var there := _floors(next)
	# Most cells have one floor, and most searches no crowd, so that case is kept short.
	if there.size() == FLOOR_STRIDE:
		if absf(there[0] - height) > (slope_step if there[2] == surface else LEDGE_HEIGHT):
			return -1
		return -1 if not _crowd.is_empty() and _is_crowded(next, there[0]) else 0
	var best := -1
	var best_rise := INF
	for i in there.size() / FLOOR_STRIDE:
		var rise := absf(there[i * FLOOR_STRIDE] - height)
		var allowed := slope_step if there[i * FLOOR_STRIDE + 2] == surface else LEDGE_HEIGHT
		if rise <= allowed and rise < best_rise and not _is_crowded(next, there[i * FLOOR_STRIDE]):
			best = i
			best_rise = rise
	return best


## The floor of a cell nearest a body's feet at this height, or -1.
func _floor_near(cell: Vector2i, height: float, avoid_crowd := true, tolerance := START_HEIGHT_TOLERANCE) -> int:
	var floors := _floors(cell)
	var best := -1
	var best_offset := tolerance
	for i in floors.size() / FLOOR_STRIDE:
		var offset := absf(floors[i * FLOOR_STRIDE] - height)
		if offset <= best_offset and not (avoid_crowd and _is_crowded(cell, floors[i * FLOOR_STRIDE])):
			best = i
			best_offset = offset
	return best


func _is_crowded(cell: Vector2i, height: float) -> bool:
	var center := _center_of(cell)
	for i in _crowd.size():
		var other := _crowd[i]
		if absf(other.y - height) < PROBE_HEIGHT and center.distance_squared_to(Vector2(other.x, other.z)) < _crowd_clearance[i] * _crowd_clearance[i]:
			return true
	return false


func _floors(cell: Vector2i) -> PackedFloat64Array:
	var key := _key(cell)
	var known: Variant = _cells.get(key)
	if known != null:
		return known
	_spend(PROBE_COST)
	var floors := _probe(_center_of(cell))
	_cells[key] = floors
	return floors


## Looks down from above the terrain for surfaces the body fits on, highest first. Terrain too steep
## to walk up doesn't count, and anything solid but other characters, who move, is in the way. A
## floor needs room above it up to the next surface, since the capsule check alone can fit under
## the sloping end of a bridge deck.
func _probe(point: Vector2) -> PackedFloat64Array:
	var floors := PackedFloat64Array()
	var ground := _terrain.height_at(point.x, point.y)
	var headroom := PROBE_LIFT + PROBE_HEIGHT
	var ceiling := INF
	_ray.from = Vector3(point.x, ground + FLOOR_SEARCH_HEIGHT, point.y)
	_ray.to = Vector3(point.x, ground - FLOOR_SEARCH_DEPTH, point.y)
	for i in MAX_RAYS:
		var hit := _space.intersect_ray(_ray)
		if hit.is_empty() or hit["collider"] == _terrain:
			if ceiling - ground >= headroom and _is_walkable_ground(point, ground) and _fits(point, ground):
				_add_floor(floors, point, ground, 0)
			break
		var at: Vector3 = hit["position"]
		var collider: Object = hit["collider"]
		_ray.from = at + Vector3.DOWN * RAY_RESTART
		if collider is CharacterBody3D:
			continue
		if ceiling - at.y >= headroom and hit["normal"].y >= FLOOR_MIN_NORMAL_Y and _fits(point, at.y):
			_add_floor(floors, point, at.y, _surfaces.get_or_add(collider.get_instance_id(), _surfaces.size() + 1))
			if floors.size() >= MAX_FLOORS * FLOOR_STRIDE:
				break
		ceiling = at.y
	return floors


func _is_walkable_ground(point: Vector2, height: float) -> bool:
	var rise_x := _terrain.height_at(point.x + SLOPE_SAMPLE_DISTANCE, point.y) - height
	var rise_z := _terrain.height_at(point.x, point.y + SLOPE_SAMPLE_DISTANCE) - height
	return Vector2(rise_x, rise_z).length() / SLOPE_SAMPLE_DISTANCE <= WALKABLE_SLOPE


func _fits(point: Vector2, height: float) -> bool:
	var capsule: CapsuleShape3D = _query.shape
	var center := height + PROBE_LIFT + capsule.height / 2.0
	_query.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, center, point.y))
	for hit: Dictionary in _space.intersect_shape(_query, PROBE_RESULTS):
		if not hit["collider"] is CharacterBody3D:
			return false
	return true


func _add_floor(floors: PackedFloat64Array, point: Vector2, height: float, surface: int) -> void:
	floors.append(height)
	# Water slows the body down, and it would rather not get wet, so wading counts for more than that.
	var wading := inverse_lerp(1.0, Terrain.WADING_SPEED_FACTOR, _terrain.wading_factor(Vector3(point.x, height, point.y)))
	floors.append(lerpf(1.0, _water_cost, wading))
	floors.append(surface)


func _add_open(cell: Vector2i, floor_index: int, from_key: int, cost: float) -> void:
	var key := _node_key(cell, floor_index)
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


func _node_key(cell: Vector2i, floor_index: int) -> int:
	return (_key(cell) << FLOOR_BITS) | floor_index


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
	_surfaces.clear()


## Things in the world can change, such as a gathering spot being used up.
static func _refresh_grids() -> void:
	var now := Engine.get_physics_frames()
	if now < _grids_expire_at:
		return
	forget_all()
	_grids_expire_at = now + roundi(float(FeatureFlags.value("enemy_path_cache_seconds")) * Engine.physics_ticks_per_second)
