extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func run() -> void:
	check(BattleEffects.FRAMES.get_animation_names().size() == BattleEffects.PROFILES.size(), "Every BDragon battle preset is imported")
	for layers in BattleEffects.PROFILES.values():
		for layer in layers:
			check(BattleEffects.FRAMES.has_animation(layer[0]), "Ability presets reference an imported pack clip")
	for clip in BattleEffects.FRAMES.get_animation_names():
		check(not BattleEffects.FRAMES.get_animation_loop(clip), "Effect clips must end")
		check(BattleEffects.FRAMES.get_frame_count(clip) >= 6, "Imported effects are frame animations")
		for index in range(BattleEffects.FRAMES.get_frame_count(clip)):
			var texture := BattleEffects.FRAMES.get_frame_texture(clip, index) as AtlasTexture
			check(texture != null and texture.atlas != null and texture.region.end.x <= texture.atlas.get_width() and texture.region.end.y <= texture.atlas.get_height(), "Atlas regions fit the source sheet")
	for type in ["slash", "pierce", "blunt", "fire", "frost", "lightning", "poison", "arcane"]:
		var ability := AbilityDefinition.new()
		ability.damage_type = load("res://resources/rpg/damage_types/%s.tres" % type)
		check(BattleEffects.preset_for(ability) == type, "Damage type chooses its effect: " + type)
	for id in ["jolly_cheer", "caring_friend", "lock_on", "ride_the_gale", "graceful_assault", "painful_stab", "immobilizing_stab", "i_am_scary", "bonk", "cover"]:
		var ability: AbilityDefinition = load("res://resources/rpg/abilities/%s.tres" % id)
		check(BattleEffects.preset_for(ability) == id, "Unique skills override the default effect")
	var status_ability := AbilityDefinition.new()
	status_ability.damage_type = load("res://resources/rpg/damage_types/pierce.tres")
	status_ability.status_effect = load("res://resources/rpg/statuses/painful_poison.tres")
	check(BattleEffects.preset_for(status_ability) == "debuff", "A special status effect takes precedence over damage type")
	status_ability.battle_animation = "immobilizing_stab"
	check(BattleEffects.preset_for(status_ability) == "immobilizing_stab", "An explicit animation takes precedence over automatic status effects")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game(false)
	game.explore()
	game.start_combat(false)
	var battle := game.ui.get_child(0) as CombatScreen
	battle.attack_animation_duration = 0.2
	await create_timer(0.3).timeout
	var actor := battle.session.party[0]
	var target := battle.session.enemies[0]
	var action := BattleAction.new(actor, target, null, true)
	battle._animate_action(action, [target], {"success": true, "missed": true})
	check(not battle.effects.is_playing(), "Missed attacks never display a hit effect")
	battle._animate_action(action, [target], {"success": false})
	check(not battle.effects.is_playing(), "Failed actions never display success effects")
	battle._animate_action(action, [target], {"success": true, "missed": false})
	check(battle.effects.is_playing(), "Successful attacks start a pre-made animation")
	var sprite: AnimatedSprite2D = battle.effects.active[0].sprite
	await create_timer(0.07).timeout
	check(sprite.frame > 0, "Frame animation advances")
	paused = true
	var frame := sprite.frame
	await create_timer(0.12).timeout
	check(sprite.frame == frame and battle.effects.is_playing(), "Conversation pause freezes active effects")
	paused = false
	battle.information.open(battle.session)
	frame = sprite.frame
	await create_timer(0.12).timeout
	check(sprite.frame == frame, "Battle information suspends active effects")
	battle.information.close_immediately()
	await battle.effects.wait_until_finished()
	check(not battle.effects.is_playing(), "Animation completion releases the action sequence")
	var card := battle._effect_target(actor)
	battle.effects.play_effect("heal", card, 0.2)
	sprite = battle.effects.active[0].sprite
	var card_center := battle.effects.get_global_transform().affine_inverse() * card.get_global_rect().get_center()
	check(sprite.position.is_equal_approx(card_center), "Friendly animations are centered directly over their character card")
	check(battle.effects.get_index() > battle.party_cards.get_index(), "Effects render above character cards")
	await battle.effects.wait_until_finished()
	battle.attack_animation_duration = 0.0
	battle._animate_action(action, [target], {"success": true})
	check(not battle.effects.is_playing(), "Zero duration disables presentation without blocking combat")
	# The next planning phase can be calculated while its final visual is playing.
	# Keep the action log up and command panels away until presentation finishes.
	battle._performing_round = true
	battle._refresh()
	check(not battle._panel_targets[battle.action_panel.name] and battle._panel_targets[battle.battle_log.name], "Planning UI stays hidden during action presentation")
	battle._performing_round = false
	battle._refresh()
	battle.attack_animation_duration = 0.12
	battle.action_delay = 0.0
	while battle.session.phase == BattleSession.Phase.ACTION_SELECTION:
		battle.session.choose_defend()
	battle._execute_round()
	check(battle._performing_round and battle.effects.is_playing(), "Committing a round starts its first effect")
	var queue_index := battle.session._queue_index
	await create_timer(0.03).timeout
	check(battle.session._queue_index == queue_index, "The next action waits for the current animation")
	while battle._performing_round:
		await process_frame
	check(battle.session.phase == BattleSession.Phase.ACTION_SELECTION and not battle.effects.is_playing() and battle._panel_targets[battle.action_panel.name], "Planning returns after all action animations finish")
	battle.attack_animation_duration = 0.0
	# Real resolution emits only the recipients actually chosen after retargeting.
	var received: Array = []
	battle.session.action_performed.connect(func(performed, targets, result): received.append([performed, targets, result]))
	battle.session.choose_attack()
	battle.session.select_target(target)
	while battle.session.phase == BattleSession.Phase.ACTION_SELECTION:
		battle.session.choose_defend()
	battle.session.begin_resolution()
	battle.session.resolve_next_action()
	check(received.size() == 1 and received[0][2].get("success", false), "Resolved actions supply presentation data")
	# Battle exit must wait for the final animation before its victory log hold.
	battle.attack_animation_duration = 0.3
	battle._animate_action(action, [target], {"success": true})
	for enemy in battle.session.enemies:
		enemy.current_hp = 0
	battle.session._check_finished()
	await process_frame
	check(battle.effects.is_playing() and not battle.get_node("BattleLog/Log").text.ends_with("Victory!"), "Victory presentation waits for the final attack")
	await battle.effects.wait_until_finished()
	await process_frame
	check(battle.get_node("BattleLog/Log").text.ends_with("Victory!"), "Victory follows the last animation")
	game.queue_free()
	await process_frame
	print("Battle animation tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
