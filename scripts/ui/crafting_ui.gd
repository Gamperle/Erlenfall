class_name CraftingUI
extends CanvasLayer
## The inventory and crafting screen, including the forging minigame.

const PANEL_WIDTH := 640.0
const BAR_HEIGHT := 36.0
const BAR_COLOR := Color(0.16, 0.13, 0.11)
const TARGET_COLOR := Color(0.95, 0.55, 0.15)
const MARKER_COLOR := Color(1.0, 1.0, 0.95)
const RESULT_SECONDS := 1.0

var _player: Player
var _station := ""
var _selected: Dictionary = {}
var _game: HammerGame
var _recipe: Dictionary = {}

var _panel: PanelContainer
var _title: Label
var _inventory_label: Label
var _materials_label: Label
var _materials: HFlowContainer
var _selection_label: Label
var _actions: HBoxContainer
var _clear_button: Button
var _craft_button: Button
var _close_button: Button
var _known_label: Label
var _message: Label
var _bar: Control
var _target: ColorRect
var _marker: ColorRect


func _ready() -> void:
	add_to_group(CraftingStation.UI_GROUP)
	_build()
	_panel.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_open() -> bool:
	return _panel.visible


func is_forging() -> bool:
	return _game != null


func open_station(station_id: String, title: String, player: Player) -> void:
	_open(player, station_id, title)


func open_inventory(player: Player) -> void:
	_open(player, "", tr("UI_INVENTORY"))


func close() -> void:
	_panel.visible = false
	_selected.clear()
	_player.set_busy(false)


func add_material(item_id: String) -> void:
	_selected[item_id] = int(_selected.get(item_id, 0)) + 1
	_refresh()


func clear_selection() -> void:
	_selected.clear()
	_message.text = ""
	_refresh()


## Tries the selected materials. Nothing is used up unless they form a recipe.
func craft() -> void:
	var recipe := CraftingData.find_recipe(_station, _selected)
	if recipe.is_empty():
		_message.text = tr("UI_NO_RESULT")
		return
	for item_id: String in recipe["inputs"]:
		_player.inventory.remove(item_id, int(recipe["inputs"][item_id]))
	_selected.clear()
	_recipe = recipe
	if recipe.has("strikes"):
		_start_forging(recipe)
	else:
		_finish_recipe("")


## Hits the current strike. Public so the keyboard, controller, and tests share one path.
func strike() -> void:
	var accuracy := _game.strike()
	_message.text = tr(_strike_key(accuracy))
	if _game.is_finished():
		var quality := CraftingData.quality_for_score(_game.score())
		_game = null
		_bar.visible = false
		_finish_recipe(quality)
	else:
		_update_strike_text()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if is_forging():
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			strike()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or (_station == "" and event.is_action_pressed("inventory")):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_forging():
		return
	_game.update(delta)
	var width := _bar.size.x
	_target.position.x = (_game.target - HammerGame.TARGET_WIDTH / 2.0) * width
	_target.size = Vector2(HammerGame.TARGET_WIDTH * width, BAR_HEIGHT)
	_marker.position.x = _game.marker * width - _marker.size.x / 2.0


func _open(player: Player, station_id: String, title: String) -> void:
	_player = player
	_station = station_id
	_selected.clear()
	_title.text = title
	_message.text = ""
	_panel.visible = true
	_player.set_busy(true)
	_refresh()


func _refresh() -> void:
	_inventory_label.text = _inventory_text()
	var at_station := _station != ""
	var forging := is_forging()
	_materials_label.visible = at_station and not forging
	_materials.visible = at_station and not forging
	_selection_label.visible = at_station and not forging
	_clear_button.visible = at_station and not forging
	_craft_button.visible = at_station and not forging
	_close_button.visible = not forging
	_known_label.visible = at_station and not forging
	if not at_station or forging:
		if not forging:
			_close_button.grab_focus()
		return

	var previous_focus := _focused_material()
	for child in _materials.get_children():
		_materials.remove_child(child)
		child.queue_free()
	for item_id in _material_ids():
		var used := int(_selected.get(item_id, 0))
		var button := Button.new()
		button.name = item_id
		var available := _player.inventory.count(item_id) - used
		button.text = "%s (%d)" % [CraftingData.item_name(item_id), available]
		button.disabled = available <= 0
		button.pressed.connect(add_material.bind(item_id))
		_materials.add_child(button)

	var parts := PackedStringArray()
	for item_id: String in _selected:
		parts.append("%d x %s" % [_selected[item_id], CraftingData.item_name(item_id)])
	_selection_label.text = tr("UI_SELECTED") % (", ".join(parts) if parts.size() > 0 else "-")
	_craft_button.disabled = _selected.is_empty()
	_known_label.text = _known_recipes_text()

	var focus_target: Control = _close_button
	var previous := _materials.get_node_or_null(previous_focus) as Button
	if previous != null and not previous.disabled:
		focus_target = previous
	elif not _selected.is_empty():
		focus_target = _craft_button
	else:
		for child in _materials.get_children():
			if not (child as Button).disabled:
				focus_target = child
				break
	focus_target.grab_focus()


