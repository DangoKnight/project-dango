class_name MonsterCompendium
extends RefCounted

signal changed

const DAMAGE_TYPES: Array[DamageType] = [
	preload("res://resources/rpg/damage_types/slash.tres"),
	preload("res://resources/rpg/damage_types/pierce.tres"),
	preload("res://resources/rpg/damage_types/blunt.tres"),
	preload("res://resources/rpg/damage_types/fire.tres"),
	preload("res://resources/rpg/damage_types/frost.tres"),
	preload("res://resources/rpg/damage_types/lightning.tres"),
	preload("res://resources/rpg/damage_types/poison.tres"),
	preload("res://resources/rpg/damage_types/arcane.tres"),
]

# Knowledge belongs to a monster species, never to a level or encounter instance.
var entries: Dictionary[StringName, Dictionary] = {}


func encounter(monster: CharacterDefinition) -> void:
	if not entries.has(monster.id):
		entries[monster.id] = {"definition": monster, "resistances": {}, "abilities": {}}
		changed.emit()


func learn_resistance(monster: CharacterState, damage_type: DamageType) -> void:
	if damage_type == null:
		return
	encounter(monster.definition)
	var label := DamageResistance.display_label(monster.get_resistance(damage_type))
	entries[monster.definition.id].resistances[damage_type.id] = {
		"name": damage_type.display_name, "label": label if not label.is_empty() else "Normal"}
	changed.emit()


func learn_ability(monster: CharacterDefinition, ability: AbilityDefinition) -> void:
	encounter(monster)
	entries[monster.id].abilities[ability.id] = ability
	changed.emit()


func describe(monster_id: StringName) -> String:
	if not entries.has(monster_id):
		return "No information discovered."
	var entry := entries[monster_id]
	var lines := PackedStringArray([entry.definition.display_name, "", "DISCOVERED RESISTANCES"])
	var listed: Array[StringName] = []
	for damage_type in DAMAGE_TYPES:
		listed.append(damage_type.id)
		var resistance: Dictionary = entry.resistances.get(damage_type.id, {})
		lines.append("%s: %s" % [damage_type.display_name, resistance.get("label", "???")])
	for type_id in entry.resistances:
		if type_id not in listed:
			var resistance: Dictionary = entry.resistances[type_id]
			lines.append("%s: %s" % [resistance.name, resistance.label])
	lines.append("\nOBSERVED ABILITIES")
	if entry.abilities.is_empty():
		lines.append("???")
	for ability in entry.abilities.values():
		lines.append(ability.display_name)
		lines.append(ability.description)
	return "\n".join(lines)
