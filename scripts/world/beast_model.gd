class_name BeastModel
extends Humanoid
## A four-legged animal built from shapes. Its feet are at its origin, and it faces -Z.

const STRIDE_PER_SPEED := 1.6
const MAX_BEAST_STRIDE := 0.8
const FULL_STRIDE_SPEED := 5.0
const SNAP_SECONDS := 0.5
const SNAP_REACH := 0.35
const HEAD_REST_Z := -0.5

var _legs: Array[Node3D] = []
var _head: Node3D
var _snap_left := 0.0


## Builds the animal at about 1 m long and 0.75 m high, to be scaled to its size.
func setup_beast(coat: Color, belly: Color) -> void:
	var coat_material := _new_material(coat)
	var belly_material := _new_material(belly)
	var dark_material := _new_material(coat.darkened(0.4))

	_add_part(self, _capsule(0.2, 0.9), coat_material, Vector3(0.0, 0.5, 0.0)).rotation.x = PI / 2.0
	_add_part(self, _capsule(0.14, 0.6), belly_material, Vector3(0.0, 0.4, 0.0)).rotation.x = PI / 2.0

	_head = Node3D.new()
	_head.position = Vector3(0.0, 0.62, HEAD_REST_Z)
	add_child(_head)
	_add_part(_head, _sphere(0.16), coat_material, Vector3.ZERO)
	_add_part(_head, _capsule(0.07, 0.3), dark_material, Vector3(0.0, -0.04, -0.2)).rotation.x = PI / 2.0
	for side: float in [-1.0, 1.0]:
		_add_part(_head, _capsule(0.04, 0.16), dark_material, Vector3(side * 0.1, 0.17, 0.04)).rotation.z = side * -0.3

	_add_part(self, _capsule(0.05, 0.4), coat_material, Vector3(0.0, 0.55, 0.62)).rotation.x = PI / 2.0 + 0.5

	for z: float in [-0.3, 0.3]:
		for x: float in [-0.13, 0.13]:
			_legs.append(_add_limb(Vector3(x, 0.4, z), _capsule(0.055, 0.42), dark_material))


func play_action(_animation_name: StringName, _duration := 0.0, _start := 0.0) -> void:
	_snap_left = SNAP_SECONDS


func animate(speed: float, delta: float) -> void:
	_phase += delta * STRIDE_PER_SPEED * speed
	_snap_left = maxf(_snap_left - delta, 0.0)
	var stride := sin(_phase) * MAX_BEAST_STRIDE * minf(speed / FULL_STRIDE_SPEED, 1.0)
	for i in _legs.size():
		# Diagonal legs move together.
		_legs[i].rotation.x = stride if (i == 0 or i == 3) else -stride
	_head.position.z = HEAD_REST_Z - sin(_snap_left / SNAP_SECONDS * PI) * SNAP_REACH
