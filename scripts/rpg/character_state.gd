class_name CharacterState
extends RefCounted

signal changed

const MAX_LEVEL := 99
const GEAR_LIMIT := 4
const GEAR_TYPE_LIMITS := [3, 1, 1]
var definition: CharacterDefinition
var character_class: CharacterClass
var level: int = 1
var current_hp: int
var current_mp: int
var defending := false
var equipped_weapon: WeaponDefinition
var _permanent_stats: Dictionary[StringName, float] = {}
var _statuses: Dictionary = {}
var _gear: Array[GearInstance] = []
var _battle_context: WeakRef


func _init(character: CharacterDefinition, class_override: CharacterClass = null, starting_level: int = 1) -> void:
	assert(character != null, "A character definition is required")
	definition = character
	character_class = class_override if class_override != null else character.starting_class
	for stat in RPGStats.NAMES:
		_permanent_stats[stat] = _stat_part(definition.base_stats, stat) + (_stat_part(character_class.base_stats, stat) if character_class != null else 0.0)
	set_level(starting_level)
	for gear in definition.starting_gear:
		if gear != null:
			equip_gear(GearInstance.new(gear))
	current_hp = get_stat(&"max_hp")
	current_mp = get_stat(&"max_mp")
	if can_equip_weapon(definition.starting_weapon):
		equipped_weapon = definition.starting_weapon


func get_stat(stat: StringName) -> int:
	if stat not in RPGStats.NAMES:
		return 0
	var total: float = _permanent_stats.get(stat, 0.0)
	for status in _statuses.values():
		total += float(status.definition.stat_modifiers.get(stat, 0.0))
	for item in _gear:
		if item.definition.kind == GearDefinition.Kind.ARTIFACT:
			total += float(item.definition.stat_modifiers.get(stat, 0.0))
	for passive in definition.hidden_abilities:
		if passive != null and passive.stat_multipliers.has(stat) and _passive_active(passive):
			total *= passive.stat_multipliers[stat]
	return maxi(1 if stat == &"max_hp" else 0, int(floor(total)))


## Weak context avoids retaining a battle through its party members.
func bind_battle(context: RefCounted) -> void:
	_battle_context = weakref(context) if context != null else null
	_clamp_vitals()


func _passive_active(passive: PassiveAbilityDefinition) -> bool:
	var battle = _battle_context.get_ref() if _battle_context != null else null
	if battle == null or not battle.passives_active():
		return false
	var friends: Array[CharacterState] = battle.party if self in battle.party else battle.enemies
	var foes: Array[CharacterState] = battle.enemies if self in battle.party else battle.party
	match passive.condition:
		PassiveAbilityDefinition.Condition.PARTY_HEALTHY:
			for friend in friends:
				if float(friend.current_hp) <= friend.get_stat(&"max_hp") * passive.health_threshold:
					return false
			return not friends.is_empty()
		PassiveAbilityDefinition.Condition.ALLY_HURT:
			for friend in friends:
				if friend.definition.id == passive.ally_id:
					return not friend.is_alive() or float(friend.current_hp) < friend.get_stat(&"max_hp") * passive.health_threshold
		PassiveAbilityDefinition.Condition.EASY_TARGET:
			for foe in foes:
				if not foe.is_alive():
					continue
				if foe.level < level:
					return true
				for status in foe.get_active_statuses():
					if status.definition.is_harmful():
						return true
		PassiveAbilityDefinition.Condition.OPENING_ROUNDS:
			return battle.round_number <= passive.round_limit
	return false


func get_damage_multiplier() -> float:
	var multiplier := 1.0
	for passive in definition.hidden_abilities:
		if passive == null or not _passive_active(passive):
			continue
		var bonus := passive.damage_multiplier
		if passive.condition == PassiveAbilityDefinition.Condition.ALLY_HURT:
			var battle = _battle_context.get_ref()
			var friends: Array[CharacterState] = battle.party if self in battle.party else battle.enemies
			for friend in friends:
				if friend.definition.id == passive.ally_id and not friend.is_alive():
					bonus = passive.downed_damage_multiplier
		multiplier *= bonus
	return multiplier


