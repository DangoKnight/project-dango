class_name AbilityDefinition
extends Resource

enum Effect { DAMAGE, HEAL, STATUS }
enum Target { ENEMY, ALLY, SELF, ANY, PARTY, ENEMIES }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var effect: Effect = Effect.DAMAGE
@export var targeting: Target = Target.ENEMY
@export var guaranteed_hit: bool = false
@export var can_crit: bool = true
@export_range(0, 1, 0.01) var hit_chance: float = 1.0
@export var damage_type: DamageType
@export var status_effect: StatusEffectDefinition
@export_range(0, 9999) var power: int = 0
@export_range(0, 999) var mana_cost: int = 0
@export_enum("strength", "mental_acuity", "defense", "mental_resilience", "speed") var scaling_stat: String = "strength"
@export_range(0, 10, 0.1) var scaling: float = 1.0
@export_enum("defense", "mental_resilience", "none") var defending_stat: String = "defense"


func is_valid() -> bool:
	if id.is_empty() or mana_cost < 0 or not is_finite(hit_chance) or hit_chance < 0 or hit_chance > 1 or targeting not in [Target.ENEMY, Target.ALLY, Target.SELF, Target.ANY, Target.PARTY, Target.ENEMIES]:
		return false
	if effect == Effect.STATUS:
		return status_effect != null and status_effect.is_valid()
	return (
		not id.is_empty()
		and effect in [Effect.DAMAGE, Effect.HEAL]
		and power >= 0 and mana_cost >= 0 and scaling >= 0.0
		and scaling_stat in RPGStats.NAMES
		and (defending_stat == "none" or defending_stat in RPGStats.NAMES)
		and (effect == Effect.HEAL or (damage_type != null and not damage_type.id.is_empty()))
	)
