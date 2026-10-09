extends SceneTree

const FRONTLINER = preload("res://tests/fixtures/frontliner.tres")
const CASTER = preload("res://tests/fixtures/caster.tres")
const VANGUARD = preload("res://resources/rpg/classes/vanguard.tres")
const ARCANIST = preload("res://resources/rpg/classes/arcanist.tres")
const EMBER = preload("res://resources/rpg/abilities/ember.tres")
const CLEAVE = preload("res://resources/rpg/abilities/cleave.tres")
const MEND = preload("res://resources/rpg/abilities/mend.tres")
const FIRE = preload("res://resources/rpg/damage_types/fire.tres")
const FROST = preload("res://resources/rpg/damage_types/frost.tres")
const ARCANE = preload("res://resources/rpg/damage_types/arcane.tres")
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func run() -> void:
	var frontliner := CharacterState.new(FRONTLINER)
	var caster := CharacterState.new(CASTER)
	check(frontliner.get_stat(&"max_hp") == 80 and frontliner.get_stat(&"strength") == 12, "Character and class base stats combine")
	check(frontliner.get_abilities().size() == 2 and CLEAVE not in frontliner.get_abilities(), "Unique and level-one class abilities are available")
	frontliner.set_level(3)
	check(frontliner.get_stat(&"max_hp") == 104 and frontliner.get_stat(&"strength") == 19, "Character and class growth combine")
	check(frontliner.get_stat(&"defense") == 14, "Fractional growth accumulates before rounding")
	check(CLEAVE in frontliner.get_abilities(), "Class ability unlocks at required level")
	check(frontliner.current_hp == 80, "Leveling does not automatically heal")
	frontliner.set_level(1)
	frontliner.set_level(3)
	check(frontliner.get_stat(&"defense") == 14, "Repeated or lower level requests cannot remove or duplicate permanent growth")
	var earned_stats := frontliner.get_stat(&"strength")
	frontliner.set_class(ARCANIST)
	check(frontliner.get_stat(&"strength") == earned_stats, "Class changes preserve earned stats")
	check(EMBER in frontliner.get_abilities() and CLEAVE not in frontliner.get_abilities(), "Changing class updates class abilities")
	check(FRONTLINER.unique_abilities[0] in frontliner.get_abilities(), "Changing class preserves character ability")
	frontliner.set_class(VANGUARD)
	frontliner = CharacterState.new(FRONTLINER)
	check(is_equal_approx(frontliner.get_resistance(FIRE), 0.2), "Character resistance applies")
	check(is_equal_approx(caster.get_resistance(ARCANE), 0.2), "Class resistance applies")
	check(is_equal_approx(frontliner.get_resistance(FROST), -0.25), "Weakness applies")
	check(RPGCombat.calculate_amount(caster, frontliner, EMBER) == 20, "Damage uses scaling, defense, and resistance")
	var neutral_fire := DamageType.new()
	neutral_fire.id = FIRE.id
	check(is_equal_approx(frontliner.get_resistance(neutral_fire), 0.2), "Types match by stable ID, not resource identity")
	var custom := DamageType.new()
	custom.id = &"custom"
	check(frontliner.get_resistance(custom) == 0.0, "Unconfigured damage types are neutral")
	var hp := frontliner.current_hp
	var mp := caster.current_mp
	var result := RPGCombat.use_ability(caster, frontliner, EMBER)
	check(result.success and result.amount == 20 and frontliner.current_hp == hp - 20, "Using an ability deals calculated damage")
	check(caster.current_mp == mp - EMBER.mana_cost, "Successful abilities spend MP")
	result = RPGCombat.use_ability(frontliner, caster, EMBER)
	check(not result.success and result.reason == "ability_not_known", "Unknown abilities are rejected")
	var forged := EMBER.duplicate() as AbilityDefinition
	forged.power = 999
	check(not RPGCombat.use_ability(caster, frontliner, forged).success, "An altered resource cannot impersonate a known ability")
	caster.current_mp = 0
	hp = frontliner.current_hp
	check(not RPGCombat.use_ability(caster, frontliner, EMBER).success and frontliner.current_hp == hp, "Insufficient MP leaves target unchanged")
	caster.set_level(2)
	caster.restore()
	check(MEND in caster.get_abilities(), "Second class has its own learned abilities")
	frontliner.current_hp = frontliner.get_stat(&"max_hp") - 2
	result = RPGCombat.use_ability(caster, frontliner, MEND)
	check(result.success and result.amount == 2 and frontliner.current_hp == frontliner.get_stat(&"max_hp"), "Healing clamps to max HP and reports actual healing")
	frontliner.current_hp = 1
	result = RPGCombat.use_ability(caster, frontliner, EMBER)
	check(result.amount == 1 and not frontliner.is_alive(), "Damage clamps at zero and reports actual damage")
	mp = caster.current_mp
	check(not RPGCombat.use_ability(caster, frontliner, MEND).success and caster.current_mp == mp, "Healing cannot resurrect or spend MP on a defeated target")
	check(not RPGCombat.use_ability(frontliner, caster, FRONTLINER.unique_abilities[0]).success, "Defeated characters cannot act")
	var another_frontliner := CharacterState.new(FRONTLINER)
	check(another_frontliner.current_hp == 80 and FRONTLINER.base_stats.max_hp == 60, "Runtime instances do not modify definitions or each other")
	var custom_def := FRONTLINER.duplicate(true) as CharacterDefinition
	var resistance := DamageResistance.new()
	resistance.damage_type = FIRE
	resistance.amount = 0.9
	custom_def.resistances.append(resistance)
	var immune := CharacterState.new(custom_def)
	var custom_class := VANGUARD.duplicate(true) as CharacterClass
	var class_resistance := DamageResistance.new()
	class_resistance.damage_type = FIRE
	class_resistance.amount = 0.1
	custom_class.resistances.append(class_resistance)
	var combined := CharacterState.new(FRONTLINER, custom_class)
	check(is_equal_approx(combined.get_resistance(FIRE), 0.3), "Character and class resistances add")
	var duplicate_unlock := AbilityUnlock.new()
	duplicate_unlock.ability = FRONTLINER.unique_abilities[0]
	custom_class.learned_abilities.append(duplicate_unlock)
	check(combined.get_abilities().size() == 2, "Abilities with the same ID are not duplicated")
	check(immune.get_resistance(FIRE) == 1.0 and RPGCombat.calculate_amount(caster, immune, EMBER) == 0, "Stacked resistance clamps at immunity")
	resistance.amount = -2.0
	check(immune.get_resistance(FIRE) == -1.0, "Weakness clamps at double damage")
	var raw := RPGCombat.calculate_amount(caster, another_frontliner, EMBER)
	check(RPGCombat.calculate_amount(caster, immune, EMBER) > raw, "Weakness increases damage")
	var empty := CharacterDefinition.new()
	var minimal := CharacterState.new(empty)
	check(minimal.get_stat(&"max_hp") == 1 and minimal.get_abilities().is_empty(), "Missing optional stats and class have safe defaults")
	check(RPGCombat.calculate_amount(caster, another_frontliner, AbilityDefinition.new()) == 0, "Invalid ability is rejected")
	var armored_def := FRONTLINER.duplicate(true) as CharacterDefinition
	armored_def.base_stats.mental_resilience = 9999
	check(RPGCombat.calculate_amount(caster, CharacterState.new(armored_def), EMBER) == 0, "Defense cannot cause negative damage")
	frontliner.set_level(1000)
	frontliner.restore()
	frontliner.set_level(-5)
	check(frontliner.level == 99 and frontliner.current_hp == frontliner.get_stat(&"max_hp"), "Level bounds apply and earned levels cannot be removed")
	print("RPG tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
