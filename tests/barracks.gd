extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func drag_slot(source: Control, target: Control) -> void:
	var start := root.get_final_transform() * source.get_global_transform_with_canvas() * (source.size * 0.5)
	var destination := root.get_final_transform() * target.get_global_transform_with_canvas() * (target.size * 0.5)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	press.global_position = start
	Input.parse_input_event(press)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = start + Vector2(30, 0)
	motion.global_position = motion.position
	motion.relative = Vector2(30, 0)
	Input.parse_input_event(motion)
	await process_frame
	check(root.gui_is_dragging(), "Mouse motion starts a native Godot drag")
	motion = motion.duplicate()
	motion.relative = destination - motion.position
	motion.position = destination
	motion.global_position = destination
	Input.parse_input_event(motion)
	await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = destination
	release.global_position = destination
	Input.parse_input_event(release)
	await process_frame


func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.starting_party_size = 4 # Exercise a full formation and occupied-slot swaps.
	game.starting_characters.append(load("res://resources/rpg/characters/koumi.tres")) # Recruited only for this fixture.
	game.new_game(false)
	# These checks exercise module UI after its introductory dialogue.
	for introduction in game.ui.get_child(0).module_conversations.values():
		game.state.completed_conversations[introduction.id] = true
	var town = game.ui.get_child(0)
	check(town.get_node("Panel/Buttons/Explore").disabled, "New games start with labyrinth navigation disabled")
	town._on_button_pressed("Explore")
	check(game.screen == "town" and game.world == null, "Disabled exploration cannot be triggered programmatically")
	game.state.set_flag(&"labyrinth_unlocked", true)
	check(not town.get_node("Panel/Buttons/Explore").disabled, "Progression flag enables exploration")
	check(town.get_node("Panel").anchor_left >= 1.0, "Safe Zone card begins beyond the right edge")
	await create_timer(town.card_slide_duration * 0.4).timeout
	check(town.get_node("Panel").anchor_left > 0.69, "Safe Zone card moves in from the right")
	root.size = Vector2i(1600, 900)
	await create_timer(town.card_slide_duration + 0.05).timeout
	check(is_equal_approx(town.get_node("Panel").anchor_left, 0.59), "Safe Zone finishes at its anchors after resize")
	for location in ["Tinkerer", "Barterer", "Barracks"]:
		town.get_node("Panel/Buttons/" + location).pressed.emit()
		var view = game.ui.get_child(0).module_view
		check(view.get_node("Panel").anchor_right <= 0.0, "Module begins beyond the left edge: " + location)
		await create_timer(view.card_slide_duration + 0.05).timeout
		check(is_equal_approx(view.get_node("Panel").anchor_left, 0.03), "Module slides into the left side: " + location)
		check(view.get_node("Panel").get_global_rect().end.x <= view.size.x * 0.5 + 1.0, "Module stays within the left half of the scene: " + location)
		var overlap: float = view.get_node("Panel").get_global_rect().end.x - town.get_node("ModuleNPC").get_global_rect().position.x
		check(absf(overlap) <= 1.0, "Module meets the NPC area at the center: " + location)
		for window_size in [Vector2i(800, 450), Vector2i(900, 1200), Vector2i(1600, 900)]:
			root.size = window_size
			for frame in range(4):
				await process_frame
			check(view.get_node("Panel").get_global_rect().end.x <= view.size.x * 0.5 + 1.0, "Resized module stays within the left half: %s at %s" % [location, window_size])
		check(not town.get_node("Panel").visible, "Hub actions hide while a module is open")
		check(town.get_node("ModuleNPC").visible and town.get_node("ModuleNPC/Image").texture == town.location_npcs[location], "Each module shows its corresponding NPC")
		check(is_equal_approx(town.get_node("ModuleNPC").anchor_left, 0.5), "NPC occupies the right half")
		check(is_equal_approx(town.get_node("ModuleNPC/Image").get_global_rect().end.y, town.get_global_rect().end.y), "NPC portrait is anchored to the bottom")
		check(town.get_node("Panel/Buttons/Explore").disabled, "Hidden hub actions cannot receive input")
		if location != "Barracks":
			view.get_node("Panel/Buttons/ReturnToHub").pressed.emit()
			await create_timer(town.card_slide_duration + 0.05).timeout
			check(town.module_view == null and town.get_node("Panel").visible and not town.get_node("ModuleNPC").visible, "Return to Hub restores hub actions and dismisses the NPC")
			check(not town.get_node("Panel/Buttons/Barracks").disabled, "Returning enables hub actions")
	var barracks = game.ui.get_child(0).module_view
	check(game.ui.get_child(0) == town, "Opening and switching modules retains the Safe Zone navigation instance")
	check(not town.get_node("Panel").visible, "Hub actions stay hidden during module use")
	check(not barracks.get_node("PartyPanel").visible, "Barracks starts with the party card closed")
	check(barracks.get_node("Panel/Buttons/Save").disabled, "Save is visible but disabled")
	check(barracks.get_node("Panel/Buttons/ManageParty") is Button, "Barracks exposes a Manage Party button")
	barracks.get_node("Panel/Buttons/ManageParty").pressed.emit()
	await create_timer(barracks.card_slide_duration * 2 + 0.05).timeout
	check(barracks.get_node("PartyPanel").visible and not barracks.get_node("Panel").visible and not town.get_node("Panel").visible, "Manage Party replaces Barracks while hub actions stay hidden")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	game._unhandled_input(escape)
	await create_timer(barracks.card_slide_duration * 2 + 0.05).timeout
	check(not barracks.get_node("PartyPanel").visible and game.screen == "location" and town.module_view == barracks, "Escape closes the party card before the module")
	barracks.open_party()
	await create_timer(barracks.card_slide_duration * 2 + 0.05).timeout
	var original: CharacterState = game.state.party[0]
	original.current_hp = 0
	original.current_mp = 0
	var permanent: Dictionary = original._permanent_stats.duplicate()
	var weapon := original.equipped_weapon
	barracks.close_party()
	await create_timer(barracks.card_slide_duration * 2 + 0.05).timeout
	barracks.get_node("Panel/Buttons/Sleep").pressed.emit()
	await create_timer(game.sleep_fade_duration * 2 + 0.05).timeout
	barracks.open_party()
	await create_timer(barracks.card_slide_duration * 2 + 0.05).timeout
	check(original.current_hp == original.get_stat(&"max_hp") and original.current_mp == original.get_stat(&"max_mp"), "Sleep revives and restores HP/SP")
	check(original._permanent_stats == permanent and original.equipped_weapon == weapon, "Sleep preserves permanent stats and equipment")
	check(barracks.party_slots.get_child_count() == 4, "Party always displays four slots")
	check(barracks.portrait.texture == original.definition.portrait, "Selected character uses their V03 portrait")
	check(barracks.stats.text.contains("Mental Acuity") and not barracks.stats.text.to_lower().contains("growth"), "Selected stats include current values without hidden growth")
	var second: CharacterState = game.state.party[1]
	barracks.party_slots.get_child(1).pressed.emit()
	check(barracks.selected_member == second and barracks.portrait.texture == second.definition.portrait, "Clicking a party name changes the portrait and stats")
	var data := {"source": barracks, "character": original}
	var reserve_target = barracks.reserve_slots.get_child(0)
	check(reserve_target._can_drop_data(Vector2.ZERO, data), "Empty reserve area accepts an active member")
	reserve_target._drop_data(Vector2.ZERO, data)
	check(game.state.party.size() == 3 and original not in game.state.party and original in game.state.roster, "Dragging to reserve removes only active membership")
	check(barracks.reserve_slots.get_child(0).member == original and barracks.party_slots.get_child(3).member == null, "Reserve names and empty party slots refresh after a drag")
	original.current_hp = 1
	original.current_mp = 0
	barracks.apply_rest()
	check(original.current_hp == original.get_stat(&"max_hp") and original.current_mp == original.get_stat(&"max_mp"), "Sleep also restores reserves")
	barracks.reserve_slots.get_child(0).pressed.emit()
	check(barracks.selected_member == original, "Reserve characters can be selected for inspection")
	var empty_slot = barracks.party_slots.get_child(3)
	check(empty_slot._can_drop_data(Vector2.ZERO, data), "An empty party slot accepts a reserve")
	empty_slot._drop_data(Vector2.ZERO, data)
	check(game.state.party[-1] == original and game.state.party.size() == 4, "Dragging a reserve into an empty slot preserves their character state")
	barracks.party_slots.get_child(0)._drop_data(Vector2.ZERO, data)
	check(game.state.party[0] == original, "Dragging between occupied party slots swaps party order")
	check(not barracks.can_drop_character(data, true, 0), "Dropping onto the same slot is rejected")
	check(not barracks.can_drop_character({"source": town, "character": original}, false, 0), "Foreign drag payloads are rejected")
	check(not barracks.can_drop_character({"source": barracks, "character": CharacterState.new(original.definition)}, false, 0), "Unrecruited characters cannot be dragged into the party")
	while game.state.party.size() > 1:
		barracks.drop_character({"source": barracks, "character": game.state.party[-1]}, false, 0)
	check(not barracks.can_drop_character(data, false, 0), "Cannot drag the final active member into reserve")
	check(not barracks.drop_character(data, false, 0), "Drop validation enforces the minimum party size")

	for window_size in [Vector2i(800, 450), Vector2i(1920, 1080), Vector2i(900, 1200)]:
		root.size = window_size
		for frame in range(4):
			await process_frame
		check(barracks.get_global_rect().grow(1).encloses(barracks.get_node("PartyPanel").get_global_rect()), "Party card fits resized viewport")
		check(barracks.get_node("PartyPanel").get_global_rect().end.x <= barracks.size.x * 0.5 + 1.0, "Party management stays within the left half after resizing")
		check(not barracks.get_node("Panel").visible, "Barracks remains hidden during party management")
		check(not town.get_node("Panel").get_global_rect().intersects(barracks.get_node("PartyPanel").get_global_rect()), "Party card leaves space for the NPC")
		for path in ["Content", "Feedback", "CloseParty"]:
			check(barracks.get_node("PartyPanel").get_global_rect().grow(1).encloses(barracks.get_node("PartyPanel/Buttons/" + path).get_global_rect()), "Barracks content fits: " + path)
		var character_panel: Control = barracks.get_node("PartyPanel/Buttons/Content/Character")
		var party_column: Control = barracks.get_node("PartyPanel/Buttons/Content/Party")
		var reserve_column: Control = barracks.get_node("PartyPanel/Buttons/Content/Reserve")
		check(character_panel.get_global_rect().end.x <= party_column.global_position.x and party_column.get_global_rect().end.x <= reserve_column.global_position.x, "Portrait and stats sit left of the party and reserve columns")
	# Navigation preserves identity, selected membership, and planning order.
	var saved_party: Array[CharacterState] = game.state.party.duplicate()
	check(not barracks.has_node("Panel/Buttons/Town"), "Barracks has no Back to Safe Zone button")
	barracks.close_party()
	await create_timer(barracks.card_slide_duration * 2 + 0.05).timeout
	barracks.get_node("Panel/Buttons/ReturnToHub").pressed.emit()
	check(town.module_view == null and barracks.is_inside_tree(), "Return to Hub closes Barracks with a slide")
	await create_timer(barracks.card_slide_duration + 0.05).timeout
	check(not is_instance_valid(barracks) and game.screen == "town", "Returning leaves Safe Zone navigation open")
	game.show_location("Barracks")
	check(game.ui.get_child(0).module_view.party == saved_party, "Reentering Barracks preserves party membership")
	game.show_town()
	game.explore()
	game.start_combat(false)
	var battle := game.ui.get_child(0) as CombatScreen
	check(battle.session.party == saved_party and battle.session.active_character() == saved_party[0], "Battle uses the selected active party and order")
	game.new_game(false)
	# These checks exercise module UI after its introductory dialogue.
	for introduction in game.ui.get_child(0).module_conversations.values():
		game.state.completed_conversations[introduction.id] = true
	check(game.state.party.size() == 4 and game.state.roster.size() == 4 and game.state.roster[0] != original, "New Game resets roster and formation")
	# Future recruits stay available even when the initial party reaches capacity.
	var extra := game.starting_characters[0].duplicate(true) as CharacterDefinition
	extra.id = &"reserve_fixture"
	game.starting_characters.append(extra)
	game.new_game(false)
	# These checks exercise module UI after its introductory dialogue.
	for introduction in game.ui.get_child(0).module_conversations.values():
		game.state.completed_conversations[introduction.id] = true
	game.show_location("Barracks")
	barracks = game.ui.get_child(0).module_view
	barracks.open_party()
	await create_timer(barracks.card_slide_duration * 2 + 0.05).timeout
	check(game.state.party.size() == 4 and game.state.roster.size() == 5 and barracks.reserve_slots.get_child_count() == 1, "Additional recruits start in reserve")
	var recruit: CharacterState = game.state.roster[4]
	var outgoing: CharacterState = game.state.party[1]
	var swap_data := {"source": barracks, "character": recruit}
	check(barracks.can_drop_character(swap_data, true, 1), "A reserve can replace a member of a full party")
	barracks.party_slots.get_child(1)._drop_data(Vector2.ZERO, swap_data)
	check(game.state.party.size() == 4 and game.state.party[1] == recruit and outgoing not in game.state.party and outgoing in game.state.roster, "Reserve-to-occupied-slot drop sends the previous member to reserve")
	barracks.close_party()
	await create_timer(barracks.card_slide_duration * 2 + 0.05).timeout
	check(not barracks.get_node("PartyPanel").visible and barracks.get_node("Panel").visible, "Returning restores Barracks and hides Manage Party")
	barracks.open_party()
	await create_timer(barracks.card_slide_duration * 2 + 0.05).timeout
	check(is_equal_approx(barracks.get_node("PartyPanel").anchor_left, 0.03), "Repeated opening restores party card anchors")
	await drag_slot(barracks.reserve_slots.get_child(0), barracks.party_slots.get_child(2))
	check(game.state.party[2] == outgoing, "Native mouse drag exchanges a reserve with the targeted party member")

	game.queue_free()
	await process_frame
	print("Barracks tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
