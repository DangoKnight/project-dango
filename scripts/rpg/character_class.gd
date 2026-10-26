class_name CharacterClass
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var base_stats: RPGStats
@export var stat_growth: RPGStats
@export var resistances: Array[DamageResistance] = []
@export var learned_abilities: Array[AbilityUnlock] = []
## Grants these proficiencies in addition to the other character/class list. Both empty means unrestricted.
@export var allowed_weapon_types: Array[WeaponType] = []
