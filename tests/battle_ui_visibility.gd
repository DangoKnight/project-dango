extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func toggle(battle: CombatScreen) -> void:
	var event := InputEventAction.new()
	event.action = "toggle_battle_ui"
	event.pressed = true
	battle._input(event)

func settle() -> void:
	for frame in 5:
		await process_frame

func hidden(battle: CombatScreen) -> void:
	for control in [battle.action_panel, battle.special_panel, battle.portrait, battle.party_cards, battle.round_counter, battle.battle_log, battle.confirmation]:
		check(not control.visible, "Q hides " + control.name)
	check(battle.enemy_stage.visible and battle.get_node("Background").visible, "Q preserves enemies and background")

func run() -> void:
	var battle := load("res://scenes/battle/combat.tscn").instantiate() as CombatScreen
	battle.menu_slide_duration = 0
	root.add_child(battle)
	var party: Array[CharacterState] = [CharacterState.new(load("res://resources/rpg/characters/usami.tres")), CharacterState.new(load("res://resources/rpg/characters/takane.tres"))]
	battle.configure(party, battle.default_encounter)
	await settle()
	var previous: Button
	for command in battle.actions.get_children():
		if command.text == L10n.text("ui.battle.return_previous"):
			previous = command
	check(previous != null and previous.disabled, "First character has a disabled previous-character button")
	check(previous.get_index() + 1 == battle.actions.get_child_count() - 1, "Previous-character button sits immediately above Run")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	check(key.is_action_pressed("toggle_battle_ui"), "Q is mapped to the battle UI toggle")
	toggle(battle)
	hidden(battle)
	battle._refresh()
	await settle()
	hidden(battle)
	toggle(battle)
	check(battle.action_panel.visible and battle.portrait.visible and battle.party_cards.visible, "Q restores planning UI")
	battle.effects.play_effect("heal", battle.party_buttons[0], 0.15)
	battle.effects.play_effect("slash", battle.enemy_slots[0].get_node("Image"), 0.15)
	toggle(battle)
	await settle()
	check(not battle.effects.active[0].sprite.visible and battle.effects.active[1].sprite.visible, "Q hides friendly effects while preserving enemy effects")
	await battle.effects.wait_until_finished()
	toggle(battle)

	battle._open_special()
	toggle(battle)
	hidden(battle)
	toggle(battle)
	check(battle.special_panel.visible and battle._special_open, "Q preserves the open abilities drawer")
	battle._close_special()
	battle.information.open(battle.session)
	toggle(battle)
	check(battle.information.modulate.a == 0 and not battle.get_node("InformationBlocker").visible, "Q conceals battle information")
	toggle(battle)
	check(battle.information.modulate.a == 1 and battle.information.is_open, "Q restores battle information without changing its state")
	battle.information.close_immediately()
	battle.session.choose_defend()
	for command in battle.actions.get_children():
		if command.text.begins_with("Return to "):
			check(not command.disabled and command.text.contains("Usami"), "Later characters can return to the previous character")
	battle.session.choose_defend()
	await settle()
	for dimensions in [Vector2i(800, 450), Vector2i(1280, 720), Vector2i(900, 1200)]:
		root.size = dimensions
		await settle()
		check(battle.confirmation.get_rect().get_center().distance_to(battle.size * 0.5) < 2, "Confirmation stays centered")
		check(battle.confirmation.size.y < 200, "Confirmation height fits its content")
		check(battle.confirmation.get_theme_stylebox("panel").corner_radius_top_left > 0, "Confirmation has rounded corners")
		check(battle.get_node("Confirmation/Layout/Execute").get_theme_stylebox("normal").corner_radius_top_left > 0, "Confirmation buttons match commands")
	toggle(battle)
	hidden(battle)
	check(battle.session.phase == BattleSession.Phase.READY and battle.session.planned_actions.size() == 2, "Q leaves chosen actions intact")
	toggle(battle)
	check(battle.confirmation.visible, "Q restores confirmation")
	toggle(battle)
	battle.action_delay = 0
	battle.attack_animation_duration = 0.02
	battle._execute_round()
	while battle._performing_round:
		await process_frame
	hidden(battle)
	check(battle.session.round_number == 2, "Action sequence continues while the UI is hidden")
	toggle(battle)
	check(battle.action_panel.visible and not battle.confirmation.visible, "Q restores the current phase after a hidden action sequence")
	check(battle.get_viewport().gui_get_focus_owner() != null, "Restored phase has keyboard focus")

	battle.queue_free()
	await process_frame
	print("Battle UI visibility failures: ", failures)
	quit(failures)
