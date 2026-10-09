class_name ConsumableEffect
extends Resource

enum Kind { HEAL_HP, RESTORE_MP, APPLY_STATUS, DAMAGE }

@export var kind: Kind = Kind.HEAL_HP
@export_range(0, 9999) var amount: int = 0
@export var damage_type: DamageType
@export_enum("defense", "mental_resilience", "none") var defending_stat: String = "none"
@export var status: StatusEffectDefinition


func is_valid() -> bool:
	if kind == Kind.DAMAGE:
		return amount > 0 and damage_type != null and not damage_type.id.is_empty() and defending_stat in ["defense", "mental_resilience", "none"]
	if kind == Kind.APPLY_STATUS:
		return status != null and status.is_valid()
	return kind in [Kind.HEAL_HP, Kind.RESTORE_MP] and amount > 0
