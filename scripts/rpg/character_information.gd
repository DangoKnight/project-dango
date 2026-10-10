class_name CharacterInformation
extends RefCounted


static func describe(character: CharacterState, damage_types: Array[DamageType], include_description: bool = true) -> String:
	var class_name_text := character.character_class.display_name if character.character_class != null else "None"
	var lines := PackedStringArray([
		"%s — Level %d %s" % [character.definition.display_name, character.level, class_name_text],
		character.definition.title,
		character.definition.description if include_description else "",
		"", "HP %d / %d    MP %d / %d" % [character.current_hp, character.get_stat(&"max_hp"), character.current_mp, character.get_stat(&"max_mp")],
		"", "STATS",
	])
	for stat in RPGStats.NAMES:
		lines.append("%s: %d" % [RPGStats.display_name(stat), character.get_stat(stat)])
	lines.append("\nAVAILABLE ABILITIES")
	for ability in character.get_abilities():
		var origin := "Medallion"
		if ability in character.definition.unique_abilities:
			origin = "Unique"
		elif character.character_class != null:
			for unlock in character.character_class.learned_abilities:
				if unlock != null and unlock.level <= character.level and unlock.ability == ability:
					origin = "Class"
		var effect_name := ["Damage", "Heal", "Status"][ability.effect] as String
		lines.append("%s [%s / %s] — %d MP" % [ability.display_name, origin, effect_name, ability.mana_cost])
		lines.append("  " + ability.description)
	if character.character_class != null:
		lines.append("\nFUTURE CLASS ABILITIES")
		for unlock in character.character_class.learned_abilities:
			if unlock != null and unlock.ability != null and unlock.level > character.level:
				lines.append("Level %d: %s" % [unlock.level, unlock.ability.display_name])
	lines.append("\nWEAPON")
	lines.append(character.equipped_weapon.display_name if character.equipped_weapon != null else "Unarmed")
	var allowed_names := PackedStringArray()
	for weapon_type in character.get_allowed_weapon_types():
		allowed_names.append(weapon_type.display_name)
	var allowed_text := ", ".join(allowed_names) if not allowed_names.is_empty() else "None"
	lines.append("Allowed types: " + (allowed_text if character.has_weapon_restrictions() else "Any"))
	lines.append("\nGEAR (%d / 4)" % character.get_equipped_gear().size())
	for item in character.get_equipped_gear():
		lines.append("%s [%s]%s" % [item.definition.display_name, item.definition.type_name(), " — %d uses" % item.remaining_uses() if item.definition.kind == GearDefinition.Kind.CONSUMABLE else ""])
	lines.append("\nACTIVE STATUSES")
	var statuses := character.get_active_statuses()
	if statuses.is_empty():
		lines.append("None")
	for status in statuses:
		lines.append("%s: %d turns" % [status.definition.display_name, status.remaining_turns])
	lines.append("\nRESISTANCES AND WEAKNESSES")
	var has_affinity := false
	for damage_type in damage_types:
		if damage_type != null:
			var label := DamageResistance.display_label(character.get_resistance(damage_type))
			if not label.is_empty():
				lines.append("%s: %s" % [damage_type.display_name, label])
				has_affinity = true
	if not has_affinity:
		lines.append("None")
	return "\n".join(lines)
