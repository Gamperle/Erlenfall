class_name Interactable
extends StaticBody3D
## Something the player can use. Subclasses define what happens.

const GROUP := "interactable"

var prompt_key := ""


func _enter_tree() -> void:
	add_to_group(GROUP)


func is_available() -> bool:
	return true


func prompt() -> String:
	return tr(prompt_key)


func interact(_player: Player) -> void:
	pass
