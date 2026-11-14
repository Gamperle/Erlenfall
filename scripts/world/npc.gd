class_name Npc
extends Interactable
## A villager the player can talk to.

const UI_GROUP := "dialogue_ui"
const BODY_RADIUS := 0.35
const BODY_HEIGHT := 1.75

var npc_id := ""
## The story flag that brings this villager to the village. Empty means they are always there.
var arrival_flag := ""
## Where the layout file puts them, in x and z: the place of a routine stop that names none.
var home := Vector2.ZERO
## Looks up the ground's height at an x and a z, so that walkers follow the land.
var ground_height := Callable()

var _label: Label3D
var _goal := Vector2.ZERO
## Places to walk through on the way to the goal, in order, ahead of the goal itself.
var _route: Array[Vector2] = []
var _goal_facing := NAN
var _body: Node3D
var _dialogue_ui: Node


func setup(data: Dictionary) -> void:
	npc_id = data["id"]
	prompt_key = data["name"]
	name = npc_id
	arrival_flag = data.get("appears_when", {}).get("flag", "")
	home = Vector2(data["x"], data["z"])

	if data.has("model") and FeatureFlags.enabled("realistic_villagers"):
		var model := CharacterModel.new()
		model.load_model(data["model"])
		add_child(model)
		_body = model
	else:
		var figure := Humanoid.new()
		figure.setup(Color(data["color"]), Humanoid.DEFAULT_SKIN, Color(data.get("hair", Humanoid.DEFAULT_HAIR.to_html())))
		add_child(figure)
		_body = figure

	var shape := CapsuleShape3D.new()
	shape.radius = BODY_RADIUS
	shape.height = BODY_HEIGHT
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = BODY_HEIGHT / 2.0
	add_child(collision)

	var label := Label3D.new()
	_label = label
	label.text = tr(prompt_key)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = BODY_HEIGHT + 0.15
	label.pixel_size = 0.006
	label.outline_size = 8
	add_child(label)


## Shows or hides the villager for the story flag that brings them, and makes them unreachable while away.
func apply_flags(flags: Dictionary) -> void:
	if arrival_flag.is_empty():
		return
	var here := flags.has(arrival_flag)
	visible = here
	if not here:
		set_process(false)
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).set_deferred("disabled", not here)


func is_available() -> bool:
	return arrival_flag.is_empty() or visible


func _ready() -> void:
	# Only walking needs a frame update.
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _label != null:
		_label.text = tr(prompt_key)


func prompt() -> String:
	return tr("PROMPT_TALK") % tr(prompt_key)


func interact(player: Player) -> void:
	# Villagers face -Z, so turn that side toward whoever is talking to them.
	var offset := player.global_position - global_position
	rotation.y = atan2(-offset.x, -offset.z)
	player.frame_conversation(global_position)
	get_tree().call_group(UI_GROUP, "open_conversation", npc_id, tr(prompt_key), player)


## Starts walking to a place. Does nothing if they are already there or heading there.
## A facing (radians around the vertical axis) is taken up on arrival. `via` lists places to walk
## through first, so the walk goes around buildings and water (#222).
func go_to(spot: Vector2, facing := NAN, via: Array[Vector2] = []) -> void:
	if _is_at(spot) or (is_processing() and _goal.is_equal_approx(spot)):
		return
	_goal = spot
	_route = via.duplicate()
	_goal_facing = facing
	set_process(true)


## Puts them at a place at once.
func place_at(spot: Vector2, facing := NAN) -> void:
	set_process(false)
	_route.clear()
	_body.animate(0.0, 0.0)
	position.x = spot.x
	position.z = spot.y
	_snap_to_ground()
	if not is_nan(facing):
		rotation.y = facing


func _is_at(spot: Vector2) -> bool:
	return Vector2(position.x, position.z).distance_to(spot) < 0.05


func _snap_to_ground() -> void:
	if ground_height.is_valid():
		position.y = ground_height.call(position.x, position.z)


## Only runs while walking.
func _process(delta: float) -> void:
	if _dialogue_ui == null:
		_dialogue_ui = get_tree().get_first_node_in_group(UI_GROUP)
	if _dialogue_ui != null and _dialogue_ui.is_open():
		return
	var speed: float = FeatureFlags.value("villager_walk_speed", 1.2)
	var step := speed * delta
	# Each stop on the way counts as reached once a step is enough to get there.
	while not _route.is_empty() and Vector2(position.x, position.z).distance_to(_route[0]) <= step:
		_route.remove_at(0)
	var to_go := (_route[0] if not _route.is_empty() else _goal) - Vector2(position.x, position.z)
	if _route.is_empty() and to_go.length() <= step:
		place_at(_goal, _goal_facing)
		return
	var heading := to_go.normalized()
	position.x += heading.x * step
	position.z += heading.y * step
	_snap_to_ground()
	# Villagers face -Z.
	rotation.y = lerp_angle(rotation.y, atan2(-heading.x, -heading.y), minf(1.0, delta * 8.0))
	_body.animate(speed, delta)
