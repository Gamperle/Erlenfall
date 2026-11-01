class_name Health
extends RefCounted
## Hit points shared by the player and enemies.

signal changed
signal died

var maximum: float
var current: float


func _init(max_health: float) -> void:
	maximum = max_health
	current = max_health


func is_alive() -> bool:
	return current > 0.0


func fraction() -> float:
	return current / maximum


func damage(amount: float) -> void:
	if not is_alive():
		return
	current = maxf(current - amount, 0.0)
	changed.emit()
	if current == 0.0:
		died.emit()


func heal(amount: float) -> void:
	current = minf(current + amount, maximum)
	changed.emit()


func restore() -> void:
	heal(maximum)
