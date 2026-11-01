extends SceneTree
## Run with: godot --headless --path . --script res://tests/smoke_test.gd

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await _physics_frames(90)

	var terrain: Terrain = scene.get_node("Terrain")
	var player: Player = scene.get_node("Player")
	var day_night: DayNight = scene.get_node("DayNight")
	var village: Village = scene.get_node("Village")

	_check(absf(terrain.height_at(0.0, 0.0)) < 1.0, "village site is flat")
	_check(terrain.height_at(0.0, 600.0) > 60.0, "mountains surround the valley")
	_check(player.is_on_floor(), "player lands on terrain")
	_check(absf(player.position.y - terrain.height_at(player.position.x, player.position.z)) < 1.0, "collision matches terrain")
	_check(village.get_node_or_null("forge") != null, "buildings load from data")
	_check(village.get_node("Roads").get_child_count() == 2, "roads load from data")
	_check(village.get_node("Boulders").get_child_count() > 0, "boulders have collision")
	_check(terrain.is_on_landslide(40.0, -300.0) and not terrain.is_on_landslide(0.0, 0.0), "landslide stays out of the village")

	var start := player.position
	Input.action_press("move_forward")
	await _physics_frames(120)
	Input.action_release("move_forward")
	_check(player.position.z < start.z - 3.0, "player walks forward")

	var before_toggle := player.first_person
	var event := InputEventAction.new()
	event.action = "toggle_camera"
	event.pressed = true
	Input.parse_input_event(event)
	await _physics_frames(5)
	_check(player.first_person != before_toggle, "camera mode switches")
	_check(not player.get_node("Body").visible, "body is hidden in first person")

	player.position = Vector3(0.0, 200.0, 900.0)
	await _physics_frames(2)
	_check(Vector2(player.position.x, player.position.z).length() <= Player.WORLD_RADIUS + 1.0, "player stays inside the world")

	day_night.hour = 12.0
	var noon := day_night.daylight()
	day_night.hour = 1.0
	var night := day_night.daylight()
	_check(noon == 1.0 and night == 0.0, "daylight follows the hour")

	for action in ["move_forward", "look_left", "jump", "sprint", "toggle_camera"]:
		var kinds := {}
		for input in InputMap.action_get_events(action):
			kinds[input.get_class()] = true
		_check(kinds.size() >= 1 and _has_joypad(kinds), "%s has a controller binding" % action)

	await _test_crafting(scene, player)
	await _test_story(scene, player)
	_test_translations()

	print("FAILED: %d" % _failures if _failures > 0 else "ALL PASSED")
	quit(1 if _failures > 0 else 0)


func _test_crafting(scene: Node, player: Player) -> void:
	var ui: CraftingUI = scene.get_node("CraftingUI")
	var village: Village = scene.get_node("Village")

	var furnace: CraftingStation = village.get_node("furnace")
	var pivot: Node3D = player.get_node("CameraPivot")
	pivot.rotation = Vector3.ZERO
	player.position = furnace.position + Vector3(0.0, 0.5, 2.5)
	await _physics_frames(10)
	_check(player.interact_target == furnace, "player can target a station")

	var ore_node: ResourceNode = null
	for child in village.get_children():
		if child is ResourceNode and child.item_id == "iron_ore":
			ore_node = child
			break
	for i in ore_node.uses:
		ore_node.interact(player)
	_check(player.inventory.count("iron_ore") == ore_node.uses, "gathering adds items")
	_check(not ore_node.is_available(), "gathering spots run out")
	player.inventory.add("coal", 2)
	player.inventory.add("wood", 1)

	player.interact()
	_check(ui.is_open(), "furnace opens the crafting screen")
	ui.add_material("wood")
	ui.craft()
	_check(player.inventory.count("wood") == 1, "a failed experiment costs nothing")
	ui.clear_selection()
	ui.add_material("iron_ore")
	ui.add_material("iron_ore")
	ui.add_material("coal")
	ui.craft()
	_check(player.inventory.count("iron_ingot") == 1, "smelting makes an ingot")
	_check(player.known_recipes.has("smelt_iron"), "smelting is discovered")
	ui.close()
	_check(not ui.is_open(), "crafting screen closes")

	ui.open_station("anvil", "Anvil", player)
	ui.add_material("iron_ingot")
	ui.add_material("wood")
	ui.craft()
	_check(ui.is_forging(), "forging starts the minigame")
	while ui.is_forging():
		ui._game.marker = ui._game.target
		ui.strike()
	var made := player.inventory.entries().filter(func(entry): return entry["id"] == "iron_dagger")
	_check(made.size() == 1 and made[0]["quality"] == "masterwork", "perfect forging gives masterwork")
	ui.close()

	var clumsy := HammerGame.new(2, 1.0)
	clumsy.marker = clamp(clumsy.target + 0.5, 0.0, 1.0) if clumsy.target < 0.5 else clumsy.target - 0.5
	clumsy.strike()
	_check(CraftingData.quality_for_score(clumsy.score()) == "crude", "bad forging gives crude quality")
	_check(CraftingData.find_recipe("anvil", {"coal": 1}).is_empty(), "unknown combinations match nothing")
	_check(CraftingData.item_name("iron_sword") != "ITEM_IRON_SWORD", "item names are translated")


