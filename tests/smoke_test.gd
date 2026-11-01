extends SceneTree
## Run with: godot --headless --path . --script res://tests/smoke_test.gd

const TEST_SAVE := "user://smoke_test_save.json"
const TEST_FLAGS_A := "user://smoke_test_flags_a.json"
const TEST_FLAGS_B := "user://smoke_test_flags_b.json"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(TEST_SAVE)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.show_menu = false
	scene.save_path = TEST_SAVE
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

	for action in ["move_forward", "look_left", "jump", "sprint", "toggle_camera", "toggle_torch"]:
		var kinds := {}
		for input in InputMap.action_get_events(action):
			kinds[input.get_class()] = true
		_check(kinds.size() >= 1 and _has_joypad(kinds), "%s has a controller binding" % action)

	_test_feature_flags()
	await _test_torch(player)
	await _test_crafting(scene, player)
	await _test_story(scene, player)
	await _test_combat(scene, player)
	await _test_save_and_menu(scene, player, day_night)
	_test_translations()

	print("FAILED: %d" % _failures if _failures > 0 else "ALL PASSED")
	quit(1 if _failures > 0 else 0)


func _test_feature_flags() -> void:
	_check(FeatureFlags.enabled("torch_recipe"), "an aggregate of enabled flags is on")
	_check(not FeatureFlags.enabled("torch_burns_out"), "an aggregate with a disabled flag is off")

	_write_flags(TEST_FLAGS_A, { "flags": { "torch_burn_time_enabled": true, "test_not": { "not": "torches" }, "test_nested": { "any": [false, { "all": ["torches", "test_not"] }, "torch_recipe"] }, "test_loop": { "all": ["test_loop"] } }, "values": { "torch_burn_seconds": 5 } })
	_write_flags(TEST_FLAGS_B, { "flags": { "torch_burn_time_enabled": false }, "values": { "torch_burn_seconds": 9 } })
	FeatureFlags.load_layers([TEST_FLAGS_A])
	_check(FeatureFlags.enabled("torch_burns_out"), "a mod's flag changes an aggregate")
	_check(not FeatureFlags.enabled("test_not") and FeatureFlags.enabled("test_nested"), "aggregates can be negated and nested")
	_check(FeatureFlags.value("torch_burn_seconds") == 5, "a mod overrides a value")
	FeatureFlags.load_layers([TEST_FLAGS_A, TEST_FLAGS_B])
	_check(not FeatureFlags.enabled("torch_burns_out") and FeatureFlags.value("torch_burn_seconds") == 9, "the last mod in the load order wins")
	FeatureFlags.load_layers([TEST_FLAGS_B, TEST_FLAGS_A])
	_check(FeatureFlags.enabled("torch_burns_out") and FeatureFlags.value("torch_burn_seconds") == 5, "swapping the load order swaps the winner")
	_check(not FeatureFlags.enabled("test_loop"), "a flag that depends on itself counts as off")
	_check(not FeatureFlags.enabled("test_missing"), "an unknown flag counts as off")

	_write_flags(TEST_FLAGS_A, { "flags": { "torch_crafting_enabled": false } })
	FeatureFlags.load_layers([TEST_FLAGS_A])
	_check(CraftingData.find_recipe("furnace", { "wood": 1, "coal": 1 }).is_empty(), "a disabled flag removes a recipe")
	FeatureFlags.load_layers()
	_check(not CraftingData.find_recipe("furnace", { "wood": 1, "coal": 1 }).is_empty(), "the torch recipe is on by default")


func _test_torch(player: Player) -> void:
	_check(player.inventory.count("torch") == 1, "a new game starts with a torch")
	player.give_starting_items()
	_check(player.inventory.count("torch") == 1, "the starting torch is only given once")

	player.toggle_torch()
	_check(player.torch_lit, "the torch lights")
	await _physics_frames(30)
	_check(player.torch_lit and player.inventory.count("torch") == 1, "by default a torch burns forever")

	_write_flags(TEST_FLAGS_A, { "flags": { "torch_burn_time_enabled": true }, "values": { "torch_burn_seconds": 0.1 } })
	FeatureFlags.load_layers([TEST_FLAGS_A])
	await _physics_frames(30)
	_check(not player.torch_lit and player.inventory.count("torch") == 0, "with a burn time, a torch burns out and is used up")
	player.toggle_torch()
	_check(not player.torch_lit, "no torch means no light")
	FeatureFlags.load_layers()
	player.inventory.add("torch")
	DirAccess.remove_absolute(TEST_FLAGS_A)
	DirAccess.remove_absolute(TEST_FLAGS_B)


