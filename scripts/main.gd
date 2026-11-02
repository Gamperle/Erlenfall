extends Node3D

const SPAWN := Vector2(0.0, 110.0)
const WELCOME_SECONDS := 4.0
const FADE_SECONDS := 1.5
const FIRST_QUEST := "arrival"
const FINAL_QUEST := "first_nails"
const WAKE_UP_SPOT := Vector2(-12.0, 30.0)
const DEATH_MATERIAL_LOSS := 0.25
const MESSAGE_SECONDS := 5.0
const AUTOSAVE_SECONDS := 60.0
const WAKE_UP_HOUR := 7.0

## Tests turn the menu off and use their own save file.
var show_menu := true
var save_path := SaveGame.DEFAULT_PATH

var _playing := false
var _since_save := 0.0
var _ending_shown := false

@onready var _terrain: Terrain = $Terrain
@onready var _village: Village = $Village
@onready var _day_night: DayNight = $DayNight
@onready var _player: Player = $Player
@onready var _menu: GameMenu = $GameMenu
@onready var _ui: CanvasLayer = $UI
@onready var _welcome_label: Label = $UI/WelcomeLabel
@onready var _controls_label: Label = $UI/ControlsLabel
@onready var _prompt_label: Label = $UI/PromptLabel
@onready var _quest_label: Label = $UI/QuestLabel
@onready var _health_bar: ProgressBar = $UI/HealthBar
@onready var _message_label: Label = $UI/MessageLabel
@onready var _compass: Compass = $UI/Compass
@onready var _performance_overlay: PerformanceOverlay = $UI/PerformanceOverlay


func _enter_tree() -> void:
	add_to_group(Bed.GAME_GROUP)


func _ready() -> void:
	_welcome_label.modulate.a = 0.0
	_welcome_label.text = tr("UI_WELCOME")
	_controls_label.text = tr("UI_CONTROLS")
	_compass.visible = FeatureFlags.enabled("compass")
	_performance_overlay.visible = FeatureFlags.enabled("performance_overlay")
	_performance_overlay.set_process(_performance_overlay.visible)
	if not _performance_overlay.visible:
		_quest_label.offset_top = _performance_overlay.offset_top

	_player.quests.changed.connect(_on_quests_changed)
	_player.inventory.changed.connect(_update_quest_label)
	_player.health.changed.connect(_update_health_bar)
	_player.health.died.connect(_on_player_died)
	_player.notice.connect(_show_message)
	_player.busy_changed.connect(_update_prompt)

	_menu.continue_chosen.connect(_continue_game)
	_menu.new_game_chosen.connect(_start_new_game)
	_menu.resume_chosen.connect(resume)
	_menu.quit_chosen.connect(_save_and_quit)

	# The title screen looks at the village from the road, without the game's interface.
	_player.position = _spawn_position()
	_ui.visible = false
	_player.visible = false
	if show_menu:
		_menu.open_title(SaveGame.exists(save_path))
	else:
		_start_new_game()


func _process(delta: float) -> void:
	_compass.heading = _player.heading_degrees()
	_update_prompt()
	if _playing:
		_since_save += delta
		if _since_save >= AUTOSAVE_SECONDS:
			save_game()


func _update_prompt() -> void:
	var target := _player.interact_target
	_prompt_label.visible = target != null and not _player.is_busy()
	if _prompt_label.visible:
		_prompt_label.text = tr("UI_INTERACT_PROMPT") % target.prompt()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _playing:
		save_game()


func save_game() -> void:
	_since_save = 0.0
	SaveGame.write(save_path, _player, _day_night, _village)


func open_pause_menu() -> void:
	_player.set_busy(true)
	_menu.open_pause()


func resume() -> void:
	_menu.close()
	_player.set_busy(false)


func sleep() -> void:
	_day_night.hour = WAKE_UP_HOUR
	_player.health.restore()
	save_game()
	_show_message("UI_SLEPT")


func _spawn_position() -> Vector3:
	return Vector3(SPAWN.x, _terrain.height_at(SPAWN.x, SPAWN.y) + 1.0, SPAWN.y)


func _start_new_game() -> void:
	_player.quests.start(FIRST_QUEST)
	_begin_playing()
	_welcome_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(WELCOME_SECONDS)
	tween.tween_property(_welcome_label, "modulate:a", 0.0, FADE_SECONDS)


func _continue_game() -> void:
	# A finished story was already announced when it was first completed.
	_ending_shown = true
	if SaveGame.apply(save_path, _player, _day_night, _village):
		_begin_playing()
	else:
		_ending_shown = false
		_start_new_game()


func _begin_playing() -> void:
	_playing = true
	_ui.visible = true
	_player.visible = true
	_since_save = 0.0
	_menu.close()
	_player.set_busy(false)
	_player.give_starting_items()
	_on_quests_changed()
	_update_health_bar()


func _save_and_quit() -> void:
	if _playing:
		save_game()
	get_tree().quit()


func _on_quests_changed() -> void:
	_village.apply_flags(_player.quests.flags)
	_update_quest_label()
	if _playing:
		save_game()
	if _player.quests.is_done(FINAL_QUEST) and not _ending_shown:
		_ending_shown = true
		_show_message("UI_DEMO_END")


func _update_quest_label() -> void:
	_quest_label.text = "\n".join(_player.quests.tracker_lines(_player.inventory))


func _update_health_bar() -> void:
	_health_bar.value = _player.health.fraction() * 100.0


func _on_player_died() -> void:
	_player.inventory.lose_materials(DEATH_MATERIAL_LOSS)
	var height := _terrain.height_at(WAKE_UP_SPOT.x, WAKE_UP_SPOT.y) + 1.0
	_player.revive_at(Vector3(WAKE_UP_SPOT.x, height, WAKE_UP_SPOT.y))
	get_tree().call_group(Enemy.GROUP, "revive")
	_show_message("UI_WOKE_UP")


func _show_message(text_key: String) -> void:
	_message_label.text = tr(text_key)
	_message_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(MESSAGE_SECONDS)
	tween.tween_property(_message_label, "modulate:a", 0.0, FADE_SECONDS)
