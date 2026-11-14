class_name Noticing
extends RefCounted
## The rules for how far away an enemy notices the player (#207). The range is the enemy's
## `aggro_range` times a factor. Every number is in data/feature_flags.json and described in
## docs/FEATURE_FLAGS.md, and `noticing_rules` turns all but the sneak factor off.
##
## What the player does (how visible they are, whatever looks at them):
##   stance and speed: sneaking, standing still, sprinting
##   light: night makes the player hard to see, and a lit torch makes them easy to see
## What the enemy sees (per enemy):
##   facing: from behind, it notices less far
##   line of sight: a wall, rock, or prop in the way makes it notice less far
## Closer than `notice_close_range` an enemy notices the player regardless (it hears them).

## A player moving slower than this counts as standing still.
const STILL_SPEED := 0.2
const MAX_BLOCKERS_SKIPPED := 3


static func rules_on() -> bool:
	return FeatureFlags.enabled("noticing_rules")


static func _value(key: String, fallback: float) -> float:
	return float(FeatureFlags.value(key, fallback))


## The part of the factor that depends on the player alone: stance, speed, and light. 1.0 is a player
## walking in daylight. This is what the HUD indicator shows.
static func player_factor(player: Player) -> float:
	var factor := 1.0
	if player.is_sneaking():
		factor *= _value("sneak_notice_factor", 0.35)
	if not rules_on():
		return factor
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > STILL_SPEED
	if not moving:
		factor *= _value("still_notice_factor", 0.75)
	elif player.is_sprinting():
		factor *= _value("sprint_notice_factor", 1.3)
	return factor * light_factor(player)


## 1.0 in daylight. Darker at night, down to `night_notice_factor`, and a lit torch adds back
## `torch_notice_bonus` (less of it in daylight, when its light hardly shows).
static func light_factor(player: Player) -> float:
	var daylight := 1.0
	var day_night := player.get_tree().get_first_node_in_group(DayNight.GROUP) as DayNight
	if day_night != null:
		daylight = day_night.daylight()
	var light := lerpf(_value("night_notice_factor", 0.6), 1.0, daylight)
	if player.torch_lit:
		light += _value("torch_notice_bonus", 0.6) * lerpf(1.0, Torch.DAYLIGHT_LIGHT_SHARE, daylight)
	return light


## How seen the player is from 0 to 1, for the HUD, where 1 is `visibility_full_factor` of the range.
static func visibility(player: Player) -> float:
	return clampf(player_factor(player) / maxf(_value("visibility_full_factor", 1.5), 0.01), 0.0, 1.0)


## The levels the HUD names: 0 hidden, 1 cautious, 2 seen. Compares the factor itself, so the
## thresholds mean "the enemy notices from this share of its normal range".
static func level(player: Player) -> int:
	var factor := player_factor(player)
	if factor < _value("visibility_hidden_below", 0.4):
		return 0
	return 2 if factor > _value("visibility_seen_above", 0.8) else 1


## The part that depends on where the enemy looks: from 1.0 down to `notice_back_factor` when the
## player is behind it, times `notice_blocked_factor` when something is in the way.
static func enemy_factor(enemy: Enemy, player: Player) -> float:
	if not rules_on():
		return 1.0
	var to_player := player.global_position - enemy.global_position
	to_player.y = 0.0
	if to_player.length() < _value("notice_close_range", 2.5):
		return 1.0
	return facing_factor(-enemy.global_basis.z, to_player) * (_value("notice_blocked_factor", 0.4) if is_blocked(enemy, player) else 1.0)


## 1.0 in front, and less toward the back, between `notice_front_degrees` and `notice_back_degrees`.
static func facing_factor(forward: Vector3, to_target: Vector3) -> float:
	var flat_forward := Vector3(forward.x, 0.0, forward.z)
	var flat_target := Vector3(to_target.x, 0.0, to_target.z)
	if flat_forward.length_squared() < 0.0001 or flat_target.length_squared() < 0.0001:
		return 1.0
	var angle := rad_to_deg(flat_forward.angle_to(flat_target))
	var front := _value("notice_front_degrees", 90.0)
	var back := maxf(_value("notice_back_degrees", 150.0), front + 1.0)
	return lerpf(1.0, _value("notice_back_factor", 0.5), clampf((angle - front) / (back - front), 0.0, 1.0))


## Whether something solid (ground, a wall, a prop) lies between the enemy's eyes and the player.
## Characters don't count, so a villager between them doesn't hide anyone.
static func is_blocked(enemy: Enemy, player: Player) -> bool:
	var from := enemy.global_position + Vector3.UP * _value("notice_eye_height", 1.4)
	var to := player.global_position + Vector3.UP * _value("notice_target_height", 1.0)
	var space := enemy.get_world_3d().direct_space_state
	var skipped: Array[RID] = [enemy.get_rid(), player.get_rid()]
	for _attempt in MAX_BLOCKERS_SKIPPED + 1:
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = skipped
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return false
		if hit["collider"] is CharacterBody3D:
			skipped.append(hit["rid"])
			continue
		return true
	return false


## The distance at which this enemy notices the player. The enemy's own view (facing and line of
## sight) is only looked at when the player is near enough for it to matter, so the ray is rare.
static func notice_range(enemy: Enemy, player: Player, base_range: float) -> float:
	var reach := base_range * player_factor(player)
	if not rules_on() or enemy.global_position.distance_to(player.global_position) >= reach:
		return reach
	return reach * enemy_factor(enemy, player)
