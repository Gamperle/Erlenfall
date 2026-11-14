class_name Journal
extends CanvasLayer
## The journal screen, opened with the journal key. It has a Quests tab (active and finished quests with
## their objectives, and a way to pin one), a Map tab (the world map, shown inside the journal) and a
## Notes tab. It pauses the game like the map. See the `journal` flag.
##
## Everything is a Godot Control that can take focus, so the keyboard, the mouse and a controller all work:
## the arrow keys and the d-pad move between the tabs and the quests, and accept pins a quest.

const TAB_QUESTS := 0
const TAB_MAP := 1
const TAB_NOTES := 2
const TAB_KEYS: Array[String] = ["UI_JOURNAL_QUESTS", "UI_JOURNAL_MAP", "UI_JOURNAL_NOTES"]
const DIM_COLOR := Color(0.03, 0.03, 0.02, 0.9)
const TEXT_COLOR := Color(0.95, 0.92, 0.85)
const DONE_COLOR := Color(0.62, 0.62, 0.55)
const TRACKED_COLOR := Color(0.95, 0.75, 0.3)
const FONT_SIZE := 18
const TITLE_FONT_SIZE := 26
const MARGIN := 28

## Says whether the journal may open now, such as not during a menu or dialogue.
var can_open := func() -> bool: return true

var _player: Player
var _world_map: WorldMap
var _root: Control
var _theme := Theme.new()
var _title: Label
var _tabs: Array[Button] = []
var _pages: Array[Control] = []
var _quest_list: VBoxContainer
var _note_list: VBoxContainer
var _hint: Label
var _tab := TAB_QUESTS
var _is_open := false


func _init() -> void:
	name = "Journal"
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


## Makes the journal under `parent`, or returns null when the `journal` flag is off. It opens only while
## the game's interface is showing and the player is free, like the map.
static func create(parent: Node, player: Player, hud: HudLayout, world_map: WorldMap) -> Journal:
	if not FeatureFlags.enabled("journal"):
		return null
	var journal := Journal.new()
	journal.can_open = func() -> bool: return hud.visible and not player.is_busy()
	parent.add_child(journal)
	journal.setup(player, world_map)
	return journal


## `world_map` may be null when the map is off: the Map tab then says so.
func setup(player: Player, world_map: WorldMap) -> void:
	_player = player
	_world_map = world_map
	_build()


func is_open() -> bool:
	return _is_open


func current_tab() -> int:
	return _tab


func open() -> void:
	_is_open = true
	visible = true
	_player.set_busy(true)
	_apply_text_size()
	select_tab(TAB_QUESTS)
	_tabs[_tab].grab_focus()


func close() -> void:
	_is_open = false
	visible = false
	if _world_map != null:
		_world_map.release()
	_player.set_busy(false)


## Shows one of the tabs and builds its content again, so it is current.
func select_tab(tab: int) -> void:
	_tab = clampi(tab, 0, _pages.size() - 1)
	for index in _pages.size():
		_pages[index].visible = index == _tab
		_tabs[index].set_pressed_no_signal(index == _tab)
	if _world_map != null:
		_world_map.release()
		if _tab == TAB_MAP:
			_world_map.embed(_pages[TAB_MAP])
	match _tab:
		TAB_QUESTS:
			_fill_quests()
		TAB_NOTES:
			_fill_notes()
	_hint.text = tr("UI_JOURNAL_HINT_QUESTS") if _tab == TAB_QUESTS else tr("UI_JOURNAL_HINT")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _root != null:
		_title.text = tr("UI_JOURNAL")
		for index in _tabs.size():
			_tabs[index].text = tr(TAB_KEYS[index])
		if _is_open:
			select_tab(_tab)


