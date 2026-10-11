class_name CharacterInformation
extends RefCounted


static func describe(character: CharacterState, damage_types: Array[DamageType], include_description: bool = true) -> String:
	var class_name_text := L10n.text(character.character_class.display_name) if character.character_class != null else L10n.text("None")
	var lines := PackedStringArray([
		L10n.text("%s — Level %d %s") % [L10n.text(character.definition.display_name), character.level, class_name_text],
		L10n.text(character.definition.title),
		L10n.text(character.definition.description) if include_description else "",
		"", L10n.text("HP %d / %d    MP %d / %d") % [character.current_hp, character.get_stat(&"max_hp"), character.current_mp, character.get_stat(&"max_mp")],
		"", L10n.text("STATS"),
	])
	for stat in RPGStats.NAMES:
		lines.append(L10n.text("%s: %d") % [RPGStats.display_name(stat), character.get_stat(stat)])
	lines.append(L10n.text("\nAVAILABLE ABILITIES"))
	for ability in character.get_abilities():
		var origin := L10n.text("Medallion")
		if ability in character.definition.unique_abilities:
			origin = L10n.text("Unique")
		elif character.character_class != null:
			for unlock in character.character_class.learned_abilities:
				if unlock != null and unlock.level <= character.level and unlock.ability == ability:
					origin = L10n.text("Class")
		var effect_name := [L10n.text("Damage"), L10n.text("Heal"), L10n.text("Status")][ability.effect] as String
		lines.append(L10n.text("%s [%s / %s] — %d MP") % [L10n.text(ability.display_name), origin, effect_name, ability.mana_cost])
		lines.append("  " + L10n.text(ability.description))
	if character.character_class != null:
		lines.append(L10n.text("\nFUTURE CLASS ABILITIES"))
		for unlock in character.character_class.learned_abilities:
			if unlock != null and unlock.ability != null and unlock.level > character.level:
				lines.append(L10n.text("Level %d: %s") % [unlock.level, L10n.text(unlock.ability.display_name)])
	lines.append(L10n.text("\nWEAPON"))
	lines.append(L10n.text(character.equipped_weapon.display_name) if character.equipped_weapon != null else L10n.text("Unarmed"))
	var allowed_names := PackedStringArray()
	for weapon_type in character.get_allowed_weapon_types():
		allowed_names.append(L10n.text(weapon_type.display_name))
	var allowed_text := ", ".join(allowed_names) if not allowed_names.is_empty() else L10n.text("None")
	lines.append(L10n.text("Allowed types: %s") % (allowed_text if character.has_weapon_restrictions() else L10n.text("Any")))
	lines.append(L10n.text("\nGEAR (%d / 4)") % character.get_equipped_gear().size())
	for item in character.get_equipped_gear():
		lines.append(L10n.text("%s [%s]%s") % [L10n.text(item.definition.display_name), item.definition.type_name(), L10n.text(" — %d uses") % item.remaining_uses() if item.definition.kind == GearDefinition.Kind.CONSUMABLE else ""])
	lines.append(L10n.text("\nACTIVE STATUSES"))
	var statuses := character.get_active_statuses()
	if statuses.is_empty():
		lines.append(L10n.text("None"))
	for status in statuses:
		lines.append(L10n.text("%s: %d turns") % [L10n.text(status.definition.display_name), status.remaining_turns])
	lines.append(L10n.text("\nRESISTANCES AND WEAKNESSES"))
	var has_affinity := false
	for damage_type in damage_types:
		if damage_type != null:
			var label := DamageResistance.display_label(character.get_resistance(damage_type))
			if not label.is_empty():
				lines.append(L10n.text("%s: %s") % [L10n.text(damage_type.display_name), L10n.text(label)])
				has_affinity = true
	if not has_affinity:
		lines.append(L10n.text("None"))
	return "\n".join(lines)
