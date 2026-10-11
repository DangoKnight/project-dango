extends "res://scripts/ui/screen.gd"

var compendium: MonsterCompendium
var _ids: Array[StringName] = []


func _ready() -> void:
	super._ready()
	$Panel/Layout/Content/Members.item_selected.connect(_select)


func configure(knowledge: MonsterCompendium) -> void:
	compendium = knowledge
	var members: ItemList = $Panel/Layout/Content/Members
	for monster_id in compendium.entries:
		_ids.append(monster_id)
		members.add_item(compendium.entries[monster_id].definition.display_name)
	if _ids.is_empty():
		$Panel/Layout/Content/Entry/Details.text = "No monsters encountered yet."
	else:
		members.select(0)
		_select(0)


func _select(index: int) -> void:
	var monster_id := _ids[index]
	$Panel/Layout/Content/Entry/Portrait.texture = compendium.entries[monster_id].definition.combat_texture
	$Panel/Layout/Content/Entry/Details.text = compendium.describe(monster_id)
	$Panel/Layout/Content/Entry/Details.scroll_to_line(0)
