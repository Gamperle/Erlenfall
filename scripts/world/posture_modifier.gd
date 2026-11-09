class_name PostureModifier
extends SkeletonModifier3D
## Straightens the back and neck over the animations, which lean these bodies forward by a different amount for each body.
## Measures the first pose once, then turns each bone back by the same amount in every pose after.
## Also brings hanging arms forward, since the animations pull the shoulders back and the arms hang behind the body,
## and turns the legs in, since the knees swing outward when running.
## The values can change at any time, and data/posture_tuning.json replaces the ones below. The posture tuner writes it.
## Leans and turns are in degrees. In the skeleton's axes, +Z is ahead, +Y is up, and +X is the character's left.

const TUNING_PATH := "res://data/posture_tuning.json"

## Each bone, the two joints whose line it sets, and the property that holds how far that line should lean.
const SEGMENTS := [
	[&"Spine", &"Hips", &"Neck", &"spine_lean"],
	[&"UpperChest", &"UpperChest", &"Neck", &"chest_lean"],
	[&"Neck", &"Neck", &"Head", &"neck_lean"],
]

## How far each line leans, as in the bodies' own rest pose.
var spine_lean := 1.0
var chest_lean := 6.0
var neck_lean := 19.0
## How far each shoulder turns forward around the upright axis, and each upper arm swings forward, when the arm hangs down.
var shoulder_turn_degrees := 18.0
var arm_swing_degrees := 6.0
## How far each shoulder is raised, each upper arm is spread away from the body, and each upper arm is twisted around its length, when the arm hangs down.
var shoulder_raise_degrees := 0.0
var arm_out_degrees := 0.0
var arm_twist_degrees := 0.0
## How far down the upper arm points, from 0 for level to 1 for straight down, where the turns start and reach full strength.
var hanging_from := 0.5
var hanging_to := 0.85
## How much of the arms' sideways swing, in and out of the body, is removed: 0 keeps it, and 1 holds each upper arm at the angle it has had on average over the last moments.
## Arms raised above the shoulder are left alone.
var arm_sideways_damping := 0.0
## How far each elbow is brought toward the body, in every pose but with the arms raised above the shoulder.
## Arm out does the same only for arms hanging straight down, which running's arms are not.
var elbow_in_degrees := 0.0
## 1 changes only hanging arms, so a raised torch or sword stays where the animation holds it, and 0 changes the arms in every pose.
var arm_hanging_only := 1.0
## How far each thigh is brought toward the middle, each thigh is twisted around its length so the knee turns in,
## each shin is brought toward the middle, and each foot is turned so the toes point in.
var thigh_in_degrees := 0.0
var thigh_twist_degrees := 0.0
var shin_in_degrees := 0.0
var foot_in_degrees := 0.0

## How long, in seconds, the average angle of an arm takes to follow it, which should be longer than a stride.
const AVERAGE_SECONDS := 0.5

## How far each line leans in the first pose, before any turn.
var _measured: Array[float] = []
## How far out each upper arm has pointed on average, by side, in radians, and when that was last updated.
var _average_out := {}
var _average_time := 0.0
var _average_blend := 0.0

static var _tuning: Dictionary
static var _tuning_loaded := false


## Starts with the saved values, or without them to get the ones written above.
func _init(tuned := true) -> void:
	if not tuned:
		return
	for property: String in _load_tuning():
		set(property, float(_tuning[property]))


## The values saved by the posture tuner, by property name.
static func _load_tuning() -> Dictionary:
	if not _tuning_loaded:
		_tuning_loaded = true
		if FileAccess.file_exists(TUNING_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TUNING_PATH))
			if parsed is Dictionary:
				_tuning = parsed
	return _tuning


