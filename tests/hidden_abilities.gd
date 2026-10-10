extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func unit(name_text: String) -> CharacterState:
	var definition := load("res://resources/rpg/characters/" + name_text + ".tres").duplicate(true) as CharacterDefinition
	definition.base_stats.max_hp = 90 # Explorer adds 10, making thresholds exact.
	definition.accuracy = 1.0
	definition.critical_rate = 0.0
	return CharacterState.new(definition)


func run() -> void:
	var usami := unit("usami")
	var takane := unit("takane")
	var kurako := unit("kurako")
	var koumi := unit("koumi")
	var foe := CharacterState.new(load("res://resources/rpg/enemies/sentinel.tres"), null, 2)
	var base_speed := usami.get_stat(&"speed")
	var base_acuity := kurako.get_stat(&"mental_acuity")
	var koumi_base: Dictionary = {}
	for stat in RPGStats.NAMES:
		koumi_base[stat] = koumi.get_stat(stat)
	var normal_damage := RPGCombat.calculate_amount(takane, foe, RPGCombat.BASIC_ATTACK)
	var battle := BattleSession.new([usami, takane, kurako, koumi], [foe])
	check(usami.get_stat(&"speed") == int(floor(base_speed * 1.2)), "Happy friends activates for a healthy party")
	usami.current_hp = 70
	check(usami.get_stat(&"speed") == base_speed, "Exactly 70 percent does not count as above 70")
	usami.current_hp = 71
	check(usami.get_stat(&"speed") == int(floor(base_speed * 1.2)), "Healing above threshold activates immediately")
	takane.current_hp = 0
	check(usami.get_stat(&"speed") == base_speed, "Downed allies prevent Happy friends")
	takane.restore()
	usami.current_hp = 50
	check(is_equal_approx(takane.get_damage_multiplier(), 1.0), "Overprotective sister does not activate at exactly half health")
	usami.current_hp = 49
	check(is_equal_approx(takane.get_damage_multiplier(), 1.2), "Hurt Usami activates 120 percent damage")
	var expected := int(round(normal_damage * 1.2))
	check(RPGCombat.calculate_amount(takane, foe, RPGCombat.BASIC_ATTACK) == expected, "Passive affects calculated attack damage")
	usami.current_hp = 0
	check(is_equal_approx(takane.get_damage_multiplier(), 1.5), "Downed Usami grants 150 percent, without stacking")
	usami.restore()
	check(is_equal_approx(takane.get_damage_multiplier(), 1.0), "Recovering Usami removes the damage bonus")
	check(kurako.get_stat(&"mental_acuity") == base_acuity, "Higher-level healthy enemies do not activate Easy target")
	var harmful := StatusEffectDefinition.new()
	harmful.id = &"test_debuff"
	harmful.stat_percent_modifiers = {&"strength": -1.0}
	foe.apply_status(harmful)
	check(kurako.get_stat(&"mental_acuity") == int(floor(base_acuity * 1.2)), "A debuffed enemy activates Easy target")
	foe.remove_status(harmful.id)
	harmful.stat_percent_modifiers = {}
	harmful.is_negative = true
	foe.apply_status(harmful)
	check(kurako.get_stat(&"mental_acuity") == int(floor(base_acuity * 1.2)), "Explicit negative statuses activate Easy target")
	foe.remove_status(harmful.id)
	foe.apply_status(load("res://resources/rpg/statuses/paralysis.tres"))
	check(kurako.get_stat(&"mental_acuity") == int(floor(base_acuity * 1.2)), "Paralysis activates Easy target")
	foe.remove_status(&"paralysis")
	foe.apply_status(load("res://resources/rpg/statuses/painful_poison.tres"))
	check(kurako.get_stat(&"mental_acuity") == int(floor(base_acuity * 1.2)), "Poison activates Easy target")
	for status in foe.get_active_statuses():
		foe.remove_status(status.definition.id)
	foe.apply_status(load("res://resources/rpg/statuses/fortified.tres"))
	check(kurako.get_stat(&"mental_acuity") == base_acuity, "Beneficial enemy statuses do not activate Easy target")
	kurako.set_level(3)
	var boosted_acuity := kurako.get_stat(&"mental_acuity")
	foe.set_level(3)
	var unboosted_acuity := kurako.get_stat(&"mental_acuity")
	check(boosted_acuity == int(floor(kurako._permanent_stats[&"mental_acuity"] * 1.2)), "A lower-level foe activates Easy target without a debuff")
	var low_foe := CharacterState.new(foe.definition)
	battle.enemies.append(low_foe)
	check(kurako.get_stat(&"mental_acuity") == boosted_acuity, "Any qualifying enemy activates the bonus once")
	low_foe.current_hp = 0
	check(kurako.get_stat(&"mental_acuity") == unboosted_acuity, "Defeated qualifying enemies do not activate Easy target")
	battle.enemies.erase(low_foe)
	for round_index in range(1, 5):
		battle.round_number = round_index
		for stat in RPGStats.NAMES:
			var multiplier := 1.0 if stat in [&"max_hp", &"max_mp"] else 1.1
			check(koumi.get_stat(stat) == int(floor(float(koumi_base[stat]) * multiplier)), "Collected applies only to the five combat stats: %s in round %d" % [stat, round_index])
	koumi.restore()
	battle.round_number = 5
	battle._start_round()
	for stat in RPGStats.NAMES:
		check(koumi.get_stat(stat) == koumi_base[stat], "Collected expires without changing permanent " + String(stat))
	check(koumi.current_hp == koumi.get_stat(&"max_hp") and koumi.current_mp == koumi.get_stat(&"max_mp"), "Collected leaves HP and SP limits unchanged")
	for character in battle.party:
		for ability in character.get_abilities():
			check(ability.id != character.definition.hidden_abilities[0].id, "Hidden abilities stay out of action menus")
	foe.current_hp = 0
	battle._check_finished()
	check(usami.get_stat(&"speed") == base_speed and is_equal_approx(takane.get_damage_multiplier(), 1.0), "Battle end clears passive effects")
	var next_battle := BattleSession.new([koumi], [CharacterState.new(foe.definition)])
	check(next_battle.round_number == 1 and koumi.get_stat(&"strength") == int(floor(float(koumi_base[&"strength"]) * 1.1)), "Collected resets for the next fight")
	print("Hidden ability tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
