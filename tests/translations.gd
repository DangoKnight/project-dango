extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func run() -> void:
	var previous_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var all_keys := {}
	for category in ["ui", "content", "dialogue"]:
		var file := FileAccess.open("res://localization/%s.csv" % category, FileAccess.READ)
		check(file != null, "Translation source table exists: " + category)
		var columns := file.get_csv_line()
		check(columns == PackedStringArray(["keys", "en"]), "Only English is configured")
		var translation := load("res://localization/%s.en.translation" % category) as Translation
		check(translation != null and translation.locale == "en", "Godot imports the table")
		while not file.eof_reached():
			var row := file.get_csv_line()
			if row.size() == 1 and row[0].is_empty():
				continue
			check(row.size() == 2 and not row[0].strip_edges().is_empty(), "Valid translation row")
			check(not all_keys.has(row[0]), "Translation keys have a single owning table")
			all_keys[row[0]] = true
			check(String(translation.get_message(row[0])) == row[1], "CSV messages survive Godot import, including multiline text")
	check(L10n.text("Unknown future text") == "Unknown future text", "Missing translations fall back to source text")
	# A temporary test locale proves the English tables are wired to presentation.
	var test_locale := Translation.new()
	test_locale.locale = "fr"
	for pair in [["Station 45-B", "Gare 45-B"], ["Back to %s", "Retour à %s"], ["Attack", "Attaquer"], ["Special", "Spécial"], ["Observe", "Observer"], ["Round %d", "Tour %d"], ["Usami", "Usami test"], ["Your offer", "Votre offre"], ["Pierce", "Perforation"], ["Normal", "Neutre"], ["Strength", "Force"], ["Test conversation", "Conversation traduite"]]:
		test_locale.add_message(pair[0], pair[1])
	TranslationServer.add_translation(test_locale)
	TranslationServer.set_locale("fr")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game(false)
	# These checks exercise module UI after its introductory dialogue.
	for introduction in game.ui.get_child(0).module_conversations.values():
		game.state.completed_conversations[introduction.id] = true
	check(game.ui.get_child(0).get_node("Panel/Buttons/Title").text == "GARE 45-B", "Town translates its name before capitalization")
	check(game.state.roster[0].definition.display_name == "Usami", "Localization never mutates resource names")
	check(RPGStats.display_name(&"strength") == "Force", "Stat names are translated")
	game.show_pause("town")
	check(game.ui.get_child(0).left_page.get_child(1).text == "Gare 45-B", "Town name is translated in the book")
	game.show_characters()
	check(game.ui.get_child(0).get_node("Panel/Buttons/Town").text == "Retour à Gare 45-B", "Return label translates its template and town name")
	game.show_town()
	game.show_location("Barterer")
	check(game.ui.get_child(0).module_view.offered_list != null, "Translated offer labels do not change service routing")
	game.explore()
	game.start_combat(false)
	var combat := game.ui.get_child(0) as CombatScreen
	check(combat.round_counter.text == "Tour 1", "Battle round is translated before formatting")
	check(combat.actions.get_child(0).text == "Attaquer", "Battle commands translate")
	combat._open_special()
	combat._close_special()
	combat._toggle_observe()
	check(combat.session.active_character().observing, "Translated command names still support Observe")
	var enemy: CharacterState = combat.session.enemies[0]
	var pierce: DamageType = load("res://resources/rpg/damage_types/pierce.tres")
	combat.session.compendium.learn_resistance(enemy, pierce)
	check(combat.session.compendium.describe(enemy.definition.id).contains("Perforation:"), "Compendium translates damage types")
	check(combat.session.compendium.entries[enemy.definition.id].resistances[pierce.id].name == "Pierce", "Discovered knowledge stores source text")
	var conversation := load("res://scenes/ui/conversation.tscn").instantiate() as ConversationOverlay
	root.add_child(conversation)
	var line := ConversationLine.new()
	line.text = "Test conversation"
	var event := ConversationEvent.new()
	event.lines = [line]
	conversation.configure(event)
	check(conversation.body.text == "Conversation traduite", "Dialogue translates before typing")
	conversation.queue_free()
	game.queue_free()
	await process_frame
	TranslationServer.remove_translation(test_locale)
	TranslationServer.set_locale(previous_locale)
	print("Translation tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
