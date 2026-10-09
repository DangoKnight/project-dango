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
	game.explore()
	check(is_equal_approx(game.battle_reveal_duration, 2.0), "Battle reveal defaults to two seconds")
	game.start_combat()
	check(game.screen == "combat_transition" and game.battle_fade.visible, "Entry begins with a blocking fade")
	check(not game.player.movement_enabled, "Movement stops before fading")
	game.start_combat()
	while game.screen == "combat_transition":
		await process_frame
	var battle := game.ui.get_child(0) as CombatScreen
	check(battle != null and battle.intro_playing, "Battle enters with presentation suspended")
	check(not battle.has_node("ActorStats"), "Description panel is removed")
	check(game.battle_fade.color.a > 0.9, "Battle switches behind the opaque fade")
	var started := Time.get_ticks_msec()
	await create_timer(1.0).timeout
	check(game._battle_transition and battle.intro_playing, "Reveal remains active after one second")
	check(game.battle_fade.color.a > 0.1 and game.battle_fade.color.a < 0.9, "Black overlay fades continuously")
	for path in ["RoundCounter", "Party", "ActionPanel", "BattleLog", "PortraitOverlay"]:
		check(not battle.get_node(path).visible, "UI hidden during reveal: " + path)
	check(battle.enemy_slots[0].visible and battle.get_node("Background").visible, "Battlefield remains visible during reveal")
	check(battle.session.planned_actions.is_empty(), "Intro does not advance combat")
	root.size = Vector2i(1600, 900)
	await process_frame
	check(game.battle_fade.get_global_rect().encloses(battle.get_global_rect()), "Fade covers resized battle")
	while game._battle_transition:
		await process_frame
	check(Time.get_ticks_msec() - started >= 1900, "Reveal lasts two seconds")
	check(not game.battle_fade.visible and not battle.intro_playing, "Fade releases input after reveal")
	await create_timer(battle.menu_slide_duration + 0.05).timeout
	check(battle.portrait.visible and battle.get_node("ActionPanel").visible and battle.get_node("Party").visible, "UI appears when reveal ends")
	check(battle.session.phase == BattleSession.Phase.ACTION_SELECTION, "Combat starts at the first action")
	game.queue_free()
	await process_frame
	print("Battle transition tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
