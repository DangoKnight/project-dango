extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func run() -> void:
	var state := root.get_node("GameState") as RunState
	var conversations := root.get_node("Conversations")
	check(not state.has_started and state.party.is_empty(), "GameState begins without an active run")
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	game.new_game(false)
	check(game.state == state and state.has_started and state.party.size() == 3, "New Game initializes the shared state with three active characters")
	check(state.roster.size() == 3, "The starting roster has no reserve recruits")
	for candidate in state.roster:
		check(candidate.definition.id != &"koumi", "Koumi is not recruited at New Game")
	check(state.roster[0] == state.party[0], "Party and roster share the same character state")
	var member := state.party[0]
	member.store_experience(123, 60.0)
	member.current_hp = 1
	var item := state.gear_inventory.add(load("res://resources/rpg/gear/iron_artifact.tres"))
	state.set_flag(&"met_tinkerer", true)
	check(state.get_flag(&"met_tinkerer", false) == true and state.get_flag(&"missing", 42) == 42, "Story flags support values and fallback defaults")
	state.record_exploration_completion(0.6)
	state.record_exploration_completion(0.2)
	check(is_equal_approx(state.highest_labyrinth_completion, 0.6), "Exploration keeps the highest completion")
	var discoveries := state.discoveries_for("test_map")
	discoveries[&"test_refuge"] = true
	state.labyrinth_entries["test_map"] = &"test_refuge"
	state.completed_conversations[&"test_event"] = true
	check(conversations.completed.has(&"test_event"), "Conversation completion uses GameState's history")
	state.compendium.encounter(load("res://resources/rpg/enemies/rat.tres"))
	var town := game.ui.get_child(0) as Town
	var services := state.services_for(town)
	var service_key := state.active_safe_zone_key
	check(state.services_for(town) == services, "Services reuse the current Safe Zone's state")
	services.talk()
	state.advance_service_step()
	check(services.steps_since_visit == 1, "Walking advances state-owned service timers")
	var recipe := services.recipes[0]
	services.accept_commission(recipe)
	state.record_service_kill(&"rat")
	check(services.commissions[recipe.product_key()].kills[&"rat"] == 1, "Kills advance state-owned commissions")
	game.queue_free()
	await process_frame
	game = scene.instantiate()
	root.add_child(game)
	check(game.state == state and state.party[0] == member and member.current_hp == 1 and member.stored_experience() == 60.0, "Recreating the controller preserves characters and banked XP")
	check(item in state.gear_inventory.get_items() and state.safe_zone_services[service_key] == services, "Inventory and service state survive scene destruction")
	check(state.discoveries_for("test_map").has(&"test_refuge") and state.completed_conversations.has(&"test_event") and state.compendium.entries.has(&"rat"), "Discoveries, compendium and conversation history survive scene destruction")
	check(state.get_flag(&"met_tinkerer") == true, "Story flags survive scene destruction")
	game.show_town()
	check(game.ui.get_child(0) is Town, "A recreated controller can resume the current town from GameState")
	game.new_game(false)
	check(state.party[0] != member and state.party[0].stored_experience() == 0.0, "New Game creates fresh character progress")
	check(item not in state.gear_inventory.get_items() and state.safe_zone_services.is_empty() and state.weapon_inventory.is_empty(), "New Game resets inventory and services")
	check(state.flags.is_empty() and state.labyrinth_discoveries.is_empty() and state.labyrinth_entries.is_empty() and state.completed_conversations.is_empty() and conversations.completed.is_empty() and state.compendium.entries.is_empty(), "New Game clears run-wide knowledge and story state")
	check(state.highest_labyrinth_completion == 0.0 and state.last_safe_zone_scene == game.starting_town, "New Game resets exploration and recovery checkpoint")
	game.queue_free()
	await process_frame
	state.reset()
	check(not state.has_started and state.roster.is_empty() and state.current_town_scene == null, "Reset leaves a clean inactive state")
	print("GameState tests: %d failure(s)" % failures)
	quit(1 if failures else 0)
