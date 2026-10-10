extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func unit(reward: float = 0.0, speed: float = 10.0) -> CharacterState:
	var definition := CharacterDefinition.new()
	definition.base_stats = RPGStats.new()
	for stat in RPGStats.NAMES:
		definition.base_stats.set(stat, 11.0)
	definition.base_stats.max_hp = 41
	definition.base_stats.speed = speed
	definition.accuracy = 1
	definition.evasion = 0.2
	definition.critical_rate = 0.1
	definition.base_experience_reward = reward
	return CharacterState.new(definition)


func resolve(session: BattleSession) -> void:
	while session.phase == BattleSession.Phase.ACTION_SELECTION:
		session.choose_wait()
	session.begin_resolution()
	while session.phase == BattleSession.Phase.RESOLVING:
		session.resolve_next_action()


func run() -> void:
	var actor := unit()
	var ally := unit()
	var enemy := unit(8, 1)
	var session := BattleSession.new([actor, ally], [enemy])
	var before: Dictionary = {}
	for stat in RPGStats.ALL_NAMES:
		before[stat] = actor.get_stat(stat) if stat in RPGStats.NAMES else actor.get_combat_stat(stat)
	session.toggle_observe()
	check(actor.observing and not ally.observing and session.planned_actions.is_empty(), "Observe toggles only the active character without consuming their action")
	for stat in RPGStats.NAMES:
		var factor := 1.0 if stat in [&"max_hp", &"max_mp"] else 0.5
		check(actor.get_stat(stat) == int(floor(before[stat] * factor)), "Observe affects only non-vital stats: " + stat)
	for stat in RPGStats.COMBAT_NAMES:
		check(is_equal_approx(actor.get_combat_stat(stat), before[stat] * 0.5), "Observe halves hidden stat internally: " + stat)
	check(actor.current_hp == 41 and actor.current_mp == 11, "Observe leaves current HP and SP unchanged")
	for cycle in range(10):
		session.toggle_observe()
		session.toggle_observe()
	session.toggle_observe()
	check(actor.current_hp == 41 and actor.current_mp == 11, "Repeated toggles preserve odd HP/SP without healing or draining them")
	session.toggle_observe()
	actor.current_hp -= 3
	actor.current_mp -= 1
	session.toggle_observe()
	check(actor.current_hp == 38 and actor.current_mp == 10, "Toggling off preserves damage and spent SP without rescaling")
	actor.current_mp = 1
	session.toggle_observe()
	session.toggle_observe()
	check(actor.current_mp == 1, "Low SP stays unchanged across Observe toggles")
	actor.restore()
	actor.store_experience(999, 50)
	session.toggle_observe()
	# Guaranteed hits remain reliable even with Observe's reduced accuracy.
	var assault := load("res://resources/rpg/abilities/graceful_assault.tres") as AbilityDefinition
	actor.definition.unique_abilities = [assault]
	actor.definition.critical_rate = 0.0
	enemy.definition.evasion = 0.0
	resolve(session)
	check(actor.stored_experience() == 62 and ally.stored_experience() == 8, "Observe boosts round XP by 50% without changing prior XP or other characters")
	enemy.current_hp = 1
	session.choose_ability(assault)
	session.select_target(enemy)
	session.choose_wait()
	session.begin_resolution()
	session.toggle_observe()
	check(actor.observing, "Observe cannot toggle after round commitment")
	while session.phase == BattleSession.Phase.RESOLVING:
		session.resolve_next_action()
	check(session.victory and actor.stored_experience() == 71 and ally.stored_experience() == 14, "Observe also boosts defeat XP independently for that character")
	check(not actor.observing and actor.get_stat(&"max_hp") == 41, "Battle end clears Observe and restores ordinary stats")
	# Retreat removes boosted rewards, and knockout still clears every unspent reward.
	enemy = unit(8, 1)
	session = BattleSession.new([actor, ally], [enemy])
	session.toggle_observe()
	session.choose_run()
	resolve(session)
	check(actor.stored_experience() == 71 and ally.stored_experience() == 14 and not actor.observing, "Retreat discards current boosted XP and clears Observe")
	actor.current_hp = 0
	check(actor.stored_experience() == 0, "Observe rewards obey the full knockout penalty")
	# Verify the actual battle button remains checked and leaves the action menu open.
	var battle := load("res://scenes/battle/combat.tscn").instantiate() as CombatScreen
	root.add_child(battle)
	actor = unit()
	var party: Array[CharacterState] = [actor]
	battle.configure(party, battle.default_encounter)
	battle._toggle_observe()
	var found := false
	for button in battle.actions.get_children():
		if button.text == "Observe":
			found = button.toggle_mode and button.button_pressed
	check(found and battle.session.phase == BattleSession.Phase.ACTION_SELECTION and battle.session.planned_actions.is_empty(), "Observe is a checked toggle in the battle action menu")
	battle.queue_free()
	await process_frame
	print("Observe tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
