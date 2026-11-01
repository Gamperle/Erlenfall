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
const THIRD_PERSON_DISTANCE := 4.0

const INTERACT_DISTANCE := 3.5
const INTERACT_FACING := 0.3

var first_person := false
var inventory := Inventory.new()
var known_recipes: Dictionary = {}
var quests := QuestLog.new()
## What pressing the use button would act on right now, if anything.
var interact_target: Interactable

var _busy := false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _pivot: Node3D = $CameraPivot
@onready var _spring_arm: SpringArm3D = $CameraPivot/SpringArm
@onready var _body_mesh: Node3D = $Body


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


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative * MOUSE_SENSITIVITY)
	elif event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("inventory"):
		get_tree().call_group(CraftingStation.UI_GROUP, "open_inventory", self)
	elif event.is_action_pressed("toggle_camera"):
		first_person = not first_person
		_apply_camera_mode()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
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
	var acceleration := ACCELERATION if is_on_floor() else AIR_ACCELERATION
	var target := direction * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	move_and_slide()
	_keep_inside_world()
	interact_target = _find_interact_target()

	if direction.length_squared() > 0.01:
		var target_yaw := atan2(-direction.x, -direction.z)
		_body_mesh.rotation.y = lerp_angle(_body_mesh.rotation.y, target_yaw, TURN_SPEED * delta)


func _find_interact_target() -> Interactable:
	var forward := Vector3.FORWARD.rotated(Vector3.UP, _pivot.rotation.y)
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
	_body_mesh.visible = not first_person
