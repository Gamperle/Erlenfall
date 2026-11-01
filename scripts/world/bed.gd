class_name Bed
extends Interactable
## Sleeping heals the player, passes the night, and saves the game.

const GAME_GROUP := "game"


func interact(_player: Player) -> void:
	get_tree().call_group(GAME_GROUP, "sleep")
