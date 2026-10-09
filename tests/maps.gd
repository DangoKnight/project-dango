extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func run() -> void:
	# Create a second town and map from the saved scenes to exercise generic routing.
	var map_template := load("res://scenes/world/exploration_room.tscn").instantiate() as Map
	map_template.map_id = &"second_map"
	map_template.get_node("SpawnPoint").position = Vector3(3, 0.1, 4)
	map_template.get_node("SpawnPoint").rotation.y = 0.5
	var second_map := PackedScene.new()
	check(second_map.pack(map_template) == OK, "Map scene should be reusable")
	map_template.free()
	var town_template := load("res://scenes/ui/town.tscn").instantiate() as Town
	town_template.town_id = &"second_town"
	town_template.display_name = "Second Town"
	town_template.exploration_map = second_map
	town_template.location_backgrounds["Barracks"] = load("res://textures/wall.png")
	var second_town := PackedScene.new()
	check(second_town.pack(town_template) == OK, "Town scene should be reusable")
	town_template.free()
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var party_member: CharacterState = game.party[0]
	check(game.ui.get_child(0) is Town, "Starting town should be a Town instance")
	game.show_town(second_town)
	var town := game.ui.get_child(0) as Town
	check(town.town_id == &"second_town", "Router should open the selected town")
	check(town.get_node("Panel/Buttons/Title").text == "SECOND TOWN", "Town should apply its own display name")
	town.get_node("Panel/Buttons/Explore").pressed.emit()
	check(game.world.map_id == &"second_map", "Explore should use this town's configured map")
	check(game.player.global_position.is_equal_approx(Vector3(3, 0.1, 4)), "Map should place the player at its own spawn point")
	check(is_equal_approx(game.player.rotation.y, 0.5), "Map should use the spawn orientation")
	check(game.player.movement_enabled, "Entering a map should activate its player")
	game.show_pause()
	check(not game.player.movement_enabled, "Pausing should deactivate map controls")
	game.resume_exploration()
	check(game.player.movement_enabled, "Resuming should activate map controls")
	game.show_town()
	check(game.ui.get_child(0).town_id == &"second_town", "Returning from a map should return to its originating town")
	game.show_options("town")
	game._options_back()
	check(game.ui.get_child(0).town_id == &"second_town", "Options should preserve the selected town")
	game.show_location("Barracks")
	check(game.ui.get_child(0).get_node("Background").texture == load("res://textures/wall.png"), "Locations should use the town's configured background")
	game.show_town()
	check(game.party[0] == party_member, "Changing towns and maps should preserve party state")
	game.new_game()
	check(game.ui.get_child(0).town_id == &"starting_town", "New Game should reset the starting town")
	# A town without an exploration destination cannot navigate to an invalid map.
	var base_town: Town = load("res://scenes/base/town.tscn").instantiate()
	root.add_child(base_town)
	check(base_town.get_node("Panel/Buttons/Explore").disabled, "Unconfigured towns should disable Explore")
	base_town.queue_free()
	await process_frame
	print("Map/Town tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
