extends Node3D

const SPAWN := Vector2(0.0, 110.0)
const WELCOME_SECONDS := 4.0
const FADE_SECONDS := 1.5
const FIRST_QUEST := "arrival"

@onready var _terrain: Terrain = $Terrain
@onready var _player: Player = $Player
@onready var _welcome_label: Label = $UI/WelcomeLabel
@onready var _controls_label: Label = $UI/ControlsLabel
@onready var _prompt_label: Label = $UI/PromptLabel
@onready var _quest_label: Label = $UI/QuestLabel


func _ready() -> void:
	_welcome_label.text = tr("UI_WELCOME")
	_controls_label.text = tr("UI_CONTROLS")
	_player.position = Vector3(SPAWN.x, _terrain.height_at(SPAWN.x, SPAWN.y) + 1.0, SPAWN.y)

	_player.quests.changed.connect(_update_quest_label)
	_player.inventory.changed.connect(_update_quest_label)
	_player.quests.start(FIRST_QUEST)
	_update_quest_label()

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