func _test_story(scene: Node, player: Player) -> void:
	var ui: DialogueUI = scene.get_node("DialogueUI")
	var village: Village = scene.get_node("Village")
	var quests := player.quests

	_check(quests.current_objective("arrival") == "see_grandmother", "the first quest starts on its own")
	_check(quests.tracker_lines(player.inventory).size() == 1, "the tracker shows the active quest")

	var hedda: Npc = village.get_node("hedda")
	var pivot: Node3D = player.get_node("CameraPivot")
	pivot.rotation = Vector3.ZERO
	player.position = hedda.position + Vector3(0.0, 0.5, 2.0)
	await _physics_frames(10)
	_check(player.interact_target == hedda, "player can target a villager")
	player.interact()
	_check(ui.is_open() and player.is_busy(), "talking opens the dialogue screen")
	ui.choose(1)
	ui.choose(0)
	_check(quests.current_objective("arrival") == "see_smith", "grandmother sends the player to the smith")
	ui.choose(0)
	_check(not ui.is_open() and not player.is_busy(), "the conversation ends")

	_talk(ui, "bertram", player, [0, 0, 0])
	_check(quests.is_done("arrival") and quests.current_objective("first_nails") == "make_nails", "the smith gives the nails quest")

	player.inventory.remove("iron_nails", player.inventory.count("iron_nails"))
	_talk(ui, "bertram", player, [0])
	_check(quests.current_objective("first_nails") == "make_nails", "the smith waits for the nails")

	player.inventory.add("iron_nails", 4, "fine")
	var ingots := player.inventory.count("iron_ingot")
	_check(quests.tracker_lines(player.inventory)[0].contains("(4/4)"), "the tracker counts the nails")
	_talk(ui, "bertram", player, [0])
	_check(player.inventory.count("iron_nails") == 0, "the smith takes the nails")
	_check(player.inventory.count("iron_ingot") == ingots + 2, "the smith pays the player")
	_check(quests.current_objective("first_nails") == "tell_mayor", "the smith sends the player to the mayor")

	_talk(ui, "brandt", player, [1, 0])
	_check(quests.is_done("first_nails"), "telling the mayor completes the quest")
	_check(quests.flags.has("mayor_annoyed"), "the player's choice is remembered")
	var cold := DialogueRunner.new("brandt", player)
	_check(cold.text_key() == "DLG_BRANDT_COLD", "the mayor reacts to the choice")
	_check(DialogueRunner.new("hedda", player).text_key() == "DLG_HEDDA_PROUD", "grandmother reacts to the finished quest")


func _talk(ui: DialogueUI, npc_id: String, player: Player, answers: Array) -> void:
	ui.open_conversation(npc_id, npc_id, player)
	for answer: int in answers:
		ui.choose(answer)


## Every story and item key must exist in both languages.
func _test_translations() -> void:
	var missing := PackedStringArray()
	var text := FileAccess.get_file_as_string("res://data/dialogue.json") + FileAccess.get_file_as_string("res://data/quests.json") + FileAccess.get_file_as_string("res://data/crafting.json")
	var pattern := RegEx.create_from_string("\"((?:DLG|OBJ|QUEST|ITEM)_[A-Z_]+)\"")
	for locale in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for found in pattern.search_all(text):
			if TranslationServer.translate(found.get_string(1)) == found.get_string(1):
				missing.append("%s:%s" % [locale, found.get_string(1)])
	TranslationServer.set_locale("en")
	_check(missing.is_empty(), "all text is translated %s" % ", ".join(missing))


func _has_joypad(kinds: Dictionary) -> bool:
	return kinds.has("InputEventJoypadButton") or kinds.has("InputEventJoypadMotion")


func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, label: String) -> void:
	print("%s: %s" % ["ok" if condition else "FAIL", label])
	if not condition:
		_failures += 1
