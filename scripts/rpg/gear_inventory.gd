class_name GearInventory
extends RefCounted

var _items: Array[GearInstance] = []


func add(definition: GearDefinition) -> GearInstance:
	if definition == null or not definition.is_valid():
		return null
	var item := GearInstance.new(definition)
	_items.append(item)
	return item


## A shared stash; carried items still belong to the inventory but are not available.
func get_items() -> Array[GearInstance]:
	for item in _items.duplicate():
		if item.is_destroyed():
			_items.erase(item)
	return _items.duplicate()


func get_available_items() -> Array[GearInstance]:
	var result: Array[GearInstance] = []
	for item in get_items():
		if item.get_carrier() == null:
			result.append(item)
	return result


func register(item: GearInstance) -> bool:
	if item == null or item in _items or item.is_destroyed() or item.definition == null or not item.definition.is_valid():
		return false
	_items.append(item)
	return true