func _process_modification() -> void:
	var skeleton := get_skeleton()
	var measuring := _measured.is_empty()
	for index in SEGMENTS.size():
		var segment: Array = SEGMENTS[index]
		if measuring:
			_measured.append(_lean(skeleton, segment[1], segment[2]))
		_turn(skeleton, segment[0], Quaternion(Vector3.RIGHT, deg_to_rad(get(segment[3])) - _measured[index]))
	var now := Time.get_ticks_usec() / 1000000.0
	_average_blend = 1.0 - exp(-clampf(now - _average_time, 0.0, 0.1) / AVERAGE_SECONDS)
	_average_time = now
	# Each side's turns are mirrored, with +1 for the left side and -1 for the right.
	for side in [["Left", 1.0], ["Right", -1.0]]:
		_process_arm(skeleton, side[0], side[1])
		_process_leg(skeleton, side[0], side[1])


func _process_arm(skeleton: Skeleton3D, side: String, mirror: float) -> void:
	var upper := StringName(side + "UpperArm")
	var axis := _direction(skeleton, upper, StringName(side + "LowerArm"))
	var hanging := smoothstep(hanging_from, hanging_to, -axis.y)
	var strength := lerpf(1.0, hanging, arm_hanging_only)
	_turn(skeleton, StringName(side + "Shoulder"), Quaternion(Vector3.UP, -mirror * strength * deg_to_rad(shoulder_turn_degrees)) \
		* Quaternion(Vector3.BACK, mirror * strength * deg_to_rad(shoulder_raise_degrees)))
	_turn(skeleton, upper, Quaternion(Vector3.RIGHT, -strength * deg_to_rad(arm_swing_degrees)) \
		* Quaternion(Vector3.BACK, mirror * strength * deg_to_rad(arm_out_degrees)))
	axis = _direction(skeleton, upper, StringName(side + "LowerArm"))
	# Holds the arm nearer its average angle out of the body, where the animation swings it in and out.
	var out := atan2(mirror * axis.x, -axis.y)
	var average: float = _average_out.get(side, out)
	_average_out[side] = lerp_angle(average, out, _average_blend)
	var held := lerp_angle(out, average, arm_sideways_damping * smoothstep(0.2, -0.2, axis.y))
	_turn(skeleton, upper, Quaternion(Vector3.BACK, mirror * (held - out)))
	_turn(skeleton, upper, Quaternion(Vector3.BACK, -mirror * deg_to_rad(elbow_in_degrees) * smoothstep(0.2, -0.2, axis.y)))
	# The twist is around the arm as it is now, after the turns above.
	axis = _direction(skeleton, upper, StringName(side + "LowerArm"))
	_turn(skeleton, upper, Quaternion(axis, mirror * strength * deg_to_rad(arm_twist_degrees)))


func _process_leg(skeleton: Skeleton3D, side: String, mirror: float) -> void:
	var thigh := StringName(side + "UpperLeg")
	_turn(skeleton, thigh, Quaternion(Vector3.BACK, -mirror * deg_to_rad(thigh_in_degrees)))
	var axis := _direction(skeleton, thigh, StringName(side + "LowerLeg"))
	_turn(skeleton, thigh, Quaternion(axis, mirror * deg_to_rad(thigh_twist_degrees)))
	_turn(skeleton, StringName(side + "LowerLeg"), Quaternion(Vector3.BACK, -mirror * deg_to_rad(shin_in_degrees)))
	_turn(skeleton, StringName(side + "Foot"), Quaternion(Vector3.UP, -mirror * deg_to_rad(foot_in_degrees)))


## Turns a bone by a rotation in the skeleton's axes, keeping its parent where it is.
func _turn(skeleton: Skeleton3D, bone_name: StringName, turn: Quaternion) -> void:
	var bone := skeleton.find_bone(bone_name)
	var wanted := turn * skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()
	var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone, (parent.inverse() * wanted).normalized())


func _direction(skeleton: Skeleton3D, from: StringName, to: StringName) -> Vector3:
	return (skeleton.get_bone_global_pose(skeleton.find_bone(to)).origin - skeleton.get_bone_global_pose(skeleton.find_bone(from)).origin).normalized()


func _lean(skeleton: Skeleton3D, from: StringName, to: StringName) -> float:
	var line := skeleton.get_bone_global_pose(skeleton.find_bone(to)).origin - skeleton.get_bone_global_pose(skeleton.find_bone(from)).origin
	return atan2(line.z, line.y)
