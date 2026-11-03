class_name Enemy
extends CharacterBody3D
## A melee enemy: it guards its home, chases the player, and telegraphs each attack.

enum State { IDLE, CHASE, WINDUP, RECOVER, DEAD }

const ATTACK_ANIMATION := &"Punch_Jab"
const DATA_PATH := "res://data/enemies.json"
const GROUP := "enemy"
const TURN_SPEED := 8.0
const WINDUP_COLOR := Color(0.95, 0.35, 0.1)
const HIT_COLOR := Color(1.0, 1.0, 1.0)
const HIT_FLASH_SECONDS := 0.12
const HOME_TOLERANCE := 2.0
const ATTACK_REACH_MARGIN := 0.5
const BAR_WIDTH := 0.8
const BAR_HEIGHT := 0.08
const KNOCKBACK_SPEED := 4.0
const KNOCKBACK_DECAY := 14.0
const SPARK_COLOR := Color(1.0, 0.75, 0.35)
const WAYPOINT_REACHED := 0.35
const WAYPOINT_LOOKAHEAD_PER_FRAME := 2
const ARRIVE_FRACTION := 0.8
const SEARCH_WAIT_SECONDS := 0.5
const FAILED_SEARCH_WAIT_SECONDS := 2.0
const CLEAR_WAY_CHECK_SECONDS := 0.25
const GOAL_MOVED_DISTANCE := 2.0
const STUCK_SECONDS := 0.6
const STUCK_DISTANCE := 0.3
const GOAL_LINE_SKIP := 0.75
const STUCK_MARK_DISTANCE := 0.5
const FORGET_DISTANCE := 1.5
const SIDESTEP_SECONDS := 0.5
## Other enemies standing still this near are planned around.
const CROWD_RANGE := 15.0
## Room left between this body and one standing still that is planned around.
const CROWD_MARGIN := 0.3
## An enemy walking straight looks for water on the way now and then, and plans a path at most
## this often when there is some, since it would rather walk around.
const WATER_SEARCH_WAIT_SECONDS := 2.0
## How far ahead it looks for water on the way.
const WATER_LOOKAHEAD := 15.0
## While it plans a way around water, it walks on until it's this near.
const WATER_STOP_DISTANCE := 2.5
## A waiting enemy looks again at once when one of those in the way moves this far.
const CROWD_MOVED_DISTANCE := 0.3
## Other moving enemies this near are watched, so as not to walk into them.
const MAKE_WAY_RANGE := 2.5
## How far ahead, in seconds, it looks for walking into one of them.
const MAKE_WAY_LOOKAHEAD := 0.5
## Room left between the two.
const MAKE_WAY_MARGIN := 0.15
## The longest it lets another go first before it walks on for a while.
const MAKE_WAY_SECONDS := 1.5
const MAKE_WAY_COOLDOWN_SECONDS := 1.0
## Two walking at each other at least this straight meet head on.
const HEAD_ON_DOT := -0.7
const MAKE_WAY_STEP := 1.0

static var _data: Dictionary = {}

var health: Health
var state := State.IDLE

var _stats: Dictionary = {}
var _home := Vector3.ZERO
var _timer := 0.0
var _flash := 0.0
var _knockback := Vector3.ZERO
var _sparks: CPUParticles3D
var _path: EnemyPath
var _waypoint := 0
var _following := false
var _path_goal := Vector3.ZERO
var _search_wait := 0.0
var _clear_way_wait := 0.0
var _stuck_left := STUCK_SECONDS
var _stuck_from := Vector3.ZERO
var _sidestep_left := 0.0
var _sidestep_side := 1.0
var _moving := false
var _waiting := false
var _wait_left := 0.0
var _wait_after_path := false
var _water_wait := 0.0
var _water_ahead := Vector3.INF
var _make_way_left := MAKE_WAY_SECONDS
var _make_way_cooldown := 0.0
var _searched_crowd := PackedVector3Array()
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _body: Humanoid
var _collision: CollisionShape3D
var _bar: MeshInstance3D


func setup(enemy_type: String, home: Vector3) -> void:
	# Walking almost straight into a wall still slides along it, so a body never stops dead at a corner.
	wall_min_slide_angle = 0.0
	_stats = _get_data()[enemy_type]
	_home = home
	position = home
	health = Health.new(_stats["health"])
	health.changed.connect(_update_bar)
	health.died.connect(_die)
	_build()


