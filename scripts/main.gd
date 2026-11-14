extends Node3D

const MIN_WINDOW_SIZE := Vector2i(640, 360)
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
const HURT_COLOR := Color(0.6, 0.05, 0.02, 0.28)
const HURT_FADE_SECONDS := 0.35
const DEATH_BLACK_SECONDS := 0.5
const DEATH_FADE_SECONDS := 1.5
const HUD_FONT_SIZE := 16

## Tests turn the menu off and use their own save file.
var show_menu := true
var save_path := SaveGame.DEFAULT_PATH
var slot_paths := SaveGame.slot_paths()

var _playing := false
var _since_save := 0.0
var _ending_shown := false
var _hurt_overlay: ColorRect
var _fade_overlay: ColorRect

@onready var _terrain: Terrain = $Terrain
@onready var _village: Village = $Village
@onready var _day_night: DayNight = $DayNight
@onready var _player: Player = $Player
var _map: MapController
var _controls_tween: Tween
var _hurt_tween: Tween

@onready var _menu: GameMenu = $GameMenu
@onready var _ui: HudLayout = $UI
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
	for problem in DataValidator.validate_directory():
		push_error("Data problem: %s" % problem)
	Settings.load_saved()
	get_window().min_size = MIN_WINDOW_SIZE
	get_window().size_changed.connect(_fit_interface)
	_fit_interface()
	_apply_graphics()
	_menu.graphics_changed.connect(_apply_graphics)
	_menu.text_size_changed.connect(_apply_text_size)
	_apply_text_size()
	_welcome_label.modulate.a = 0.0
	_set_translated_text()
	_compass.visible = FeatureFlags.enabled("compass")
	_performance_overlay.visible = FeatureFlags.enabled("performance_overlay")
	_performance_overlay.set_process(_performance_overlay.visible)
	_ui.arrange()
	_map = MapController.new()
	add_child(_map)
	_map.setup(_terrain, _village, _player, _ui)

	_player.quests.changed.connect(_on_quests_changed)
	_player.inventory.changed.connect(_update_quest_label)
	_player.health.changed.connect(_update_health_bar)
	_player.health.died.connect(_on_player_died)
	_player.notice.connect(_show_message)
	_player.busy_changed.connect(_update_prompt)
	_player.hurt.connect(_flash_hurt)
	_hurt_overlay = _add_overlay(HURT_COLOR)
	_fade_overlay = _add_overlay(Color.BLACK)

	_menu.slot_paths = slot_paths
	_menu.continue_chosen.connect(_on_continue_chosen)
	_menu.new_game_chosen.connect(_on_new_game_chosen)
	_menu.resume_chosen.connect(resume)
	_menu.quit_chosen.connect(_save_and_quit)

	# The title screen looks at the village from the road, without the game's interface.
	_player.position = _spawn_position()
	_ui.visible = false
	_player.visible = false
	if show_menu:
		_menu.open_title()
	else:
		_start_new_game()


func _process(delta: float) -> void:
	_compass.heading = _player.heading_degrees()
	_compass.objective_bearings = _objective_bearings()
	_update_prompt()
	if _playing:
		_since_save += delta
		if _since_save >= AUTOSAVE_SECONDS:
			save_game()


func _objective_bearings() -> PackedFloat32Array:
	var bearings := PackedFloat32Array()
	if FeatureFlags.enabled("compass_objectives"):
		for marker in _player.quests.objective_markers(_player.inventory):
			bearings.append(Compass.bearing_between(Vector2(_player.position.x, _player.position.z), _village.marker_position(marker)))
	return bearings


func _update_prompt() -> void:
	var target := _player.interact_target
	_prompt_label.visible = target != null and not _player.is_busy()
	if _prompt_label.visible:
		_prompt_label.text = tr("UI_INTERACT_PROMPT") % target.prompt()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _playing:
		save_game()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_set_translated_text()
		_update_quest_label()


func _set_translated_text() -> void:
	_welcome_label.text = tr("UI_WELCOME")
	_controls_label.text = tr("UI_CONTROLS")


func _fit_interface() -> void:
	var window := get_window()
	window.content_scale_factor = InterfaceScale.factor_for(
		Vector2(window.size), Vector2(window.content_scale_size), FeatureFlags.value("interface_min_scale")
	)


