class_name EnemyTalk
extends Interactable
## Lets the player talk to an enemy that has noticed them and is sizing them up (#206).
##
## An enemy whose entry in data/enemies.json has a "talk" block can be spoken to. When it notices the
## player from afar and comes within `range`, it stops for `wary_seconds` before it attacks. In that
## window the interact key opens the conversation named by `dialogue` in data/dialogue.json. The
## conversation's effects ("calm_enemy", "provoke_enemy") decide what comes of it. Enemies without a
## "talk" block, like wolves and brutes, are never spoken to. The "enemy_talk" feature flag turns it off.

const UI_GROUP := "dialogue_ui"

var _enemy: Enemy
var _config: Dictionary = {}
var _calm_left := 0.0
var _wary_left := 0.0
var _was_far := false
var _near := false
var _refused := false


func setup(enemy: Enemy, config: Dictionary) -> void:
	_enemy = enemy
	_config = config
	name = "EnemyTalk"
	prompt_key = enemy._stats["name"]
	collision_layer = 0
	collision_mask = 0
	_reset()


func is_calm() -> bool:
	return _calm_left > 0.0


## True while the enemy waits for the player to speak instead of attacking. The enemy asks this each
## time it would walk closer, with how far the player is. It only waits if it came up to the player
## from beyond talking range, so an enemy that noticed them at arm's length attacks at once.
func holds_back(distance: float, delta: float) -> bool:
	if not _enabled() or _refused:
		return false
	_near = distance <= float(_config["range"])
	if not _near:
		_was_far = true
		return false
	if not _was_far or _wary_left <= 0.0:
		return false
	_wary_left -= delta
	return _wary_left > 0.0


## A blow ends the truce and any chance to talk.
func break_calm() -> void:
	_calm_left = 0.0
	_wary_left = 0.0
	_refused = true


## Applies a dialogue effect: "calm_enemy" ({seconds}) stands the enemy down, "provoke_enemy" starts the fight.
func apply_effect(effect: Dictionary) -> void:
	match effect["type"]:
		"calm_enemy":
			_calm_left = float(effect["seconds"])
			_enemy.stand_down()
		"provoke_enemy":
			_refused = true
			_wary_left = 0.0
			_calm_left = 0.0


func is_available() -> bool:
	if not _enabled() or _refused or is_calm() or _wary_left <= 0.0 or not _was_far or not _near:
		return false
	return _enemy.state == Enemy.State.CHASE


func prompt() -> String:
	return tr("PROMPT_TALK") % tr(prompt_key)


func interact(player: Player) -> void:
	player.frame_conversation(_enemy.global_position)
	get_tree().call_group(UI_GROUP, "open_conversation", _config["dialogue"], tr(prompt_key), player, self)


func _process(delta: float) -> void:
	if _calm_left > 0.0:
		_calm_left = maxf(0.0, _calm_left - delta)
	if _enemy.state == Enemy.State.IDLE or _enemy.state == Enemy.State.DEAD:
		_reset()


func _reset() -> void:
	_wary_left = float(_config["wary_seconds"])
	_was_far = false
	_near = false
	_refused = false


func _enabled() -> bool:
	return FeatureFlags.enabled("enemy_talk")
