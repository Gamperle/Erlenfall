class_name ResourceNode
extends Interactable
## A gathering spot that gives one item per use and regrows after being used up.

var item_id := ""
var uses := 3
var respawn_seconds := 120.0

var _uses_left := 0
var _visual: Node3D


func setup(data: Dictionary, visual: Node3D) -> void:
	item_id = data["item"]
	prompt_key = data["prompt"]
	uses = data["uses"]
	respawn_seconds = data["respawn_seconds"]
	_uses_left = uses
	_visual = visual
	add_child(visual)


func is_available() -> bool:
	return _uses_left > 0


func interact(player: Player) -> void:
	player.inventory.add(item_id)
	_uses_left -= 1
	if _uses_left == 0:
		_visual.visible = false
		get_tree().create_timer(respawn_seconds).timeout.connect(_respawn)


func _respawn() -> void:
	_uses_left = uses
	_visual.visible = true
