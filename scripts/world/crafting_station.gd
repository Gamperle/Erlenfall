class_name CraftingStation
extends Interactable
## Opens the crafting screen for one station, such as the furnace or the anvil.

const UI_GROUP := "crafting_ui"
const STATION_GROUP := "crafting_stations"
const MADE_WEAPON_ROTATION := Vector3(-PI / 2.0, 0.0, PI / 2.0)

var station_id := ""
## Where something just made lies on the station. Not every station has a flat top.
var work_spot: Variant = null

var _made_model: Node3D


func _enter_tree() -> void:
	super()
	add_to_group(STATION_GROUP)


func interact(player: Player) -> void:
	get_tree().call_group(UI_GROUP, "open_station", station_id, tr(prompt_key), player)


## Lays the newest thing made here on the station, in place of the last one.
func show_made(at_station: String, item_id: String, variant: String = "") -> void:
	if at_station != station_id or work_spot == null:
		return
	if _made_model != null:
		_made_model.queue_free()
	_made_model = CraftingData.item_model(item_id, variant)
	if _made_model != null:
		_made_model.position = work_spot
		# Weapons are modeled upright, so they lie down. Other items are modeled lying flat.
		if CraftingData.weapon_damage(item_id, "") > 0.0:
			_made_model.rotation = MADE_WEAPON_ROTATION
			var middle := Vector3.UP * CraftingData.item_length(item_id) / 2.0
			_made_model.position -= _made_model.basis * middle
		add_child(_made_model)