func _enter_tree() -> void:
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		_timer -= delta
		if _timer <= 0.0:
			revive()
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	var player := _find_target()
	match state:
		State.IDLE:
			_process_idle(player)
		State.CHASE:
			_process_chase(player)
		State.WINDUP:
			_process_windup(player, delta)
		State.RECOVER:
			_stop()
			_timer -= delta
			if _timer <= 0.0:
				state = State.CHASE
	velocity += _knockback
	move_and_slide()
	velocity -= _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	_body.animate(Vector2(velocity.x, velocity.z).length(), delta)
	_update_color(delta)


## Takes damage from an attack, and is pushed away from where it came from. Ignored once dead.
func take_hit(amount: float, from_position := Vector3.INF) -> void:
	if state == State.DEAD:
		return
	_flash = HIT_FLASH_SECONDS
	_sparks.restart()
	if from_position != Vector3.INF:
		var away := global_position - from_position
		away.y = 0.0
		_knockback = away.normalized() * KNOCKBACK_SPEED
	health.damage(amount)


## Brings the enemy back at its home, at full health.
func revive() -> void:
	health.restore()
	position = _home
	velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	state = State.IDLE
	_forget_path()
	visible = true
	_collision.set_deferred("disabled", false)


## Whether it stands still, such as while attacking, so others should walk around it.
func is_holding_ground() -> bool:
	return state != State.DEAD and not _moving


func to_data() -> Dictionary:
	return {
		"position": [position.x, position.y, position.z],
		"health": health.current,
		"respawn_left": _timer if state == State.DEAD else 0.0,
	}


## Restores a saved enemy. A living one has forgotten any fight and walks back if it was chasing.
func load_data(data: Dictionary) -> void:
	revive()
	var saved_position: Array = data["position"]
	position = Vector3(saved_position[0], saved_position[1], saved_position[2])
	if data["health"] <= 0.0:
		health.current = 0.0
		_become_dead()
		_timer = data["respawn_left"]
	else:
		health.current = data["health"]
	health.changed.emit()


func _process_idle(player: Player) -> void:
	if player != null and _distance_to(player) < float(_stats["aggro_range"]):
		state = State.CHASE
		return
	if _flat_distance(_home) > HOME_TOLERANCE:
		_move_toward_point(_home, HOME_TOLERANCE)
	else:
		_stop()


func _process_chase(player: Player) -> void:
	if player == null or _flat_distance(_home) > float(_stats["leash_range"]):
		state = State.IDLE
		return
	if _distance_to(player) < float(_stats["attack_range"]):
		state = State.WINDUP
		_timer = _stats["windup_seconds"]
		_body.play_action(ATTACK_ANIMATION)
		_stop()
	else:
		_move_toward_point(player.global_position, float(_stats["attack_range"]))


func _process_windup(player: Player, delta: float) -> void:
	_stop()
	_timer -= delta
	if _timer > 0.0:
		return
	var reach := float(_stats["attack_range"]) + ATTACK_REACH_MARGIN
	if player != null and _distance_to(player) < reach:
		player.take_hit(_stats["damage"], global_position)
	state = State.RECOVER
	_timer = _stats["recover_seconds"]


func _die() -> void:
	_give_drops()
	_become_dead()


func _become_dead() -> void:
	state = State.DEAD
	_timer = _stats["respawn_seconds"]
	visible = false
	_collision.set_deferred("disabled", true)


func _give_drops() -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	for drop: Dictionary in _stats.get("drops", []):
		if randf() < float(drop["chance"]):
			player.receive_drop(drop["item"], randi_range(int(drop["min"]), int(drop["max"])))


## Enemies ignore a player who is dead.
func _find_target() -> Player:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null or not player.health.is_alive():
		return null
	return player


func _distance_to(player: Player) -> float:
	return _flat_distance(player.global_position)


func _flat_distance(point: Vector3) -> float:
	return Vector2(global_position.x, global_position.z).distance_to(Vector2(point.x, point.z))


## Walks straight toward the point until something is in the way, then along a path around it.
## It's near enough at `reach`, which is how far the search for a path needs to get.
func _move_toward_point(point: Vector3, reach: float) -> void:
	var direction := _steer(point, reach)
	if direction == Vector3.ZERO:
		velocity.x = 0.0
		velocity.z = 0.0
		_moving = false
		direction = _flat_direction(point)
		if direction != Vector3.ZERO:
			rotation.y = atan2(-direction.x, -direction.z)
		return
	_moving = true
	rotation.y = atan2(-direction.x, -direction.z)
	var speed := float(_stats["speed"]) * (get_tree().get_first_node_in_group(Terrain.GROUP) as Terrain).wading_factor(global_position)
	direction = _make_way(direction, speed)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed


