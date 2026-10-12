extends SceneTree

var failures := 0
var director: Node


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func finish_conversation() -> void:
	for tick in range(500):
		if not director.is_active():
			return
		director.overlay.body.visible_characters = -1
		director.overlay.advance()
		await create_timer(0.01).timeout
	check(false, "Conversation finishes within the test timeout")


func quick_event(event: ConversationEvent) -> ConversationEvent:
	var copy := event.duplicate(true) as ConversationEvent
	copy.characters_per_second = 0.0
	for line in copy.lines:
		line.minimum_duration = 0.02
		line.left_entrance_duration = 0.02
		line.right_entrance_duration = 0.02
		line.left_exit_duration = 0.02
		line.right_exit_duration = 0.02
	return copy


func wait_for_entry(game: Node) -> void:
	for tick in range(150):
		if not game._battle_transition:
			return
		await create_timer(0.02).timeout
	check(false, "Labyrinth entry transition completes")


func run() -> void:
	director = root.get_node("Conversations")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.navigation_fade_duration = 0.1
	game.new_game(false)
	var town := game.ui.get_child(0) as Town
	for key in town.module_conversations.keys():
		town.module_conversations[key] = quick_event(town.module_conversations[key])
	town.departure_conversation = quick_event(town.departure_conversation)
	var departure_id := town.departure_conversation.id
	check(town.get_node("Panel/Buttons/Explore").disabled, "New Game locks the entrance")
	game.enter_labyrinth()
	check(game.world == null and not director.is_active() and not game._battle_transition, "Locked entrance cannot begin dialogue or transition")
	var order := ["Barterer", "Barracks", "Tinkerer"]
	for index in range(order.size()):
		game.show_location(order[index])
		check(director.is_active() and not bool(game.state.get_flag(&"labyrinth_unlocked", false)), "Entrance stays locked during the introductory conversation")
		await finish_conversation()
		check(town.module_view != null, "Completed introduction opens the service")
		check(bool(game.state.get_flag(&"labyrinth_unlocked", false)) == (index == 2), "Only three distinct module visits unlock the entrance")
		game.show_town()
		await create_timer(0.3).timeout
		check(town.get_node("Panel/Buttons/Explore").disabled == (index != 2), "Hub button reflects the unlock state")
		if index == 0:
			game.show_location(order[0])
			check(not director.is_active() and not bool(game.state.get_flag(&"labyrinth_unlocked", false)), "Repeated visits do not count as another module")
			game.show_town()
			await create_timer(0.3).timeout
	town.get_node("Panel/Buttons/Explore").pressed.emit()
	check(director.is_active() and director.active_event.id == departure_id, "Unlocked entrance requests the departure conversation")
	check(game.world == null and not game.battle_fade.visible and not game._battle_transition and paused, "Departure dialogue precedes the fade and labyrinth generation")
	town._on_button_pressed("Explore")
	game._on_action_requested("Options")
	check(game.ui.get_child(0) == town and game.world == null, "Departure prevents duplicate entry and menu input")
	await finish_conversation()
	check(game._battle_transition and game.battle_fade.visible, "Fade begins after dialogue finishes")
	await wait_for_entry(game)
	check(game.screen == "explore" and game.world != null and game.player.movement_enabled, "Departure enters the selected labyrinth and releases movement")
	game.show_town()
	town = game.ui.get_child(0)
	check(not town.get_node("Panel/Buttons/Explore").disabled, "Unlock persists after recreating the hub")
	town.get_node("Panel/Buttons/Explore").pressed.emit()
	check(not director.is_active() and game._battle_transition, "Later entries skip the once-per-game departure")
	await wait_for_entry(game)
	game.new_game(false)
	town = game.ui.get_child(0)
	check(town.get_node("Panel/Buttons/Explore").disabled and not game.state.completed_conversations.has(departure_id), "New Game resets the entrance and departure history")
	game.state.set_flag(&"labyrinth_unlocked", true)
	town.get_node("Panel/Buttons/Explore").pressed.emit()
	check(director.is_active(), "New Game makes the departure available again")
	game.new_game(false)
	await create_timer(0.3).timeout
	check(not director.is_active() and not paused and game.world == null and game.screen == "town", "New Game cancels pending departure without a stale entry")
	game.queue_free()
	await process_frame
	print("Departure tests: %d failure(s)" % failures)
	quit(1 if failures else 0)
