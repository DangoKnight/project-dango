class_name StatusEffectDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export_range(1, 99) var duration_turns: int = 3
@export_range(0, 9999) var turn_damage: int = 0
@export var damage_type: DamageType
@export var prevents_action: bool = false
## Explicit marker for harmful effects without damage, paralysis, or stat penalties.
@export var is_negative: bool = false
## Flat stat changes; negative values are debuffs. Keys use RPGStats.NAMES.
@export var stat_modifiers: Dictionary[StringName, float] = {}


func is_valid() -> bool:
	if id.is_empty() or duration_turns < 1 or turn_damage < 0:
		return false
	if turn_damage > 0 and (damage_type == null or damage_type.id.is_empty()):
		return false
	for stat in stat_modifiers:
		if stat not in RPGStats.ALL_NAMES or not is_finite(stat_modifiers[stat]):
			return false
	return true


func is_harmful() -> bool:
	if is_negative or prevents_action or turn_damage > 0:
		return true
	for modifier in stat_modifiers.values():
		if modifier < 0.0:
			return true
	return false
