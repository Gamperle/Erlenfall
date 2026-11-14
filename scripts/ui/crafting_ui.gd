class_name CraftingUI
extends CanvasLayer
## The inventory and crafting screen, including the forging minigame.

const PANEL_WIDTH := 640.0
const BAR_HEIGHT := 36.0
const MARKER_COLOR := Color(1.0, 1.0, 0.95)
const RESULT_SECONDS := 1.0

var _player: Player
var _station := ""
var _selected: Dictionary = {}
var _game: HammerGame
var _showing_forge_hint := false
var _recipe: Dictionary = {}
var _choices: Dictionary = {}
var _variant := ""
var _parts_item := ""

var _panel: FittedPanel
var _title: Label
var _inventory_label: Label
var _materials_label: Label
var _materials: HFlowContainer
var _use_row: HFlowContainer
var _selection_label: Label
var _parts: GridContainer
var _actions: HBoxContainer
var _clear_button: Button
var _craft_button: Button
var _close_button: Button
var _known_label: Label
var _known_page: PanelContainer
var _message: Label
var _forge_line: PromptLine
var _bar: Control
var _target: Panel
var _marker: ColorRect


func _ready() -> void:
	add_to_group(CraftingStation.UI_GROUP)
	add_to_group(InputDevice.PROMPT_GROUP)
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


## Picks the option for one part of the item about to be made. Ignored if the item has no such choice.
func choose_part(slot: String, option_id: String) -> void:
	var item_id := _pending_item()
	if item_id == "" or not CraftingData.part_options(item_id, slot).has(option_id):
		return
	_choices[slot] = option_id
	_update_part_buttons()


## Eats or drinks one of the item to regain health. Public so the buttons and tests share one path.
func use_item(item_id: String) -> void:
	if _player.health.current >= _player.health.maximum:
		_say(tr("UI_HEALTH_FULL"))
	elif Healing.use_item(_player, item_id):
		_say(tr("UI_USED_ITEM") % CraftingData.item_name(item_id))
	_refresh()


func clear_selection() -> void:
	_selected.clear()
	_say("")
	_refresh()


## Tries the selected materials. Nothing is used up unless they form a recipe.
func craft() -> void:
	var recipe := CraftingData.find_recipe(_station, _selected)
	if recipe.is_empty():
		_say(tr("UI_NO_RESULT"))
		return
	for item_id: String in recipe["inputs"]:
		_player.inventory.remove(item_id, int(recipe["inputs"][item_id]))
	_variant = CraftingData.variant_key(recipe["result"], _choices)
	_selected.clear()
	_recipe = recipe
	if recipe.has("strikes"):
		_start_forging(recipe)
	else:
		_finish_recipe("")


## Hits the current strike. Public so the keyboard, controller, and tests share one path.
func strike() -> void:
	_showing_forge_hint = false
	var accuracy := _game.strike()
	_say(tr(_strike_key(accuracy)))
	if _game.is_finished():
		var quality := CraftingData.quality_for_score(_game.score())
		_game = null
		_bar.visible = false
		_finish_recipe(quality)
	else:
		_update_strike_text()


## Stops forging. Half of the materials, rounded down, can be saved, so retrying for quality has a cost.
func abandon_forging() -> void:
	for item_id: String in _recipe["inputs"]:
		var saved := int(_recipe["inputs"][item_id]) / 2
		if saved > 0:
			_player.inventory.add(item_id, saved)
	_game = null
	_bar.visible = false
	_say(tr("UI_FORGE_ABANDONED"))
	_title.text = tr("UI_" + _station.to_upper())
	_refresh()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if is_forging():
		if event.is_action_pressed("ui_cancel"):
			abandon_forging()
			get_viewport().set_input_as_handled()
			return
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
	_target.position.x = (_game.target - _game.target_width / 2.0) * width
	_target.size = Vector2(_game.target_width * width, BAR_HEIGHT)
	_marker.position.x = _game.marker * width - _marker.size.x / 2.0


func _open(player: Player, station_id: String, title: String) -> void:
	_player = player
	_station = station_id
	_selected.clear()
	_choices.clear()
	_title.text = title
	_say("")
	_panel.visible = true
	_player.set_busy(true)
	_refresh()