func _stat_part(stats: RPGStats, stat: StringName) -> float:
	return stats.value(stat) if stats != null else 0.0


func get_abilities() -> Array[AbilityDefinition]:
	var result: Array[AbilityDefinition] = []
	var seen: Dictionary = {}
	for ability in definition.unique_abilities:
		_add_ability(result, seen, ability)
	if character_class != null:
		for unlock in character_class.learned_abilities:
			if unlock != null and unlock.level <= level:
				_add_ability(result, seen, unlock.ability)
	for item in _gear:
		if item.definition.kind == GearDefinition.Kind.MEDALLION:
			for spell in item.definition.spells:
				_add_ability(result, seen, spell)
	return result


func _add_ability(result: Array[AbilityDefinition], seen: Dictionary, ability: AbilityDefinition) -> void:
	if ability != null and ability.is_valid() and not seen.has(ability.id):
		seen[ability.id] = true
		result.append(ability)


func get_resistance(damage_type: DamageType) -> float:
	if damage_type == null:
		return 0.0
	var total := _resistance_part(definition.resistances, damage_type.id)
	if character_class != null:
		total += _resistance_part(character_class.resistances, damage_type.id)
	for item in _gear:
		if item.definition.kind == GearDefinition.Kind.ARTIFACT:
			total += _resistance_part(item.definition.resistances, damage_type.id)
	return clampf(total, -1.0, 1.0)


func _resistance_part(entries: Array[DamageResistance], type_id: StringName) -> float:
	var total := 0.0
	for entry in entries:
		if entry != null and entry.damage_type != null and entry.damage_type.id == type_id:
			total += entry.amount
	return total


## Levels only advance; previously earned growth cannot be removed or earned twice.
func set_level(new_level: int) -> void:
	var destination := clampi(new_level, level, MAX_LEVEL)
	if destination == level:
		return
	for stat in RPGStats.NAMES:
		_permanent_stats[stat] += (destination - level) * get_growth(stat)
	level = destination
	_clamp_vitals()
	changed.emit()


func set_class(new_class: CharacterClass) -> void:
	character_class = new_class
	if not can_equip_weapon(equipped_weapon):
		equipped_weapon = null
	_clamp_vitals()
	changed.emit()


func _clamp_vitals() -> void:
	current_hp = clampi(current_hp, 0, get_stat(&"max_hp"))
	current_mp = clampi(current_mp, 0, get_stat(&"max_mp"))


func restore() -> void:
	current_hp = get_stat(&"max_hp")
	current_mp = get_stat(&"max_mp")
	changed.emit()


func is_alive() -> bool:
	return current_hp > 0


func has_weapon_restrictions() -> bool:
	return not definition.allowed_weapon_types.is_empty() or (character_class != null and not character_class.allowed_weapon_types.is_empty())


func can_equip_weapon_type(weapon_type: WeaponType) -> bool:
	if weapon_type == null or weapon_type.id.is_empty():
		return false
	return _allows_type(definition.allowed_weapon_types, weapon_type.id) and (character_class == null or _allows_type(character_class.allowed_weapon_types, weapon_type.id))


func _allows_type(allowed: Array[WeaponType], type_id: StringName) -> bool:
	if allowed.is_empty():
		return true
	for weapon_type in allowed:
		if weapon_type != null and weapon_type.id == type_id:
			return true
	return false


## Empty can mean no matching types; use has_weapon_restrictions() to distinguish unrestricted.
func get_allowed_weapon_types() -> Array[WeaponType]:
	var result: Array[WeaponType] = []
	var candidates := definition.allowed_weapon_types
	if candidates.is_empty() and character_class != null:
		candidates = character_class.allowed_weapon_types
	var seen: Dictionary = {}
	for weapon_type in candidates:
		if can_equip_weapon_type(weapon_type) and not seen.has(weapon_type.id):
			result.append(weapon_type)
			seen[weapon_type.id] = true
	return result


