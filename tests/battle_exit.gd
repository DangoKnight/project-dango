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
	var original_map: Map = game.world
	game.start_combat(false)
	var battle := game.ui.get_child(0) as CombatScreen
	await create_timer(0.3).timeout
	for enemy in battle.session.enemies:
		enemy.current_hp = 0
	battle.session._check_finished()
	await process_frame
	check(battle.actions.get_child_count() == 0, "Battle end has no prompt or continuation button")
	check(battle.get_node("BattleLog/Log").text.ends_with("Victory!"), "Victory is the final log entry")
	await create_timer(0.8).timeout
	check(game.screen == "combat" and not battle._exiting and battle.party_cards.visible and battle.battle_log.visible, "Victory log remains visible for one second")
	check(battle.get_node("BattleLog/Log").size.x > battle.size.x * 0.8, "Final log lays out across the screen")
	await create_timer(0.3).timeout
	check(battle._exiting and battle.party_cards.anchor_top > 0.9, "Battle elements slide away after the hold")
	await create_timer(0.25).timeout
	check(game.battle_fade.visible and game._battle_transition, "Return fades after the slide")
	await create_timer(0.8).timeout
	check(game.screen == "explore" and game.world == original_map, "Victory automatically returns to the existing map")
	check(not game.battle_fade.visible and not game._battle_transition and game.player.movement_enabled, "Navigation input returns after fading")
	game.queue_free()
	await process_frame
	print("Battle exit tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
