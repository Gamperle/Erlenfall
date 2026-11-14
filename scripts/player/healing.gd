class_name Healing
extends RefCounted
## Health recovery: slow regeneration out of combat, and eating or drinking items that have a "use" action in the data.


## Seconds without a hit before regeneration starts, or 0 if regeneration is switched off.
static func regen_delay() -> float:
	return float(FeatureFlags.value("health_regen_delay_seconds", 8.0))


## Health regained per second once regeneration has started. 0 when the feature is off.
static func regen_per_second() -> float:
	if not FeatureFlags.enabled("health_regen"):
		return 0.0
	return float(FeatureFlags.value("health_regen_per_second", 2.0))


## Whether the item can be used from the inventory.
static func is_usable(item_id: String) -> bool:
	return FeatureFlags.enabled("healing_items") and CraftingData.heal_amount(item_id) > 0.0


## Uses one carried copy of the item, and reports whether it did. Needs the item, a live player, and missing health.
static func use_item(player: Player, item_id: String) -> bool:
	if not is_usable(item_id) or not player.health.is_alive() or player.health.current >= player.health.maximum:
		return false
	if not player.inventory.remove(item_id):
		return false
	player.health.heal(CraftingData.heal_amount(item_id))
	return true
