class_name PostureModifier
extends SkeletonModifier3D
## Straightens the back and neck over the animations, which lean these bodies forward by a different amount for each body.
## Measures the first pose once, then turns each bone back by the same amount in every pose after.
## The values can change at any time.
## Also brings hanging arms forward, since the animations pull the shoulders back and the arms hang behind the body.
## Leans are in degrees forward, in the skeleton's axes, where +Z is ahead.

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
## How far down the upper arm points, from 0 for level to 1 for straight down, where the turns start and reach full strength.
var hanging_from := 0.5
var hanging_to := 0.85

## How far each line leans in the first pose, before any turn.
var _measured: Array[float] = []


func _process_modification() -> void:
	var skeleton := get_skeleton()
	var measuring := _measured.is_empty()
	for index in SEGMENTS.size():
		var segment: Array = SEGMENTS[index]
		if measuring:
			_measured.append(_lean(skeleton, segment[1], segment[2]))
		_turn(skeleton, segment[0], Quaternion(Vector3.RIGHT, deg_to_rad(get(segment[3])) - _measured[index]))
	for side in [[&"LeftShoulder", &"LeftUpperArm", &"LeftLowerArm", -1.0], [&"RightShoulder", &"RightUpperArm", &"RightLowerArm", 1.0]]:
		# Only hanging arms move, so a raised torch or sword stays where the animation holds it.
		var hanging := smoothstep(hanging_from, hanging_to, -_direction(skeleton, side[1], side[2]).y)
		_turn(skeleton, side[0], Quaternion(Vector3.UP, side[3] * hanging * deg_to_rad(shoulder_turn_degrees)))
		_turn(skeleton, side[1], Quaternion(Vector3.RIGHT, -hanging * deg_to_rad(arm_swing_degrees)))


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
