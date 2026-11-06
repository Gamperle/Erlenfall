class_name PostureModifier
extends SkeletonModifier3D
## Straightens the back and neck over the animations, which lean these bodies forward by a different amount for each body.
## Measures the first pose once, then turns each bone back by the same amount in every pose after.
## Leans are in degrees forward, in the skeleton's axes, where +Z is ahead.

## Each bone, the two joints whose line it sets, and how far that line should lean, as in the bodies' own rest pose.
const SEGMENTS := [
	[&"Spine", &"Hips", &"Neck", 1.0],
	[&"UpperChest", &"UpperChest", &"Neck", 6.0],
	[&"Neck", &"Neck", &"Head", 19.0],
]

var _turns: Array[float] = []


func _process_modification() -> void:
	var skeleton := get_skeleton()
	var measuring := _turns.is_empty()
	for index in SEGMENTS.size():
		var segment: Array = SEGMENTS[index]
		if measuring:
			_turns.append(deg_to_rad(segment[3]) - _lean(skeleton, segment[1], segment[2]))
		var bone := skeleton.find_bone(segment[0])
		var wanted := Quaternion(Vector3.RIGHT, _turns[index]) * skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()
		var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone)).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(bone, (parent.inverse() * wanted).normalized())


func _lean(skeleton: Skeleton3D, from: StringName, to: StringName) -> float:
	var line := skeleton.get_bone_global_pose(skeleton.find_bone(to)).origin - skeleton.get_bone_global_pose(skeleton.find_bone(from)).origin
	return atan2(line.z, line.y)
