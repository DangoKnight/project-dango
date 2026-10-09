class_name GearInstance
extends RefCounted

var definition: GearDefinition
var _uses_left: int = 0
var _carrier: WeakRef


func _init(gear: GearDefinition) -> void:
	definition = gear
	if gear != null and gear.kind == GearDefinition.Kind.CONSUMABLE:
		_uses_left = gear.max_uses


func remaining_uses() -> int:
	return _uses_left


func is_destroyed() -> bool:
	return definition != null and definition.kind == GearDefinition.Kind.CONSUMABLE and _uses_left <= 0


func get_carrier() -> RefCounted:
	return _carrier.get_ref() as RefCounted if _carrier != null else null


func _set_carrier(character: RefCounted) -> void:
	_carrier = weakref(character) if character != null else null


func _spend_use() -> bool:
	if definition == null or definition.kind != GearDefinition.Kind.CONSUMABLE or is_destroyed():
		return false
	_uses_left -= 1
	return true
