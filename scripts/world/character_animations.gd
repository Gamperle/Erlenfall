class_name CharacterAnimations
extends RefCounted
## The animations shared by all character models, prepared once.

const SOURCE := preload("res://assets/animations/humanoid.glb")
const LOOPING: Array[StringName] = [&"Idle", &"Idle_Torch", &"Sword_Idle", &"Walk", &"Sprint", &"Crouch_Idle", &"Crouch_Fwd"]

static var _library: AnimationLibrary


## Adds a player to a character model and starts an animation at a random point, so villagers don't move in step.
static func play(model: Node3D, animation_name: StringName) -> AnimationPlayer:
	var player := AnimationPlayer.new()
	player.name = "Animations"
	model.add_child(player)
	player.owner = model
	player.root_node = NodePath("..")
	player.add_animation_library("", library())
	player.play(animation_name)
	player.seek(randf() * player.current_animation_length, true)
	return player


static func library() -> AnimationLibrary:
	if _library == null:
		_library = _prepare()
	return _library


static func _prepare() -> AnimationLibrary:
	var source: Node = SOURCE.instantiate()
	var player: AnimationPlayer = source.find_child("AnimationPlayer", true, false)
	var original := player.get_animation_library("")
	var prepared := AnimationLibrary.new()
	for animation_name in original.get_animation_list():
		var animation: Animation = original.get_animation(animation_name).duplicate(true)
		if animation_name in LOOPING:
			animation.loop_mode = Animation.LOOP_LINEAR
		prepared.add_animation(animation_name, animation)
	source.free()
	return prepared
