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
	check(game.state.gear_inventory.get_items().is_empty() and game.state.weapon_inventory.is_empty(), "New Game starts without gear, consumables, or stored weapons")
	for member in game.state.roster:
		check(member.equipped_weapon == null and member.get_equipped_gear().is_empty(), "Starting roster has no equipment")
	var director := root.get_node("Conversations")
	game.show_location("Barracks")
	check(director.is_active() and game.ui.get_child(0).module_view == null, "York speaks before Barracks opens")
	var view := director.overlay as ConversationOverlay
	while view.event.lines[view.line_index].reward_gear == null:
		view.body.visible_characters = -1
		view.advance()
		await create_timer(0.02).timeout
	var reward_line := view.event.lines[view.line_index]
	var items: Array[GearInstance] = game.state.gear_inventory.get_items()
	check(items.size() == 4, "York grants exactly four ration instances on the receipt step")
	check(view.get_node("Root/Notification").visible and view.get_node("Root/Notification/Text").text == L10n.text(reward_line.notification_text), "Receipt displays the authored message on the top notification card")
	check(not view.get_node("Root/Dialogue").visible and paused, "Notification-only step hides dialogue while the scene stays paused")
	var style: StyleBox = view.get_node("Root/Notification").get_theme_stylebox("panel")
	check(style is StyleBoxFlat and style.bg_color.a > 0.0 and style.bg_color.a < 1.0, "Notification card has a translucent background")
	view._show_line()
	check(game.state.gear_inventory.get_items().size() == 4, "Refreshing a conversation line does not duplicate rewards")
	for item in items:
		check(item.definition.id == &"simple_rations" and item.remaining_uses() == 2 and item.get_carrier() == null, "Each ration is fresh and unequipped")
	var member: CharacterState = game.state.party[0]
	member.current_hp -= 20
	var hp := member.current_hp
	check(member.equip_gear(items[0]), "Rations can be equipped normally")
	var result := RPGConsumables.use_item(member, items[0], [member])
	check(result.success and member.current_hp == hp + 10 and items[0].remaining_uses() == 1, "First ration use heals ten HP and spends one use")
	result = RPGConsumables.use_item(member, items[0], [member])
	check(result.success and member.current_hp == hp + 20 and items[0].is_destroyed(), "Second ration use heals ten HP and consumes the item")
	check(items[1].remaining_uses() == 2, "Ration copies have independent uses")
	while director.is_active():
		view.body.visible_characters = -1
		view.advance()
		await create_timer(0.02).timeout
	check(game.screen == "location" and game.ui.get_child(0).module_view != null, "Barracks opens when the receipt and departures finish")
	game.show_town()
	await create_timer(0.3).timeout
	game.show_location("Barracks")
	check(not director.is_active() and game.state.gear_inventory.get_items().size() == 3, "Revisiting Barracks does not award rations again")
	game.new_game(false)
	check(game.state.gear_inventory.get_items().is_empty(), "New Game clears previous rewards")
	game.show_location("Barracks")
	check(director.is_active(), "York's reward conversation becomes available again on a new run")
	game.new_game(false)
	var departure: ConversationEvent = load("res://resources/conversations/station_departure.tres")
	check(departure != null and departure.is_valid(), "Departure conversation loads with all authored lines")
	var join_line := departure.lines[departure.lines.size() - 2]
	check(join_line.recruit_character != null and join_line.recruit_character.id == &"koumi" and not join_line.notification_text.is_empty(), "Second-to-last departure step recruits Koumi and announces it")
	var join_event := ConversationEvent.new()
	join_event.lines.append(join_line)
	check(director.play(join_event), "Recruitment notification can play")
	check(game.state.party.size() == 4 and game.state.party[3].definition.id == &"koumi" and game.state.roster.size() == 4, "Koumi joins the active party when the notification begins")
	director.overlay._show_line()
	check(game.state.party.size() == 4 and game.state.roster.size() == 4, "Refreshing the notification does not duplicate Koumi")
	game.state.recruit_character(join_line.recruit_character)
	check(game.state.roster.size() == 4, "Repeated recruitment keeps the existing character")
	game.new_game(false)
	check(game.state.party.size() == 3 and game.state.roster.size() == 3, "New Game clears recruitment")
	game.queue_free()
	await process_frame
	print("Conversation reward tests: %d failure(s)" % failures)
	quit(1 if failures else 0)
