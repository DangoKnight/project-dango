class_name RPGConsumables
extends RefCounted


## Callers supply valid faction targets. Validation completes before spending a use.
static func use_item(user: CharacterState, item: GearInstance, targets: Array[CharacterState]) -> Dictionary:
	if user == null or not user.is_alive():
		return {"success": false, "reason": "character_defeated"}
	if not user.can_act():
		return {"success": false, "reason": "cannot_act"}
	if item == null or item.definition == null or not item.definition.is_valid() or item.definition.kind != GearDefinition.Kind.CONSUMABLE or item.is_destroyed() or item not in user.get_equipped_gear():
		return {"success": false, "reason": "consumable_not_equipped_or_depleted"}
	if targets.is_empty():
		return {"success": false, "reason": "no_valid_targets"}
	var seen: Dictionary = {}
	for target in targets:
		if target == null or not target.is_alive() or seen.has(target):
			return {"success": false, "reason": "invalid_target"}
		seen[target] = true
	if item.definition.consumable_target == GearDefinition.Target.SELF and (targets.size() != 1 or targets[0] != user):
		return {"success": false, "reason": "invalid_target"}
	if item.definition.consumable_target in [GearDefinition.Target.ALLY, GearDefinition.Target.ENEMY] and targets.size() != 1:
		return {"success": false, "reason": "invalid_target"}
	var healed := 0
	var restored := 0
	var damage := 0
	item._spend_use()
	for target in targets:
		for effect in item.definition.effects:
			match effect.kind:
				ConsumableEffect.Kind.HEAL_HP:
					var old_hp := target.current_hp
					target.current_hp = mini(target.get_stat(&"max_hp"), target.current_hp + effect.amount)
					healed += target.current_hp - old_hp
				ConsumableEffect.Kind.RESTORE_MP:
					var old_mp := target.current_mp
					target.current_mp = mini(target.get_stat(&"max_mp"), target.current_mp + effect.amount)
					restored += target.current_mp - old_mp
				ConsumableEffect.Kind.DAMAGE:
					var defense := 0 if effect.defending_stat == "none" else target.get_stat(StringName(effect.defending_stat))
					var dealt := maxi(0, int(round(maxi(0, effect.amount - defense) * (1.0 - target.get_resistance(effect.damage_type)) * user.get_damage_multiplier())))
					if target.defending:
						dealt = int(ceil(dealt * 0.5))
					dealt = mini(target.current_hp, dealt)
					target.current_hp -= dealt
					damage += dealt
				ConsumableEffect.Kind.APPLY_STATUS:
					target.apply_status(effect.status)
		target.changed.emit()
	if item.is_destroyed():
		user.unequip_gear(item)
	else:
		user.changed.emit()
	return {"success": true, "reason": "", "healing": healed, "damage": damage, "sp_restored": restored, "remaining_uses": item.remaining_uses(), "destroyed": item.is_destroyed()}
