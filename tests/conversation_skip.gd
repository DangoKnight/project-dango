extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func settle() -> void:
	await process_frame
	await process_frame

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game(false)
	var director := root.get_node("Conversations")
	game.show_location("Barracks")
	check(director.is_active() and game.state.gear_inventory.get_items().is_empty(), "Barracks begins before its reward")
	var view := director.overlay as ConversationOverlay
	await process_frame
	var point := view.skip_button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	check(view._closing, "Mouse input activates Skip instead of advancing the dialogue")
	view.skip() # Repeated activation must not duplicate rewards or completion.
	await settle()
	check(not director.is_active() and not paused and game.screen == "location", "Skipping completes the introduction and opens Barracks")
	check(game.state.gear_inventory.get_items().size() == 4, "Skipping York's introduction grants all four rations")
	game.show_town()
	game.show_location("Barracks")
	check(not director.is_active() and game.state.gear_inventory.get_items().size() == 4, "Completed introduction cannot grant rewards again")

	game.new_game(false)
	game.show_location("Barracks")
	view = director.overlay
	while view.event.lines[view.line_index].reward_gear == null:
		view.body.visible_characters = -1
		view.advance()
		await create_timer(0.02).timeout
	check(game.state.gear_inventory.get_items().size() == 4 and view.event.lines[view.line_index].auto_advance, "Reward was already granted on an automatic step")
	view.skip()
	await settle()
	check(game.state.gear_inventory.get_items().size() == 4 and not director.is_active(), "Skip bypasses the automatic hold without duplicating collected rewards")

	game.new_game(false)
	# A custom event exercises several rewards, recruitment, and queued events together.
	var event := ConversationEvent.new()
	event.id = &"test_skip_rewards"
	event.once_per_game = true
	var first := ConversationLine.new()
	first.text = "Test opening"
	first.minimum_duration = 30.0
	event.lines.append(first)
	for quantity in [2, 3]:
		var reward := ConversationLine.new()
		reward.reward_gear = load("res://resources/rpg/gear/simple_rations.tres")
		reward.reward_quantity = quantity
		event.lines.append(reward)
	var recruit := ConversationLine.new()
	recruit.recruit_character = load("res://resources/rpg/characters/koumi.tres")
	event.lines.append(recruit)
	var queued := ConversationEvent.new()
	queued.id = &"test_skip_queued"
	var queued_line := ConversationLine.new()
	queued_line.text = "Queued event"
	queued_line.reward_gear = load("res://resources/rpg/gear/simple_rations.tres")
	queued.lines.append(queued_line)
	check(director.play(event) and director.play(queued), "Reward event and follow-up queue successfully")
	view = director.overlay
	view.skip_button.grab_focus()
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	view._input(accept)
	await settle()
	check(director.active_event == queued and paused, "Keyboard skip bypasses forced duration and preserves queued conversations")
	check(game.state.gear_inventory.get_items().size() == 6 and game.state.party.size() == 4 and game.state.party[3].definition.id == &"koumi", "All remaining item rewards and recruitment apply before the next event")
	check(director.completed.has(event.id) and not director.play(event), "Skipped once-per-game event is completed")
	director.overlay.skip()
	await settle()
	check(not director.is_active() and not paused and game.state.gear_inventory.get_items().size() == 6, "Skipping the next event preserves its already granted reward and resumes the scene")
	game.new_game(false)
	check(game.state.gear_inventory.get_items().is_empty() and game.state.roster.size() == 3, "New Game clears skipped-conversation rewards and recruitment")
	game.queue_free()
	await settle()
	print("Conversation skip tests: %d failure(s)" % failures)
	quit(1 if failures else 0)