## Lets another moving enemy go first rather than walk into it: one ahead, or the one that has
## right of way when both are ahead of each other. It waits while the other passes or walks on, and
## steps to its right when they meet head on. It counts as moving while it waits, so the other one
## doesn't plan a way around it, unless they meet head on with no room to step aside.
func _make_way(direction: Vector3, speed: float) -> Vector3:
	var delta := get_physics_process_delta_time()
	_make_way_cooldown = maxf(_make_way_cooldown - delta, 0.0)
	var other := _enemy_in_the_way(direction * speed)
	if other == null or _make_way_cooldown > 0.0:
		_make_way_left = MAKE_WAY_SECONDS
		return direction
	# Waiting can go on for good when the other doesn't get anywhere either, so it gives up after a
	# while and walks on, for the old sidestep to sort out.
	_make_way_left -= delta
	if _make_way_left <= 0.0:
		_make_way_cooldown = MAKE_WAY_COOLDOWN_SECONDS
	_stuck_left = STUCK_SECONDS
	_stuck_from = global_position
	var their_direction := -other.global_basis.z
	if direction.dot(their_direction) < HEAD_ON_DOT:
		var right := direction.cross(Vector3.UP).normalized()
		if _path.is_line_clear(global_position, global_position + right * MAKE_WAY_STEP):
			return right
		# With no room to step aside, such as in a narrow passage, the other one has to find a way
		# around it, or wait.
		_moving = false
	return Vector3.ZERO


## The moving enemy this one would walk into soon at this velocity, if it should let it go first.
func _enemy_in_the_way(mine: Vector3) -> Enemy:
	var direction := mine.normalized()
	for other: Enemy in get_tree().get_nodes_in_group(GROUP):
		if other == self or not other._moving or other.state == State.DEAD:
			continue
		var offset := other.global_position - global_position
		offset.y = 0.0
		if offset.length_squared() > MAKE_WAY_RANGE * MAKE_WAY_RANGE or offset.dot(direction) <= 0.0:
			continue
		# Where they'd be nearest each other in the next moments, at the velocities they have now.
		var closing := Vector3(other.velocity.x, 0.0, other.velocity.z) - mine
		var soon := clampf(-offset.dot(closing) / maxf(closing.length_squared(), 0.0001), 0.0, MAKE_WAY_LOOKAHEAD)
		var room := float(_stats["radius"]) + float(other._stats["radius"]) + MAKE_WAY_MARGIN
		if (offset + closing * soon).length_squared() >= room * room:
			continue
		# When each is ahead of the other, as when their ways cross, the older one goes first.
		var their_direction := -other.global_basis.z
		if -offset.dot(their_direction) <= 0.0 or other.get_instance_id() < get_instance_id():
			return other
	return null


