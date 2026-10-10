extends SceneTree

var game: Node
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func click(title: String) -> void:
	var buttons: Array[Node] = game.ui.find_children("*", "Button", true, false)
	for button in buttons:
		if button.text == title:
			button.pressed.emit()
			return
	check(false, "Missing button: " + title)


func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.screen == "main", "Game should start at main menu")
	click("Options")
	check(game.screen == "options", "Options should open")
	click("Back")
	click("New Game")
	check(game.screen == "town", "New Game should open town")
	var town_buttons: Array[Node] = game.ui.get_child(0).find_children("*", "Button", true, false)
	check(town_buttons.size() == 4, "Town shows only the three services and Explore")
	for obsolete in ["Characters", "Options", "MainMenu"]:
		check(not game.ui.get_child(0).has_node("Panel/Buttons/" + obsolete), "Shortcut-only option is absent from town: " + obsolete)
	check(game.party.size() == 4, "New Game should initialize the starting party")
	var expected_names := ["Usami", "Takane", "Kurako", "Koumi"]
	var expected_images := ["Usami-chan", "Takane-chan", "Kurako-chan", "Koumi-chan"]
	for index in range(4):
		var definition: CharacterDefinition = game.party[index].definition
		check(definition.starting_class.id == &"explorer", "All starting characters should be Explorers")
		check(definition.display_name == expected_names[index], "Starting party should contain " + expected_names[index])
		check(definition.portrait != null and definition.portrait.resource_path == "res://textures/Characters/Alpha/" + expected_images[index] + ".png", "Each character should use their matching portrait")
		check(definition.combat_texture == definition.portrait, "Character combat texture should match its V03 portrait")
	var original_character: CharacterState = game.party[0]
	var tab := InputEventAction.new()
	tab.action = "party_information"
	tab.pressed = true
	game._input(tab)
	check(game.screen == "characters", "Characters should open the party screen")
	var roster: Control = game.ui.get_child(0)
	check(roster.get_node("Panel/Buttons/Content/Members").item_count == 4, "Party screen should list characters")
	check("Usami" in roster.get_node("Panel/Buttons/Content/Details").text, "Party screen should show selected character")
	check("Training Sword" in roster.get_node("Panel/Buttons/Content/Details").text, "Party screen should show equipped weapons")
	check("Allowed types: Sword, Axe, Spear" in roster.get_node("Panel/Buttons/Content/Details").text, "Party screen should show combined weapon restrictions")
	roster.get_node("Panel/Buttons/Content/Members").item_selected.emit(1)
	check("Takane" in roster.get_node("Panel/Buttons/Content/Details").text, "Selecting a character should update details")
	click("Back to Safe Zone")
	check(game.party[0] == original_character, "Returning to town should preserve character state")
	for location in ["Barracks", "Tinkerer", "Chemist"]:
		click(location)
		check(game.screen == "location", location + " should open")
		var module = game.ui.get_child(0).module_view
		check(not module.has_node("Panel/Buttons/Town"), location + " has no redundant return button")
		click(location)
		await create_timer(module.card_slide_duration + 0.05).timeout
		check(game.screen == "town", location + " toggles closed from town navigation")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	game._unhandled_input(escape)
	check(game.screen == "pause" and game.pause_return == "town", "Escape opens the town menu")
	click("Options")
	click("Back")
	check(game.screen == "pause" and game.pause_return == "town", "Town options return to the town menu")
	click("Return")
	check(game.screen == "town", "Town menu returns to town")
	click("Enter the Labyrinth")
	check(game.screen == "explore", "Explore should open room")
	check(game.ui.get_child_count() == 1, "Exploration should replace the town screen")
	check(game.world is Map, "Walkable rooms should be Map instances")
	check(game.world.has_node("Ground") and game.world.has_node("WorldEnvironment"), "Map should preserve the exploration room geometry and lighting")
	var start: Vector3 = game.player.position
	if DisplayServer.get_name() != "headless":
		await process_frame
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Exploration should capture the mouse")
		var initial_yaw: float = game.player.rotation.y
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(640, 360)
		motion.relative = Vector2(40, 20)
		Input.parse_input_event(motion)
		await process_frame
		check(game.player.rotation.y < initial_yaw, "Mouse motion should pass through the HUD and rotate the player")
		check(game.player.camera.rotation.x < 0.0, "Mouse motion should tilt the camera")
		game.player.rotation.y = initial_yaw
		game.player.camera.rotation.x = 0.0
	else:
		print("Skipping OS mouse capture and mouse-look checks: headless display")
	Input.action_press("move_forward")
	for frame in range(360):
		await physics_frame
	Input.action_release("move_forward")
	check(game.player.position.z < start.z - 5.0, "Player should move forward")
	check(game.player.position.z > -19.3, "North wall should block movement")
	check(absf(game.player.position.y) < 0.1, "Ground should support player")
	game.show_pause()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Pause should release the mouse")
	var paused_at: Vector3 = game.player.position
	Input.action_press("move_forward")
	for frame in range(10):
		await physics_frame
	Input.action_release("move_forward")
	check(game.player.position.is_equal_approx(paused_at), "Player should stay still when paused")
	click("Options")
	click("Back")
	check(game.screen == "pause", "Exploration options should return to pause")
	click("Resume")
	check(game.screen == "explore", "Resume should restore exploration")
	if DisplayServer.get_name() != "headless":
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Resume should recapture the mouse")
	game.show_pause()
	click("Return to Safe Zone")
	check(game.world == null, "Returning to town should remove room")
	click("Enter the Labyrinth")
	check(game.player.position.is_equal_approx(start), "Reentering room should reset player")
	game.show_pause()
	click("Main Menu")
	check(game.screen == "main" and game.world == null, "Main menu should clear room")
	click("New Game")
	check(game.party[0] != original_character and game.party[0].level == 1, "New Game should create fresh character states")
	await process_frame
	print("Smoke test complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
