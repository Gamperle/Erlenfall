class_name Enemy
extends CharacterBody3D
## A melee enemy: it guards its home, chases the player, and telegraphs each attack.

enum State { IDLE, CHASE, WINDUP, RECOVER, DEAD }

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

static var _data: Dictionary = {}

var health: Health
var state := State.IDLE

var _stats: Dictionary = {}
var _home := Vector3.ZERO
var _timer := 0.0
var _flash := 0.0
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
	move_and_slide()
	_body.animate(Vector2(velocity.x, velocity.z).length(), delta)
	_update_color(delta)


## Takes damage from an attack. Ignored once dead.
func take_hit(amount: float) -> void:
	if state == State.DEAD:
		return
	_flash = HIT_FLASH_SECONDS
	health.damage(amount)


## Brings the enemy back at its home, at full health.
func revive() -> void:
	health.restore()
	position = _home
	velocity = Vector3.ZERO
	state = State.IDLE
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
		_die()
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
	state = State.DEAD
	_timer = _stats["respawn_seconds"]
	visible = false
	_collision.set_deferred("disabled", true)


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
	var direction := offset.normalized()
	velocity.x = direction.x * float(_stats["speed"])
	velocity.z = direction.z * float(_stats["speed"])
	rotation.y = atan2(-direction.x, -direction.z)


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


static func _get_data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return _data
