extends Button

var manager: Control
var member: CharacterState
var party_slot := false
var slot_index := 0


func _get_drag_data(_position: Vector2) -> Variant:
	if member == null:
		return null
	manager.select_member(member)
	var preview := PanelContainer.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = member.definition.display_name
	preview.add_child(label)
	set_drag_preview(preview)
	return {"source": manager, "character": member}


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return manager.can_drop_character(data, party_slot, slot_index)


func _drop_data(_position: Vector2, data: Variant) -> void:
	manager.drop_character(data, party_slot, slot_index)
