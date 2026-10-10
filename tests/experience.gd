extends SceneTree

var failures := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func unit(reward: float = 0.0, speed: float = 10.0) -> CharacterState:
	var definition := CharacterDefinition.new()
	definition.base_stats = RPGStats.new()
	definition.base_stats.max_hp = 100
	definition.base_stats.strength = 10
	definition.base_stats.speed = speed
	definition.stat_growth = RPGStats.new()
	definition.stat_growth.strength = 2
	definition.growth_variation = 0
	definition.base_experience_reward = reward
	return CharacterState.new(definition)


func resolve(session: BattleSession) -> void:
	while session.phase == BattleSession.Phase.ACTION_SELECTION:
		session.choose_wait()
	check(session.begin_resolution(), "Round starts resolving")
	while session.phase == BattleSession.Phase.RESOLVING:
		session.resolve_next_action()


func _initialize() -> void:
	check(load("res://resources/rpg/enemies/sentinel.tres").base_experience_reward == 20 and load("res://resources/rpg/enemies/acolyte.tres").base_experience_reward == 30, "Shipped enemies expose their authored base XP rewards")
	var actor := unit()
	var ally := unit()
	var enemy := unit(8, 1)
	var battle := BattleSession.new([actor, ally], [enemy])
	check(actor.stored_experience() == 0, "Planning grants no experience")
	resolve(battle)
	check(actor.stored_experience() == 8 and ally.stored_experience() == 8, "Each living character stores enemy base experience on round one")
	resolve(battle)
	check(actor.stored_experience() == 12, "Round two contributes half the base reward")
	enemy.current_hp = 1
	battle.choose_attack()
	battle.select_target(enemy)
	resolve(battle)
	check(battle.victory and actor.stored_experience() == 18 and ally.stored_experience() == 18, "Round three contributes a quarter plus the literal four-XP defeat bonus")
	battle.resolve_next_action()
	check(actor.stored_experience() == 18 and actor.level == 1, "Finished fights cannot duplicate rewards or apply levels")
	# Accumulated XP survives fights, but retreat rolls back only the current one.
	var second := unit(4, 1)
	enemy = unit(8, 1)
	battle = BattleSession.new([actor, ally], [enemy, second])
	enemy.current_hp = 1
	battle.choose_attack()
	battle.select_target(enemy)
	resolve(battle)
	check(actor.stored_experience() == 31, "Multiple enemies contribute, including a separate defeat bonus")
	battle.choose_run()
	resolve(battle)
	check(battle.escaped and actor.stored_experience() == 18 and ally.stored_experience() == 18, "Running removes all round and kill rewards from this encounter for the entire party")
	# Direct damage, status damage, and other HP changes all use the same knockout rule.
	actor.store_experience(1001, 40)
	actor.current_hp = 0
	check(actor.stored_experience() == 0, "A knockout clears unspent rewards from all fights")
	actor.store_experience(1002, 20)
	check(actor.stored_experience() == 0, "Downed units cannot bank XP")
	actor.restore()
	check(actor.stored_experience() == 0, "Reviving never restores lost experience")
	actor.store_experience(1003, 350)
	var strength := actor.get_stat(&"strength")
	check(actor.apply_stored_experience() == 2 and actor.level == 3 and actor.experience == 50, "Rest consumes 100 then 200 XP for two levels and retains overflow")
	check(actor.get_stat(&"strength") == strength + 4 and actor.stored_experience() == 0, "Rest levels use permanent growth and consume the bank once")
	check(actor.apply_stored_experience() == 0 and actor.experience == 50, "Repeated rest cannot reapply consumed XP")
	actor.store_experience(1004, 10)
	actor.current_hp = 0
	check(actor.experience == 50 and actor.level == 3, "Knockouts preserve already-applied experience and permanent levels")
	# A real enemy action downs one ally; the survivor retains their older bank.
	actor = unit()
	ally = unit()
	actor.current_hp = 1
	actor.store_experience(2001, 99)
	ally.store_experience(2001, 99)
	enemy = unit(8, 100)
	battle = BattleSession.new([actor, ally], [enemy])
	resolve(battle)
	check(not actor.is_alive() and actor.stored_experience() == 0 and ally.stored_experience() == 107, "Combat knockout wipes only the downed character's complete bank")
	resolve(battle)
	check(actor.stored_experience() == 0 and ally.stored_experience() == 111, "Downed party members gain no XP in later rounds")
	# Fractions remain exact instead of rounding away diminishing rewards.
	actor = unit()
	enemy = unit(0.5, 1)
	battle = BattleSession.new([actor], [enemy])
	resolve(battle)
	resolve(battle)
	check(actor.stored_experience() == 0.75, "Fractional per-round rewards accumulate")
	actor.apply_stored_experience()
	check(actor.experience == 0.75, "Applied fractional XP remains available for future levels")
	# Poison defeats pay once through the same battle reward path.
	actor = unit()
	enemy = unit(8, 1)
	battle = BattleSession.new([actor], [enemy])
	enemy.current_hp = 1
	enemy.apply_status(load("res://resources/rpg/statuses/painful_poison.tres"))
	resolve(battle)
	check(battle.victory and actor.stored_experience() == 9, "Poison defeats grant the round-one kill bonus")
	print("Experience tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
