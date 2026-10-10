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
	game.new_game()
	game.show_location("Barracks")
	var town = game.ui.get_child(0)
	var barracks = town.module_view
	await create_timer(barracks.card_slide_duration + 0.05).timeout
	barracks.open_party()
	await create_timer(barracks.card_slide_duration * 0.4).timeout
	check(barracks.get_node("Panel").visible and barracks.get_node("Panel").anchor_left < 0.03 and not barracks.get_node("PartyPanel").visible, "Barracks slides out before Manage Party appears")
	await create_timer(barracks.card_slide_duration * 1.7).timeout
	check(barracks.get_node("PartyPanel").visible and not barracks.is_busy(), "Manage Party completes its incoming slide")
	barracks.close_party()
	await create_timer(barracks.card_slide_duration * 0.4).timeout
	check(barracks.get_node("PartyPanel").visible and barracks.get_node("PartyPanel").anchor_left < 0.03 and not barracks.get_node("Panel").visible, "Manage Party slides out before Barracks returns")
	await create_timer(barracks.card_slide_duration * 1.7).timeout
	var member: CharacterState = game.party[0]
	member.current_hp = 1
	member.current_mp = 0
	member.store_experience(123, 350)
	game.sleep_fade_duration = 0.2
	barracks.get_node("Panel/Buttons/Sleep").pressed.emit()
	check(game.battle_fade.visible and game._battle_transition and member.level == 1, "Sleep begins a fade without applying XP immediately")
	await create_timer(0.08).timeout
	check(game.battle_fade.color.a > 0.0 and game.battle_fade.color.a < 1.0 and member.level == 1, "Screen fades toward black before rest")
	var tab := InputEventAction.new()
	tab.action = "party_information"
	tab.pressed = true
	game._input(tab)
	game._on_action_requested("Chemist")
	check(town.module_view == barracks and game.screen == "location", "Sleep blocks shortcuts and navigation")
	await create_timer(0.16).timeout
	check(member.level == 3 and member.experience == 50 and member.stored_experience() == 0, "XP is applied at black using the agreed level curve")
	check(member.current_hp == member.get_stat(&"max_hp") and member.current_mp == member.get_stat(&"max_mp"), "Rest restores post-level-up HP and SP")
	check(not barracks.get_node("Panel/Buttons/Feedback").text.to_lower().contains("experience"), "Barracks feedback does not reveal stored experience")
	check(game.level_up_notice != null and is_equal_approx(game.battle_fade.color.a, 1.0), "Level-up card appears over a fully black screen")
	check(game.level_up_notice.reports.size() == 2, "Each earned level has its own report")
	check(game.level_up_notice.get_node("Panel/Layout/Content/Portrait").texture == member.definition.portrait, "Level-up notification shows the character portrait")
	var details: String = game.level_up_notice.get_node("Panel/Layout/Content/Details").text
	check(details.contains("STAT CHANGES") and details.contains("ABILITIES LEARNED") and not details.contains("Critical"), "Level-up notification shows actual primary stat changes and learned abilities")
	await create_timer(0.3).timeout
	check(is_equal_approx(game.battle_fade.color.a, 1.0) and game._battle_transition, "Black screen persists until the player dismisses reports")
	game.level_up_notice.get_node("Panel/Layout/Continue").pressed.emit()
	check(game.level_up_notice.index == 1 and is_equal_approx(game.battle_fade.color.a, 1.0), "Next level report keeps the screen black")
	var accept := InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.pressed = true
	Input.parse_input_event(accept)
	await process_frame
	accept = accept.duplicate()
	accept.pressed = false
	Input.parse_input_event(accept)
	await create_timer(0.22).timeout
	check(not game.battle_fade.visible and not game._battle_transition and town.module_view == barracks, "Fade returns to the same Barracks and releases input")
	check(barracks.get_node("Panel").visible and not barracks.get_node("PartyPanel").visible, "Sleep finishes at the Barracks menu")
	town.get_node("Panel/Buttons/Chemist").pressed.emit()
	check(barracks.is_inside_tree() and barracks.get_node("Panel").visible, "Replacing a module retains the outgoing card during its slide")
	await create_timer(barracks.card_slide_duration + 0.05).timeout
	check(not is_instance_valid(barracks), "Outgoing module is removed only after the slide")
	game.show_location("Barracks")
	barracks = town.module_view
	await create_timer(barracks.card_slide_duration + 0.05).timeout
	town.get_node("Panel/Buttons/Explore").pressed.emit()
	check(game.screen == "location", "Entering the labyrinth waits for the module card to slide out")
	await create_timer(barracks.card_slide_duration + 0.05).timeout
	check(game.screen == "explore", "Navigation continues after the card exits")
	game.queue_free()
	await process_frame
	print("Rest transition tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
