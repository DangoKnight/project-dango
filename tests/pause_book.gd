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
	game.explore()
	var map := game.world as LabyrinthMap
	var cells: Array = map.layout.rewards.keys()
	for index in range(2):
		map.player.position = map.layout.world_position(cells[index])
		map._record_walked_cell()
		map.interact()
	check(map.items_picked_up == 2, "Collecting gear tracks the number actually picked up")
	map.interact()
	check(map.items_picked_up == 2, "Empty caches cannot increase the collected count")
	game.compendium.encounter(load("res://resources/rpg/enemies/rat.tres"))
	game.compendium.encounter(load("res://resources/rpg/enemies/ethereal_orb.tres"))
	game.show_pause()
	var book := game.ui.get_child(0) as PauseBook
	check(book != null and not map.player.movement_enabled, "Pause opens the book and stops navigation")
	check(book.command("Town") == null, "Book must not offer Safe Zone teleportation")
	check(book.command("Monsters").text == "Monsters", "Monster menu uses the requested label")
	check(book.left_page.is_ancestor_of(book.command("Map")) and book.right_page.is_ancestor_of(book.command("Options")), "Options occupy both book pages")
	check(book.command("Map").get_theme_stylebox("hover") != book.command("Map").get_theme_stylebox("normal"), "Options have a distinct hover highlight")
	book.command("Map").pressed.emit()
	check(book.transitioning and book.current_page == "index", "Clicking an option starts a transition before replacing contents")
	await create_timer(0.08).timeout
	check(book.left_page.modulate.a > 0 and book.left_page.modulate.a < 1 and book.right_page.modulate.a > 0 and book.right_page.modulate.a < 1, "Both pages fade all their options together")
	book.command("Options").pressed.emit()
	await create_timer(0.35).timeout
	check(book.current_page == "map" and not book.transitioning, "Repeated clicks cannot replace the selected page during its fade")
	check(book.left_page.is_ancestor_of(book.widget("Completion")) and book.right_page.is_ancestor_of(book.widget("MapCanvas")), "Map stats are on the left and the chart is on the right")
	check(book.widget("Items").text == "Picked up items\n2", "Map shows picked up items without revealing a total")
	check(book.widget("Landmarks").text == "Discovered landmarks\n1", "Landmark statistic includes the discovered Safe Zone")
	var chart: Control = book.widget("MapCanvas")
	var landmark: LabyrinthLandmark = chart.visible_landmarks()[0]
	var map_label: Label = chart._landmark_labels[landmark.id]
	check(map_label.text == landmark.display_name and chart.is_ancestor_of(map_label), "Discovered landmark names appear on the map")
	for label in book.left_page.find_children("*", "Label", true, false):
		check(label.text != landmark.display_name, "Landmark names are omitted from the stats page")
	for label in book.right_page.find_children("*", "Label", true, false):
		check(not "Square:" in label.text and not "Arrow:" in label.text, "Map has no explanatory legend")
	var expected := 100.0 * map.walked_cells.size() / map.layout.passages.size()
	check(book.widget("Completion").text == "Map completion\n%.1f%%" % expected, "Completion measures walked cells in the current layout")
	await book.open_page("monsters")
	check(book.widget("Monsters").item_count == 2 and book.left_page.is_ancestor_of(book.widget("Monsters")), "Monsters list fills the left page")
	check(book.right_page.is_ancestor_of(book.widget("MonsterDetails")) and book.widget("MonsterDetails").text.contains("Pierce: ???"), "Monster notes fill the right page and preserve undiscovered information")
	book.widget("Monsters").item_selected.emit(1)
	check(book.widget("MonsterDetails").text.contains("Ethereal Orb"), "Selecting a monster changes the right page")
	await book.open_page("options")
	var original_volume := AudioServer.get_bus_volume_linear(0)
	book.widget("Volume").value = 0.37
	check(is_equal_approx(AudioServer.get_bus_volume_linear(0), 0.37), "Book volume control changes audio settings")
	AudioServer.set_bus_volume_linear(0, original_volume)
	check(book.right_page.is_ancestor_of(book.widget("Fullscreen")), "Display controls occupy the right page")
	for page in ["index", "map", "monsters", "options"]:
		await book.open_page(page)
		for dimensions in [Vector2i(800, 450), Vector2i(900, 1200), Vector2i(2560, 1080)]:
			root.size = dimensions
			await process_frame
			await process_frame
			for side in [book.left_page, book.right_page]:
				var bounds: Rect2 = side.get_global_rect()
				check(bounds.position.x >= 0 and bounds.position.y >= 0 and bounds.end.x <= book.size.x and bounds.end.y <= book.size.y, "Book pages fit the resized window")
				for child in side.get_children():
					if child is Control and child.visible:
						check(child.get_global_rect().end.y <= bounds.end.y + 1.0 and child.get_global_rect().end.x <= bounds.end.x + 1.0, "Page contents stay within their page: %s" % page)
	root.size = Vector2i(1280, 720)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	game._unhandled_input(escape)
	await create_timer(0.4).timeout
	check(game.screen == "pause" and book.current_page == "index", "Escape from a chapter returns to book contents")
	book.command("Resume").pressed.emit()
	await create_timer(0.25).timeout
	check(game.screen == "explore" and game.world == map and map.player.movement_enabled, "Resume fades the contents and restores the existing labyrinth")
	game.show_town()
	game.explore()
	game.show_pause()
	book = game.ui.get_child(0) as PauseBook
	await book.open_page("map")
	check(book.widget("Items").text == "Picked up items\n0", "Item count resets on the next visit")
	check(book.widget("Completion").text == "Map completion\n%.1f%%" % (100.0 * game.world.walked_cells.size() / game.world.layout.passages.size()), "Map completion resets on every entry")
	game.queue_free()
	await process_frame
	print("Pause book tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
