class_name HammerGame
extends RefCounted
## Forging rules: strike when the marker is over the target. Accuracy decides quality.

const BASE_SPEED := 0.9
const TARGET_WIDTH := 0.14
const MISS_DISTANCE := 0.3
const SPEED_GAIN_PER_STRIKE := 0.08

var marker := 0.0
var target := 0.5
var strikes_done := 0
var strikes_total: int
var speed: float

var _direction := 1.0
var _total_accuracy := 0.0
var _random := RandomNumberGenerator.new()


func _init(strikes: int, speed_factor: float) -> void:
	strikes_total = strikes
	speed = BASE_SPEED * speed_factor
	_pick_target()


func is_finished() -> bool:
	return strikes_done >= strikes_total


func update(delta: float) -> void:
	marker += _direction * speed * delta
	if marker >= 1.0 or marker <= 0.0:
		marker = clampf(marker, 0.0, 1.0)
		_direction = -_direction


## Scores a strike at the marker's position and returns its accuracy from 0 to 1.
func strike() -> float:
	var distance := maxf(absf(marker - target) - TARGET_WIDTH / 2.0, 0.0)
	var accuracy := clampf(1.0 - distance / MISS_DISTANCE, 0.0, 1.0)
	_total_accuracy += accuracy
	strikes_done += 1
	speed += SPEED_GAIN_PER_STRIKE
	_pick_target()
	return accuracy


func score() -> float:
	return _total_accuracy / maxi(strikes_done, 1)


func _pick_target() -> void:
	target = _random.randf_range(0.15, 0.85)
