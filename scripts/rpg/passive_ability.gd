class_name PassiveAbilityDefinition
extends Resource

enum Condition { PARTY_HEALTHY, ALLY_HURT, EASY_TARGET, OPENING_ROUNDS }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var condition: Condition
@export var health_threshold := 0.7
@export var ally_id: StringName
@export var round_limit := 4
@export var stat_multipliers: Dictionary[StringName, float] = {}
@export var damage_multiplier := 1.0
@export var downed_damage_multiplier := 1.0
