class_name RepairSite
extends Interactable
## A place where the player helps repair a building during one quest objective.

var quest_id := ""
var objective_id := ""
var flag := ""


func setup(data: Dictionary) -> void:
	quest_id = data["quest"]
	objective_id = data["objective"]
	flag = data["flag"]
	prompt_key = data["prompt"]


func is_available() -> bool:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	return player != null and player.quests.current_objective(quest_id) == objective_id


func interact(player: Player) -> void:
	player.quests.flags[flag] = true
	player.quests.advance(quest_id)