func _focused_material() -> String:
	var focused := _panel.get_viewport().gui_get_focus_owner()
	return String(focused.name) if focused != null and focused.get_parent() == _materials else "_"


func _material_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in _player.inventory.entries():
		if CraftingData.is_material(entry["id"]) and not ids.has(entry["id"]):
			ids.append(entry["id"])
	return ids


func _inventory_text() -> String:
	var lines := PackedStringArray()
	for entry in _player.inventory.entries():
		var quality := CraftingData.quality_name(entry["quality"])
		var label := CraftingData.item_name(entry["id"])
		if quality != "":
			label = "%s (%s)" % [label, quality]
		lines.append("%d x %s" % [entry["count"], label])
	return tr("UI_CARRYING") % (", ".join(lines) if lines.size() > 0 else tr("UI_NOTHING"))


func _known_recipes_text() -> String:
	var lines := PackedStringArray()
	for recipe in CraftingData.recipes_for(_station):
		if _player.known_recipes.has(recipe["id"]):
			var inputs := PackedStringArray()
			for item_id: String in recipe["inputs"]:
				inputs.append("%d x %s" % [recipe["inputs"][item_id], CraftingData.item_name(item_id)])
			lines.append("%s: %s" % [CraftingData.item_name(recipe["result"]), ", ".join(inputs)])
	if lines.is_empty():
		return tr("UI_NO_RECIPES")
	return tr("UI_KNOWN_RECIPES") % "\n".join(lines)


func _start_forging(recipe: Dictionary) -> void:
	_game = HammerGame.new(int(recipe["strikes"]), recipe["speed"])
	_bar.visible = true
	_message.text = tr("UI_FORGE_HINT")
	_update_strike_text()
	_refresh()


func _update_strike_text() -> void:
	_title.text = tr("UI_FORGING") % [
		CraftingData.item_name(_recipe["result"]), _game.strikes_done + 1, _game.strikes_total
	]


func _finish_recipe(quality: String) -> void:
	var is_new := not _player.known_recipes.has(_recipe["id"])
	_player.known_recipes[_recipe["id"]] = true
	_player.inventory.add(_recipe["result"], int(_recipe["count"]), quality)
	var made := CraftingData.item_name(_recipe["result"])
	if quality != "":
		made = "%s (%s)" % [made, CraftingData.quality_name(quality)]
	_message.text = tr("UI_MADE_NEW" if is_new else "UI_MADE") % made
	_title.text = tr("UI_" + _station.to_upper())
	_refresh()


func _strike_key(accuracy: float) -> String:
	if accuracy >= 1.0:
		return "UI_STRIKE_PERFECT"
	return "UI_STRIKE_GOOD" if accuracy >= 0.5 else "UI_STRIKE_POOR"


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	column.add_child(_title)

	_inventory_label = _wrapped_label(column)
	_materials_label = _wrapped_label(column)
	_materials_label.text = tr("UI_ADD_MATERIALS")

	_materials = HFlowContainer.new()
	column.add_child(_materials)

	_selection_label = _wrapped_label(column)

	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	_bar.visible = false
	_bar.clip_contents = true
	column.add_child(_bar)
	var background := ColorRect.new()
	background.color = BAR_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar.add_child(background)
	_target = ColorRect.new()
	_target.color = TARGET_COLOR
	_bar.add_child(_target)
	_marker = ColorRect.new()
	_marker.color = MARKER_COLOR
	_marker.size = Vector2(6.0, BAR_HEIGHT)
	_bar.add_child(_marker)

	_actions = HBoxContainer.new()
	column.add_child(_actions)
	_craft_button = _action_button("UI_CRAFT", craft)
	_clear_button = _action_button("UI_CLEAR", clear_selection)
	_close_button = _action_button("UI_CLOSE", close)

	_message = _wrapped_label(column)
	_known_label = _wrapped_label(column)


func _action_button(text_key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = tr(text_key)
	button.pressed.connect(action)
	_actions.add_child(button)
	return button


func _wrapped_label(parent: Control) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label
