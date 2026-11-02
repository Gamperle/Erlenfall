class_name Player
extends CharacterBody3D
## Walks the valley with third- and first-person cameras, on keyboard, mouse, and controller.

## Asks the game to show the player a short message.
signal notice(text_key: String)
signal busy_changed

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
## How far the third-person camera swings aside in a conversation, to show both people.
const CONVERSATION_SWING := 0.45

const GROUP := "player"
const PLAYER_CLOTH_COLOR := Color(0.45, 0.3, 0.2)
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
const WEAPON_HAND_POSITION := Vector3(0.0, -0.58, -0.05)
const WEAPON_FIRST_PERSON_POSITION := Vector3(0.3, -0.42, -0.7)
const WEAPON_FIRST_PERSON_SCALE := 0.4
## Held forward and up from the hand, since the arm hangs down.
const WEAPON_REST_ANGLE := -1.0
const WEAPON_SWING_ANGLE := -2.2
const WEAPON_FIRST_PERSON_REST_ANGLE := -0.35
const WEAPON_FIRST_PERSON_SWING_ANGLE := -1.4
const WEAPON_BLOCK_ANGLE := 1.3
const MODEL_PATH := "res://assets/characters/player.glb"
const ATTACK_ANIMATION := &"Sword_Attack"
const DODGE_ANIMATION := &"Roll"
const DODGE_ANIMATION_SECONDS := 0.5
## The roll starts with a high dive, which this skips.
const DODGE_ANIMATION_START := 0.38
const BACKSTEP_ANIMATION := &"Crouch_Idle"
const BACKSTEP_ANIMATION_SECONDS := 0.4
const BLOCK_ANIMATION := &"Sword_Idle"
const TORCH_ANIMATION := &"Idle_Torch"
const WEAPON_GRIP_POSITION := Vector3(0.0, 0.08, 0.02)
## Points the blade up and ahead in the blocking pose.
const WEAPON_GRIP_ROTATION := Vector3(-0.005935, 0.008892, -1.964538)
const TORCH_GRIP_POSITION := Vector3(0.0, 0.08, 0.02)
const TORCH_GRIP_SCALE := 0.75
const TORCH_ITEM := "torch"
const TORCH_ARM_RAISE := 1.2
const TORCH_HAND_POSITION := Vector3(0.0, -0.58, -0.05)
const TORCH_FIRST_PERSON_POSITION := Vector3(-0.4, -0.5, -0.7)
const TORCH_FIRST_PERSON_SCALE := 0.7

var first_person := false
var inventory := Inventory.new()
var known_recipes: Dictionary = {}
var quests := QuestLog.new()
## What pressing the use button would act on right now, if anything.
var interact_target: Interactable
var torch_lit := false
var torch_given := false
## How long the current torch has burned, when torches burn out.
var torch_burned_seconds := 0.0

var health := Health.new(MAX_HEALTH)

var _busy := false
var _look_before_conversation: Variant = null
var _attack_cooldown := 0.0
var _attack_windup := 0.0
var _dodge_time := 0.0
var _dodge_cooldown := 0.0
var _dodge_direction := Vector3.ZERO
var _since_hit := REGEN_DELAY
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _torch := Torch.new()

@onready var _pivot: Node3D = $CameraPivot
@onready var _spring_arm: SpringArm3D = $CameraPivot/SpringArm
@onready var _body_mesh: Humanoid = $Body
@onready var _weapon: Node3D = $CameraPivot/Weapon


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if FeatureFlags.enabled("realistic_player"):
		_replace_body()
	else:
		_body_mesh.setup(PLAYER_CLOTH_COLOR)
	_spring_arm.add_excluded_object(get_rid())
	# Conversations pause the world, and the arm still has to keep the camera out of walls.
	_spring_arm.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_torch)
	_apply_camera_mode()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## While busy, in a menu or conversation, the world is paused and the mouse is free.
