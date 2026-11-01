class_name CraftingStation
extends Interactable
## Opens the crafting screen for one station, such as the furnace or the anvil.

const UI_GROUP := "crafting_ui"

var station_id := ""


func interact(player: Player) -> void:
	get_tree().call_group(UI_GROUP, "open_station", station_id, tr(prompt_key), player)
