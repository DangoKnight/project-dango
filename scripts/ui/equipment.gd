extends "res://scripts/ui/screen.gd"

var party: Array[CharacterState] = []
var inventory: GearInventory
var member_index := 0
var selected: GearInstance
@onready var members: OptionButton = $Panel/Layout/Members
@onready var equipped: ItemList = $Panel/Layout/Lists/Carried/Items
@onready var stash: ItemList = $Panel/Layout/Lists/Stash/Items
@onready var details: RichTextLabel = $Panel/Layout/Details
@onready var feedback: Label = $Panel/Layout/Feedback
@onready var equip_button: Button = $Panel/Layout/Actions/Equip
@onready var unequip_button: Button = $Panel/Layout/Actions/Unequip


func _ready() -> void:
	super._ready()
	members.item_selected.connect(func(index: int): member_index = index; _refresh())
	equipped.item_selected.connect(func(index: int): _select(equipped.get_item_metadata(index)))
	stash.item_selected.connect(func(index: int): _select(stash.get_item_metadata(index)))


func configure(characters: Array[CharacterState], shared_inventory: GearInventory) -> void:
	party = characters
	inventory = shared_inventory
	members.clear()
	for member in party:
		members.add_item(member.definition.display_name)
	_refresh()


func _refresh() -> void:
	selected = null
	equipped.clear()
	stash.clear()
	details.text = "Select gear to see its effects. Weapons use their separate weapon slot."
	feedback.text = "4 total · up to 3 Artifacts · 1 Medallion · 1 Consumable"
	equip_button.disabled = true
	unequip_button.disabled = true
	if party.is_empty() or inventory == null:
		return
	var carried := party[member_index].get_equipped_gear()
	$Panel/Layout/Lists/Carried/Title.text = "Carried (%d / 4)" % carried.size()
	for item in carried:
		_add_item(equipped, item)
	for item in inventory.get_available_items():
		_add_item(stash, item)


func _add_item(list: ItemList, item: GearInstance) -> void:
	var label := item.definition.display_name
	if item.definition.kind == GearDefinition.Kind.CONSUMABLE:
		label += " (%d uses)" % item.remaining_uses()
	var index := list.add_item(label)
	list.set_item_metadata(index, item)
	list.set_item_tooltip(index, label)


func _select(item: GearInstance) -> void:
	selected = item
	var gear := item.definition
	var lines := PackedStringArray([gear.display_name + " — " + gear.type_name(), gear.description])
	if gear.kind == GearDefinition.Kind.ARTIFACT:
		for stat in gear.stat_modifiers:
			lines.append("%s: %+.1f" % [RPGStats.display_name(stat), gear.stat_modifiers[stat]])
		for resistance in gear.resistances:
			lines.append("%s resistance: %+.0f%%" % [resistance.damage_type.display_name, resistance.amount * 100])
	elif gear.kind == GearDefinition.Kind.MEDALLION:
		for spell in gear.spells:
			lines.append("%s — %d MP" % [spell.display_name, spell.mana_cost])
	else:
		lines.append("Uses: %d / %d · Target: %s" % [item.remaining_uses(), gear.max_uses, ["Single ally", "Party", "Self", "Single enemy", "All enemies"][gear.consumable_target]])
	details.text = "\n".join(lines)
	var carried := item in party[member_index].get_equipped_gear()
	if carried:
		stash.deselect_all()
	else:
		equipped.deselect_all()
	var error := party[member_index].gear_equip_error(item) if not carried else ""
	feedback.text = error if not error.is_empty() else "Unequip to return to the shared stash." if carried else "Ready to equip."
	equip_button.disabled = carried or not error.is_empty()
	unequip_button.disabled = not carried


func _on_button_pressed(action: String) -> void:
	if action in ["Equip", "Unequip"]:
		if selected != null and not party.is_empty():
			if action == "Equip":
				party[member_index].equip_gear(selected)
			else:
				party[member_index].unequip_gear(selected)
			_refresh()
	else:
		super._on_button_pressed(action)