func _steer(goal: Vector3, reach: float) -> Vector3:
	var delta := get_physics_process_delta_time()
	_search_wait = maxf(_search_wait - delta, 0.0)
	_water_wait = maxf(_water_wait - delta, 0.0)
	if _path == null:
		_path = EnemyPath.new(self, _stats["radius"])
	if _path.is_searching() and _path.advance():
		_water_ahead = Vector3.INF
		_following = not _path.waypoints.is_empty()
		_waypoint = 0
		_clear_way_wait = CLEAR_WAY_CHECK_SECONDS
		# Others standing in the way may move, so it waits nearby instead of pushing past them.
		_wait_after_path = not _path.reached and _path.crowd_size() > 0
		_waiting = _wait_after_path and not _following
		_wait_left = float(FeatureFlags.value("enemy_crowd_wait_seconds"))
		if not _path.reached and not _wait_after_path:
			_search_wait = FAILED_SEARCH_WAIT_SECONDS
	if _waiting:
		return _wait(goal, reach, delta)
	_stuck_left -= delta
	if _stuck_left <= 0.0:
		var stuck := _flat_distance(_stuck_from) < STUCK_DISTANCE
		_stuck_from = global_position
		_stuck_left = STUCK_SECONDS
		if stuck and _touches_still_enemy():
			if not _path.is_searching():
				_start_search(goal, reach)
		elif stuck and is_on_wall() and not _touches_scenery():
			_sidestep_left = SIDESTEP_SECONDS
			_sidestep_side = -_sidestep_side
		elif stuck and _search_wait <= 0.0:
			_on_stuck(goal, reach)
	if _sidestep_left > 0.0:
		_sidestep_left -= delta
		return _flat_direction(goal).rotated(Vector3.UP, _sidestep_side * PI / 2.0)
	if _following:
		_update_following(goal, reach, delta)
	if _waiting:
		return Vector3.ZERO
	if _following:
		return _flat_direction(_waypoint_position())
	var direction := _flat_direction(goal)
	if _path.is_searching() and (_touches_still_enemy() or _flat_distance(_water_ahead) < WATER_STOP_DISTANCE):
		_stuck_left = STUCK_SECONDS
		_stuck_from = global_position
		return Vector3.ZERO
	if _search_wait > 0.0 or _path.is_searching():
		return direction
	if _touches_scenery():
		_path.forget_around(global_position, FORGET_DISTANCE)
		_start_search(goal, reach)
	elif _touches_still_enemy():
		_start_search(goal, reach)
	elif _water_wait <= 0.0:
		# A bridge nearby can be quicker than wading, and it should turn to it before the river.
		_water_wait = CLEAR_WAY_CHECK_SECONDS
		var wet := _path.wet_distance(global_position, goal, WATER_LOOKAHEAD)
		if wet < INF:
			_water_wait = WATER_SEARCH_WAIT_SECONDS
			_start_search(goal, reach)
			_water_ahead = global_position + direction * wet
	return direction


## Stands still where others block the way, and looks again now and then.
func _wait(goal: Vector3, reach: float, delta: float) -> Vector3:
	_stuck_left = STUCK_SECONDS
	_stuck_from = global_position
	_wait_left -= delta
	_clear_way_wait -= delta
	if _clear_way_wait <= 0.0:
		_clear_way_wait = CLEAR_WAY_CHECK_SECONDS
		var crowd := _update_crowd()
		if _path.is_line_clear(global_position, goal, GOAL_LINE_SKIP):
			_waiting = false
			_path.cancel()
			return _flat_direction(goal)
		if _crowd_moved(crowd):
			_wait_left = 0.0
	var goal_moved := _path_goal.distance_to(goal) > GOAL_MOVED_DISTANCE
	if (_wait_left <= 0.0 or goal_moved) and not _path.is_searching():
		_wait_left = float(FeatureFlags.value("enemy_crowd_wait_seconds"))
		_start_search(goal, reach)
	return Vector3.ZERO


func _update_following(goal: Vector3, reach: float, delta: float) -> void:
	_clear_way_wait -= delta
	if _clear_way_wait <= 0.0:
		_clear_way_wait = CLEAR_WAY_CHECK_SECONDS
		_update_crowd()
		if _path.is_line_clear(global_position, goal, GOAL_LINE_SKIP):
			_following = false
			_wait_after_path = false
			return
	if _path_goal.distance_to(goal) > GOAL_MOVED_DISTANCE and _search_wait <= 0.0 and not _path.is_searching():
		_start_search(goal, reach)
	var last := _path.waypoints.size() - 1
	for i in WAYPOINT_LOOKAHEAD_PER_FRAME:
		if _waypoint >= last or not _path.is_line_clear(global_position, _waypoint_position(_waypoint + 1)):
			break
		_waypoint += 1
	if _flat_distance(_waypoint_position()) < WAYPOINT_REACHED:
		_waypoint += 1
		if _waypoint > last:
			_following = false
			if _wait_after_path:
				_wait_after_path = false
				_waiting = true
				_wait_left = float(FeatureFlags.value("enemy_crowd_wait_seconds"))


## A path that doesn't fit avoids the spot just ahead from now on. Otherwise something new is in
## the way, so what is known nearby is out of date.
func _on_stuck(goal: Vector3, reach: float) -> void:
	if _following:
		var ahead := global_position + _flat_direction(_waypoint_position()) * STUCK_MARK_DISTANCE
		_path.mark_blocked(Vector2(ahead.x, ahead.z))
		_following = false
	else:
		_path.forget_around(global_position, FORGET_DISTANCE)
	if not _path.is_searching():
		_start_search(goal, reach)


