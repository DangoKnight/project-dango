extends SceneTree

const FRONTLINER = preload("res://tests/fixtures/frontliner.tres")
const CASTER = preload("res://tests/fixtures/caster.tres")
const ARCANIST = preload("res://resources/rpg/classes/arcanist.tres")
const FORTIFY = preload("res://resources/rpg/abilities/fortify.tres")
const ENFEEBLE = preload("res://resources/rpg/abilities/enfeeble.tres")
const FORTIFIED = preload("res://resources/rpg/statuses/fortified.tres")
const EMBER = preload("res://resources/rpg/abilities/ember.tres")
const SWORD = preload("res://resources/rpg/weapon_types/sword.tres")
const HAMMER = preload("res://resources/rpg/weapon_types/hammer.tres")
const SPEAR = preload("res://resources/rpg/weapon_types/spear.tres")
const DAGGER = preload("res://resources/rpg/weapon_types/dagger.tres")
const SWORD_WEAPON = preload("res://resources/rpg/weapons/training_sword.tres")
const STAFF_WEAPON = preload("res://resources/rpg/weapons/apprentice_staff.tres")
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
	check(frontliner.equipped_weapon == SWORD_WEAPON and caster.equipped_weapon == STAFF_WEAPON, "Allowed starting weapons should equip")
	check(frontliner.can_equip_weapon_type(SWORD), "A type allowed by character and class should pass")
	check(not frontliner.can_equip_weapon_type(HAMMER), "Character restrictions should reject a class-allowed type")
	check(not frontliner.can_equip_weapon_type(SPEAR), "Class restrictions should reject a character-allowed type")
	check(not caster.can_equip_weapon_type(DAGGER), "Arcanist should restrict Test Caster's dagger proficiency")
	check(frontliner.get_allowed_weapon_types().size() == 2, "Effective allowed types should be the intersection")
	check(not frontliner.equip_weapon(STAFF_WEAPON) and frontliner.equipped_weapon == SWORD_WEAPON, "Rejected equipment should preserve the current weapon")
	check(not frontliner.equip_weapon(WeaponDefinition.new()), "Malformed weapons should be rejected")
	var same_type := WeaponType.new()
	same_type.id = SWORD.id
	check(frontliner.can_equip_weapon_type(same_type), "Weapon types should match by ID")
	check(not frontliner.can_equip_weapon_type(null), "Missing weapon types should be rejected")
	check(frontliner.equip_weapon(null) and frontliner.equipped_weapon == null, "Null should unequip")
	frontliner.equip_weapon(SWORD_WEAPON)
	frontliner.set_class(ARCANIST)
	check(frontliner.equipped_weapon == null and frontliner.get_allowed_weapon_types().is_empty() and frontliner.has_weapon_restrictions(), "Class changes should unequip invalid weapons and allow an empty intersection")
	var unrestricted := CharacterState.new(CharacterDefinition.new())
	check(not unrestricted.has_weapon_restrictions() and unrestricted.can_equip_weapon_type(SWORD), "Empty character and class lists should be unrestricted")
	var character_only := FRONTLINER.duplicate() as CharacterDefinition
	character_only.starting_class = null
	var no_class := CharacterState.new(character_only)
	check(no_class.can_equip_weapon_type(SPEAR) and not no_class.can_equip_weapon_type(HAMMER), "No class should leave only the character's restrictions")
	var class_only := CharacterState.new(CharacterDefinition.new(), ARCANIST)
	check(class_only.can_equip_weapon(STAFF_WEAPON) and not class_only.can_equip_weapon(SWORD_WEAPON), "An unrestricted character should obey class restrictions")
	var invalid_start := CASTER.duplicate() as CharacterDefinition
	invalid_start.starting_weapon = SWORD_WEAPON
	check(CharacterState.new(invalid_start).equipped_weapon == null, "Invalid starting weapons should not equip")
	frontliner = CharacterState.new(FRONTLINER, null, 2)
	check(FORTIFY in frontliner.get_abilities(), "Status abilities should unlock through the class")
	var base_defense := frontliner.get_stat(&"defense")
	var hp := frontliner.current_hp
	var mp := frontliner.current_mp
	var result := RPGCombat.use_ability(frontliner, frontliner, FORTIFY)
	check(result.success and result.amount == 0 and result.status_id == FORTIFIED.id, "Status abilities should report application without damage")
	check(frontliner.current_hp == hp and frontliner.current_mp == mp - FORTIFY.mana_cost, "Status application should spend MP and preserve HP")
	check(frontliner.get_stat(&"defense") == int(floor(frontliner._permanent_stats[&"defense"] * 1.25)), "Buffs should modify stats")
	check(RPGCombat.calculate_amount(frontliner, caster, FORTIFY) == 0, "Status previews should not predict HP damage")
	frontliner.advance_status_turn()
	check(frontliner.get_active_statuses()[0].remaining_turns == 2, "Turn advancement should decrement duration")
	RPGCombat.use_ability(frontliner, frontliner, FORTIFY)
	check(frontliner.get_active_statuses().size() == 1 and frontliner.get_active_statuses()[0].remaining_turns == 3 and frontliner.get_stat(&"defense") == int(floor(frontliner._permanent_stats[&"defense"] * 1.25)), "Reapplication should refresh, not stack")
	var snapshot := frontliner.get_active_statuses()
	snapshot[0].remaining_turns = 999
	check(frontliner.get_active_statuses()[0].remaining_turns == 3, "Status snapshots should not expose mutable duration state")
	var other_frontliner := CharacterState.new(FRONTLINER, null, 2)
	check(other_frontliner.get_stat(&"defense") == base_defense and other_frontliner.get_active_statuses().is_empty(), "Statuses should be local to an instance")
	for turn in range(3):
		frontliner.advance_status_turn()
	check(frontliner.get_active_statuses().is_empty() and frontliner.get_stat(&"defense") == base_defense, "Expired statuses should remove their modifiers")
	caster.set_level(3)
	caster.restore()
	var before_damage := RPGCombat.calculate_amount(caster, frontliner, EMBER)
	result = RPGCombat.use_ability(caster, frontliner, ENFEEBLE)
	check(result.success and RPGCombat.calculate_amount(caster, frontliner, EMBER) > before_damage, "Debuffs should affect subsequent combat calculations")
	check(frontliner.remove_status(ENFEEBLE.status_effect.id) and RPGCombat.calculate_amount(caster, frontliner, EMBER) == before_damage, "Removing a status should restore the original stats")
	check(not frontliner.remove_status(&"missing"), "Removing an absent status should be harmless")
	frontliner.current_mp = 0
	check(not RPGCombat.use_ability(frontliner, caster, FORTIFY).success and caster.get_active_statuses().is_empty(), "Insufficient MP must not apply statuses")
	frontliner.restore()
	caster.current_hp = 0
	mp = frontliner.current_mp
	check(not RPGCombat.use_ability(frontliner, caster, FORTIFY).success and frontliner.current_mp == mp, "Defeated targets should reject statuses without spending MP")
	var malformed := AbilityDefinition.new()
	malformed.id = &"bad_status"
	malformed.effect = AbilityDefinition.Effect.STATUS
	check(not malformed.is_valid(), "Status abilities require a valid status definition")
	var bad_status := StatusEffectDefinition.new()
	bad_status.id = &"bad"
	bad_status.stat_percent_modifiers[&"unknown_stat"] = 4.0
	check(not frontliner.apply_status(bad_status), "Unknown stat modifiers should be rejected")
	bad_status.stat_percent_modifiers.clear()
	bad_status.duration_turns = 0
	check(not bad_status.is_valid(), "Zero-duration statuses should be rejected")
	var hp_buff := StatusEffectDefinition.new()
	hp_buff.id = &"vigor"
	hp_buff.duration_turns = 1
	hp_buff.stat_percent_modifiers[&"max_hp"] = 0.25
	frontliner.apply_status(hp_buff)
	frontliner.restore()
	frontliner.advance_status_turn()
	check(frontliner.current_hp == frontliner.get_stat(&"max_hp"), "Expiration of max-HP buffs should clamp current HP")
	check(FORTIFIED.stat_percent_modifiers[&"defense"] == 0.25 and FORTIFIED.duration_turns == 3, "Applying and expiring statuses must not mutate definitions")
	# Percentages scale raw stats and equipment, retain fractions until final rounding,
	# combine additively across effects, and leave permanent progression untouched.
	var scaled := CharacterState.new(CharacterDefinition.new())
	scaled._permanent_stats[&"strength"] = 40.5
	var permanent := scaled._permanent_stats.duplicate()
	var artifact := GearDefinition.new()
	artifact.id = &"percentage_fixture"
	artifact.stat_modifiers = {&"strength": 3.5}
	scaled.equip_gear(GearInstance.new(artifact))
	var buff := StatusEffectDefinition.new()
	buff.id = &"percentage_buff"
	buff.stat_percent_modifiers = {&"strength": 0.25, &"critical_rate": 0.25, &"accuracy": 0.1, &"evasion": 0.2, &"critical_damage": 1.0}
	scaled.apply_status(buff)
	check(scaled.get_stat(&"strength") == 55, "Percentage buff includes equipment and unrounded permanent stats")
	check(is_equal_approx(scaled.get_combat_stat(&"critical_rate"), scaled.definition.critical_rate + 0.25), "Critical rate adds percentage points")
	check(scaled.get_combat_stat(&"accuracy") == 1.0, "Accuracy caps at full accuracy after additive bonuses")
	check(is_equal_approx(scaled.get_combat_stat(&"evasion"), 0.2), "Additive evasion works from a zero base")
	check(is_equal_approx(scaled.get_combat_stat(&"critical_damage"), scaled.definition.critical_damage + 1.0), "Critical damage adds percentage points to its multiplier")
	scaled.apply_status(buff)
	check(scaled.get_stat(&"strength") == 55, "Reapplying a percentage effect never compounds it")
	var debuff := StatusEffectDefinition.new()
	debuff.id = &"percentage_debuff"
	debuff.stat_percent_modifiers = {&"strength": -0.2}
	scaled.apply_status(debuff)
	check(scaled.get_stat(&"strength") == 46 and debuff.is_harmful(), "Buff and debuff percentages add before a single rounding")
	debuff.stat_percent_modifiers[&"critical_rate"] = -0.1
	check(is_equal_approx(scaled.get_combat_stat(&"critical_rate"), scaled.definition.critical_rate + 0.15), "Rate bonuses and penalties add together")
	debuff.stat_percent_modifiers[&"critical_rate"] = -2.0
	check(scaled.get_combat_stat(&"critical_rate") == 0.0, "Rate debuffs clamp at zero")
	debuff.stat_percent_modifiers[&"strength"] = -2.0
	check(scaled.get_stat(&"strength") == 0, "Severe debuffs cannot produce negative stats")
	scaled.remove_status(buff.id)
	scaled.remove_status(debuff.id)
	check(scaled.get_stat(&"strength") == 44 and scaled._permanent_stats == permanent, "Removing effects restores equipment-adjusted stats without changing permanent values")
	buff.stat_percent_modifiers[&"strength"] = INF
	check(not buff.is_valid(), "Nonfinite percentage modifiers are rejected")
	print("Equipment/status tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
