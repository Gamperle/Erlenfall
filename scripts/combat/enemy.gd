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
const FOLLOW_MAX_SECONDS := 15.0
const FOLLOW_TURN_SPEED := 2.5
const FOLLOW_LOST_WALL_SECONDS := 1.0
const SIGHT_HEIGHT := 0.6
const SIGHT_WIDTH := 0.95

static var _data: Dictionary = {}

var health: Health
var state := State.IDLE

var _stats: Dictionary = {}
var _home := Vector3.ZERO
var _timer := 0.0
var _flash := 0.0
var _knockback := Vector3.ZERO
var _sparks: CPUParticles3D
var _follow_left := 0.0
var _follow_direction := Vector3.ZERO
var _follow_side := 1.0
var _since_wall := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _body: Humanoid
var _collision: CollisionShape3D
var _bar: MeshInstance3D


func setup(enemy_type: String, home: Vector3) -> void:
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
	_follow_left = 0.0
	visible = true
	_collision.set_deferred("disabled", false)


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
		_move_toward_point(_home)
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
		_move_toward_point(player.global_position)


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


func _move_toward_point(point: Vector3) -> void:
	var offset := point - global_position
	offset.y = 0.0
	var direction := _steer_around_obstacles(offset.normalized(), point)
	var speed := float(_stats["speed"]) * (get_tree().get_first_node_in_group(Terrain.GROUP) as Terrain).wading_factor(global_position)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	rotation.y = atan2(-direction.x, -direction.z)


## Follows a blocking wall around its corners, keeping it on the same hand, until the way is clear.
func _steer_around_obstacles(direction: Vector3, goal: Vector3) -> Vector3:
	var following := _follow_left > 0.0
	if following:
		var delta := get_physics_process_delta_time()
		_follow_left = maxf(_follow_left - delta, 0.0)
		_since_wall += delta
		# Without a wall nearby, a hill may be what hides the goal, so don't circle.
		if _since_wall > FOLLOW_LOST_WALL_SECONDS or _has_clear_way(goal):
			_follow_left = 0.0
			following = false
		else:
			# With no wall to touch, turn toward where it went, which rounds outside corners.
			_follow_direction = _follow_direction.rotated(Vector3.UP, _follow_side * FOLLOW_TURN_SPEED * delta)
	if is_on_wall():
		var along_wall := Vector3.UP.cross(get_wall_normal()).normalized()
		if not following:
			_follow_side = 1.0 if along_wall.dot(direction) >= 0.0 else -1.0
			_follow_left = FOLLOW_MAX_SECONDS
			following = true
		_follow_direction = along_wall * _follow_side
		_since_wall = 0.0
	return _follow_direction if following else direction


## Checks both sides of the body as well as the middle, since a thin line could fit where the body can't.
func _has_clear_way(point: Vector3) -> bool:
	var side := (point - global_position).cross(Vector3.UP).normalized() * float(_stats["radius"]) * SIGHT_WIDTH
	for offset: Vector3 in [Vector3.ZERO, side, -side]:
		if not _can_see(point + offset, global_position + offset):
			return false
	return true


## Other characters don't count, since they move out of the way.
func _can_see(point: Vector3, from: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * SIGHT_HEIGHT, point + Vector3.UP * SIGHT_HEIGHT)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] is CharacterBody3D


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


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