## Enemies stay where they are, so a menu can't be used to escape a fight.
func set_busy(busy: bool) -> void:
	_busy = busy
	get_tree().paused = busy
	busy_changed.emit()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if busy else Input.MOUSE_MODE_CAPTURED


## Turns the player and camera toward a person, so the player's body doesn't hide them.
func frame_conversation(point: Vector3) -> void:
	_look_before_conversation = _pivot.rotation
	var offset := point - global_position
	var yaw := atan2(-offset.x, -offset.z)
	_body_mesh.rotation.y = yaw
	_pivot.rotation = Vector3(0.0, yaw + (0.0 if first_person else CONVERSATION_SWING), 0.0)


## Gives the camera back to the player, looking where it did before the conversation.
func end_conversation() -> void:
	if _look_before_conversation != null:
		_pivot.rotation = _look_before_conversation
		_look_before_conversation = null


func is_busy() -> bool:
	return _busy


func interact() -> void:
	if interact_target != null:
		interact_target.interact(self)


## The direction the camera faces, in degrees clockwise from north (-Z).
func heading_degrees() -> float:
	return fposmod(-rad_to_deg(_pivot.rotation.y), 360.0)


func is_dodging() -> bool:
	return _dodge_time > 0.0


func is_blocking() -> bool:
	return not _busy and Input.is_action_pressed("block")


## Gives the starting torch once per game, including to games saved before torches existed.
func give_starting_items() -> void:
	if not torch_given and FeatureFlags.enabled("torch_at_start"):
		torch_given = true
		inventory.add(TORCH_ITEM)


func toggle_torch() -> void:
	if not FeatureFlags.enabled("torches"):
		return
	if not torch_lit and inventory.count(TORCH_ITEM) == 0:
		notice.emit("UI_NO_TORCH")
		return
	set_torch_lit(not torch_lit)


func set_torch_lit(lit: bool) -> void:
	torch_lit = lit
	_torch.set_lit(lit)
	_body_mesh.left_arm_raise = TORCH_ARM_RAISE if lit else 0.0


## Starts a swing. The hit lands after a short windup.
func attack() -> void:
	if _attack_cooldown <= 0.0 and not is_blocking() and not is_dodging():
		_attack_cooldown = ATTACK_COOLDOWN
		_attack_windup = ATTACK_WINDUP
		_body_mesh.play_action(ATTACK_ANIMATION)
		_body_mesh.rotation.y = _pivot.rotation.y


## Rolls in the direction of movement, or backward when standing still. Avoids all damage.
func dodge() -> void:
	if _dodge_cooldown > 0.0 or not is_on_floor():
		return
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var backstep := move == Vector2.ZERO
	if backstep:
		move = Vector2.DOWN
	_dodge_direction = Vector3(move.x, 0.0, move.y).normalized().rotated(Vector3.UP, _pivot.rotation.y)
	if backstep:
		# Standing still, the player ducks back while still facing ahead.
		_body_mesh.rotation.y = _pivot.rotation.y
		_body_mesh.play_action(BACKSTEP_ANIMATION, BACKSTEP_ANIMATION_SECONDS)
	else:
		# The roll animation goes forward, so the body faces where it's going.
		_body_mesh.rotation.y = atan2(-_dodge_direction.x, -_dodge_direction.z)
		_body_mesh.play_action(DODGE_ANIMATION, DODGE_ANIMATION_SECONDS, DODGE_ANIMATION_START)
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


func receive_drop(item_id: String, amount: int) -> void:
	inventory.add(item_id, amount)
	notice.emit(tr("UI_GOT_DROP") % [amount, CraftingData.item_name(item_id)])


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
		# Screen units, so the window's size and the interface scale don't change the sensitivity.
		_look(event.screen_relative * MOUSE_SENSITIVITY)
	elif event.is_action_pressed("attack"):
		attack()
	elif event.is_action_pressed("dodge"):
		dodge()
	elif event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("inventory"):
		get_tree().call_group(CraftingStation.UI_GROUP, "open_inventory", self)
	elif event.is_action_pressed("toggle_torch"):
		toggle_torch()
	elif event.is_action_pressed("toggle_camera"):
		first_person = not first_person
		_apply_camera_mode()
	elif event.is_action_pressed("pause"):
		get_tree().call_group(Bed.GAME_GROUP, "open_pause_menu")


