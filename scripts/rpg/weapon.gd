class_name WeaponDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var weapon_type: WeaponType


func is_valid() -> bool:
	return not id.is_empty() and weapon_type != null and not weapon_type.id.is_empty()
