extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func press_tab() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_TAB
	event.pressed = true
	Input.parse_input_event(event)


func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	game.explore()
	game.start_combat(false)
	var battle := game.ui.get_child(0) as CombatScreen
	var panel = battle.information
	check(not panel.visible, "Information begins closed")
	await process_frame
	press_tab()
	await process_frame
	check(panel.enemy_tab.text == "Hostiles" and not panel.has_node("Layout/Tabs/Party"), "Friendly view has one Hostiles switch")
	check(panel.visible and panel.members.item_count == 4, "Tab opens full party information")
	check(panel.anchor_top < 0.0, "Information begins sliding down from above")
	await create_timer(panel.slide_duration + 0.05).timeout
	check(panel.details.text.contains("Usami") and panel.details.text.contains("Jolly cheer"), "Own character details and skills are available")
	check(panel.details.text.contains("RESISTANCES") and panel.details.text.contains("Mental Acuity"), "Information includes stats and all resistances")
	check(not panel.details.text.contains(battle.session.party[0].definition.description), "Battle information omits character description")
	panel.enemy_tab.pressed.emit()
	check(panel.enemy_tab.text == "Friendlies", "Hostile view offers return to Friendlies")
	check(panel.showing_enemies and panel.members.item_count == battle.session.enemies.size(), "Opposite tab lists all enemies")
	check(panel.details.text.contains(battle.session.enemies[0].definition.display_name) and panel.details.text.contains("Critical rate"), "Full enemy details are known immediately")
	panel.enemy_tab.pressed.emit()
	panel.members.select(3)
	panel.members.item_selected.emit(3)
	check(panel.details.text.contains("Koumi") and panel.details.text.contains("Bonk"), "Every party unit is selectable")
	for window_size in [Vector2i(800, 450), Vector2i(1920, 1080), Vector2i(900, 1200)]:
		root.size = window_size
		for frame in range(3):
			await process_frame
		check(panel.get_global_rect().is_equal_approx(battle.get_global_rect()), "Information fills resized screen")
		for path in ["Layout/Tabs", "Layout/Content/Members", "Layout/Content/Details", "Layout/Close"]:
			check(panel.get_global_rect().grow(1).encloses(panel.get_node(path).get_global_rect()), "Panel content fits: " + path)
	press_tab()
	await create_timer(panel.slide_duration + 0.05).timeout
	check(not panel.visible and battle.session.planned_actions.is_empty(), "Tab closes without changing choices")
	battle.session.choose_attack()
	press_tab()
	await process_frame
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await create_timer(panel.slide_duration + 0.05).timeout
	check(not panel.visible and battle.session.phase == BattleSession.Phase.TARGET_SELECTION, "Esc closes information without canceling target selection")
	battle.session.cancel_target()
	while battle.session.phase != BattleSession.Phase.READY:
		battle.session.choose_wait()
	battle.action_delay = 0.05
	battle._execute_round()
	press_tab()
	await process_frame
	var messages := battle._messages.size()
	var queue_index := battle.session._queue_index
	await create_timer(0.2).timeout
	check(panel.visible and battle._messages.size() == messages and battle.session._queue_index == queue_index, "Information pauses queued combat actions")
	panel.closed.emit()
	await create_timer(0.8).timeout
	check(battle.session.round_number == 2, "Closing information resumes round resolution")
	battle.set_intro_playing(true)
	press_tab()
	await create_timer(panel.slide_duration + 0.05).timeout
	check(not panel.visible, "Battle intro blocks the information shortcut")
	battle.set_intro_playing(false)
	press_tab()
	await create_timer(panel.slide_duration * 0.4).timeout
	press_tab()
	await create_timer(panel.slide_duration * 0.4).timeout
	check(panel.visible and not panel.is_open and battle.get_node("InformationBlocker").visible, "Closing slide continues blocking battle input")
	press_tab()
	await create_timer(panel.slide_duration + 0.05).timeout
	check(panel.visible and panel.is_open and is_zero_approx(panel.anchor_top), "Rapid reopen reverses the outgoing slide")
	press_tab()
	await create_timer(panel.slide_duration + 0.05).timeout
	check(not panel.visible and not battle.get_node("InformationBlocker").visible, "Closing slide releases input at completion")
	game.queue_free()
	await process_frame
	print("Battle information tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
