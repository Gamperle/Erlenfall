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
const CUE_HEIGHT := 2.3
## What floats over the goblin: a question mark while it waits to be spoken to, and a tilde with the
## word "calm" once it stood down. The words and shapes differ, so colour is never the only difference.
const CUE_TEXT := { "wait": "?", "calm": "~" }

var _enemy: Enemy
var _config: Dictionary = {}
var _calm_left := 0.0
var _wary_left := 0.0
var _was_far := false
var _near := false
var _refused := false
var _cue: Label3D
var _cue_look := ""


func setup(enemy: Enemy, config: Dictionary) -> void:
	_enemy = enemy
	_config = config
	name = "EnemyTalk"
	prompt_key = enemy._stats["name"]
	collision_layer = 0
	collision_mask = 0
	_reset()
	_cue = Label3D.new()
	_cue.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cue.no_depth_test = true
	_cue.pixel_size = 0.01
	_cue.position.y = CUE_HEIGHT
	_cue.visible = false
	add_child(_cue)


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


## Which cue shows over the enemy: "wait", "calm" or "" for none.
func cue() -> String:
	if not _enabled() or _enemy.state == Enemy.State.DEAD:
		return ""
	if is_calm():
		return "calm"
	return "wait" if is_available() else ""


## Seconds of calm left, saved with the game (#329).
func calm_left() -> float:
	return _calm_left


## Restores a saved calm. The enemy itself is already standing down after a load.
func restore_calm(seconds: float) -> void:
	_calm_left = maxf(0.0, seconds)
	if _calm_left > 0.0:
		_refused = false
		_wary_left = 0.0


func _update_cue() -> void:
	var key := cue()
	var look := "%s|%s|%s" % [key, Settings.colour_vision, Settings.high_contrast]
	if look == _cue_look:
		return
	_cue_look = look
	_cue.visible = key != ""
	if key == "":
		return
	var high := Settings.high_contrast
	_cue.text = CUE_TEXT[key] + "\n" + tr("TALK_CUE_" + key.to_upper())
	_cue.modulate = Color.WHITE if high else Accessibility.color("objective" if key == "wait" else "player")
	_cue.outline_size = Accessibility.HC_OUTLINE_SIZE * 2 if high else 8
	_cue.outline_modulate = Accessibility.HC_OUTLINE_COLOR


func _process(delta: float) -> void:
	if _calm_left > 0.0:
		_calm_left = maxf(0.0, _calm_left - delta)
	if _enemy.state == Enemy.State.IDLE or _enemy.state == Enemy.State.DEAD:
		_reset()
	_update_cue()


func _reset() -> void:
	_wary_left = float(_config["wary_seconds"])
	_was_far = false
	_near = false
	_refused = false


func _enabled() -> bool:
	return FeatureFlags.enabled("enemy_talk")
