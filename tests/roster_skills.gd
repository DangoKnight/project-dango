extends SceneTree

const EXPLORER = preload("res://resources/rpg/classes/explorer.tres")
const VANGUARD = preload("res://resources/rpg/classes/vanguard.tres")
const ARCANIST = preload("res://resources/rpg/classes/arcanist.tres")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func character(name_text: String) -> CharacterState:
	return CharacterState.new(load("res://resources/rpg/characters/" + name_text + ".tres"))

func skill(name_text: String) -> AbilityDefinition:
	return load("res://resources/rpg/abilities/" + name_text + ".tres")

func target(hp: int = 999) -> CharacterState:
	var definition := CharacterDefinition.new()
	definition.id = &"test_target"
	definition.display_name = "Target"
	definition.base_stats = RPGStats.new()
	definition.base_stats.max_hp = hp
	return CharacterState.new(definition)

func resolve_round(session: BattleSession) -> void:
	check(session.begin_resolution(), "Planned round should resolve")
	while session.phase == BattleSession.Phase.RESOLVING:
		session.resolve_next_action()

func run() -> void:
	var names := ["usami", "takane", "kurako", "koumi"]
	var titles := ["The friendly rabbit", "The hunting hawk", "The prankster jellyfish", "Emotions hare"]
	var ids := [["jolly_cheer", "caring_friend"], ["lock_on", "ride_the_gale", "graceful_assault"], ["painful_stab", "immobilizing_stab", "i_am_scary"], ["bonk", "cover"]]
	for index in range(names.size()):
		var unit := character(names[index])
		check(unit.definition.portrait != null and unit.definition.portrait.resource_path.get_file() == names[index].capitalize() + "-chan.png", "Character uses the renamed portrait: " + names[index])
		check(unit.character_class == EXPLORER and unit.definition.title == titles[index], "Explorer class and requested title for " + names[index])
		check(unit.get_abilities().size() == ids[index].size(), "No old unique/class abilities on " + names[index])
		for ability_id in ids[index]:
			check(skill(ability_id) in unit.get_abilities() and skill(ability_id).is_valid(), "Requested skill configured: " + ability_id)
	for stat in [&"strength", &"defense", &"mental_acuity", &"mental_resilience", &"speed"]:
		check(EXPLORER.stat_growth.value(stat) == 1.0, "Explorer has balanced primary-stat growth")
	# Growth is accumulated at each level, using the class equipped for those levels.
	var growth_unit := character("usami")
	growth_unit.definition = growth_unit.definition.duplicate(true)
	growth_unit.definition.growth_variation = 0.0
	growth_unit.set_level(3)
	var before: Dictionary = {}
	for stat in RPGStats.NAMES:
		before[stat] = growth_unit.get_stat(stat)
	var before_raw := growth_unit._permanent_stats.duplicate()
	var hp := growth_unit.current_hp
	var mp := growth_unit.current_mp
	growth_unit.set_class(ARCANIST)
	for stat in RPGStats.NAMES:
		check(growth_unit.get_stat(stat) == before[stat], "Class change preserves " + String(stat))
	check(growth_unit.current_hp == hp and growth_unit.current_mp == mp, "Class change does not refill or reduce pools")
	growth_unit.set_level(5)
	check(growth_unit.get_stat(&"max_hp") == int(floor(before_raw[&"max_hp"] + 2.0 * growth_unit.get_growth(&"max_hp"))), "New levels use new class HP growth")
	check(growth_unit.get_stat(&"mental_acuity") == int(floor(before_raw[&"mental_acuity"] + 2.0 * growth_unit.get_growth(&"mental_acuity"))), "New class mental growth applies only to future levels")
	var earned := growth_unit.get_stat(&"strength")
	var earned_raw: float = growth_unit._permanent_stats[&"strength"]
	growth_unit.set_class(VANGUARD)
	check(growth_unit.get_stat(&"strength") == earned, "A second class change does not retroactively replace growth")
	growth_unit.set_level(6)
	check(growth_unit.get_stat(&"strength") == int(floor(earned_raw + growth_unit.get_growth(&"strength"))), "Fractional permanent growth accumulates across classes before rounding")
	growth_unit.set_level(1)
	check(growth_unit.level == 6, "Lower level request cannot remove permanent growth")
	var last := growth_unit.get_stat(&"strength")
	growth_unit.set_level(6)
	check(growth_unit.get_stat(&"strength") == last, "Repeated level request cannot farm growth")
	growth_unit.set_class(null)
	var last_raw: float = growth_unit._permanent_stats[&"strength"]
	growth_unit.set_level(7)
	check(growth_unit.get_stat(&"strength") == int(floor(last_raw + growth_unit.get_growth(&"strength"))), "Without a class only character growth applies")
	var temporary_unit := character("usami")
	temporary_unit.definition = temporary_unit.definition.duplicate(true)
	temporary_unit.definition.growth_variation = 0.0
	var original_strength: float = temporary_unit._permanent_stats[&"strength"]
	var iron := GearInstance.new(load("res://resources/rpg/gear/iron_artifact.tres"))
	temporary_unit.equip_gear(iron)
	temporary_unit.apply_status(skill("jolly_cheer").status_effect)
	temporary_unit.set_class(ARCANIST)
	temporary_unit.set_level(2)
	temporary_unit.unequip_gear(iron)
	temporary_unit.remove_status(&"jolly_cheer")
	check(temporary_unit.get_stat(&"strength") == int(floor(original_strength + temporary_unit.get_growth(&"strength"))), "Temporary buffs and gear never become permanent during class changes or level-ups")
	# Usami: single-ally buff and a group heal with one MP cost.
	var usami := character("usami")
	var takane := character("takane")
	var kurako := character("kurako")
	var koumi := character("koumi")
	var old_strength := takane.get_stat(&"strength")
	var old_defense := takane.get_stat(&"defense")
	check(RPGCombat.use_ability(usami, takane, skill("jolly_cheer")).success, "Jolly cheer applies to one ally")
	check(takane.get_stat(&"strength") == int(floor(old_strength * 1.25)) and takane.get_stat(&"defense") == int(floor(old_defense * 1.25)) and usami.get_active_statuses().is_empty(), "Jolly cheer affects only chosen ally")
	for unit in [usami, takane, kurako, koumi]:
		unit.current_hp -= 15
	var session := BattleSession.new([usami, takane, kurako, koumi], [target()])
	mp = usami.current_mp
	check(session.choose_ability(skill("caring_friend")) and session.valid_targets().size() == 4, "Group healing permits friendly confirmation targets")
	session.select_target(takane)
	check(usami.current_mp == mp, "Group planning does not spend MP")
	while session.phase == BattleSession.Phase.ACTION_SELECTION:
		session.choose_wait()
	resolve_round(session)
	check(usami.current_mp == mp - skill("caring_friend").mana_cost, "Full-party heal spends MP once")
	for unit in [usami, takane, kurako, koumi]:
		check(unit.current_hp > unit.get_stat(&"max_hp") - 15, "Full-party heal affects every living ally")
	usami.restore()
	var invalid_target := target()
	invalid_target.current_hp = 0
	mp = usami.current_mp
	hp = takane.current_hp
	check(not RPGCombat.use_ability_on_targets(usami, [takane, invalid_target], skill("caring_friend")).success and usami.current_mp == mp and takane.current_hp == hp, "Group validation finishes before spending MP or healing any target")
	check(not RPGCombat.use_ability_on_targets(usami, [takane, takane], skill("caring_friend")).success and usami.current_mp == mp, "Group casts reject duplicate recipients")
	# A selected group member can die before execution; other living allies still receive healing.
	var alive_ally := character("takane")
	var dying_ally := character("koumi")
	alive_ally.current_hp -= 15
	session = BattleSession.new([usami, alive_ally, dying_ally], [target()])
	session.choose_ability(skill("caring_friend"))
	session.select_target(dying_ally)
	while session.phase == BattleSession.Phase.ACTION_SELECTION:
		session.choose_wait()
	session.begin_resolution()
	dying_ally.current_hp = 0
	while session.phase == BattleSession.Phase.RESOLVING:
		session.resolve_next_action()
	check(alive_ally.current_hp > alive_ally.get_stat(&"max_hp") - 15 and dying_ally.current_hp == 0, "Group heal uses living recipients at execution and never revives")
	# Takane: crit boost, self speed buff, and unavoidable pierce attack.
	takane.restore()
	check(RPGCombat.use_ability(takane, takane, skill("lock_on")).success, "Lock-on executes")
	check(is_equal_approx(takane.get_combat_stat(&"critical_rate"), 0.7) and is_equal_approx(takane.get_combat_stat(&"critical_damage"), 2.5), "Lock-on massively boosts both critical traits")
	var speed := takane.get_stat(&"speed")
	RPGCombat.use_ability(takane, takane, skill("ride_the_gale"))
	check(takane.get_stat(&"speed") == int(floor(speed * 1.25)), "Ride the gale boosts speed")
	check(not RPGCombat.use_ability(takane, usami, skill("ride_the_gale")).success, "Self-only skill rejects another unit")
	var takane_def := takane.definition.duplicate() as CharacterDefinition
	takane_def.accuracy = 0
	takane_def.critical_rate = 0
	var inaccurate := CharacterState.new(takane_def)
	var enemy := target()
	enemy.definition.evasion = 1
	var result := RPGCombat.use_ability(inaccurate, enemy, skill("graceful_assault"))
	check(result.success and not result.missed and result.amount > 0 and skill("graceful_assault").damage_type.id == &"pierce", "Graceful assault bypasses accuracy and evasion")
	# Ordinary misses spend MP; forced critical hits use boosted damage.
	var koumi_def := koumi.definition.duplicate() as CharacterDefinition
	koumi_def.accuracy = 0
	var inaccurate_bonk := CharacterState.new(koumi_def)
	mp = inaccurate_bonk.current_mp
	result = RPGCombat.use_ability(inaccurate_bonk, enemy, skill("bonk"))
	check(result.success and result.missed and result.amount == 0 and inaccurate_bonk.current_mp == mp - skill("bonk").mana_cost, "Ordinary attacks can miss and spend their action cost")
	koumi_def = koumi.definition.duplicate() as CharacterDefinition
	koumi_def.accuracy = 1
	koumi_def.critical_rate = 1
	koumi_def.critical_damage = 2.5
	var critical_user := CharacterState.new(koumi_def)
	enemy = target()
	var normal := RPGCombat.calculate_amount(critical_user, enemy, skill("bonk"))
	result = RPGCombat.use_ability(critical_user, enemy, skill("bonk"))
	check(result.critical and result.amount == int(round(normal * 2.5)), "Critical hit multiplier changes actual damage")
	# Kurako: poison ticks exactly five times and refreshes instead of stacking.
	kurako.restore()
	enemy = target()
	RPGCombat.use_ability(kurako, enemy, skill("painful_stab"))
	hp = enemy.current_hp
	for turn in range(5):
		var tick := enemy.advance_status_turn()
		check(tick.damage == 3, "Weak poison damage on affected turn " + str(turn + 1))
	check(enemy.current_hp == hp - 15 and enemy.get_active_statuses().is_empty(), "Poison expires after five ticks")
	RPGCombat.use_ability(kurako, enemy, skill("painful_stab"))
	enemy.advance_status_turn()
	RPGCombat.use_ability(kurako, enemy, skill("painful_stab"))
	check(enemy.get_active_statuses().size() == 1 and enemy.get_active_statuses()[0].remaining_turns == 5, "Reapplying poison refreshes its five-turn duration")
	var poison_resist := DamageResistance.new()
	poison_resist.damage_type = load("res://resources/rpg/damage_types/poison.tres")
	poison_resist.amount = 1
	enemy.definition.resistances = [poison_resist]
	check(enemy.advance_status_turn().damage == 0, "Poison respects damage resistance")
	# Group debuff chooses foes, affects all living foes, and spends MP once.
	kurako.restore()
	var foe1 := target()
	var foe2 := target()
	foe1.definition.base_stats.strength = 10
	foe1.definition.base_stats.mental_acuity = 10
	foe1 = CharacterState.new(foe1.definition)
	foe2.definition.base_stats.strength = 10
	foe2.definition.base_stats.mental_acuity = 10
	foe2 = CharacterState.new(foe2.definition)
	session = BattleSession.new([kurako], [foe1, foe2])
	check(session.choose_ability(skill("i_am_scary")) and session.valid_targets().size() == 2 and kurako not in session.valid_targets(), "Enemy-party debuff enforces faction targeting")
	session.select_target(foe1)
	mp = kurako.current_mp
	resolve_round(session)
	check(kurako.current_mp == mp - skill("i_am_scary").mana_cost, "Enemy-party debuff spends MP once")
	for foe in [foe1, foe2]:
		check(foe.get_stat(&"strength") == 8 and foe.get_stat(&"mental_acuity") == 8, "Enemy-party debuff affects attack and mental acuity of each foe")
	# Paralysis cancels already queued actions for two turns without spending their MP.
	var fast_definition := kurako.definition.duplicate(true) as CharacterDefinition
	fast_definition.base_stats.speed = 100
	var fast_kurako := CharacterState.new(fast_definition)
	var caster := CharacterState.new(load("res://tests/fixtures/caster.tres"))
	session = BattleSession.new([fast_kurako], [caster])
	session.choose_ability(skill("immobilizing_stab"))
	session.select_target(caster)
	mp = caster.current_mp
	resolve_round(session)
	check(caster.current_mp == mp and not caster.can_act(), "Paralysis blocks queued action and preserves MP on first turn")
	session.choose_wait()
	resolve_round(session)
	check(caster.current_mp == mp and caster.can_act(), "Paralysis blocks second turn then expires")
	session.choose_wait()
	resolve_round(session)
	check(caster.current_mp < mp, "Enemy can act after paralysis expires")
	# Cover boosts defense and makes the unit more likely to receive enemy attacks.
	koumi.restore()
	old_defense = koumi.get_stat(&"defense")
	RPGCombat.use_ability(koumi, koumi, skill("cover"))
	check(koumi.get_stat(&"defense") == int(floor(old_defense * 1.25)) and koumi.get_combat_stat(&"aggro") == 2, "Cover boosts self defense and aggro")
	session = BattleSession.new([usami, koumi], [target()])
	session.rng.seed = 42
	var cover_targets := 0
	for index in range(1000):
		if session._aggro_target([usami, koumi], usami) == koumi:
			cover_targets += 1
	check(cover_targets > 650 and cover_targets < 850, "Cover's aggro weight increases target probability to about 75 percent in a two-unit party")
	var cover_defense := koumi.get_stat(&"defense")
	for turn in range(3):
		koumi.advance_status_turn()
	check(koumi.get_stat(&"defense") < cover_defense and koumi.get_active_statuses().is_empty() and koumi.get_combat_stat(&"aggro") == 1, "Cover expires and restores defense/aggro")
	# Poison can end battle, and action-blocking effects still permit Wait planning.
	fast_kurako.restore()
	var fragile := target(3)
	session = BattleSession.new([fast_kurako], [fragile])
	session.choose_ability(skill("painful_stab"))
	session.select_target(fragile)
	resolve_round(session)
	check(session.phase == BattleSession.Phase.FINISHED and session.victory, "Poison damage can finish combat")
	var paralysis: StatusEffectDefinition = load("res://resources/rpg/statuses/paralysis.tres")
	usami.restore()
	usami.apply_status(paralysis)
	session = BattleSession.new([usami], [target()])
	check(not session.choose_attack() and not session.choose_ability(skill("jolly_cheer")) and session.choose_wait(), "Paralyzed party member can only plan Wait")
	# Actual battle presentation supports group targets without instructions.
	var view := load("res://scenes/battle/combat.tscn").instantiate() as CombatScreen
	root.add_child(view)
	var encounter := BattleEncounter.new()
	encounter.enemies = [load("res://resources/rpg/enemies/sentinel.tres")]
	usami = character("usami")
	view.configure([usami, character("takane"), character("kurako"), character("koumi")], encounter)
	view.session.choose_ability(skill("caring_friend"))
	check(not view._panel_targets[view.portrait.name] and view.prompt.text.is_empty() and not view.party_buttons[3].disabled, "Group spell UI hides portrait and permits fourth friendly target")
	view.session.select_target(view.session.party[3])
	check(view.session.active_character().definition.id == &"takane", "Group action advances to next character")
	view.queue_free()
	await process_frame
	print("Roster/skills tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