func _write_flags(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


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
	var torches := player.inventory.count("torch")
	player.inventory.add("wood", 1)
	ui.add_material("wood")
	ui.add_material("coal")
	ui.craft()
	_check(player.inventory.count("torch") == torches + 1, "wood and coal make a torch")
	_check(player.known_recipes.has("make_torch"), "the torch recipe is discovered")
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
	_check(quests.current_objective("first_nails") == "repair_roof", "the mayor leads to the roof repair")
	var site: RepairSite = null
	for child in village.get_children():
		if child is RepairSite:
			site = child
	var inn := village.get_node("inn")
	var repaired_roof: Node3D = inn.get_node("RepairedRoof")
	var damaged_roof: Node3D = inn.get_node("DamagedRoof")
	_check(damaged_roof.visible and not repaired_roof.visible, "the inn starts with a damaged roof")
	_check(site.is_available(), "the repair is available during its objective")
	site.interact(player)
	_check(quests.is_done("first_nails"), "repairing the roof completes the quest")
	_check(repaired_roof.visible and not damaged_roof.visible, "the repair shows on the inn")
	_check(not site.is_available(), "the repair can't be repeated")
	_check(DialogueRunner.new("greta", player).text_key() == "DLG_GRETA_GRATEFUL", "the innkeeper thanks the player")
	_check(quests.flags.has("mayor_annoyed"), "the player's choice is remembered")
	var cold := DialogueRunner.new("brandt", player)
	_check(cold.text_key() == "DLG_BRANDT_COLD", "the mayor reacts to the choice")
	_check(DialogueRunner.new("hedda", player).text_key() == "DLG_HEDDA_PROUD", "grandmother reacts to the finished quest")


func _test_combat(scene: Node, player: Player) -> void:
	var fresh := Inventory.new()
	_check(fresh.best_weapon_damage() == 0.0, "no weapon means no weapon damage")
	fresh.add("iron_sword", 1, "crude")
	fresh.add("iron_dagger", 1, "masterwork")
	_check(fresh.best_weapon_damage() == 16.0, "the strongest weapon and quality are used")
	fresh.add("wood", 4)
	fresh.lose_materials(0.25)
	_check(fresh.count("wood") == 3 and fresh.count("iron_sword") == 1, "only materials are lost")

	var enemy: Enemy = null
	for node in root.get_tree().get_nodes_in_group(Enemy.GROUP):
		enemy = node
		break
	_check(enemy != null and enemy.state == Enemy.State.IDLE, "goblins wait at their camp")

	var pivot: Node3D = player.get_node("CameraPivot")
	pivot.rotation = Vector3.ZERO
	player.health.restore()
	player.position = enemy.position + Vector3(0.0, 0.3, 1.5)
	await _physics_frames(5)
	_check(enemy.state != Enemy.State.IDLE, "goblins notice a nearby player")

	# Hold block through the goblin's attack.
	Input.action_press("block")
	await _physics_frames(90)
	Input.action_release("block")
	_check(player.health.current == 100.0 - 12.0 * 0.2, "blocking reduces a goblin's hit")

	player.health.restore()
	player.dodge()
	player.take_hit(50.0, enemy.global_position)
	_check(player.is_dodging() and player.health.current == 100.0, "dodging avoids damage")
	await _physics_frames(60)

	player.health.restore()
	player.position = enemy.position + Vector3(0.0, 0.3, 1.5)
	pivot.rotation = Vector3.ZERO
	var before := enemy.health.current
	player.attack()
	await _physics_frames(20)
	_check(enemy.health.current < before, "an attack hurts the goblin")
	while enemy.state != Enemy.State.DEAD:
		enemy.take_hit(1000.0)
	await _physics_frames(2)
	_check(not enemy.visible, "a defeated goblin disappears")

	player.inventory.add("coal", 4)
	var coal := player.inventory.count("coal")
	player.take_hit(1000.0, player.global_position)
	await _physics_frames(2)
	_check(player.health.current == 100.0, "death restores health")
	_check(player.global_position.distance_to(Vector3(-12.0, player.global_position.y, 30.0)) < 2.0, "death returns the player to the village")
	_check(player.inventory.count("coal") < coal, "death costs some materials")
	_check(enemy.visible and enemy.state != Enemy.State.DEAD, "enemies return after the player dies")


func _test_save_and_menu(scene: Node, player: Player, day_night: DayNight) -> void:
	var menu: GameMenu = scene.get_node("GameMenu")
	var village: Village = scene.get_node("Village")
	var full_roof: Node3D = village.get_node("inn/RepairedRoof")

	scene.save_game()
	_check(SaveGame.exists(TEST_SAVE), "the game saves")
	var saved_position := player.position
	var saved_coal := player.inventory.count("coal")
	var recipes := player.known_recipes.size()
	player.set_torch_lit(true)
	player.torch_burned_seconds = 12.0
	scene.save_game()

	# Quest changes autosave, which would overwrite the save this test wants to restore.
	scene._playing = false
	player.position += Vector3(5.0, 0.0, 5.0)
	player.inventory.add("coal", 7)
	player.known_recipes.clear()
	player.health.current = 1.0
	player.set_torch_lit(false)
	player.torch_burned_seconds = 0.0
	player.torch_given = false
	player.quests.load_data({ "stages": {}, "flags": [] })
	_check(not full_roof.visible, "the roof depends on saved flags")
	day_night.hour = 3.0

	_check(SaveGame.apply(TEST_SAVE, player, day_night), "the game loads")
	_check(player.position.is_equal_approx(saved_position), "position is restored")
	_check(player.inventory.count("coal") == saved_coal, "inventory is restored")
	_check(player.known_recipes.size() == recipes, "recipes are restored")
	_check(player.health.current == 100.0, "health is restored")
	_check(player.torch_lit and player.torch_burned_seconds == 12.0 and player.torch_given, "the torch is restored")
	player.set_torch_lit(false)
	_check(player.quests.is_done("first_nails") and player.quests.flags.has("mayor_annoyed"), "quests and choices are restored")
	_check(full_roof.visible, "the repaired roof is restored")
	_check(day_night.hour != 3.0, "the time of day is restored")
	scene._playing = true

	var damaged := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	damaged.store_string("{ not json")
	damaged.close()
	_check(not SaveGame.exists(TEST_SAVE), "a damaged save is ignored")
	_check(not SaveGame.apply(TEST_SAVE, player, day_night), "a damaged save doesn't load")

	player.health.current = 50.0
	day_night.hour = 22.0
	scene.sleep()
	_check(player.health.current == 100.0 and day_night.hour == 7.0, "sleeping heals and passes the night")
	_check(SaveGame.exists(TEST_SAVE), "sleeping saves the game")

	scene.open_pause_menu()
	_check(menu.is_open() and player.is_busy() and paused, "the pause menu pauses the game")
	scene.resume()
	_check(not menu.is_open() and not player.is_busy() and not paused, "resuming unpauses the game")
	menu.open_title(true)
	_check(menu.is_open(), "the title menu opens")
	menu.close()
	DirAccess.remove_absolute(TEST_SAVE)


func _talk(ui: DialogueUI, npc_id: String, player: Player, answers: Array) -> void:
	ui.open_conversation(npc_id, npc_id, player)
	for answer: int in answers:
		ui.choose(answer)


## Every story and item key must exist in both languages.
func _test_translations() -> void:
	var missing := PackedStringArray()
	var text := FileAccess.get_file_as_string("res://data/dialogue.json") + FileAccess.get_file_as_string("res://data/quests.json") + FileAccess.get_file_as_string("res://data/crafting.json") + FileAccess.get_file_as_string("res://data/enemies.json")
	var pattern := RegEx.create_from_string("\"((?:DLG|OBJ|QUEST|ITEM|ENEMY)_[A-Z_]+)\"")
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
