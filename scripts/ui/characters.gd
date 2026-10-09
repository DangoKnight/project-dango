extends "res://scripts/ui/screen.gd"

@export var damage_types: Array[DamageType] = [
	preload("res://resources/rpg/damage_types/slash.tres"),
	preload("res://resources/rpg/damage_types/pierce.tres"),
	preload("res://resources/rpg/damage_types/blunt.tres"),
	preload("res://resources/rpg/damage_types/fire.tres"),
	preload("res://resources/rpg/damage_types/frost.tres"),
	preload("res://resources/rpg/damage_types/lightning.tres"),
	preload("res://resources/rpg/damage_types/poison.tres"),
	preload("res://resources/rpg/damage_types/arcane.tres"),
]
var party: Array[CharacterState] = []
@onready var members: ItemList = $Panel/Buttons/Content/Members
@onready var details: RichTextLabel = $Panel/Buttons/Content/Details


func _ready() -> void:
	super._ready()
	members.item_selected.connect(_show_character)


func configure(characters: Array[CharacterState]) -> void:
	party = characters
	members.clear()
	for character in party:
		members.add_item(character.definition.display_name)
	if not party.is_empty():
		members.select(0)
		_show_character(0)


func _show_character(index: int) -> void:
	var character := party[index]
	details.text = CharacterInformation.describe(character, damage_types)
