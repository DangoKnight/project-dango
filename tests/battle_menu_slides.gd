extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func run() -> void:
	var battle := load("res://scenes/battle/combat.tscn").instantiate() as CombatScreen
	root.add_child(battle)
	var party: Array[CharacterState] = [CharacterState.new(load("res://resources/rpg/characters/usami.tres")), CharacterState.new(load("res://resources/rpg/characters/takane.tres"))]
	battle.configure(party, battle.default_encounter)
	check(battle.action_panel.get_rect().end.x <= 0, "Menu starts offscreen")
	check(not battle.has_node("Heading") and battle.round_counter.get_rect().end.y <= 0, "Old heading is removed and round counter starts above the screen")
	check(battle.party_cards.position.y >= battle.size.y, "Health cards start below the screen")
	await create_timer(battle.menu_slide_duration + 0.05).timeout
	check(battle.action_panel.visible and battle.action_panel.get_rect().position.x > 0, "Menu slides in at battle start")
	check(battle.portrait.visible and is_equal_approx(battle.portrait.anchor_left, 0.4), "Portrait slides in from the right")
	check(not battle.get_node("BattleLog").visible, "Log stays hidden during action selection")
	check(battle.round_counter.visible and battle.round_counter.text == "Round 1" and battle.round_counter.anchor_left >= 0.8, "Round counter slides into the top right")
	check(battle.party_cards.visible and is_equal_approx(battle.party_cards.anchor_top, 0.9), "Health cards slide up into their bottom position")
	battle.session.choose_attack()
	await create_timer(battle.menu_slide_duration * 0.4).timeout
	check(battle.action_panel.position.x < 0 and battle.action_panel.visible, "Menu moves left during targeting")
	check(battle.portrait.anchor_left > 0.4 and battle.portrait.visible, "Portrait moves right during targeting")
	# Reverse an animation in progress and resize while it returns.
	battle.session.cancel_target()
	root.size = Vector2i(1600, 900)
	await create_timer(battle.menu_slide_duration + 0.05).timeout
	check(is_equal_approx(battle.action_panel.position.x / battle.size.x, 0.02), "Interrupted slide restores its anchored position after resize")
	battle.session.choose_attack()
	await create_timer(battle.menu_slide_duration + 0.05).timeout
	check(not battle.action_panel.visible and battle.action_panel.get_rect().end.x <= 0, "Targeting fully clears the action menu")
	check(not battle.portrait.visible and battle.portrait.position.x > battle.size.x, "Portrait finishes outside the right edge")
	check(battle.get_node("TargetHint").visible, "Target instructions remain visible")
	check(battle.party_cards.visible and battle.round_counter.visible, "Health and round counter remain visible during targeting")
	battle.session.select_target(battle.session.enemies[0])
	await create_timer(battle.menu_slide_duration + 0.05).timeout
	check(battle.action_panel.visible, "Selecting a target restores the menu for the next character")
	battle.session.choose_defend()
	await create_timer(battle.menu_slide_duration + 0.05).timeout
	check(not battle.action_panel.visible and battle.confirmation.visible, "Ready phase swaps the menu for confirmation")
	check(battle.confirmation.get_rect().get_center().is_equal_approx(battle.size * 0.5), "Confirmation finishes in the center")
	check(battle.get_node("Confirmation/Layout/Question").text == "Proceed with this round?" and not battle.confirmation.has_node("Layout/Scroll"), "Confirmation only asks whether to proceed")
	check(battle.get_viewport().gui_get_focus_owner() == battle.get_node("Confirmation/Layout/Execute"), "Confirmation supports keyboard execution")
	battle.get_node("Confirmation/Layout/Return").pressed.emit()
	await create_timer(battle.menu_slide_duration + 0.05).timeout
	check(not battle.confirmation.visible and battle.action_panel.visible and battle.session.active_character() == party[1], "Return hides confirmation and restores the previous character menu")
	battle.session.choose_defend()
	await create_timer(battle.menu_slide_duration + 0.05).timeout
	battle.action_delay = 0.35
	battle.get_node("Confirmation/Layout/Execute").pressed.emit()
	check(battle.get_node("BattleLog").visible and not battle.get_node("BattleLog/Log").text.is_empty(), "Log displays resolving actions")
	battle._log("First action")
	battle._log("Second action")
	battle._log("Third action")
	check(battle.get_node("BattleLog/Log").text == "Second action\nThird action", "Log retains only the two newest actions")
	check(battle.get_node("BattleLog/Log").max_lines_visible == 2 and battle.get_node("BattleLog/Log").clip_text, "Log is limited to two visual lines")
	check(battle.get_node("BattleLog").anchor_top < 0.05 and battle.get_node("BattleLog").get_theme_stylebox("panel").bg_color.a < 0.25, "Log is translucent at the top")
	await create_timer(battle.menu_slide_duration + 0.05).timeout
	check(not battle.round_counter.visible and battle.round_counter.get_rect().end.y <= 0, "Round counter slides up during resolution")
	check(battle.party_cards.visible and is_equal_approx(battle.party_cards.anchor_top, 0.9), "Health cards stay visible during resolution")
	await create_timer(1.2).timeout
	check(not battle.confirmation.visible and battle.session.round_number == 2 and battle.action_panel.visible, "Execute hides confirmation and next round restores the menu")
	check(not battle.get_node("BattleLog").visible, "Log hides after resolution")
	check(battle.round_counter.visible and battle.round_counter.text == "Round 2", "Updated round counter returns for the next round")
	battle.session.choose_defend()
	await create_timer(battle.menu_slide_duration * 2.0 + 0.05).timeout
	check(battle.portrait.visible and battle.portrait_image.texture == party[1].definition.portrait and is_equal_approx(battle.portrait.anchor_left, 0.4), "Direct actions slide the old portrait out before sliding the next one in")
	# Selecting a target before the outgoing portrait finishes used to append to
	# an already-started tween, leaving the portrait permanently stuck swapping.
	battle.session.undo_choice()
	await create_timer(battle.menu_slide_duration * 2.0 + 0.05).timeout
	battle.session.choose_attack()
	await create_timer(battle.menu_slide_duration * 0.4).timeout
	check(float(battle._panel_progress[battle.portrait.name]) > 0.0, "Regression selects while the outgoing portrait is still moving")
	battle.session.select_target(battle.session.enemies[0])
	await create_timer(battle.menu_slide_duration * 2.0 + 0.05).timeout
	check(not battle._portrait_swapping and battle.portrait.visible and battle.portrait_image.texture == party[1].definition.portrait, "Fast target selection completes the swap and restores the next portrait")
	# Changing the requested character during a swap must also recover.
	battle.session.undo_choice()
	await create_timer(battle.menu_slide_duration * 2.0 + 0.05).timeout
	battle.session.choose_attack()
	await create_timer(battle.menu_slide_duration * 0.4).timeout
	battle.session.select_target(battle.session.enemies[0])
	battle.session.undo_choice()
	await create_timer(battle.menu_slide_duration * 2.0 + 0.05).timeout
	check(not battle._portrait_swapping and battle.portrait.visible and battle.portrait_image.texture == party[0].definition.portrait, "Returning to the previous character during a swap restores the correct portrait")
	battle.queue_free()
	await process_frame
	print("Battle menu slide tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
