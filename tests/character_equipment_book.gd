extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func run() -> void:
	var proficiencies := {
		"usami": ["dagger", "amplifier"],
		"takane": ["gun", "dagger", "crossbow"],
		"kurako": ["dagger", "amplifier"],
		"koumi": ["dagger", "hammer", "spear", "sword"],
	}
	for id in proficiencies:
		var definition: CharacterDefinition = load("res://resources/rpg/characters/%s.tres" % id)
		var character := CharacterState.new(definition)
		var expected: Array = proficiencies[id].duplicate()
		for type in ["sword", "gun", "crossbow"]:
			if type not in expected:
				expected.append(type)
		check(character.get_allowed_weapon_types().size() == expected.size(), "Character and Explorer proficiencies combine: " + id)
		for type in expected:
			check(character.can_equip_weapon_type(load("res://resources/rpg/weapon_types/%s.tres" % type)), "Requested weapon access: " + id + " / " + type)
		character.set_class(null)
		check(character.get_allowed_weapon_types().size() == proficiencies[id].size(), "Removing class preserves only personal proficiencies: " + id)
	var class_weapon := WeaponDefinition.new()
	class_weapon.id = &"test_gun"
	class_weapon.weapon_type = load("res://resources/rpg/weapon_types/gun.tres")
	var usami := CharacterState.new(load("res://resources/rpg/characters/usami.tres"))
	check(usami.equip_weapon(class_weapon), "Explorer grants access to a gun")
	usami.set_class(load("res://resources/rpg/classes/arcanist.tres"))
	check(usami.equipped_weapon == null and usami.can_equip_weapon_type(load("res://resources/rpg/weapon_types/dagger.tres")), "Changing class removes class-only access while retaining personal access")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game(false)
	check(not game.ui.get_child(0).has_node("Panel/Buttons/Shortcuts"), "Town shortcut hint is removed")
	var inventory: GearInventory = game.state.gear_inventory
	var first := inventory.add(load("res://resources/rpg/gear/vital_artifact.tres"))
	var replacement := inventory.add(load("res://resources/rpg/gear/iron_artifact.tres"))
	var spare_consumable := inventory.add(load("res://resources/rpg/gear/simple_rations.tres"))
	var spare_medallion := inventory.add(load("res://resources/rpg/gear/spell_medallion.tres"))
	var member: CharacterState = game.state.roster[0]
	check(member.equip_gear(first), "Equip first artifact")
	for path in ["wind_artifact", "spell_medallion", "simple_rations"]:
		check(member.equip_gear(inventory.add(load("res://resources/rpg/gear/%s.tres" % path))), "Fill carried gear")
	check(member.gear_equip_error(replacement).length() > 0 and member.gear_equip_error(replacement, first).is_empty(), "Replacing gear works at capacity without mutating preview")
	var weapon: WeaponDefinition = load("res://resources/rpg/weapons/training_sword.tres")
	game.state.weapon_inventory.append(weapon)
	game.show_pause("town")
	var book := game.ui.get_child(0) as PauseBook
	book.page_fade_duration = 0
	await book.open_page("characters")
	check(not book.widget("CharacterDetails").text.contains("Future"), "No future abilities in breakdown")
	check(book.widget("Characters").get_index() < book.widget("CharacterPortrait").get_index(), "Character tabs are above the portrait")
	check(book.widget("OverviewTab").text == "Overview", "Overview replaces Breakdown")
	var overview: String = book.widget("CharacterDetails").text
	check(not overview.contains("Available abilities") and not overview.contains("Weapon") and not overview.contains("Gear") and not overview.contains("Jolly Cheer"), "Overview excludes equipment and abilities")
	book.widget("AbilitiesTab").pressed.emit()
	var rows := book.widget("AbilityDetails")
	check(rows.get_child_count() == member.get_abilities().size(), "All currently available abilities get a row")
	for row in rows.get_children():
		var ability: AbilityDefinition = row.get_meta("ability")
		check(row.get_parsed_text().contains(L10n.text(ability.display_name)), "Ability name is visible")
		check(row.tooltip_text.contains(L10n.text(ability.description)), "Ability description is available on hover")
		check(not row.get_parsed_text().contains(L10n.text(ability.description)), "Description is absent from the compact ability row")
		var category := CharacterInformation.ability_category(ability)
		check(row.text.contains("[color=#" + CharacterInformation.ABILITY_COLORS[category].to_html(false) + "]"), "Category uses its distinct ink color")
		var origin := L10n.text(CharacterInformation.ability_origin(member, ability))
		check(row.get_parsed_text().contains("(" + origin + "/" + L10n.text(category) + ")"), "Origin and category appear inline next to the ability name")
	var categories := {"jolly_cheer": "ui.ability.buff", "caring_friend": "ui.heal", "painful_stab": "ui.status", "immobilizing_stab": "ui.status", "i_am_scary": "ui.ability.debuff", "bonk": "ui.damage_2"}
	for id in categories:
		var ability: AbilityDefinition = load("res://resources/rpg/abilities/%s.tres" % id)
		check(CharacterInformation.ability_category(ability) == categories[id], "Correct category for " + id)
		var damage_type := ability.damage_type if ability.damage_type != null else ability.status_effect.damage_type if ability.status_effect != null else null
		if damage_type != null:
			check(CharacterInformation.ability_tooltip(ability).contains(L10n.text(damage_type.display_name)), "Hover includes damage type for " + id)

	book.widget("ClassTab").pressed.emit()
	check(book.widget("ClassDetails").text.contains("Explorer"), "Class tab shows the current class")
	check(not book.widget("ClassDetails").text.contains("Available abilities"), "Class page excludes abilities")
	check(book.widget("EquipmentTab").text == "Gear", "Character equipment tab is named Gear")
	book.widget("EquipmentTab").pressed.emit()
	check(book.widget("EquipmentSlots").item_count == 5, "Weapon plus four gear slots")
	for filter in book.widget("EquipmentFilters").get_children():
		if filter.get_meta("weapon_family") == &"sword":
			filter.pressed.emit()
			break
	var choices := book.widget("EquipmentChoices") as ItemList
	check(choices.item_count == 1 and choices.get_item_metadata(0) == weapon, "Selected family offers the matching weapon")
	check(choices.get_theme_constant("line_separation") == 4, "Equipment options use compact rows")
	choices.item_selected.emit(0)
	check(member.equipped_weapon == weapon, "Weapon equips from the book")
	book.widget("EquipmentSlots").item_selected.emit(1)
	check(book.widget("EquipmentFilters").get_child_count() == 3, "Gear has Consumables, Artifacts, and Medallions subtabs")
	choices = book.widget("EquipmentChoices")
	var replacement_index := -1
	for index in choices.item_count:
		if choices.get_item_metadata(index) == replacement:
			replacement_index = index
	check(replacement_index >= 0, "Compatible artifact replacement offered at full capacity")
	if replacement_index >= 0:
		choices.item_selected.emit(replacement_index)
	check(member.get_equipped_gear()[0] == replacement and first.get_carrier() == null and replacement.get_carrier() == member, "Replacement preserves slot and returns old gear to stash")
	for filter in book.widget("EquipmentFilters").get_children():
		if filter.get_meta("gear_kind") == GearDefinition.Kind.CONSUMABLE:
			filter.pressed.emit()
			break
	choices = book.widget("EquipmentChoices")
	for index in choices.item_count:
		var item: GearInstance = choices.get_item_metadata(index)
		check(item == null or item.definition.kind == GearDefinition.Kind.CONSUMABLE, "Consumables subtab excludes artifacts and medallions")
	choices.item_selected.emit(0)
	check(replacement.get_carrier() == null and member.get_equipped_gear().size() == 3, "Unequip returns gear to shared stash")
	book.widget("EquipmentSlots").item_selected.emit(3)
	choices = book.widget("EquipmentChoices")
	check(choices.item_count == 2 and choices.get_item_metadata(1) == spare_consumable, "Consumables subtab offers a spare consumable for the consumable slot")
	choices.item_selected.emit(1)
	check(spare_consumable.get_carrier() == member, "Filtered consumable replaces an equipped consumable")
	book.widget("EquipmentSlots").item_selected.emit(2)
	for filter in book.widget("EquipmentFilters").get_children():
		if filter.get_meta("gear_kind") == GearDefinition.Kind.MEDALLION:
			filter.pressed.emit()
			break
	choices = book.widget("EquipmentChoices")
	check(choices.item_count == 2 and choices.get_item_metadata(1) == spare_medallion, "Medallions subtab offers a compatible spare medallion")
	choices.item_selected.emit(1)
	check(spare_medallion.get_carrier() == member, "Filtered medallion replaces an equipped medallion")
	game.queue_free()
	await process_frame
	print("Character equipment book failures: ", failures)
	quit(failures)
