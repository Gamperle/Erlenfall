class_name Player
extends CharacterBody3D
## Walks the valley with third- and first-person cameras, on keyboard, mouse, and controller.

const WALK_SPEED := 3.5
const SPRINT_SPEED := 6.5
const ACCELERATION := 12.0
const AIR_ACCELERATION := 2.0
const JUMP_VELOCITY := 4.5
const TURN_SPEED := 10.0
const WORLD_RADIUS := 500.0
const MOUSE_SENSITIVITY := 0.0025
const STICK_SENSITIVITY := 2.5
const MIN_PITCH := -1.3
const MAX_PITCH := 1.3
const THIRD_PERSON_DISTANCE := 3.5
const SHOULDER_OFFSET := 0.8

const GROUP := "player"
const MAX_HEALTH := 100.0
const REGEN_DELAY := 8.0
const REGEN_PER_SECOND := 2.0
const UNARMED_DAMAGE := 5.0
const ATTACK_WINDUP := 0.15
const ATTACK_COOLDOWN := 0.55
const ATTACK_RANGE := 2.4
const ATTACK_FACING := 0.4
const BLOCK_SPEED_FACTOR := 0.4
const BLOCK_DAMAGE_FACTOR := 0.2
const BLOCK_FACING := 0.2
const DODGE_SPEED := 9.0
const DODGE_SECONDS := 0.25
const DODGE_COOLDOWN := 0.8
const INTERACT_DISTANCE := 3.5
const INTERACT_FACING := 0.3
const WEAPON_REST_ANGLE := 0.0
const WEAPON_SWING_ANGLE := -1.4
const WEAPON_BLOCK_ANGLE := 1.3

var first_person := false
var inventory := Inventory.new()
var known_recipes: Dictionary = {}
var quests := QuestLog.new()
## What pressing the use button would act on right now, if anything.
var interact_target: Interactable

var health := Health.new(MAX_HEALTH)

var _busy := false
var _attack_cooldown := 0.0
var _attack_windup := 0.0
var _dodge_time := 0.0
var _dodge_cooldown := 0.0
var _dodge_direction := Vector3.ZERO
var _since_hit := REGEN_DELAY
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _pivot: Node3D = $CameraPivot
@onready var _spring_arm: SpringArm3D = $CameraPivot/SpringArm
@onready var _body_mesh: Node3D = $Body
@onready var _weapon: Node3D = $CameraPivot/Weapon


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_spring_arm.add_excluded_object(get_rid())
	_apply_camera_mode()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## While busy, for example in a menu, the player stands still and the mouse is free.
func set_busy(busy: bool) -> void:
	_busy = busy
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if busy else Input.MOUSE_MODE_CAPTURED


func is_busy() -> bool:
	return _busy


func interact() -> void:
	if interact_target != null:
		interact_target.interact(self)


func is_dodging() -> bool:
	return _dodge_time > 0.0


func is_blocking() -> bool:
	return not _busy and Input.is_action_pressed("block")


## Starts a swing. The hit lands after a short windup.
func attack() -> void:
	if _attack_cooldown <= 0.0 and not is_blocking() and not is_dodging():
		_attack_cooldown = ATTACK_COOLDOWN
		_attack_windup = ATTACK_WINDUP


## Rolls in the direction of movement, or backward when standing still. Avoids all damage.
func dodge() -> void:
	if _dodge_cooldown > 0.0 or not is_on_floor():
		return
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if move == Vector2.ZERO:
		move = Vector2.DOWN
	_dodge_direction = Vector3(move.x, 0.0, move.y).normalized().rotated(Vector3.UP, _pivot.rotation.y)
	_dodge_time = DODGE_SECONDS
	_dodge_cooldown = DODGE_COOLDOWN


## Takes damage from an attack that came from the given position.
func take_hit(amount: float, from_position: Vector3) -> void:
	if is_dodging() or not health.is_alive():
		return
	var offset := from_position - global_position
	offset.y = 0.0
	if is_blocking() and _forward().dot(offset.normalized()) > BLOCK_FACING:
		amount *= BLOCK_DAMAGE_FACTOR
	_since_hit = 0.0
	health.damage(amount)


