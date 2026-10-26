class_name CharacterInformation
extends RefCounted

# Dark inks remain readable on the book’s pale paper.
const ABILITY_COLORS := {
	"ui.damage_2": Color("8b2027"),
	"ui.heal": Color("17623b"),
	"ui.ability.buff": Color("174e82"),
	"ui.ability.debuff": Color("77371a"),
	"ui.status": Color("66327d"),
}


static func describe(character: CharacterState, damage_types: Array[DamageType], include_description: bool = true, include_abilities: bool = true, include_equipment: bool = true) -> String:
	var class_name_text := L10n.text(character.character_class.display_name) if character.character_class != null else L10n.text("ui.none")
	var lines := PackedStringArray([
		L10n.text("ui.character.level_and_class") % [L10n.text(character.definition.display_name), character.level, class_name_text],
		L10n.text(character.definition.title),
		L10n.text(character.definition.description) if include_description else "",
		"", L10n.text("ui.hp_d_d_mp_d_d") % [character.current_hp, character.get_stat(&"max_hp"), character.current_mp, character.get_stat(&"max_mp")],
		"", L10n.text("ui.stats"),
	])
	for stat in RPGStats.NAMES:
		lines.append(L10n.text("ui.common.stat_value") % [RPGStats.display_name(stat), character.get_stat(stat)])
	if include_abilities:
		lines.append(describe_abilities(character))
	if include_equipment:
		lines.append(L10n.text("ui.weapon"))
		lines.append(L10n.text(character.equipped_weapon.display_name) if character.equipped_weapon != null else L10n.text("ui.unarmed"))
		var allowed_names := PackedStringArray()
		for weapon_type in character.get_allowed_weapon_types():
			allowed_names.append(L10n.text(weapon_type.display_name))
		var allowed_text := ", ".join(allowed_names) if not allowed_names.is_empty() else L10n.text("ui.none")
		lines.append(L10n.text("ui.allowed_types_s") % (allowed_text if character.has_weapon_restrictions() else L10n.text("ui.any")))
		lines.append(L10n.text("ui.gear_d_4") % character.get_equipped_gear().size())
		for item in character.get_equipped_gear():
			lines.append(L10n.text("ui.equipment.name_and_type") % [L10n.text(item.definition.display_name), item.definition.type_name(), L10n.text("ui.d_uses") % item.remaining_uses() if item.definition.kind == GearDefinition.Kind.CONSUMABLE else ""])
	lines.append(L10n.text("ui.active_statuses"))
	var statuses := character.get_active_statuses()
	if statuses.is_empty():
		lines.append(L10n.text("ui.none"))
	for status in statuses:
		lines.append(L10n.text("ui.status.remaining_turns") % [L10n.text(status.definition.display_name), status.remaining_turns])
	lines.append(L10n.text("ui.resistances_and_weaknesses"))
	var has_affinity := false
	for damage_type in damage_types:
		if damage_type != null:
			var label := DamageResistance.display_label(character.get_resistance(damage_type))
			if not label.is_empty():
				lines.append(L10n.text("ui.common.label_value") % [L10n.text(damage_type.display_name), L10n.text(label)])
				has_affinity = true
	if not has_affinity:
		lines.append(L10n.text("ui.none"))
	return "\n".join(lines)


static func describe_abilities(character: CharacterState) -> String:
	var lines := PackedStringArray()
	lines.append(L10n.text("ui.available_abilities"))
	for ability in character.get_abilities():
		var origin := L10n.text(ability_origin(character, ability))
		var effect_name := L10n.text(ability_category(ability))
		lines.append(L10n.text("ui.ability.details") % [L10n.text(ability.display_name), origin, effect_name, ability.mana_cost])
		lines.append("  " + L10n.text(ability.description))
	if character.get_abilities().is_empty():
		lines.append(L10n.text("ui.none"))
	return "\n".join(lines)


static func ability_category(ability: AbilityDefinition) -> String:
	if ability.effect == AbilityDefinition.Effect.HEAL:
		return "ui.heal"
	if ability.effect == AbilityDefinition.Effect.DAMAGE:
		return "ui.damage_2"
	var status := ability.status_effect
	if status == null or status.prevents_action or status.turn_damage > 0:
		return "ui.status"
	if status.is_harmful():
		return "ui.ability.debuff"
	if not status.stat_percent_modifiers.is_empty():
		return "ui.ability.buff"
	return "ui.status"


static func ability_tooltip(ability: AbilityDefinition) -> String:
	var lines := PackedStringArray([L10n.text(ability.description)])
	var damage_type := ability.damage_type
	if damage_type == null and ability.status_effect != null:
		damage_type = ability.status_effect.damage_type
	if damage_type != null:
		lines.append(L10n.text("ui.ability.damage_type") % L10n.text(damage_type.display_name))
	return "\n".join(lines)


static func ability_origin(character: CharacterState, ability: AbilityDefinition) -> String:
	if ability in character.definition.unique_abilities:
		return "ui.unique"
	if character.character_class != null:
		for unlock in character.character_class.learned_abilities:
			if unlock != null and unlock.level <= character.level and unlock.ability == ability:
				return "ui.class"
	return "ui.medallion"
