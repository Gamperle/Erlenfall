class_name Player
extends CharacterBody3D
## Walks the valley with third- and first-person cameras, on keyboard, mouse, and controller.

## Asks the game to show the player a short message.
signal notice(text_key: String)
signal busy_changed
signal hurt
signal stamina_changed
## How full the heavy swing's charge is, from 0 to 1, or -1 when nothing is charging.
signal charge_changed(fraction: float)

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
## Said when a projectile needs a launcher, such as a bow, and the player carries none that fits.
const NEED_LAUNCHER_NOTICE := "UI_NEED_BOW"
const PLAYER_CLOTH_COLOR := Color(0.45, 0.3, 0.2)
const MAX_HEALTH := 100.0
const REGEN_DELAY := 8.0
const UNARMED_DAMAGE := 5.0
const ATTACK_WINDUP := 0.15
const ATTACK_COOLDOWN := 0.55
## How long the body glows when a heavy swing is full or lands.
const CHARGE_FULL_GLOW_SECONDS := 0.2
const HEAVY_GLOW_SECONDS := 0.35
const ATTACK_RANGE := 2.4
const ATTACK_FACING := 0.4
const BLOCK_SPEED_FACTOR := 0.4
const BLOCK_DAMAGE_FACTOR := 0.2
const BLOCK_FACING := 0.2
const DODGE_SPEED := 9.0
const DODGE_SECONDS := 0.25
const DODGE_COOLDOWN := 0.8
## Stamina: sprinting and dodging spend it, blocking a hit costs some, and it refills when not spent.
const MAX_STAMINA := 100.0
const STAMINA_REGEN := 25.0
const STAMINA_REGEN_DELAY := 0.8
const SPRINT_STAMINA_PER_SECOND := 15.0
## After running dry, sprinting waits until this much has come back.
const SPRINT_RESUME_STAMINA := 20.0
const DODGE_STAMINA_COST := 25.0
## Blocking a hit costs this much stamina per point of damage the hit would have done.
const BLOCK_STAMINA_PER_DAMAGE := 1.5
## When a block breaks, the guard stays down this long.
const BLOCK_BREAK_SECONDS := 1.5
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
const DODGE_ANIMATION_SECONDS := 0.8
## The roll keeps carrying the player after the protected part of the dodge ends.
const ROLL_CARRY_SPEED := 3.0
const BACKSTEP_ANIMATION := &"Crouch_Idle"
const BACKSTEP_ANIMATION_SECONDS := 0.4
const BLOCK_ANIMATION := &"Sword_Idle"
const TORCH_ANIMATION := &"Idle_Torch"
const WEAPON_GRIP_POSITION := Vector3(0.0, 0.095, 0.035)
## The blade runs through the closed hand, out past the index finger.
const WEAPON_BLADE_IN_HAND := Vector3(0.96, 0.15, -0.22)
const TORCH_GRIP_POSITION := Vector3(0.0, 0.095, 0.035)
const TORCH_GRIP_SCALE := 0.75
const TORCH_ITEM := "torch"
## How high above the feet projectiles start.
const RANGED_ORIGIN_HEIGHT := 1.4
const TORCH_ARM_RAISE := 1.2
const TORCH_HAND_POSITION := Vector3(0.0, -0.58, -0.05)
const TORCH_FIRST_PERSON_POSITION := Vector3(-0.4, -0.5, -0.7)
const TORCH_FIRST_PERSON_SCALE := 0.7
## How many things overhead the buried check looks past before giving up.
const BURIED_RAY_ATTEMPTS := 8

var first_person := false
var inventory := Inventory.new()
var _shown_weapon := "-"
var _shown_variant := ""
var _tool_in_hand := ""
var _tool_seconds := 0.0
var known_recipes: Dictionary = {}
## Practice in each craft, by skill id.
var skill_xp: Dictionary = {}
var quests := QuestLog.new()
var notes := JournalNotes.new()
## What pressing the use button would act on right now, if anything.
var interact_target: Interactable
var torch_lit := false
var torch_given := false
## Whether the starting bow, arrows, and flasks have been given.
var ranged_given := false
## How long the current torch has burned, when torches burn out.
var torch_burned_seconds := 0.0