func _start_search(goal: Vector3, reach: float) -> void:
	_path_goal = goal
	_search_wait = SEARCH_WAIT_SECONDS
	_searched_crowd = _update_crowd()
	_path.begin(global_position, goal, reach * ARRIVE_FRACTION)


func _waypoint_position(index := _waypoint) -> Vector3:
	var point := _path.waypoints[index]
	return Vector3(point.x, global_position.y, point.y)


func _flat_direction(point: Vector3) -> Vector3:
	var offset := point - global_position
	offset.y = 0.0
	return offset.normalized()


## Other characters don't count, since they move out of the way.
func _touches_scenery() -> bool:
	if not is_on_wall():
		return false
	for i in get_slide_collision_count():
		if not get_slide_collision(i).get_collider() is CharacterBody3D:
			return true
	return false


## Others standing still nearby, for the path search to keep clear of.
func _update_crowd() -> PackedVector3Array:
	var points := PackedVector3Array()
	var clearances := PackedFloat32Array()
	for other: Enemy in get_tree().get_nodes_in_group(GROUP):
		if other != self and other.is_holding_ground() and _flat_distance(other.global_position) < CROWD_RANGE:
			points.append(other.global_position)
			clearances.append(float(_stats["radius"]) + float(other._stats["radius"]) + CROWD_MARGIN)
	_path.set_crowd(points, clearances)
	return points


func _crowd_moved(crowd: PackedVector3Array) -> bool:
	if crowd.size() != _searched_crowd.size():
		return true
	for i in crowd.size():
		if crowd[i].distance_to(_searched_crowd[i]) > CROWD_MOVED_DISTANCE:
			return true
	return false


func _touches_still_enemy() -> bool:
	for i in get_slide_collision_count():
		var other := get_slide_collision(i).get_collider() as Enemy
		if other != null and other.is_holding_ground():
			return true
	return false


func _forget_path() -> void:
	_following = false
	_water_ahead = Vector3.INF
	_waiting = false
	_wait_after_path = false
	_stuck_left = STUCK_SECONDS
	_stuck_from = global_position
	if _path != null:
		_path.cancel()


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_moving = false
	_forget_path()


func _update_color(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	if _flash > 0.0:
		_body.set_glow(HIT_COLOR, 1.5)
	elif state == State.WINDUP:
		_body.set_glow(WINDUP_COLOR, 1.2)
	else:
		_body.set_glow(HIT_COLOR, 0.0)


func _update_bar() -> void:
	_bar.visible = health.fraction() < 1.0
	_bar.scale.x = maxf(health.fraction(), 0.01)


func _build() -> void:
	var height: float = _stats["height"]
	var radius: float = _stats["radius"]

	if _stats.has("model") and FeatureFlags.enabled("realistic_enemies"):
		var model := CreatureModel.new()
		model.load_model(_stats["model"])
		model.scale = Vector3.ONE * (height / float(_stats["model_height"]))
		_body = model
	else:
		_body = Humanoid.new()
		_body.setup(Color(_stats["color"]), Color(_stats["skin"]), Color.BLACK, false, true)
		_body.scale = Vector3.ONE * (height / Npc.BODY_HEIGHT)
	add_child(_body)

	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	_collision = CollisionShape3D.new()
	_collision.shape = shape
	_collision.position.y = height / 2.0
	add_child(_collision)

	_sparks = _build_sparks(height * 0.65)
	add_child(_sparks)

	var bar_mesh := QuadMesh.new()
	bar_mesh.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	var bar_material := StandardMaterial3D.new()
	bar_material.albedo_color = Color(0.85, 0.15, 0.1)
	bar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bar_material.billboard_keep_scale = true
	bar_mesh.material = bar_material
	_bar = MeshInstance3D.new()
	_bar.mesh = bar_mesh
	_bar.position.y = height + 0.25
	_bar.visible = false
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bar)


func _build_sparks(at_height: float) -> CPUParticles3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * 0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = SPARK_COLOR
	mesh.material = material
	var sparks := CPUParticles3D.new()
	sparks.mesh = mesh
	sparks.position.y = at_height
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 14
	sparks.lifetime = 0.35
	sparks.spread = 180.0
	sparks.initial_velocity_min = 1.5
	sparks.initial_velocity_max = 3.5
	sparks.gravity = Vector3.DOWN * 6.0
	return sparks


static func _get_data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data
