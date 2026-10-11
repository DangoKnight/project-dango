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
	game.new_game(false)
	game.show_pause("town")
	check(not game.ui.get_child(0).command("Map").visible, "Town menu does not offer a nonexistent current map")
	game.show_town()
	game.explore()
	var map := game.world as LabyrinthMap
	var entry := map.layout.landmark(map.definition.spawn_landmark)
	var initial_discovery: Dictionary[Vector2i, bool] = {entry.coordinate: true}
	for landmark in map.definition.landmarks:
		if landmark.kind == &"safe_zone" and map.discovered_landmarks.has(landmark.id):
			initial_discovery[map.layout.passages[landmark.coordinate][0]] = true
	check(map.walked_cells == initial_discovery, "Initial discovery contains the entry and known Safe Zone approaches")
	var neighbor: Vector2i = map.layout.passages[entry.coordinate][0]
	Input.action_press("move_forward")
	for frame in range(90):
		await physics_frame
		if map.player.position.distance_to(map.layout.world_position(neighbor)) < map.definition.cell_size * 0.45:
			break
	Input.action_release("move_forward")
	check(map.walked_cells == initial_discovery and map.walked_cells.has(neighbor), "Walking into the already revealed approach does not reveal extra cells")
	game.show_pause()
	var pause: Control = game.ui.get_child(0)
	check(pause.command("Map").visible and not pause.command("Map").disabled, "Pause menu offers Map in the labyrinth")
	pause.command("Map").pressed.emit()
	await create_timer(0.45).timeout
	check(game.screen == "pause" and game.ui.get_child(0).current_page == "map" and not map.player.movement_enabled, "Map opens with movement paused")
	var view: Control = game.ui.get_child(0)
	var canvas: Control = view.widget("MapCanvas")
	check(canvas.source == map, "Map renders the active labyrinth")
	check(canvas.visible_safe_zones().size() == 1 and canvas.visible_safe_zones()[0] == entry, "Only discovered Safe Zones are shown")
	var expected_walls := 0
	for cell in map.walked_cells:
		expected_walls += 4 - map.layout.passages[cell].size()
	check(canvas.visible_walls().size() == expected_walls, "Only walls belonging to walked cells are shown")
	var walked_before := map.walked_cells.duplicate()
	var paused_position := map.player.position
	Input.action_press("move_forward")
	for frame in range(8):
		await physics_frame
	Input.action_release("move_forward")
	check(map.walked_cells == walked_before and map.player.position.is_equal_approx(paused_position), "Map screen cannot move the player or reveal cells")
	for window_size in [Vector2i(800, 450), Vector2i(900, 1200), Vector2i(2560, 1080)]:
		root.size = window_size
		await process_frame
		await process_frame
		check(canvas.size.x > 0 and canvas.size.y > 0, "Map canvas fits every supported window shape")
		var back: Button = view.widget("Back")
		check(back.get_global_rect().end.y <= view.size.y and back.get_global_rect().end.x <= view.size.x, "Map return control stays within the screen")
	root.size = Vector2i(1280, 720)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	game._unhandled_input(escape)
	await create_timer(0.45).timeout
	check(game.screen == "pause" and game.world == map, "Escape returns to the same pause context")
	game.ui.get_child(0).command("Map").pressed.emit()
	await create_timer(0.45).timeout
	game.ui.get_child(0).widget("Back").pressed.emit()
	await create_timer(0.45).timeout
	check(game.screen == "pause", "Return button closes the map")
	game.ui.get_child(0).command("Resume").pressed.emit()
	await create_timer(0.25).timeout
	check(game.screen == "explore" and map.player.movement_enabled and map.walked_cells == walked_before, "Resume preserves explored cells and restores movement")
	# Enter a second Safe Zone cell without revealing the cells between them.
	var distant := map.layout.landmark(&"distant_refuge")
	map.player.position = map.layout.world_position(distant.coordinate)
	game.show_pause()
	var discovered_after_travel := walked_before.duplicate()
	discovered_after_travel[distant.coordinate] = true
	discovered_after_travel[map.layout.passages[distant.coordinate][0]] = true
	check(map.walked_cells == discovered_after_travel, "Discovering a Safe Zone reveals only its endpoint and approach")
	game.show_labyrinth_map()
	await create_timer(0.45).timeout
	check(game.ui.get_child(0).widget("MapCanvas").visible_safe_zones().size() == 2, "Walking into a Safe Zone reveals its endpoint marker")
	check(game.ui.get_child(0).widget("MapCanvas").visible_landmarks().size() == 2, "Undiscovered ordinary landmarks remain hidden")
	game.resume_exploration()
	var junction := map.layout.landmark(&"service_hub")
	map.player.position = map.layout.world_position(junction.coordinate)
	game.show_pause()
	game.show_labyrinth_map()
	await create_timer(0.45).timeout
	check(game.ui.get_child(0).widget("MapCanvas").visible_landmarks().size() == 3, "Walking into an ordinary landmark reveals its marker")
	game.show_town()
	game.explore()
	var regenerated_discovery: Dictionary[Vector2i, bool] = {entry.coordinate: true}
	for landmark in game.world.definition.landmarks:
		if landmark.kind == &"safe_zone" and game.world.discovered_landmarks.has(landmark.id):
			regenerated_discovery[game.world.layout.passages[landmark.coordinate][0]] = true
	check(game.world != map and game.world.walked_cells == regenerated_discovery, "Regeneration reveals only the entry and remembered Safe Zone approaches")
	check(not game.world.walked_cells.has(distant.coordinate) and not game.world.walked_cells.has(junction.coordinate), "Previously visited destinations do not reveal floors in the new layout")
	game.show_pause()
	game.show_labyrinth_map()
	await create_timer(0.45).timeout
	var remembered: Control = game.ui.get_child(0).widget("MapCanvas")
	check(remembered.visible_safe_zones().size() == 2 and remembered.visible_landmarks().size() == 3, "Known Safe Zones and ordinary landmarks remain visible after regeneration")
	var expected_new_walls := 0
	for cell in game.world.walked_cells:
		expected_new_walls += 4 - game.world.layout.passages[cell].size()
	check(remembered.visible_walls().size() == expected_new_walls, "Remembered markers do not reveal surrounding walls")
	game.new_game(false)
	game.explore()
	game.show_pause()
	game.show_labyrinth_map()
	await create_timer(0.45).timeout
	check(game.ui.get_child(0).widget("MapCanvas").visible_landmarks().size() == 1, "New Game resets landmark discovery, revealing only the new entry")
	game.queue_free()
	await process_frame
	print("Labyrinth chart tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
