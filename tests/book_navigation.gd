extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func tab(game: Node) -> void:
	var event := InputEventAction.new()
	event.action = "party_information"
	event.pressed = true
	game._input(event)

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game(false)
	tab(game)
	check(game.screen == "town", "Town Tab does not open character details")
	game.show_pause("town")
	var book := game.ui.get_child(0) as PauseBook
	check(book.command("Map").visible and book.command("Map").disabled, "New Game offers maps but has no charted labyrinth yet")
	await book.open_page("characters")
	check(book.widget("Characters").get_child_count() == 3 and book.widget("CharacterDetails").text.contains("Usami"), "Book lists recruited characters and their details")
	book.widget("Characters").get_child(1).pressed.emit()
	check(book.widget("CharacterDetails").text.contains("Takane"), "Selecting a character updates the facing page")
	check(book.widget("CharacterPortrait").texture == game.state.roster[1].definition.portrait and book.widget("CharacterPortrait").get_parent() == book.left_page, "Character tabs update the large left-page portrait")
	game.show_town()
	game.explore()
	var active: LabyrinthMap = game.world
	var layout := active.layout
	active.items_picked_up = 2
	tab(game)
	book = game.ui.get_child(0) as PauseBook
	await create_timer(book.page_fade_duration * 2 + 0.1).timeout
	check(book.current_page == "map" and not active.player.movement_enabled, "Exploration Tab opens the active map and pauses movement")
	check(book.widget("MapCanvas").source.layout == layout and book.widget("Items").text.ends_with("2"), "Shortcut shows the current layout and statistics")
	tab(game)
	check(game.screen == "explore" and game.world == active and active.player.movement_enabled, "Tab closes the map without regenerating the labyrinth")
	var explored := active.walked_cells.duplicate()
	game.show_town()
	check(game.world == null and game.state.labyrinth_maps.size() == 1, "Returning to town records a chart without retaining the world")
	await process_frame
	var original_chart: LabyrinthMapSnapshot = game.state.labyrinth_maps.values()[0]
	var second_chart := LabyrinthMapSnapshot.new()
	second_chart.map_path = "second_labyrinth"
	second_chart.definition = original_chart.definition.duplicate()
	second_chart.definition.display_name = "Second Labyrinth"
	second_chart.layout = original_chart.layout
	second_chart.walked_cells = original_chart.walked_cells.duplicate()
	second_chart.discovered_landmarks = original_chart.discovered_landmarks.duplicate()
	second_chart.items_picked_up = 7
	game.state.labyrinth_maps[second_chart.map_path] = second_chart
	game.show_pause("town")
	book = game.ui.get_child(0) as PauseBook
	check(book.command("Map").visible and not book.command("Map").disabled, "Safe Zone book offers visited labyrinth maps")
	await book.open_page("map")
	check(book.widget("MapCanvas").source.walked_cells == explored and book.widget("MapCanvas").source.layout == layout, "Safe Zone chart preserves walked floor, walls, and the last generated layout")
	check(book.widget("Items").text.ends_with("2"), "Safe Zone chart preserves the visit's collected item count")
	check(book.widget("Maps").item_count == 2 and book.map == original_chart, "Safe Zone prefers its connected labyrinth and lists all recorded charts")
	book.widget("Maps").item_selected.emit(1)
	await create_timer(book.page_fade_duration * 2 + 0.1).timeout
	check(book.map == second_chart and book.widget("Items").text.ends_with("7"), "Selecting another recorded labyrinth updates its map and statistics")
	game.show_town()
	game.explore()
	check(game.world.layout != layout and game.world.items_picked_up == 0, "Re-entering still regenerates the labyrinth and resets visit statistics")
	tab(game)
	book = game.ui.get_child(0) as PauseBook
	await create_timer(book.page_fade_duration * 2 + 0.1).timeout
	check(book.widget("MapCanvas").source.layout == game.world.layout, "Tab prioritizes the new active layout over the previous chart")
	game.new_game(false)
	check(game.state.labyrinth_maps.is_empty(), "New Game discards charts including the outgoing active layout")
	game.queue_free()
	await process_frame
	print("Book navigation tests: %d failure(s)" % failures)
	quit(1 if failures else 0)