func _refresh() -> void:
	_inventory_label.text = _inventory_text()
	_refresh_use_buttons()
	var at_station := _station != ""
	var forging := is_forging()
	_materials_label.visible = at_station and not forging
	_materials.visible = at_station and not forging
	_selection_label.visible = at_station and not forging
	_clear_button.visible = at_station and not forging
	_craft_button.visible = at_station and not forging
	_close_button.visible = not forging
	_known_page.visible = at_station and not forging
	if not at_station or forging:
		_parts.visible = false
		if not forging:
			# An item to use comes first, so that the A button does not close the screen at once.
			var first: Control = _use_row.get_child(0) if _use_row.get_child_count() > 0 else _close_button
			first.grab_focus()
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
	_refresh_parts()
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


## One button for each carried item that can be eaten or drunk.
func _refresh_use_buttons() -> void:
	var focused := _panel.get_viewport().gui_get_focus_owner()
	var focused_item := String(focused.name) if focused != null and focused.get_parent() == _use_row else ""
	for child in _use_row.get_children():
		_use_row.remove_child(child)
		child.queue_free()
	var seen := {}
	for entry in _player.inventory.entries():
		var item_id: String = entry["id"]
		if seen.has(item_id) or not Healing.is_usable(item_id):
			continue
		seen[item_id] = true
		var button := Button.new()
		button.name = item_id
		button.text = tr("UI_USE_ITEM") % [CraftingData.item_name(item_id), _player.inventory.count(item_id)]
		button.pressed.connect(use_item.bind(item_id))
		_use_row.add_child(button)
		if item_id == focused_item:
			button.grab_focus.call_deferred()


## The item the selected materials would make, or "" if they make nothing.
func _pending_item() -> String:
	if _station == "" or is_forging():
		return ""
	return String(CraftingData.find_recipe(_station, _selected).get("result", ""))


## Shows a choice for each part of the item about to be made, and nothing for items without parts.
func _refresh_parts() -> void:
	var item_id := _pending_item()
	var slots: Array[String] = []
	if item_id != "":
		slots = CraftingData.part_slots(item_id)
	_parts.visible = not slots.is_empty()
	if item_id == _parts_item:
		return
	_parts_item = item_id
	_choices.clear()
	for child in _parts.get_children():
		_parts.remove_child(child)
		child.queue_free()
	for slot: String in slots:
		var label := Label.new()
		label.text = CraftingData.slot_name(slot)
		_parts.add_child(label)
		var picker := OptionButton.new()
		picker.name = slot
		for option_id in CraftingData.part_options(item_id, slot):
			picker.add_item(CraftingData.option_name(option_id))
			picker.set_item_metadata(picker.item_count - 1, option_id)
		picker.item_selected.connect(func(index: int): choose_part(slot, picker.get_item_metadata(index)))
		_parts.add_child(picker)


func _update_part_buttons() -> void:
	for child in _parts.get_children():
		if child is OptionButton:
			var chosen: String = _choices.get(child.name, "")
			for index in child.item_count:
				if child.get_item_metadata(index) == chosen:
					child.select(index)


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
		var details := PackedStringArray()
		if quality != "":
			details.append(quality)
		if entry["variant"] != "":
			details.append(CraftingData.variant_text(entry["id"], entry["variant"]))
		if not details.is_empty():
			label = "%s (%s)" % [label, ", ".join(details)]
		lines.append("%d x %s" % [entry["count"], label])
	var text: String = tr("UI_CARRYING") % (", ".join(lines) if lines.size() > 0 else tr("UI_NOTHING"))
	if FeatureFlags.enabled("crafting_skill"):
		text += "\n" + _skills_text()
	return text


func _skills_text() -> String:
	var parts := PackedStringArray()
	for skill_id: String in CraftingData.skill_ids():
		var xp: int = _player.skill_xp.get(skill_id, 0)
		var next := CraftingData.skill_next_xp(skill_id, xp)
		var progress := tr("UI_SKILL_MAX") if next == 0 else "%d / %d" % [xp, next]
		parts.append("%s %d (%s)" % [CraftingData.skill_name(skill_id), CraftingData.skill_level(skill_id, xp), progress])
	return tr("UI_SKILLS") % ", ".join(parts)


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
	var levels_gained := 0
	if FeatureFlags.enabled("crafting_skill") and recipe.has("skill"):
		levels_gained = _player.skill_level(recipe["skill"]) - 1
	_game = HammerGame.new(
		int(recipe["strikes"]),
		recipe["speed"],
		levels_gained * float(FeatureFlags.value("skill_target_width_per_level", 0.0)),
		levels_gained * float(FeatureFlags.value("skill_speed_reduction_per_level", 0.0)),
	)
	_bar.visible = true
	_showing_forge_hint = true
	_show_forge_hint()
	_update_strike_text()
	_refresh()


