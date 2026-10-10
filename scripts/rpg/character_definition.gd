@tool
class_name CharacterDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var title: String:
	set(value):
		title = value
		emit_changed()
@export_multiline var description: String
@export var starting_class: CharacterClass
## Experience contributed per resolved battle round when used as an enemy.
@export_range(0.0, 100000.0, 0.5) var base_experience_reward: float = 0.0
@export var base_stats: RPGStats
@export var stat_growth: RPGStats
## Independent uniform variation around combined growth for every stat and earned level.
@export_range(0.0, 10.0, 0.05) var growth_variation: float = 0.5
@export var resistances: Array[DamageResistance] = []
@export var unique_abilities: Array[AbilityDefinition] = []
## Automatic combat passives; excluded from skill menus and character information.
@export var hidden_abilities: Array[PassiveAbilityDefinition] = []
## Empty means unrestricted. Otherwise the type must also be allowed by the class.
@export var allowed_weapon_types: Array[WeaponType] = []
@export var starting_weapon: WeaponDefinition
@export_group("Combat Traits")
## Probabilities use fractions; critical damage is a multiplier and aggro is a weight.
@export_range(0, 1, 0.01) var critical_rate: float = 0.0
@export_range(1, 5, 0.05) var critical_damage: float = 1.5
@export_range(0, 1, 0.01) var accuracy: float = 1.0
@export_range(0, 1, 0.01) var evasion: float = 0.0
@export_range(0.01, 100, 0.1) var aggro: float = 1.0
@export_group("Portrait Presentation")
@export var portrait: Texture2D:
	set(value):
		portrait = value
		emit_changed()
## Fractions of the portrait area: +X moves right, +Y moves down. 0.1 means 10%.
@export var portrait_offset: Vector2 = Vector2.ZERO:
	set(value):
		portrait_offset = value
		emit_changed()
## Uniform scale around the center of the portrait rectangle.
@export_range(0.1, 3.0, 0.01) var portrait_scale: float = 1.0:
	set(value):
		portrait_scale = value
		emit_changed()
## Inherit the combat scene's setting, fit the whole image, or crop to fill.
@export_enum("Scene Default:-1", "Fit:5", "Fill:6") var portrait_stretch_mode: int = -1:
	set(value):
		portrait_stretch_mode = value
		emit_changed()
@export_group("")
@export var combat_texture: Texture2D
@export var starting_gear: Array[GearDefinition] = []
