extends SceneTree

var failures := 0
var director: Node


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func event_with_text(id: StringName, once := false) -> ConversationEvent:
	var event := ConversationEvent.new()
	event.id = id
	event.once_per_game = once
	event.characters_per_second = 0.0
	var line := ConversationLine.new()
	line.text = "Test dialogue"
	event.lines.append(line)
	return event


func close_conversation() -> void:
	director.overlay.advance()
	await process_frame
	await process_frame


func run() -> void:
	director = root.get_node("Conversations")
	var invalid := ConversationEvent.new()
	check(not director.play(invalid) and not paused, "Empty events are rejected without pausing")
	var opening: ConversationEvent = load("res://resources/conversations/station_check_in.tres")
	check(opening != null and opening.is_valid(), "Authored opening event loads with valid lines")
	# Keep interaction tests independent of edits to the game's opening dialogue.
	var sample := event_with_text(&"test_check_in")
	sample.characters_per_second = 40.0
	sample.lines[0].left_character = load("res://resources/rpg/characters/takane.tres")
	sample.lines[0].right_character = load("res://resources/rpg/characters/usami.tres")
	sample.lines[0].speaker = ConversationLine.Speaker.RIGHT
	sample.lines[0].left_entrance = ConversationLine.Entrance.FROM_LEFT
	sample.lines[0].right_entrance = ConversationLine.Entrance.FROM_RIGHT
	var second: ConversationLine = sample.lines[0].duplicate()
	second.speaker = ConversationLine.Speaker.LEFT
	sample.lines.append(second)
	sample.lines.append(sample.lines[0].duplicate())
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game_reveal_duration = 0.2
	game.new_game()
	var opening_town = game.ui.get_child(0)
	check(game.battle_fade.visible and is_equal_approx(game.battle_fade.color.a, 1.0), "New Game covers the Safe Zone in black before revealing it")
	check(not paused and not director.is_active() and opening_town.navigation_locked, "New Game locks town before the opening can start")
	check(not opening_town.get_node("Panel").visible, "Safe Zone action card is hidden before the opening")
	for button in opening_town.get_node("Panel/Buttons").get_children():
		if button is Button:
			check(button.disabled, "Safe Zone action is disabled before the opening: %s" % button.name)
	game._on_action_requested("Tinkerer")
	opening_town._on_button_pressed("Explore")
	check(game.screen == "town" and opening_town.module_view == null and game.world == null, "Locked opening prevents service and exploration actions")
	await create_timer(0.09).timeout
	check(game.battle_fade.color.a > 0.0 and game.battle_fade.color.a < 1.0 and not director.is_active(), "Safe Zone fades into view before dialogue begins")
	await create_timer(0.17).timeout
	check(not game.battle_fade.visible and not game._battle_transition, "Opening waits until the reveal fade is fully finished")
	check(paused and director.active_event == game.opening_conversation, "Opening conversation starts automatically")
	check(opening_town.get_node("Panel/Buttons/Barracks").disabled, "Town buttons stay disabled during the opening")
	check(not opening_town.get_node("Panel").visible, "Action card stays hidden throughout the conversation")
	while director.is_active():
		director.overlay.body.visible_characters = -1
		await close_conversation()
	check(not paused and not opening_town.navigation_locked, "Finishing the opening resumes and unlocks the town")
	check(opening_town.get_node("Panel").visible, "Action card appears only after the conversation finishes")
	for button in opening_town.get_node("Panel/Buttons").get_children():
		if button is Button:
			check(not button.disabled, "Safe Zone action becomes available after opening: %s" % button.name)
	game.show_town(game.starting_town)
	check(not director.is_active() and not game.ui.get_child(0).navigation_locked, "Returning to town does not replay the opening")
	game.new_game()
	await create_timer(0.26).timeout
	check(director.is_active() and game.ui.get_child(0).navigation_locked, "Another New Game replays the opening and locks its buttons")
	while director.is_active():
		director.overlay.body.visible_characters = -1
		await close_conversation()
	game.opening_conversation = invalid
	game.new_game()
	await create_timer(0.26).timeout
	check(not paused and not game.ui.get_child(0).navigation_locked, "Invalid opening does not leave navigation locked")
	game.opening_conversation = sample
	game.new_game(false)
	var town = game.ui.get_child(0)
	var trigger := ConversationTrigger.new()
	trigger.event = sample
	town.add_child(trigger)
	check(trigger.trigger() and paused and director.is_active(), "Town trigger pauses the scene")
	check(not trigger.trigger(), "Once-per-instance trigger rejects repeat activation")
	check(director.overlay.left_portrait.texture == game.party[1].definition.portrait, "Slot 1 uses Takane's current portrait")
	check(director.overlay.right_portrait.texture == game.party[0].definition.portrait, "Slot 2 uses Usami's current portrait")
	check(director.overlay.right_portrait.anchor_left >= 1.0, "Usami enters slot 2 from beyond the right edge")
	check(director.overlay.speaker_label.text == "Usami", "Speaker name comes from the character resource")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Conversation releases the mouse")
	director.overlay.advance()
	check(director.overlay.line_index == 0 and director.overlay.body.visible_characters == -1, "First advance reveals typing without skipping the line")
	director.overlay.advance()
	check(director.overlay.line_index == 1 and director.overlay.speaker_label.text == "Takane", "Second advance switches speaker")
	director.overlay.advance()
	director.overlay.advance()
	director.overlay.advance()
	await close_conversation()
	check(not paused and game.ui.get_child(0) == town, "Finishing resumes the same Town instance")
	var animated := event_with_text(&"entrances")
	animated.lines[0].right_character = game.party[0].definition
	animated.lines[0].right_entrance = ConversationLine.Entrance.FROM_RIGHT
	animated.lines[0].right_entrance_duration = 0.2
	var same_character := ConversationLine.new()
	same_character.right_character = game.party[0].definition
	same_character.text = "Stay in the same slot."
	animated.lines.append(same_character)
	var replacement := ConversationLine.new()
	replacement.right_character = game.party[2].definition
	replacement.right_entrance = ConversationLine.Entrance.FADE
	replacement.right_entrance_duration = 0.1
	replacement.text = "A new face."
	animated.lines.append(replacement)
	var departure := ConversationLine.new()
	departure.left_character = game.party[1].definition
	departure.left_entrance = ConversationLine.Entrance.FROM_TOP
	departure.left_entrance_duration = 0.1
	departure.text = "The right slot clears."
	animated.lines.append(departure)
	director.play(animated)
	var animated_view = director.overlay
	await create_timer(0.05).timeout
	check(animated_view.right_portrait.anchor_left > 0.51 and animated_view.right_portrait.anchor_left < 1.02, "Portrait animates while the game is paused")
	var initial_tween: Tween = animated_view._entrance_tweens[animated_view.right_portrait]
	animated_view.advance()
	check(animated_view._entrance_tweens[animated_view.right_portrait] == initial_tween, "Same character does not restart an entrance on the next line")
	await create_timer(0.2).timeout
	check(is_equal_approx(animated_view.right_portrait.anchor_left, 0.51), "Slide ends at slot 2's normal anchor")
	animated_view.advance()
	check(is_zero_approx(animated_view.right_portrait.self_modulate.a), "Replacement character fades in from transparent")
	await create_timer(0.14).timeout
	check(is_equal_approx(animated_view.right_portrait.self_modulate.a, 1.0), "Fade entrance reaches full visibility")
	animated_view.advance()
	check(not animated_view.right_portrait.visible and animated_view.left_portrait.anchor_bottom < 0.0, "Empty slot hides its occupant and the other slot can enter from above")
	await close_conversation()
	var swaps := event_with_text(&"swaps")
	swaps.lines[0].left_character = game.party[0].definition
	var swap := ConversationLine.new()
	swap.left_character = game.party[1].definition
	swap.left_exit = ConversationLine.Exit.TO_LEFT
	swap.left_exit_duration = 0.1
	swap.left_entrance = ConversationLine.Entrance.FROM_LEFT
	swap.left_entrance_duration = 0.1
	swap.text = "Replacement"
	swaps.lines.append(swap)
	var leave := ConversationLine.new()
	leave.left_exit = ConversationLine.Exit.FADE
	leave.left_exit_duration = 0.1
	leave.text = "Empty stage"
	swaps.lines.append(leave)
	director.play(swaps)
	var swap_view = director.overlay
	swap_view.advance()
	check(swap_view.left_portrait.texture == game.party[0].definition.portrait, "Previous portrait remains during its exit")
	await create_timer(0.04).timeout
	check(swap_view.left_portrait.anchor_right < 0.49 and swap_view.left_portrait.texture == game.party[0].definition.portrait, "Outgoing character slides away before replacement")
	await create_timer(0.09).timeout
	check(swap_view.left_portrait.texture == game.party[1].definition.portrait and swap_view.left_portrait.anchor_left < 0.01, "Replacement slides in only after the exit completes")
	await create_timer(0.14).timeout
	check(is_equal_approx(swap_view.left_portrait.anchor_left, 0.01), "Replacement reaches slot 1")
	swap_view.advance()
	check(swap_view.left_portrait.visible, "Clearing a slot keeps its outgoing portrait until the exit completes")
	await create_timer(0.14).timeout
	check(not swap_view.left_portrait.visible, "Cleared slot hides after exit")
	await close_conversation()
	# Skipping a pending replacement must cancel all callbacks that could respawn it.
	director.play(swaps)
	swap_view = director.overlay
	swap_view.advance()
	await create_timer(0.03).timeout
	swap_view.advance()
	await create_timer(0.25).timeout
	check(not swap_view.left_portrait.visible and swap_view._occupants[swap_view.left_portrait] == null, "Rapid advancement cancels a superseded replacement")
	await close_conversation()
	var ending := event_with_text(&"departure_step")
	ending.lines[0].left_character = game.party[0].definition
	ending.lines[0].right_character = game.party[1].definition
	var final_step := ConversationLine.new()
	final_step.auto_advance = true
	final_step.left_exit = ConversationLine.Exit.TO_LEFT
	final_step.left_exit_duration = 0.08
	final_step.right_exit = ConversationLine.Exit.TO_RIGHT
	final_step.right_exit_duration = 0.2
	ending.lines.append(final_step)
	director.play(ending)
	var ending_view = director.overlay
	ending_view.advance()
	check(not ending_view.get_node("Root/Dialogue").visible and paused, "Empty automatic departure hides dialogue and keeps gameplay paused")
	ending_view.advance()
	check(director.is_active(), "Manual input cannot cut off an automatic departure")
	await create_timer(0.13).timeout
	check(director.is_active() and not ending_view.left_portrait.visible and ending_view.right_portrait.visible, "Final step waits for the slower portrait exit")
	await create_timer(0.15).timeout
	check(not director.is_active() and not paused, "Final departure closes automatically after both characters leave")

	var once := event_with_text(&"once", true)
	check(director.play(once), "Once-per-game event starts")
	check(not director.play(once), "Active once-per-game event cannot queue twice")
	var queued := event_with_text(&"queued")
	check(director.play(queued), "Another event queues")
	await close_conversation()
	check(paused and director.active_event == queued, "Queued event keeps the scene paused")
	await close_conversation()
	check(not paused and not director.play(once), "Completion history prevents replay")
	# Completion callbacks must also preserve the original pause/mouse state.
	director.finished.connect(func(event: ConversationEvent):
		if event.id == &"chain":
			director.play(queued)
	)
	director.play(event_with_text(&"chain"))
	await close_conversation()
	check(paused and director.active_event == queued, "Completion callback can queue another conversation")
	await close_conversation()
	check(not paused, "Callback queue restores the original pause state")
	paused = true
	director.play(queued)
	await close_conversation()
	check(paused, "An already paused scene remains paused")
	paused = false
	# A scene-entry trigger waits while the game is transitioning.
	game._battle_transition = true
	var entry_trigger := ConversationTrigger.new()
	entry_trigger.event = queued
	entry_trigger.on_scene_entry = true
	town.add_child(entry_trigger)
	await process_frame
	await process_frame
	check(not director.is_active() and entry_trigger._triggered, "Scene-entry trigger queues during transitions")
	game._battle_transition = false
	await process_frame
	await process_frame
	check(director.is_active(), "Scene-entry trigger opens after the transition")
	# Input must stay inside the overlay instead of opening town or battle menus.
	var tab := InputEventAction.new()
	tab.action = "party_information"
	tab.pressed = true
	Input.parse_input_event(tab)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	check(game.screen == "town" and director.is_active(), "Tab and Escape do not reach gameplay during dialogue")
	await close_conversation()
	# A blank side hides its portrait; NPC overrides and narration are independent.
	queued.lines[0].right_portrait = sample.lines[0].right_character.portrait
	queued.lines[0].right_name = "Visitor"
	queued.lines[0].speaker = ConversationLine.Speaker.RIGHT
	director.play(queued)
	check(not director.overlay.left_portrait.visible and director.overlay.right_portrait.visible, "A conversation may display only one character")
	check(director.overlay.speaker_label.text == "Visitor", "NPC portrait and name overrides work")
	await close_conversation()

	game.explore()
	var map = game.world
	var original_position: Vector3 = map.player.position
	var prior_mouse := Input.mouse_mode
	map.player.velocity = Vector3(5, 0, 0)
	director.play(queued)
	await create_timer(0.12).timeout
	check(map.player.position == original_position and game.world == map, "Exploration remains frozen in place")
	await close_conversation()
	check(not paused and Input.mouse_mode == prior_mouse, "Exploration mouse mode is restored")
	map.player.velocity = Vector3.ZERO
	game.world.encounter = load("res://resources/rpg/encounters/training.tres")
	game.start_combat(false)
	var combat = game.ui.get_child(0)
	combat.action_delay = 0.1
	for member in game.party:
		combat.session.choose_defend()
	combat._execute_round()
	var queue_index: int = combat.session._queue_index
	director.play(queued)
	await create_timer(0.25).timeout
	check(combat.session._queue_index == queue_index and game.ui.get_child(0) == combat, "Battle action delay does not elapse during dialogue")
	await close_conversation()
	await create_timer(0.14).timeout
	check(combat.session._queue_index > queue_index, "Battle actions resume after dialogue")
	# Events requested during scene fades wait until the fade ends.
	game._battle_transition = true
	director.play(queued)
	check(not director.is_active() and not paused, "Transition delays conversation activation")
	game._battle_transition = false
	await process_frame
	await process_frame
	check(director.is_active() and paused, "Pending event starts when the transition ends")
	director.reset()
	check(not paused and director.completed.is_empty(), "Reset releases pause and clears history")
	game.queue_free()
	await process_frame
	print("Conversation tests: %d failure(s)" % failures)
	quit(1 if failures else 0)