func _physics_process(delta: float) -> void:
	_update_combat(delta)
	_update_torch(delta)
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
	_body_mesh.animate(Vector2(velocity.x, velocity.z).length(), delta)

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

	if _body_mesh is CharacterModel:
		var idle: StringName = &""
		if is_blocking():
			idle = BLOCK_ANIMATION
		elif torch_lit:
			idle = TORCH_ANIMATION
		(_body_mesh as CharacterModel).idle_override = idle
		# In third person, the model's own animations move the weapon.
		if not first_person:
			return

	# Swing the placeholder weapon while the cooldown runs, and raise it to block.
	var swing := _attack_cooldown / ATTACK_COOLDOWN
	var rest_angle := WEAPON_FIRST_PERSON_REST_ANGLE if first_person else WEAPON_REST_ANGLE
	var swing_angle := WEAPON_FIRST_PERSON_SWING_ANGLE if first_person else WEAPON_SWING_ANGLE
	_weapon.rotation.x = lerpf(rest_angle, swing_angle, swing)
	if is_blocking():
		_weapon.rotation = Vector3(0.0, 0.0, WEAPON_BLOCK_ANGLE)
	else:
		_weapon.rotation.z = 0.0


func _update_torch(delta: float) -> void:
	if not torch_lit or not FeatureFlags.enabled("torch_burns_out"):
		return
	torch_burned_seconds += delta
	if torch_burned_seconds >= float(FeatureFlags.value("torch_burn_seconds", 0.0)):
		torch_burned_seconds = 0.0
		inventory.remove(TORCH_ITEM)
		set_torch_lit(false)
		notice.emit("UI_TORCH_BURNED_OUT")


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


func _replace_body() -> void:
	var old_body := _body_mesh
	remove_child(old_body)
	old_body.free()
	var model := CharacterModel.new()
	model.name = "Body"
	model.load_model(MODEL_PATH)
	add_child(model)
	_body_mesh = model


func _apply_camera_mode() -> void:
	_spring_arm.spring_length = 0.0 if first_person else THIRD_PERSON_DISTANCE
	_spring_arm.position.x = 0.0 if first_person else SHOULDER_OFFSET
	_body_mesh.visible = not first_person
	# In first person the body is hidden, so the weapon follows the camera instead of the hand.
	_weapon.reparent(_pivot if first_person else _body_mesh.right_hand(), false)
	_weapon.position = WEAPON_FIRST_PERSON_POSITION if first_person else WEAPON_HAND_POSITION
	_weapon.scale = Vector3.ONE * (WEAPON_FIRST_PERSON_SCALE if first_person else 1.0)
	# The raised arm would tilt the torch, so turn it back to stand upright.
	_torch.reparent(_pivot if first_person else _body_mesh.left_hand(), false)
	_torch.position = TORCH_FIRST_PERSON_POSITION if first_person else TORCH_HAND_POSITION
	_torch.rotation.x = 0.0 if first_person else -TORCH_ARM_RAISE
	_torch.scale = Vector3.ONE * (TORCH_FIRST_PERSON_SCALE if first_person else 1.0)
	if _body_mesh is CharacterModel and not first_person:
		_weapon.position = WEAPON_GRIP_POSITION
		_weapon.rotation = WEAPON_GRIP_ROTATION
		_torch.position = TORCH_GRIP_POSITION
		_torch.scale = Vector3.ONE * TORCH_GRIP_SCALE
	_torch.keep_upright = _body_mesh is CharacterModel and not first_person
