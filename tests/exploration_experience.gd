extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.starting_party_size = 4 # Keep the fourth member active for knockout coverage.
	game.starting_characters.append(load("res://resources/rpg/characters/koumi.tres"))
	game.new_game(false)
	check(game.state.highest_labyrinth_completion == 0.0, "New Game starts without an exploration multiplier")
	game.explore()
	var map := game.world as LabyrinthMap
	check(is_equal_approx(game.state.highest_labyrinth_completion, map.exploration_completion()), "Initial map discovery contributes to the global exploration peak")
	var target := map.layout.passages.size() / 2
	var landmark_cells: Array[Vector2i] = []
	for landmark in map.definition.landmarks:
		landmark_cells.append(landmark.coordinate)
	for cell in map.layout.passages:
		if map.walked_cells.size() >= target:
			break
		if cell not in landmark_cells:
			map.player.position = map.layout.world_position(cell)
			map._record_walked_cell()
	check(is_equal_approx(game.state.highest_labyrinth_completion, 0.5), "Exploration automatically records a 50% session peak")
	game.show_town()
	game.explore()
	check(game.world.exploration_completion() < 0.5 and game.state.highest_labyrinth_completion == 0.5, "A regenerated map cannot lower the highest completion")
	game.show_town()
	var first: CharacterState = game.state.roster[0]
	first.experience = 10.0
	first.store_experience(1, 40.0)
	game.state.roster[1].store_experience(1, 70.0)
	var reserve := CharacterState.new(game.starting_characters[0])
	game.state.roster.append(reserve)
	reserve.store_experience(1, 80.0)
	var downed: CharacterState = game.state.roster[3]
	downed.store_experience(1, 25.0)
	downed.current_hp = 0
	check(downed.stored_experience() == 0.0 and game.state.highest_labyrinth_completion == 0.5, "Knockouts clear character XP without resetting global exploration")
	reserve.store_experience(2, 10.0)
	reserve.discard_encounter_experience(2)
	check(reserve.stored_experience() == 80.0 and game.state.highest_labyrinth_completion == 0.5, "Retreat's XP rollback preserves the exploration peak")
	game.show_location("Barracks")
	var barracks = game.ui.get_child(0).module_view
	game.sleep_fade_duration = 0.0
	await game._sleep_at_barracks(barracks)
	check(first.experience == 30.0 and game.state.roster[1].experience == 35.0 and reserve.experience == 40.0, "Rest scales active and reserve banks by the same peak without rescaling applied XP")
	for member in game.state.roster:
		check(member.stored_experience() == 0.0 and member.is_alive(), "Rest consumes every bank and restores the roster")
	check(game.state.highest_labyrinth_completion == 0.0, "Rest resets the global peak after applying all characters' XP")
	await game._sleep_at_barracks(barracks)
	check(first.experience == 30.0 and reserve.experience == 40.0, "Repeated rest cannot reapply XP")
	first.store_experience(3, 20.0)
	await game._sleep_at_barracks(barracks)
	check(first.experience == 30.0 and first.stored_experience() == 0.0, "Zero exploration applies none of a bank and still consumes it")
	game.show_town()
	game.explore()
	map = game.world as LabyrinthMap
	for cell in map.layout.passages:
		map.player.position = map.layout.world_position(cell)
		map._record_walked_cell()
	check(game.state.highest_labyrinth_completion == 1.0, "Full exploration supplies a 100% rest multiplier")
	game.show_town()
	game.show_location("Barracks")
	barracks = game.ui.get_child(0).module_view
	first.store_experience(4, 20.0)
	await game._sleep_at_barracks(barracks)
	check(first.experience == 50.0 and game.state.highest_labyrinth_completion == 0.0, "Full exploration applies the entire XP bank and then resets")
	game.explore()
	check(game.state.highest_labyrinth_completion > 0.0, "Exploring again starts a new global peak")
	game.new_game(false)
	check(game.state.highest_labyrinth_completion == 0.0 and game.state.roster[0].stored_experience() == 0.0, "New Game resets exploration and stored XP together")
	# Fractional scaling also feeds the normal permanent-growth/level-up path.
	var actor := CharacterState.new(game.starting_characters[0])
	actor.store_experience(5, 350.0)
	var reports: Array[Dictionary] = []
	actor.apply_stored_experience(reports, 0.5)
	check(actor.level == 2 and actor.experience == 75.0 and reports.size() == 1, "Scaled XP determines levels and the level-up reports")
	actor.store_experience(6, 0.5)
	actor.apply_stored_experience([], 0.25)
	check(actor.experience == 75.125, "Fractional rest XP is preserved")
	print("Exploration experience tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
