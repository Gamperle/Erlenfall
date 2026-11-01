extends Node3D

const SPAWN := Vector2(0.0, 110.0)
const WELCOME_SECONDS := 4.0
const FADE_SECONDS := 1.5
const FIRST_QUEST := "arrival"
const WAKE_UP_SPOT := Vector2(-12.0, 30.0)
const DEATH_MATERIAL_LOSS := 0.25
const MESSAGE_SECONDS := 5.0

@onready var _terrain: Terrain = $Terrain
@onready var _player: Player = $Player
@onready var _welcome_label: Label = $UI/WelcomeLabel
@onready var _controls_label: Label = $UI/ControlsLabel
@onready var _prompt_label: Label = $UI/PromptLabel
@onready var _quest_label: Label = $UI/QuestLabel
@onready var _health_bar: ProgressBar = $UI/HealthBar
@onready var _message_label: Label = $UI/MessageLabel


func _ready() -> void:
	_welcome_label.text = tr("UI_WELCOME")
	_controls_label.text = tr("UI_CONTROLS")
	_player.position = Vector3(SPAWN.x, _terrain.height_at(SPAWN.x, SPAWN.y) + 1.0, SPAWN.y)

	_player.quests.changed.connect(_update_quest_label)
	_player.inventory.changed.connect(_update_quest_label)
	_player.quests.start(FIRST_QUEST)
	_update_quest_label()

	_player.health.changed.connect(_update_health_bar)
	_player.health.died.connect(_on_player_died)
	_update_health_bar()

	var tween := create_tween()
	tween.tween_interval(WELCOME_SECONDS)
	tween.tween_property(_welcome_label, "modulate:a", 0.0, FADE_SECONDS)


func _process(_delta: float) -> void:
	var target := _player.interact_target
	_prompt_label.visible = target != null and not _player.is_busy()
	if _prompt_label.visible:
		_prompt_label.text = tr("UI_INTERACT_PROMPT") % target.prompt()


func _update_quest_label() -> void:
	_quest_label.text = "\n".join(_player.quests.tracker_lines(_player.inventory))


func _update_health_bar() -> void:
	_health_bar.value = _player.health.fraction() * 100.0


func _on_player_died() -> void:
	_player.inventory.lose_materials(DEATH_MATERIAL_LOSS)
	var height := _terrain.height_at(WAKE_UP_SPOT.x, WAKE_UP_SPOT.y) + 1.0
	_player.revive_at(Vector3(WAKE_UP_SPOT.x, height, WAKE_UP_SPOT.y))
	get_tree().call_group(Enemy.GROUP, "revive")

	_message_label.text = tr("UI_WOKE_UP")
	_message_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(MESSAGE_SECONDS)
	tween.tween_property(_message_label, "modulate:a", 0.0, FADE_SECONDS)
