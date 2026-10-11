extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func run() -> void:
	var definition := LabyrinthDefinition.from_json("res://resources/labyrinths/office.json")
	var configured: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/labyrinths/office.json"))
	check(definition.encounter_steps_min == int(configured.encounter_steps_min) and definition.encounter_steps_max == int(configured.encounter_steps_max), "Office config loads its encounter step range")
	definition.encounter_steps_min = 0
	check(not definition.validation_error().is_empty(), "Encounter minimum must be positive")
	definition.encounter_steps_min = definition.encounter_steps_max + 1
	check(not definition.validation_error().is_empty(), "Reversed encounter ranges are rejected")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/labyrinths/office.json"))
	for invalid in [0, -1, 2.5, "often", true]:
		data.encounter_steps_min = invalid
		check(LabyrinthDefinition.from_dictionary(data) == null, "JSON rejects invalid encounter step counts")
	data.encounter_steps_min = 8
	data.encounters_enabled = "no"
	check(LabyrinthDefinition.from_dictionary(data) == null, "JSON requires a boolean encounter toggle")
	data = JSON.parse_string(FileAccess.get_file_as_string("res://resources/labyrinths/office.json"))
	for invalid in [[], ["res://resources/rpg/enemies/rat.tres"], [null], "rat_pair"]:
		data.encounters = invalid
		check(LabyrinthDefinition.from_dictionary(data) == null, "JSON rejects missing or incorrectly typed encounter presets")
	definition = LabyrinthDefinition.from_json("res://resources/labyrinths/office.json")
	var solo := BattleEncounter.new()
	solo.display_name = "Solo Rat"
	solo.enemy_level = 3
	solo.enemies.append(load("res://resources/rpg/enemies/rat.tres"))
	var trio := BattleEncounter.new()
	trio.display_name = "Orb Escort"
	trio.enemy_level = 7
	trio.enemies.assign([load("res://resources/rpg/enemies/ethereal_orb.tres"), solo.enemies[0], solo.enemies[0]])
	definition.encounters.assign([solo, trio])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7654
	var selected: Dictionary[String, bool] = {}
	for sample in range(100):
		var encounter := definition.pick_encounter(rng)
		var preset := solo if encounter.display_name == solo.display_name else trio
		check(encounter != preset and encounter.enemies == preset.enemies and encounter.enemy_level == preset.enemy_level, "Selection preserves each preset's enemy count, order, repeats, and level")
		selected[encounter.display_name] = true
		encounter.enemies.clear()
		check(not preset.enemies.is_empty(), "Runtime encounters cannot modify a configured preset's enemy array")
	check(selected.size() == 2, "All configured encounter presets can be selected")
	var invalid_preset := BattleEncounter.new()
	definition.encounters.assign([invalid_preset])
	check(not definition.validation_error().is_empty(), "Empty encounter presets are rejected")
	invalid_preset.enemies.resize(7)
	invalid_preset.enemies.fill(solo.enemies[0])
	check(not definition.validation_error().is_empty(), "Encounters exceeding six enemies are rejected")
	invalid_preset.enemies.assign(solo.enemies)
	invalid_preset.enemy_level = 0
	check(not definition.validation_error().is_empty(), "Invalid encounter levels are rejected")
	invalid_preset.enemy_level = 1
	invalid_preset.enemies[0] = null
	check(not definition.validation_error().is_empty(), "Null enemies are rejected")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game(false)
	game.battle_fade_in_duration = 0.0
	game.battle_reveal_duration = 0.0
	game.battle_return_fade_duration = 0.0
	game.explore()
	var map := game.world as LabyrinthMap
	map.definition.encounter_steps_min = 8
	map.definition.encounter_steps_max = 14
	map._encounter_rng.seed = 12345
	var rolled_counts: Dictionary[int, bool] = {}
	for sample in range(200):
		map.reset_encounters()
		check(map._encounter_steps >= 8 and map._encounter_steps <= 14, "Each encounter distance stays inside the inclusive configured range")
		rolled_counts[map._encounter_steps] = true
	check(rolled_counts.size() == 7, "Step rolls vary and include both endpoints")
	map.definition.encounter_steps_min = 1
	map.definition.encounter_steps_max = 1
	map.reset_encounters()
	check(not InputMap.has_action("start_battle"), "Manual encounter input action is removed")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_B
	key.pressed = true
	game._unhandled_input(key)
	check(game.screen == "explore", "B cannot start combat")
	game.show_pause()
	check((game.ui.get_child(0) as PauseBook).command("Town") == null, "Book cannot teleport to a Safe Zone")
	map._on_player_walked(map.definition.cell_size * 2.0)
	check(game.screen == "pause" and map._encounter_distance == 0.0, "Paused maps cannot advance encounter checks")
	game.resume_exploration()
	map._on_player_walked(map.definition.cell_size * 2.0)
	check(game.screen == "explore" and map._encounter_distance == 0.0, "Safe Zone cells cannot trigger encounters")

	# Find a traversable, straight cell-to-cell segment outside all refuges.
	var start := Vector2i.ZERO
	var finish := Vector2i.ZERO
	var safe_cells: Array[Vector2i] = []
	for landmark in map.definition.landmarks:
		if landmark.kind == &"safe_zone":
			safe_cells.append(landmark.coordinate)
	for cell in map.layout.passages:
		if cell in safe_cells:
			continue
		for neighbor in map.layout.passages[cell]:
			if neighbor not in safe_cells:
				start = cell
				finish = neighbor
				break
		if start != finish:
			break
	# Push against a closed wall: input time must not count as walking distance.
	var wall_cell := Vector2i.ZERO
	var wall_direction := Vector2i.ZERO
	for cell in map.layout.passages:
		if cell in safe_cells:
			continue
		for direction in LabyrinthLayout.DIRECTIONS:
			if cell + direction not in map.layout.passages[cell]:
				wall_cell = cell
				wall_direction = direction
				break
		if wall_direction != Vector2i.ZERO:
			break
	var toward_wall := map.layout.world_position(wall_direction).normalized()
	map.player.position = map.layout.world_position(wall_cell) + toward_wall * (map.definition.cell_size * 0.5 - 0.8)
	map.player.rotation.y = Vector3.FORWARD.signed_angle_to(toward_wall, Vector3.UP)
	Input.action_press("move_forward")
	for frame in range(120):
		await physics_frame
	Input.action_release("move_forward")
	check(game.screen == "explore" and map._encounter_distance < 1.0, "Pushing into a wall only counts the short distance actually moved")
	map.reset_encounters()
	map.player.position = map.layout.world_position(start)
	map.player.rotation.y = Vector3.FORWARD.signed_angle_to(map.layout.world_position(finish - start).normalized(), Vector3.UP)
	for frame in range(10):
		await physics_frame
	check(game.screen == "explore" and map._encounter_distance < 0.001, "Teleporting and idling do not advance encounters")
	map.definition.encounter_steps_min = 8
	map.definition.encounter_steps_max = 14
	map.reset_encounters()
	map._on_player_walked(map.definition.cell_size * (map._encounter_steps - 0.01))
	check(game.screen == "explore", "No encounter starts before its chosen step threshold")
	map.reset_encounters()
	map.definition.encounters_enabled = false
	Input.action_press("move_forward")
	for frame in range(80):
		await physics_frame
	Input.action_release("move_forward")
	check(game.screen == "explore", "Disabled encounters cannot start battles while walking")
	map.player.position = map.layout.world_position(start)
	map.player.velocity = Vector3.ZERO
	map.definition.encounters_enabled = true
	map.definition.encounter_steps_min = 1
	map.definition.encounter_steps_max = 1
	map.reset_encounters()
	map._on_player_walked(map.definition.cell_size * 0.5)
	check(game.screen == "explore", "Less than one cell of walking cannot trigger a check")
	game.show_pause()
	game.resume_exploration()
	check(is_equal_approx(map._encounter_distance, map.definition.cell_size * 0.5), "Pause/resume preserves partial walking distance")
	var previous_encounter := map.encounter
	Input.action_press("move_forward")
	for frame in range(150):
		if game.screen == "combat":
			break
		await physics_frame
	Input.action_release("move_forward")
	check(game.screen == "combat" and not map.player.movement_enabled, "Actual walking starts combat upon reaching the chosen step count")
	check(map.encounter != previous_encounter, "Every battle receives a fresh encounter instance")
	var matched_preset := false
	for preset in map.definition.encounters:
		if map.encounter.display_name == preset.display_name and map.encounter.enemies == preset.enemies and map.encounter.enemy_level == preset.enemy_level:
			matched_preset = true
	check(matched_preset, "Walking starts one complete configured encounter")
	await game._on_combat_finished(true)
	check(game.screen == "explore" and not map._encounter_pending and map._encounter_distance == 0.0, "Returning from combat resets the meter and pending encounter")
	map._on_player_walked(map.definition.cell_size * 0.5)
	check(game.screen == "explore", "Post-combat movement grace prevents an immediate second battle")
	print("Encounter test complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