## The HUD's text follows the text size setting. Menus and dialogue follow the theme.
func _apply_text_size() -> void:
	_quest_label.label_settings.font_size = Settings.scaled_font_size(HUD_FONT_SIZE)
	_ui.arrange()


func _apply_graphics() -> void:
	get_viewport().scaling_3d_scale = Settings.render_scale()
	var sun: DirectionalLight3D = $Sun
	sun.shadow_enabled = Settings.shadows()
	sun.directional_shadow_mode = Settings.shadow_splits()
	var world_environment: WorldEnvironment = $WorldEnvironment
	world_environment.environment.ssao_enabled = Settings.ambient_occlusion()
	($SkyDome as SkyDome).set_quality(Settings.graphics)
	var grass: GrassField = _village.get_node("Grass")
	grass.set_draw_scale(Settings.grass_draw_scale())


func save_game() -> void:
	_since_save = 0.0
	SaveGame.write(save_path, _player, _day_night, _village)


func open_pause_menu() -> void:
	_show_controls_hint()
	_player.set_busy(true)
	_menu.open_pause()


func resume() -> void:
	_menu.close()
	_player.set_busy(false)
	_fade_controls_hint(0.0)


func sleep() -> void:
	_day_night.hour = WAKE_UP_HOUR
	_player.health.restore()
	save_game()
	_show_message("UI_SLEPT")


func _spawn_position() -> Vector3:
	return Vector3(SPAWN.x, _terrain.height_at(SPAWN.x, SPAWN.y) + 1.0, SPAWN.y)


func _on_new_game_chosen(path: String) -> void:
	save_path = path
	_start_new_game()


func _on_continue_chosen(path: String) -> void:
	save_path = path
	_continue_game()


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
	_player.give_ranged_items()
	_on_quests_changed()
	_update_health_bar()
	_show_controls_hint()
	_fade_controls_hint(FeatureFlags.value("controls_hint_seconds"))


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
	_quest_label.visible = _quest_label.text != ""
	_ui.arrange()


func _update_health_bar() -> void:
	_health_bar.value = _player.health.fraction() * 100.0


func _on_player_died() -> void:
	_player.inventory.lose_materials(DEATH_MATERIAL_LOSS)
	var height := _terrain.height_at(WAKE_UP_SPOT.x, WAKE_UP_SPOT.y) + 1.0
	_player.revive_at(Vector3(WAKE_UP_SPOT.x, height, WAKE_UP_SPOT.y))
	get_tree().call_group(Enemy.GROUP, "revive")
	_show_message("UI_WOKE_UP")
	# The move back to the village happens behind the black screen.
	_fade_overlay.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(DEATH_BLACK_SECONDS)
	tween.tween_property(_fade_overlay, "modulate:a", 0.0, DEATH_FADE_SECONDS)


func _flash_hurt() -> void:
	# The previous hit's fade would otherwise keep running and cut this flash short.
	if _hurt_tween != null:
		_hurt_tween.kill()
	_hurt_overlay.modulate.a = 1.0
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(_hurt_overlay, "modulate:a", 0.0, HURT_FADE_SECONDS)


## A full-screen color for effects, hidden until needed, that doesn't catch the mouse.
func _add_overlay(color: Color) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = color
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.modulate.a = 0.0
	_ui.add_child(overlay)
	return overlay


func _show_controls_hint() -> void:
	if _controls_tween != null:
		_controls_tween.kill()
	_controls_label.modulate.a = 1.0


## The line takes up much of a small window, so it only stays while it's useful.
func _fade_controls_hint(delay: float) -> void:
	if FeatureFlags.value("controls_hint_seconds") <= 0:
		return
	_show_controls_hint()
	_controls_tween = create_tween()
	_controls_tween.tween_interval(delay)
	_controls_tween.tween_property(_controls_label, "modulate:a", 0.0, FADE_SECONDS)


func _show_message(text_key: String) -> void:
	_message_label.text = tr(text_key)
	_message_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(MESSAGE_SECONDS)
	tween.tween_property(_message_label, "modulate:a", 0.0, FADE_SECONDS)
