class_name GearDefinition
extends Resource

enum Kind { ARTIFACT, MEDALLION, CONSUMABLE }
enum Target { ALLY, PARTY, SELF, ENEMY, ENEMIES }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var kind: Kind = Kind.ARTIFACT
## Artifact-only flat modifiers, including negative values for penalties.
@export var stat_modifiers: Dictionary[StringName, float] = {}
## Optional future gear growth bonuses; only equipped items contribute on level-up.
@export var stat_growth_modifiers: Dictionary[StringName, float] = {}
@export var resistances: Array[DamageResistance] = []
## Medallion spells use their normal targeting rules and MP costs.
@export var spells: Array[AbilityDefinition] = []
@export_range(1, 999) var max_uses: int = 1
@export var consumable_target: Target = Target.PARTY
@export var effects: Array[ConsumableEffect] = []


func is_valid() -> bool:
	if id.is_empty() or kind not in [Kind.ARTIFACT, Kind.MEDALLION, Kind.CONSUMABLE]:
		return false
	for stat in stat_growth_modifiers:
		if stat not in RPGStats.NAMES or not is_finite(stat_growth_modifiers[stat]):
			return false
	if kind == Kind.ARTIFACT:
		for stat in stat_modifiers:
			if stat not in RPGStats.ALL_NAMES or not is_finite(stat_modifiers[stat]):
				return false
		for resistance in resistances:
			if resistance == null or resistance.damage_type == null or resistance.damage_type.id.is_empty() or not is_finite(resistance.amount):
				return false
	elif kind == Kind.MEDALLION:
		if spells.is_empty():
			return false
		for spell in spells:
			if spell == null or not spell.is_valid():
				return false
	else:
		if max_uses < 1 or effects.is_empty() or consumable_target not in [Target.ALLY, Target.PARTY, Target.SELF, Target.ENEMY, Target.ENEMIES]:
			return false
		for effect in effects:
			if effect == null or not effect.is_valid():
				return false
	return true


func type_name() -> String:
	return ["Artifact", "Medallion", "Consumable"][kind]