func _input(event: InputEvent) -> void:
	if not _is_open:
		if event.is_action_pressed("journal") and can_open.call():
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("journal") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map") and _world_map != null:
		select_tab(TAB_MAP)
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = _theme
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	_root.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	_title = Label.new()
	_title.text = tr("UI_JOURNAL")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", TEXT_COLOR)
	column.add_child(_title)

	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", 8)
	column.add_child(tab_row)
	for index in TAB_KEYS.size():
		var button := Button.new()
		button.text = tr(TAB_KEYS[index])
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(select_tab.bind(index))
		tab_row.add_child(button)
		_tabs.append(button)

	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	_quest_list = _scroll_page(content)
	var map_page := Control.new()
	map_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_page.clip_contents = true
	content.add_child(map_page)
	if _world_map == null:
		map_page.add_child(_message_label(tr("UI_JOURNAL_NO_MAP")))
	_note_list = _scroll_page(content)
	_pages.assign([_quest_list.get_parent(), map_page, _note_list.get_parent()])

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", DONE_COLOR)
	column.add_child(_hint)
	_apply_text_size()


## A scrolling list that follows the focus, so a controller can reach everything in it.
func _scroll_page(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	return list


func _apply_text_size() -> void:
	_theme.default_font_size = Settings.scaled_font_size(FONT_SIZE)
	_title.add_theme_font_size_override("font_size", Settings.scaled_font_size(TITLE_FONT_SIZE))


func _fill_quests() -> void:
	_clear(_quest_list)
	var entries := _player.quests.journal_entries(_player.inventory)
	if entries.is_empty():
		_quest_list.add_child(_message_label(tr("UI_JOURNAL_NO_QUESTS")))
		return
	var previous_done := false
	for entry in entries:
		if entry["done"] and not previous_done:
			var heading := _message_label(tr("UI_JOURNAL_COMPLETED"))
			_quest_list.add_child(heading)
		previous_done = entry["done"]
		var header := Button.new()
		header.text = entry["title"] + ("  (%s)" % tr("UI_JOURNAL_TRACKED") if entry["tracked"] else "")
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.flat = true
		header.focus_mode = Control.FOCUS_ALL
		header.add_theme_color_override("font_color", DONE_COLOR if entry["done"] else (TRACKED_COLOR if entry["tracked"] else TEXT_COLOR))
		header.add_theme_color_override("font_focus_color", header.get_theme_color("font_color"))
		header.pressed.connect(_toggle_tracking.bind(entry["id"]))
		_quest_list.add_child(header)
		for objective: Dictionary in entry["objectives"]:
			var line := _message_label(("[x] " if objective["done"] else "[ ] ") + objective["text"])
			line.add_theme_color_override("font_color", DONE_COLOR if objective["done"] else TEXT_COLOR)
			line.add_theme_constant_override("line_spacing", 2)
			var indent := MarginContainer.new()
			indent.add_theme_constant_override("margin_left", 28)
			indent.add_child(line)
			_quest_list.add_child(indent)


func _toggle_tracking(quest_id: String) -> void:
	var quests := _player.quests
	if quests.tracked == quest_id:
		quests.untrack()
	elif not quests.track(quest_id):
		return
	var focused := get_viewport().gui_get_focus_owner()
	var index := focused.get_index() if focused != null and focused.get_parent() == _quest_list else -1
	_fill_quests()
	if index >= 0 and index < _quest_list.get_child_count():
		_focus_later.call_deferred(_quest_list.get_child(index))


## The list can be rebuilt before the deferred focus runs, which takes the button out of the tree.
func _focus_later(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree():
		control.grab_focus()


func _fill_notes() -> void:
	_clear(_note_list)
	var entries := _player.notes.entries()
	if entries.is_empty():
		_note_list.add_child(_message_label(tr("UI_JOURNAL_NO_NOTES")))
		return
	for entry in entries:
		var header := Button.new()
		header.text = entry["title"]
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.flat = true
		header.focus_mode = Control.FOCUS_ALL
		_note_list.add_child(header)
		var indent := MarginContainer.new()
		indent.add_theme_constant_override("margin_left", 28)
		indent.add_child(_message_label(entry["text"]))
		_note_list.add_child(indent)


func _message_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _clear(list: Container) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