## Returns the player to life at the given place.
func revive_at(place: Vector3) -> void:
	position = place
	velocity = Vector3.ZERO
	_attack_windup = 0.0
	_dodge_time = 0.0
	_since_hit = REGEN_DELAY
	health.restore()


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	var mouse_free := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	if mouse_free and event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative * MOUSE_SENSITIVITY)
	elif event.is_action_pressed("attack"):
		attack()
	elif event.is_action_pressed("dodge"):
		dodge()
	elif event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("inventory"):
		get_tree().call_group(CraftingStation.UI_GROUP, "open_inventory", self)
	elif event.is_action_pressed("toggle_camera"):
		first_person = not first_person
		_apply_camera_mode()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	_update_combat(delta)
	if not _busy:
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		_look(stick * STICK_SENSITIVITY * delta)

	if is_on_floor():
		if not _busy and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= _gravity * delta

	var move := Vector2.ZERO
	if not _busy:
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(move.x, 0.0, move.y).rotated(Vector3.UP, _pivot.rotation.y)
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	if is_blocking():
		speed = WALK_SPEED * BLOCK_SPEED_FACTOR
	var acceleration := ACCELERATION if is_on_floor() else AIR_ACCELERATION
	var target := direction * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	if is_dodging():
		velocity.x = _dodge_direction.x * DODGE_SPEED
		velocity.z = _dodge_direction.z * DODGE_SPEED
	move_and_slide()
	_keep_inside_world()
	interact_target = _find_interact_target()

	if direction.length_squared() > 0.01:
		var target_yaw := atan2(-direction.x, -direction.z)
		_body_mesh.rotation.y = lerp_angle(_body_mesh.rotation.y, target_yaw, TURN_SPEED * delta)


func _update_combat(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_dodge_time = maxf(_dodge_time - delta, 0.0)
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	if _attack_windup > 0.0:
		_attack_windup -= delta
		if _attack_windup <= 0.0:
			_land_attack()

	_since_hit += delta
	if _since_hit >= REGEN_DELAY and health.is_alive() and health.current < health.maximum:
		health.heal(REGEN_PER_SECOND * delta)

	# Swing the placeholder weapon while the cooldown runs, and raise it to block.
	var swing := _attack_cooldown / ATTACK_COOLDOWN
	_weapon.rotation.x = lerpf(WEAPON_REST_ANGLE, WEAPON_SWING_ANGLE, swing)
	if is_blocking():
		_weapon.rotation = Vector3(0.0, 0.0, WEAPON_BLOCK_ANGLE)
	else:
		_weapon.rotation.z = 0.0


func _land_attack() -> void:
	var damage := maxf(inventory.best_weapon_damage(), UNARMED_DAMAGE)
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		if offset.length() < ATTACK_RANGE and _forward().dot(offset.normalized()) > ATTACK_FACING:
			enemy.take_hit(damage)


func _forward() -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, _pivot.rotation.y)


func _find_interact_target() -> Interactable:
	var forward := _forward()
	var best: Interactable = null
	var best_distance := INTERACT_DISTANCE
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var candidate := node as Interactable
		var offset := candidate.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance < best_distance and candidate.is_available() and forward.dot(offset.normalized()) > INTERACT_FACING:
			best = candidate
			best_distance = distance
	return best


func _look(amount: Vector2) -> void:
	_pivot.rotation.y -= amount.x
	_pivot.rotation.x = clampf(_pivot.rotation.x - amount.y, MIN_PITCH, MAX_PITCH)


func _keep_inside_world() -> void:
	var flat := Vector2(position.x, position.z)
	if flat.length() > WORLD_RADIUS:
		flat = flat.limit_length(WORLD_RADIUS)
		position.x = flat.x
		position.z = flat.y


func _apply_camera_mode() -> void:
	_spring_arm.spring_length = 0.0 if first_person else THIRD_PERSON_DISTANCE
	_spring_arm.position.x = 0.0 if first_person else SHOULDER_OFFSET
	_body_mesh.visible = not first_person