var health := Health.new(MAX_HEALTH)
var stamina := MAX_STAMINA

var _busy := false
var _look_before_conversation: Variant = null
var _attack_cooldown := 0.0
var _attack_windup := 0.0
## How long the attack button has been held, or -1 when it isn't (see HeavySwing).
var _charge := -1.0
var _swing_heavy := false
var _charge_shown := -1.0
var _glow_left := 0.0
var _ranged_cooldown := 0.0
var _dodge_time := 0.0
var _dodge_cooldown := 0.0
var _stamina_pause := 0.0
var _block_broken := 0.0
var _winded := false
var _dodge_direction := Vector3.ZERO
var _roll_left := 0.0
var _hand_pose: HandPose
var _since_hit := REGEN_DELAY
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _torch := Torch.new()

@onready var _pivot: Node3D = $CameraPivot
@onready var _spring_arm: SpringArm3D = $CameraPivot/SpringArm
@onready var _body_mesh: Humanoid = $Body
@onready var _weapon: Node3D = $CameraPivot/Weapon


## Adds practice to a skill, and returns the new level if this raised it, or 0.
func practice(skill_id: String, xp: int) -> int:
	var before := CraftingData.skill_level(skill_id, skill_xp.get(skill_id, 0))
	skill_xp[skill_id] = int(skill_xp.get(skill_id, 0)) + xp
	var after := CraftingData.skill_level(skill_id, skill_xp[skill_id])
	return after if after > before else 0


func skill_level(skill_id: String) -> int:
	return CraftingData.skill_level(skill_id, skill_xp.get(skill_id, 0))


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	inventory.changed.connect(_update_weapon_model)
	_update_weapon_model()
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


## Whether the player moves quietly, which makes enemies notice them from less far away.
## Held, and not while busy, rolling, or blocking. Off when the `sneaking` flag is off.
func is_sneaking() -> bool:
	return FeatureFlags.enabled("sneaking") and not _busy and not is_dodging() and not is_blocking() \
			and Input.is_action_pressed("sneak")


func is_blocking() -> bool:
	return not _busy and _block_broken <= 0.0 and Input.is_action_pressed("block")


## Whether stamina limits the player. Off when the `stamina` flag is off.
func uses_stamina() -> bool:
	return FeatureFlags.enabled("stamina")


