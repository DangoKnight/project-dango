extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func unit(hp: float = 100, speed: float = 10) -> CharacterState:
	var definition := CharacterDefinition.new()
	definition.id = &"test_unit"
	definition.base_stats = RPGStats.new()
	definition.base_stats.max_hp = hp
	definition.base_stats.speed = speed
	definition.accuracy = 1
	definition.critical_rate = 0
	return CharacterState.new(definition)


func run() -> void:
	var small := unit(100)
	var large := unit(200)
	var enemy := unit(1000)
	var battle := BattleSession.new([small, large], [enemy])
	check(large.get_combat_stat(&"aggro") == 2 * small.get_combat_stat(&"aggro"), "Maximum HP determines base aggro")
	large.current_hp = 1
	check(large.get_combat_stat(&"aggro") == 200, "Injuries do not reduce aggro")
	battle.rng.seed = 200
	var large_hits := 0
	for index in range(3000):
		if battle._aggro_target([small, large], small) == large:
			large_hits += 1
	check(large_hits > 1900 and large_hits < 2100, "Double maximum HP attracts approximately twice as many attacks")
	var cover: StatusEffectDefinition = load("res://resources/rpg/statuses/cover.tres")
	large.apply_status(cover)
	check(large.get_combat_stat(&"aggro") == 400, "Cover multiplies HP-based aggro")
	check(is_equal_approx(RPGCombat.mitigate_damage(40, 20), 20), "Defense at K halves raw damage")
	check(is_equal_approx(RPGCombat.mitigate_damage(40, 40), 40.0 / 3.0), "Defense above raw power still allows damage")
	check(RPGCombat.mitigate_damage(40, 0) == 40, "Bypassing defense preserves raw damage")
	check(RPGCombat.mitigate_damage(0, 100) == 0, "Zero raw damage stays zero")

	# Each actor compares with the fastest living enemy, not the group average.
	var slow := unit(1000, 5)
	var fast := unit(1000, 20)
	var slow_enemy := unit(1000, 2)
	var fast_enemy := unit(1000, 10)
	battle = BattleSession.new([slow, fast], [slow_enemy, fast_enemy])
	check(is_equal_approx(battle.escape_chance(slow), 0.3), "Slow runner compares to fastest enemy")
	check(battle.escape_chance(fast) == 1, "Fast runner has their own escape chance")
	battle._escape_failures[slow] = 1
	check(is_equal_approx(battle.escape_chance(slow), 0.45) and battle.escape_chance(fast) == 1, "Failure bonus belongs to its runner")
	fast_enemy.current_hp = 0
	check(battle.escape_chance(slow) == 1, "Defeated enemies no longer impede escape")
	# A guaranteed failure followed by the other runner's success in the same round.
	slow = unit(1000, 10)
	fast = unit(1000, 10)
	enemy = unit(1000, 10)
	battle = BattleSession.new([slow, fast], [enemy])
	battle.rng.seed = 0
	# Find a seed whose first roll fails a 60 percent chance.
	while true:
		var test_seed := battle.rng.seed
		if battle.rng.randf() >= 0.6:
			battle.rng.seed = test_seed
			break
		battle.rng.seed = test_seed + 1
	battle._escape_failures[fast] = 7
	battle.choose_run()
	battle.choose_run()
	battle.begin_resolution()
	battle.resolve_next_action()
	check(not battle.escaped and battle.phase == BattleSession.Phase.RESOLVING and battle._escape_failures[slow] == 1, "Failed Run consumes only its actor's action and increments their bonus")
	battle.resolve_next_action()
	check(battle.escaped, "Another character gets an independent attempt in the same round")

	var kurako := CharacterState.new(load("res://resources/rpg/characters/kurako.tres"))
	kurako._permanent_stats[&"speed"] = 100
	var foes: Array[CharacterState] = []
	for index in range(6):
		foes.append(unit(1000, 1))
	foes[1].current_hp = 0
	battle = BattleSession.new([kurako], foes)
	var scary: AbilityDefinition = load("res://resources/rpg/abilities/i_am_scary.tres")
	battle.choose_ability(scary)
	check(battle.affected_targets(foes[0]) == [foes[0], foes[2]], "Upper row preview excludes dead slots without shifting rows")
	check(battle.affected_targets(foes[4]) == [foes[3], foes[4], foes[5]], "Lower row preview affects only that row")
	battle.select_target(foes[4])
	battle.begin_resolution()
	# The selected anchor dies after commitment; surviving row members still receive the effect.
	foes[4].current_hp = 0
	battle.resolve_next_action()
	check(foes[0].get_active_statuses().is_empty() and foes[2].get_active_statuses().is_empty(), "Row ability leaves the other row alone")
	check(not foes[3].get_active_statuses().is_empty() and not foes[5].get_active_statuses().is_empty(), "Row ability keeps its selected row when its anchor dies")
	check(kurako.current_mp == kurako.get_stat(&"max_mp") - scary.mana_cost, "Row ability spends SP once")

	# Real scene: hovering a single confirmation target highlights every recipient.
	var view: CombatScreen = load("res://scenes/battle/combat.tscn").instantiate()
	root.add_child(view)
	var encounter := BattleEncounter.new()
	for index in range(6):
		encounter.enemies.append(load("res://resources/rpg/enemies/rat.tres"))
	view.configure([CharacterState.new(load("res://resources/rpg/characters/kurako.tres")), CharacterState.new(load("res://resources/rpg/characters/usami.tres")), CharacterState.new(load("res://resources/rpg/characters/takane.tres"))], encounter)
	view.session.choose_ability(scary)
	view.enemy_slots[4].mouse_entered.emit()
	for index in range(6):
		check(view.enemy_slots[index]._group_highlight == (index >= 3), "Enemy row highlights match selected row: " + str(index))
	view.enemy_slots[4].mouse_exited.emit()
	for slot in view.enemy_slots:
		check(not slot._group_highlight, "Leaving a target clears group highlights")
	view.session.cancel_target()
	var cheer: AbilityDefinition = load("res://resources/rpg/abilities/jolly_cheer.tres")
	view.session.choose_wait() # Usami plans the party buff.
	view.session.choose_ability(cheer)
	view.party_buttons[0].mouse_entered.emit()
	for index in range(3):
		check(view.party_buttons[index].self_modulate != Color.WHITE, "All friendly group targets highlight their cards")
	view.session.cancel_target()
	check(view.party_buttons[0].self_modulate == Color.WHITE, "Cancelling target mode clears friendly highlights")
	var item_definition: GearDefinition = load("res://resources/rpg/gear/frailty_bomb.tres").duplicate(true)
	item_definition.consumable_target = GearDefinition.Target.ENEMIES
	var item := GearInstance.new(item_definition)
	view.session.active_character().equip_gear(item)
	view.session.choose_consumable(item)
	view.enemy_slots[0].mouse_entered.emit()
	for slot in view.enemy_slots:
		check(slot._group_highlight, "All-enemy consumable highlights every recipient")
	view.session.cancel_target()
	for slot in view.enemy_slots:
		check(not slot._group_highlight, "Cancel clears all enemy group highlights")
	view.queue_free()
	await process_frame
	print("Combat rules tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