func _show_forge_hint() -> void:
	var stop := PackedStringArray()
	for kind in InputDevice.shown_kinds():
		stop.append(tr("UI_FORGE_STOP_" + kind.to_upper()))
	_forge_line.set_template(tr("UI_FORGE_HINT"), [KeyBindings.segments_for("interact"), " / ".join(stop)])
	_message.text = _forge_line.text
	_message.visible = false
	_forge_line.visible = true


## Shows the forge hint again with the inputs of the device in use.
func refresh_prompts() -> void:
	if _showing_forge_hint and is_forging():
		_show_forge_hint()


## Shows a plain message in place of the forge hint.
func _say(text: String) -> void:
	_message.text = text
	_message.visible = true
	_forge_line.visible = false


func _update_strike_text() -> void:
	_title.text = tr("UI_FORGING") % [
		CraftingData.item_name(_recipe["result"]), _game.strikes_done + 1, _game.strikes_total
	]


func _finish_recipe(quality: String) -> void:
	var is_new := not _player.known_recipes.has(_recipe["id"])
	_player.known_recipes[_recipe["id"]] = true
	_player.inventory.add(_recipe["result"], int(_recipe["count"]), quality, _variant)
	get_tree().call_group(CraftingStation.STATION_GROUP, "show_made", _station, _recipe["result"], _variant)
	var made := CraftingData.item_name(_recipe["result"])
	var details := PackedStringArray()
	if quality != "":
		details.append(CraftingData.quality_name(quality))
	if _variant != "":
		details.append(CraftingData.variant_text(_recipe["result"], _variant))
	if not details.is_empty():
		made = "%s (%s)" % [made, ", ".join(details)]
	_variant = ""
	_say(tr("UI_MADE_NEW" if is_new else "UI_MADE") % made)
	if FeatureFlags.enabled("crafting_skill") and _recipe.has("skill"):
		var new_level := _player.practice(_recipe["skill"], int(_recipe.get("xp", 1)))
		if new_level > 0:
			_message.text += "\n" + tr("UI_SKILL_UP") % [CraftingData.skill_name(_recipe["skill"]), new_level]
	_title.text = tr("UI_" + _station.to_upper())
	_refresh()


func _strike_key(accuracy: float) -> String:
	if accuracy >= 1.0:
		return "UI_STRIKE_PERFECT"
	return "UI_STRIKE_GOOD" if accuracy >= 0.5 else "UI_STRIKE_POOR"


func _build() -> void:
	_panel = FittedPanel.new(PANEL_WIDTH)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var column := _panel.content
	column.add_theme_constant_override("separation", 10)

	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	_title.add_theme_font_size_override("font_size", Settings.scaled_font_size(26))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)
	column.add_child(HSeparator.new())

	_inventory_label = _wrapped_label(column)
	_use_row = HFlowContainer.new()
	column.add_child(_use_row)
	_materials_label = _wrapped_label(column)
	# Set as keys, so that these follow a change of language on their own.
	_materials_label.text = "UI_ADD_MATERIALS"

	_materials = HFlowContainer.new()
	column.add_child(_materials)

	_selection_label = _wrapped_label(column)

	_parts = GridContainer.new()
	_parts.columns = 2
	_parts.add_theme_constant_override("h_separation", 12)
	column.add_child(_parts)

	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	_bar.visible = false
	_bar.clip_contents = true
	column.add_child(_bar)
	var background := Panel.new()
	background.theme_type_variation = &"BarTrough"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar.add_child(background)
	_target = Panel.new()
	_target.theme_type_variation = &"ForgeTarget"
	_bar.add_child(_target)
	_marker = ColorRect.new()
	_marker.color = MARKER_COLOR
	_marker.size = Vector2(6.0, BAR_HEIGHT)
	_bar.add_child(_marker)
	var frame := Panel.new()
	frame.theme_type_variation = &"BarFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar.add_child(frame)

	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	column.add_child(_actions)
	_craft_button = _action_button("UI_CRAFT", craft)
	_clear_button = _action_button("UI_CLEAR", clear_selection)
	_close_button = _action_button("UI_CLOSE", close)

	_message = _wrapped_label(column)
	_forge_line = PromptLine.new()
	_forge_line.visible = false
	column.add_child(_forge_line)
	_known_page = PanelContainer.new()
	_known_page.theme_type_variation = &"ParchmentPanel"
	column.add_child(_known_page)
	_known_label = _wrapped_label(_known_page)
	_known_label.theme_type_variation = &"InkLabel"


func _action_button(text_key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_key
	button.pressed.connect(action)
	_actions.add_child(button)
	return button


func _wrapped_label(parent: Control) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label
