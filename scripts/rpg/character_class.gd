class_name CharacterClass
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var base_stats: RPGStats
@export var stat_growth: RPGStats
@export var resistances: Array[DamageResistance] = []
@export var learned_abilities: Array[AbilityUnlock] = []
## Empty means unrestricted. Otherwise the type must also be allowed by the character.
@export var allowed_weapon_types: Array[WeaponType] = []
