class_name Torch
extends Node3D
## A burning torch with a flickering light.

const LIGHT_ENERGY := 1.8
const LIGHT_RANGE := 12.0
const FLICKER_AMOUNT := 0.2
const FLICKER_SPEED := 9.0

## Stays vertical however the hand holding it moves.
var keep_upright := false

var _light: OmniLight3D
var _time := 0.0


func _ready() -> void:
	add_child(ModelBuilder.torch())
	_light = OmniLight3D.new()
	_light.light_color = ModelBuilder.FIRE_COLOR
	_light.omni_range = LIGHT_RANGE
	_light.position = Vector3.UP * ModelBuilder.TORCH_FLAME_HEIGHT
	add_child(_light)
	set_lit(false)


func set_lit(lit: bool) -> void:
	visible = lit
	set_process(lit)


func _process(delta: float) -> void:
	if keep_upright:
		global_basis = Basis.IDENTITY.scaled(global_basis.get_scale())
	_time += delta * FLICKER_SPEED
	var flicker := sin(_time) * 0.6 + sin(_time * 2.3) * 0.4
	_light.light_energy = LIGHT_ENERGY * (1.0 + flicker * FLICKER_AMOUNT)
