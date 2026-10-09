class_name RPGCombat
extends RefCounted

const BASIC_ATTACK: AbilityDefinition = preload("res://resources/rpg/abilities/basic_attack.tres")


static func use_basic_attack(user: CharacterState, target: CharacterState, rng: RandomNumberGenerator = null) -> Dictionary:
	if user == null or target == null or not user.is_alive() or not target.is_alive():
		return _failure("character_defeated")
	if not user.can_act():
		return _failure("cannot_act")
	return _apply_effect(user, target, BASIC_ATTACK, rng)


static func calculate_amount(user: CharacterState, target: CharacterState, ability: AbilityDefinition) -> int:
	if user == null or target == null or ability == null or not ability.is_valid():
		return 0
	if ability.effect == AbilityDefinition.Effect.STATUS:
		return 0
	var raw := ability.power + user.get_stat(StringName(ability.scaling_stat)) * ability.scaling
	if ability.effect == AbilityDefinition.Effect.HEAL:
		return maxi(0, int(round(raw)))
	var defense := 0 if ability.defending_stat == "none" else target.get_stat(StringName(ability.defending_stat))
	return maxi(0, int(round(maxf(0.0, raw - defense) * (1.0 - target.get_resistance(ability.damage_type)) * user.get_damage_multiplier())))


static func use_ability(user: CharacterState, target: CharacterState, ability: AbilityDefinition, rng: RandomNumberGenerator = null) -> Dictionary:
	return use_ability_on_targets(user, [target], ability, rng)


## Callers supply the correct faction/group. Validate every recipient before spending MP once.
static func use_ability_on_targets(user: CharacterState, targets: Array[CharacterState], ability: AbilityDefinition, rng: RandomNumberGenerator = null) -> Dictionary:
	if user == null or ability == null or not ability.is_valid() or targets.is_empty():
		return _failure("invalid_ability_or_character")
	if not user.is_alive():
		return _failure("character_defeated")
	if not user.can_act():
		return _failure("cannot_act")
	if ability not in user.get_abilities():
		return _failure("ability_not_known")
	if user.current_mp < ability.mana_cost:
		return _failure("insufficient_mp")
	if ability.targeting not in [AbilityDefinition.Target.PARTY, AbilityDefinition.Target.ENEMIES] and targets.size() != 1:
		return _failure("invalid_target")
	if ability.targeting == AbilityDefinition.Target.SELF and targets[0] != user:
		return _failure("invalid_target")
	var seen: Dictionary = {}
	for target in targets:
		if target == null or not target.is_alive():
			return _failure("character_defeated")
		if seen.has(target):
			return _failure("invalid_target")
		seen[target] = true
	user.current_mp -= ability.mana_cost
	var total := 0
	var results: Array[Dictionary] = []
	for target in targets:
		var result := _apply_effect(user, target, ability, rng)
		total += result.amount
		results.append(result)
	user.changed.emit()
	var summary := {"success": true, "reason": "", "amount": total, "missed": results.size() == 1 and results[0].missed, "critical": results.size() == 1 and results[0].critical, "targets": results}
	if ability.effect == AbilityDefinition.Effect.STATUS:
		summary.status_id = ability.status_effect.id
	return summary


static func _apply_effect(user: CharacterState, target: CharacterState, ability: AbilityDefinition, rng: RandomNumberGenerator) -> Dictionary:
	var critical := false
	if ability.effect == AbilityDefinition.Effect.DAMAGE:
		var hit_chance := clampf(ability.hit_chance * user.get_combat_stat(&"accuracy") - target.get_combat_stat(&"evasion"), 0.0, 1.0)
		if not ability.guaranteed_hit and hit_chance < 1.0 and (hit_chance <= 0.0 or _roll(rng) >= hit_chance):
			return {"success": true, "reason": "", "amount": 0, "missed": true, "critical": false}
		var critical_rate := user.get_combat_stat(&"critical_rate")
		critical = ability.can_crit and critical_rate > 0.0 and (critical_rate >= 1.0 or _roll(rng) < critical_rate)
	var amount := calculate_amount(user, target, ability)
	var old_hp := target.current_hp
	if ability.effect == AbilityDefinition.Effect.HEAL:
		target.current_hp = mini(target.get_stat(&"max_hp"), target.current_hp + amount)
	elif ability.effect == AbilityDefinition.Effect.STATUS:
		target.apply_status(ability.status_effect)
	else:
		if critical:
			amount = maxi(0, int(round(amount * user.get_combat_stat(&"critical_damage"))))
		if target.defending:
			amount = int(ceil(amount * 0.5))
		target.current_hp = maxi(0, target.current_hp - amount)
	target.changed.emit()
	return {"success": true, "reason": "", "amount": absi(target.current_hp - old_hp), "missed": false, "critical": critical}


static func _roll(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng != null else randf()


static func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason, "amount": 0}
