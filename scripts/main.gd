extends Node3D

const SPAWN := Vector2(0.0, 110.0)
const WELCOME_SECONDS := 4.0
const FADE_SECONDS := 1.5

@onready var _terrain: Terrain = $Terrain
@onready var _player: Player = $Player
@onready var _welcome_label: Label = $UI/WelcomeLabel
@onready var _controls_label: Label = $UI/ControlsLabel
@onready var _prompt_label: Label = $UI/PromptLabel
@onready var _crafting_ui: CraftingUI = $CraftingUI


func _ready() -> void:
	_welcome_label.text = tr("UI_WELCOME")
	_controls_label.text = tr("UI_CONTROLS")
	_player.position = Vector3(SPAWN.x, _terrain.height_at(SPAWN.x, SPAWN.y) + 1.0, SPAWN.y)

	var tween := create_tween()
	tween.tween_interval(WELCOME_SECONDS)
	tween.tween_property(_welcome_label, "modulate:a", 0.0, FADE_SECONDS)


func _process(_delta: float) -> void:
	var target := _player.interact_target
	_prompt_label.visible = target != null and not _crafting_ui.is_open()
	if _prompt_label.visible:
		_prompt_label.text = tr("UI_INTERACT_PROMPT") % target.prompt()