func can_equip_weapon(weapon: WeaponDefinition) -> bool:
	return weapon == null or (weapon.is_valid() and can_equip_weapon_type(weapon.weapon_type))


## Passing null unequips. Rejected equipment leaves the current weapon unchanged.
func equip_weapon(weapon: WeaponDefinition) -> bool:
	if not can_equip_weapon(weapon):
		return false
	equipped_weapon = weapon
	changed.emit()
	return true


func get_equipped_gear() -> Array[GearInstance]:
	return _gear.duplicate()


func gear_equip_error(item: GearInstance) -> String:
	if item == null or item.definition == null or not item.definition.is_valid() or item.is_destroyed():
		return "This gear is invalid or depleted."
	if item.get_carrier() != null or item in _gear:
		return "This item is already equipped."
	if _gear.size() >= GEAR_LIMIT:
		return "A character can carry only four pieces of gear."
	var count := 0
	for equipped in _gear:
		if equipped.definition.kind == item.definition.kind:
			count += 1
	if count >= GEAR_TYPE_LIMITS[item.definition.kind]:
		return "Maximum %d %s gear allowed." % [GEAR_TYPE_LIMITS[item.definition.kind], item.definition.type_name()]
	return ""


func equip_gear(item: GearInstance) -> bool:
	if not gear_equip_error(item).is_empty():
		return false
	_gear.append(item)
	item._set_carrier(self)
	_clamp_vitals()
	changed.emit()
	return true


func unequip_gear(item: GearInstance) -> bool:
	if item not in _gear:
		return false
	_gear.erase(item)
	item._set_carrier(null)
	_clamp_vitals()
	changed.emit()
	return true


func apply_status(effect: StatusEffectDefinition) -> bool:
	if effect == null or not effect.is_valid() or not is_alive():
		return false
	_statuses[effect.id] = {"definition": effect, "remaining_turns": effect.duration_turns}
	_clamp_vitals()
	changed.emit()
	return true


func get_active_statuses() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for status in _statuses.values():
		result.append(status.duplicate())
	return result


func remove_status(status_id: StringName) -> bool:
	if not _statuses.erase(status_id):
		return false
	_clamp_vitals()
	changed.emit()
	return true


## Call once at the end of each living character's action opportunity, including paralysis.
func advance_status_turn() -> Dictionary:
	var damage := 0
	for status_id in _statuses.keys():
		var effect: StatusEffectDefinition = _statuses[status_id].definition
		if is_alive() and effect.turn_damage > 0:
			var amount := mini(current_hp, maxi(0, int(round(effect.turn_damage * (1.0 - get_resistance(effect.damage_type))))))
			current_hp -= amount
			damage += amount
		_statuses[status_id].remaining_turns -= 1
		if _statuses[status_id].remaining_turns <= 0:
			_statuses.erase(status_id)
	_clamp_vitals()
	changed.emit()
	return {"damage": damage}


func get_growth(stat: StringName) -> float:
	return _stat_part(definition.stat_growth, stat) + (_stat_part(character_class.stat_growth, stat) if character_class != null else 0.0)


func get_combat_stat(stat: StringName) -> float:
	if stat not in RPGStats.COMBAT_NAMES:
		return 0.0
	var total := float(definition.get(stat))
	for status in _statuses.values():
		total += float(status.definition.stat_modifiers.get(stat, 0.0))
	for item in _gear:
		if item.definition.kind == GearDefinition.Kind.ARTIFACT:
			total += float(item.definition.stat_modifiers.get(stat, 0.0))
	if stat in [&"critical_rate", &"accuracy", &"evasion"]:
		return clampf(total, 0.0, 1.0)
	return maxf(1.0 if stat == &"critical_damage" else 0.01, total)


func can_act() -> bool:
	if not is_alive():
		return false
	for status in _statuses.values():
		if status.definition.prevents_action:
			return false
	return true