## Whether the player is running, which needs stamina.
func is_sprinting() -> bool:
	return Input.is_action_pressed("sprint") and not _winded and Input.get_vector(
			"move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO


## Spends stamina if there is enough, and reports whether it did. Always succeeds without the flag.
func spend_stamina(amount: float) -> bool:
	if not uses_stamina():
		return true
	if stamina < amount:
		return false
	_lose_stamina(amount)
	return true


func _lose_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_stamina_pause = STAMINA_REGEN_DELAY
	stamina_changed.emit()


## Puts a tool such as the axe in hand for a while, after which the weapon comes back.
func show_tool(item_id: String, seconds: float) -> void:
	_tool_in_hand = item_id
	_tool_seconds = seconds
	_update_weapon_model()


## The item the hand shows right now, or "" for empty hands.
func item_in_hand() -> String:
	return _shown_weapon


## The weapon in hand is the one that attacks use, unless a tool is out. Empty hands show nothing.
func _update_weapon_model() -> void:
	var weapon := { "id": _tool_in_hand, "variant": "" } if _tool_seconds > 0.0 else inventory.best_weapon()
	var weapon_id: String = weapon["id"]
	if weapon_id == _shown_weapon and weapon["variant"] == _shown_variant:
		return
	_shown_weapon = weapon_id
	_shown_variant = weapon["variant"]
	for child in _weapon.get_children():
		child.queue_free()
	var model := CraftingData.item_model(weapon_id, _shown_variant)
	if model != null:
		_weapon.add_child(model)


## Gives the starting torch once per game, including to games saved before torches existed.
func give_starting_items() -> void:
	if not torch_given and FeatureFlags.enabled("torch_at_start"):
		torch_given = true
		inventory.add(TORCH_ITEM)


## Gives the placeholder bow, arrows, and flasks once per game. They can also be crafted.
func give_ranged_items() -> void:
	if not ranged_given and FeatureFlags.enabled("ranged_starting_items"):
		ranged_given = true
		inventory.add("short_bow")
		inventory.add("arrow", int(FeatureFlags.value("ranged_starting_arrows", 10)))
		inventory.add("fire_flask", int(FeatureFlags.value("ranged_starting_flasks", 3)))


## Fires the projectile type that belongs to this action ("shoot" or "throw"), if the player has what it needs.
## Reports whether something was fired.
func fire_ranged(action: String) -> bool:
	if not FeatureFlags.enabled("ranged_weapons") or _ranged_cooldown > 0.0 or is_blocking() or is_dodging():
		return false
	for projectile_id: String in Projectile.type_ids():
		var type := Projectile.stats(projectile_id)
		if type["action"] != action:
			continue
		var strength := 1.0
		if type["requires_item"] != "":
			var launchers := CraftingData.launchers(projectile_id)
			if launchers.is_empty():
				launchers.append(type["requires_item"])
			strength = inventory.best_launcher_multiplier(launchers)
			if strength == 0.0:
				notice.emit(NEED_LAUNCHER_NOTICE)
				return false
		var ammo := inventory.take_best_ranged(type["ammo_item"])
		if ammo == 0.0:
			notice.emit("UI_NO_" + String(type["ammo_item"]).to_upper())
			return false
		_ranged_cooldown = type["cooldown"]
		var aim := -_pivot.global_basis.z
		var origin := global_position + Vector3.UP * RANGED_ORIGIN_HEIGHT + _forward() * 0.5
		get_parent().add_child(Projectile.launch(projectile_id, origin, aim, self, strength * ammo))
		_body_mesh.rotation.y = _pivot.rotation.y
		return true
	return false


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
## Starts a swing if one can start now, and reports whether it did.
func attack(heavy := false) -> bool:
	var ready_to_swing := _attack_cooldown <= 0.0 and not is_blocking() and not is_dodging()
	if ready_to_swing:
		_swing_heavy = heavy and HeavySwing.enabled()
		if _swing_heavy and not spend_stamina(HeavySwing.stamina_cost()):
			_swing_heavy = false
			notice.emit("UI_TOO_TIRED_HEAVY")
		_attack_cooldown = ATTACK_COOLDOWN * (HeavySwing.recovery_factor() if _swing_heavy else 1.0)
		_attack_windup = HeavySwing.windup_seconds() if _swing_heavy else ATTACK_WINDUP
		if _swing_heavy:
			_flash(HEAVY_GLOW_SECONDS)
		_body_mesh.play_action(ATTACK_ANIMATION)
		_body_mesh.rotation.y = _pivot.rotation.y
	return ready_to_swing


## Rolls in the direction of movement, or backward when standing still. Avoids all damage.
func dodge() -> void:
	if _dodge_cooldown > 0.0 or not is_on_floor() or not spend_stamina(DODGE_STAMINA_COST):
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
		_body_mesh.play_action(DODGE_ANIMATION, DODGE_ANIMATION_SECONDS)
		_roll_left = DODGE_ANIMATION_SECONDS
	_dodge_time = DODGE_SECONDS
	_dodge_cooldown = DODGE_COOLDOWN


## Takes damage from an attack that came from the given position.
func take_hit(amount: float, from_position: Vector3) -> void:
	if is_dodging() or not health.is_alive():
		return
	var offset := from_position - global_position
	offset.y = 0.0
	if is_blocking() and _forward().dot(offset.normalized()) > BLOCK_FACING:
		if spend_stamina(amount * BLOCK_STAMINA_PER_DAMAGE):
			amount *= BLOCK_DAMAGE_FACTOR
		else:
			# Not enough strength left: the guard breaks and the hit lands in full.
			_lose_stamina(stamina)
			_block_broken = BLOCK_BREAK_SECONDS
			notice.emit("UI_BLOCK_BROKEN")
	_since_hit = 0.0
	hurt.emit()
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
	_block_broken = 0.0
	_winded = false
	stamina = MAX_STAMINA
	stamina_changed.emit()
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
		_look(event.screen_relative * MOUSE_SENSITIVITY * Settings.look_speed)
	elif event.is_action_pressed("attack"):
		if HeavySwing.enabled():
			_charge = 0.0
		else:
			attack()
	elif event.is_action_released("attack") and _charge >= 0.0:
		var held := _charge
		_charge = -1.0
		attack(HeavySwing.is_charged(held))
	elif event.is_action_pressed("shoot"):
		fire_ranged("shoot")
	elif event.is_action_pressed("throw"):
		fire_ranged("throw")
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
		_look(stick * STICK_SENSITIVITY * Settings.look_speed * delta)

	if is_on_floor():
		if not _busy and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= _gravity * delta

	var move := Vector2.ZERO
	if not _busy:
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(move.x, 0.0, move.y).rotated(Vector3.UP, _pivot.rotation.y)
	var speed := SPRINT_SPEED if is_sprinting() else WALK_SPEED
	if is_sneaking():
		speed = WALK_SPEED * float(FeatureFlags.value("sneak_speed_factor", 0.5))
	if is_blocking():
		speed = WALK_SPEED * BLOCK_SPEED_FACTOR
	var terrain := get_tree().get_first_node_in_group(Terrain.GROUP) as Terrain
	if terrain != null:
		speed *= terrain.wading_factor(global_position)
	var acceleration := ACCELERATION if is_on_floor() else AIR_ACCELERATION
	var target := direction * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	_roll_left = maxf(_roll_left - delta, 0.0)
	if is_dodging():
		velocity.x = _dodge_direction.x * DODGE_SPEED
		velocity.z = _dodge_direction.z * DODGE_SPEED
	elif _roll_left > 0.0:
		velocity.x = _dodge_direction.x * ROLL_CARRY_SPEED
		velocity.z = _dodge_direction.z * ROLL_CARRY_SPEED
	move_and_slide()
	_keep_inside_world()
	if terrain != null:
		lift_out_of_ground(terrain)
	interact_target = _find_interact_target()
	_body_mesh.animate(Vector2(velocity.x, velocity.z).length(), delta)

	if direction.length_squared() > 0.01:
		var target_yaw := atan2(-direction.x, -direction.z)
		_body_mesh.rotation.y = lerp_angle(_body_mesh.rotation.y, target_yaw, TURN_SPEED * delta)


func _update_stamina(delta: float) -> void:
	if not uses_stamina():
		if stamina < MAX_STAMINA:
			stamina = MAX_STAMINA
			stamina_changed.emit()
		_winded = false
		return
	_stamina_pause = maxf(_stamina_pause - delta, 0.0)
	var running := not _busy and is_sprinting() and Vector2(velocity.x, velocity.z).length() > WALK_SPEED * 0.5
	if running:
		_lose_stamina(SPRINT_STAMINA_PER_SECOND * delta)
		if stamina <= 0.0:
			_winded = true
	elif _stamina_pause <= 0.0 and stamina < MAX_STAMINA:
		stamina = minf(stamina + STAMINA_REGEN * delta, MAX_STAMINA)
		stamina_changed.emit()
	if _winded and stamina >= SPRINT_RESUME_STAMINA:
		_winded = false


## Tracks the held attack button, and shows the charge as a raised sword, a bar, and a flash when full.
func _update_charge(delta: float) -> void:
	if _glow_left > 0.0:
		_glow_left -= delta
		_body_mesh.set_glow(Accessibility.color("warning"), maxf(_glow_left, 0.0) / HEAVY_GLOW_SECONDS * 2.0)
	var was_full := _charge >= HeavySwing.charge_seconds()
	if _charge >= 0.0:
		_charge = _charge + delta if Input.is_action_pressed("attack") else -1.0
	var shown := -1.0
	if _charge >= HeavySwing.pose_delay_seconds():
		shown = HeavySwing.charge_fraction(_charge)
	if _charge >= HeavySwing.charge_seconds() and not was_full:
		_flash(CHARGE_FULL_GLOW_SECONDS)
	if shown != _charge_shown:
		_charge_shown = shown
		charge_changed.emit(shown)
	if _body_mesh is CharacterModel:
		_hand_pose.winding = shown >= 0.0 and not is_blocking()


## Makes the body glow briefly, as a cue.
func _flash(seconds: float) -> void:
	_glow_left = seconds


func _update_combat(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_ranged_cooldown = maxf(_ranged_cooldown - delta, 0.0)
	_dodge_time = maxf(_dodge_time - delta, 0.0)
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	_block_broken = maxf(_block_broken - delta, 0.0)
	_update_stamina(delta)
	_update_charge(delta)
	if _tool_seconds > 0.0:
		_tool_seconds -= delta
		if _tool_seconds <= 0.0:
			_update_weapon_model()
	if _attack_windup > 0.0:
		_attack_windup -= delta
		if _attack_windup <= 0.0:
			_land_attack()

	_since_hit += delta
	if _since_hit >= Healing.regen_delay() and health.is_alive() and health.current < health.maximum:
		health.heal(Healing.regen_per_second() * delta)

	if _body_mesh is CharacterModel:
		var idle: StringName = &""
		if is_blocking():
			idle = BLOCK_ANIMATION
		elif torch_lit:
			idle = TORCH_ANIMATION
		(_body_mesh as CharacterModel).idle_override = idle
		SneakLook.apply(self, _body_mesh as CharacterModel)
		_hand_pose.guarding = is_blocking() and not is_dodging()
		_hand_pose.grip_left = torch_lit
		# In third person, the model's own animations move the weapon.
		if not first_person:
			return

	# Swing the placeholder weapon while the cooldown runs, and raise it to block.
	var swing := minf(maxf(_attack_cooldown / ATTACK_COOLDOWN, maxf(_charge_shown, 0.0)), 1.0)
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


## A swing hits with the item in hand, so a chop hits with the axe even when a sword is carried.
func swing_damage() -> float:
	return maxf(inventory.weapon_damage(_shown_weapon), UNARMED_DAMAGE)


func _land_attack() -> void:
	var damage := swing_damage() * (HeavySwing.damage_factor() if _swing_heavy else 1.0)
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		if offset.length() < ATTACK_RANGE and _forward().dot(offset.normalized()) > ATTACK_FACING:
			enemy.take_hit(damage, global_position)


func _forward() -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, _pivot.rotation.y)


## The way the player is facing, along the ground.
func facing_direction() -> Vector3:
	return _forward()


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


## Puts a player who ended up inside the ground back on top of it, and reports whether it did.
## Only the ground's own collision counts, so a roof or bridge overhead never lifts anyone, and
## the ray looks down from above, since the collision itself can lie away from `height_at`.
func lift_out_of_ground(terrain: Terrain) -> bool:
	if not FeatureFlags.enabled("lift_buried_player"):
		return false
	var depth: float = FeatureFlags.value("buried_player_depth", 0.1)
	var feet := global_position
	var top := maxf(feet.y, terrain.height_at(feet.x, feet.z)) + float(FeatureFlags.value("buried_player_ray_height", 6.0))
	var from := Vector3(feet.x, top, feet.z)
	var query := PhysicsRayQueryParameters3D.create(from, feet + Vector3.UP * depth)
	query.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	for attempt in BURIED_RAY_ATTEMPTS:
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return false
		if hit["collider"] == terrain:
			global_position.y = hit["position"].y
			velocity.y = maxf(velocity.y, 0.0)
			return true
		# Something else overhead, like a roof or a bridge. Look past it.
		query.exclude = query.exclude + [hit["rid"]]
	return false


func _replace_body() -> void:
	var old_body := _body_mesh
	remove_child(old_body)
	old_body.free()
	var model := CharacterModel.new()
	model.name = "Body"
	model.load_model(MODEL_PATH)
	add_child(model)
	_body_mesh = model
	_hand_pose = HandPose.new()
	_hand_pose.blade_in_hand = WEAPON_BLADE_IN_HAND.normalized()
	model.add_modifier(_hand_pose)


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
		_weapon.quaternion = Quaternion(Vector3.UP, WEAPON_BLADE_IN_HAND.normalized())
		_torch.position = TORCH_GRIP_POSITION
		_torch.scale = Vector3.ONE * TORCH_GRIP_SCALE
	_torch.keep_upright = _body_mesh is CharacterModel and not first_person
