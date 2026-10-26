class_name PauseBook
extends Control

signal action_requested(action: String)

const LESSONS := [
	["ui.lessons.damage_types.title", "ui.lessons.damage_types.text"],
	["ui.lessons.weapons.title", "ui.lessons.weapons.text"],
	["ui.lessons.weapons_ii.title", "ui.lessons.weapons_ii.text"],
	["ui.lessons.physical_mental.title", "ui.lessons.physical_mental.text"],
	["ui.lessons.gear.title", "ui.lessons.gear.text"],
	["ui.lessons.statuses.title", "ui.lessons.statuses.text"],
	["ui.lessons.commissions.title", "ui.lessons.commissions.text"],
	["ui.lessons.sleeping.title", "ui.lessons.sleeping.text"],
	["ui.lessons.observing.title", "ui.lessons.observing.text"],
	["ui.lessons.exploration_completion.title", "ui.lessons.exploration_completion.text"],
]
const CHART := preload("res://scripts/ui/labyrinth_map_canvas.gd")
@export_range(0.0, 1.0, 0.02) var page_fade_duration := 0.18
@onready var left_page: VBoxContainer = $Panel/LeftPage
@onready var right_page: VBoxContainer = $Panel/RightPage
var current_page := "index"
var transitioning := false
var map: LabyrinthMapSnapshot
var maps: Array[LabyrinthMapSnapshot] = []
var roster: Array[CharacterState] = []
var inventory: GearInventory
var weapons: Array[WeaponDefinition] = []
var character_index := 0
var character_tab := 0
var equipment_slot := -1
var weapon_family: StringName
var gear_kind: GearDefinition.Kind = GearDefinition.Kind.ARTIFACT
var knowledge: MonsterCompendium
var town_context := false
var town_name := "ui.safe_zone"
var commands: Dictionary[String, Button] = {}
var widgets: Dictionary[String, Control] = {}


func _ready() -> void:
	_build_index()


func configure(current_map: Map, compendium: MonsterCompendium, in_town: bool, current_town_name: String = "ui.safe_zone", characters: Array[CharacterState] = [], saved_maps: Array = [], preferred_map_path: String = "") -> void:
	roster = characters
	maps.clear()
	for chart in saved_maps:
		maps.append(chart)
	if current_map is LabyrinthMap and current_map.layout != null and current_map.layout.error.is_empty():
		map = LabyrinthMapSnapshot.capture(current_map)
		for index in range(maps.size() - 1, -1, -1):
			if maps[index].map_path == map.map_path:
				maps.remove_at(index)
		maps.append(map)
	else:
		map = maps.back() if not maps.is_empty() else null
		for chart in maps:
			if chart.map_path == preferred_map_path:
				map = chart
				break
	knowledge = compendium
	town_context = in_town
	town_name = current_town_name
	_clear_pages()
	_build_index()


func command(action: String) -> Button:
	return commands.get(action)


func widget(id: String) -> Control:
	return widgets.get(id)


func _input(event: InputEvent) -> void:
	if transitioning:
		get_viewport().set_input_as_handled()


func open_page(page: String) -> void:
	if transitioning:
		return
	if page == "map" and map == null:
		return
	transitioning = true
	await _fade_pages(0.0)
	_clear_pages()
	current_page = page
	match page:
		"map": _build_map()
		"monsters": _build_monsters()
		"characters": _build_characters()
		"options": _build_options()
		"lessons": _build_lessons()
		_: _build_index()
	await _fade_pages(1.0)
	transitioning = false
	var focus := command("Resume") if current_page == "index" else widget("Back") as Button
	if focus != null:
		focus.grab_focus()


func _leave(action: String) -> void:
	if transitioning:
		return
	transitioning = true
	await _fade_pages(0.0)
	transitioning = false
	action_requested.emit(action)


func _fade_pages(alpha: float) -> void:
	if page_fade_duration <= 0.0:
		left_page.modulate.a = alpha
		right_page.modulate.a = alpha
		return
	var tween := create_tween().set_parallel()
	tween.tween_property(left_page, "modulate:a", alpha, page_fade_duration)
	tween.tween_property(right_page, "modulate:a", alpha, page_fade_duration)
	await tween.finished


func _clear_pages() -> void:
	commands.clear()
	widgets.clear()
	for page in [left_page, right_page]:
		for child in page.get_children():
			page.remove_child(child)
			child.queue_free()


func _label(parent: Node, text: String, font_size: int = 22) -> Label:
	var label := Label.new()
	label.text = L10n.text(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = L10n.text(text)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	button.pressed.connect(callback)
	return button


func _index_button(parent: Node, action: String, text: String) -> Button:
	var button := _button(parent, text, func():
		match action:
			"Map": open_page("map")
			"Monsters": open_page("monsters")
			"Characters": open_page("characters")
			"Options": open_page("options")
			"Lessons": open_page("lessons")
			_: _leave(action)
	)
	button.name = action
	commands[action] = button
	return button


func _back(parent: Node) -> void:
	widgets["Back"] = _button(parent, "ui.back", func(): open_page("index"))
	widgets["Back"].tooltip_text = L10n.text("ui.return_to_contents_esc")


func _scroll(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return content


func _build_index() -> void:
	current_page = "index"
	_label(left_page, L10n.text("ui.field_journal"), 32)
	_label(left_page, town_name if town_context else L10n.text(map.display_name) if map != null else L10n.text("ui.rest_a_moment"), 18)
	_index_button(left_page, "Resume", "ui.return" if town_context else "ui.resume")
	var chart := _index_button(left_page, "Map", "ui.map")
	chart.disabled = map == null
	_index_button(left_page, "Monsters", "ui.monsters")
	_index_button(left_page, "Characters", "ui.characters")
	_label(right_page, L10n.text("ui.notes_settings"), 30)
	_index_button(right_page, "Lessons", "ui.lessons.title")
	_index_button(right_page, "Options", "ui.options")
	_index_button(right_page, "MainMenu", L10n.text("ui.main_menu"))
	command("Resume").grab_focus()


func _build_map() -> void:
	var labyrinth := map
	_label(left_page, "ui.exploration", 30)
	if maps.size() > 1:
		var selector := OptionButton.new()
		for chart in maps:
			selector.add_item(L10n.text(chart.display_name))
		selector.select(maps.find(map))
		selector.item_selected.connect(func(index: int):
			map = maps[index]
			open_page("map")
		)
		left_page.add_child(selector)
		widgets["Maps"] = selector
	var stats := _scroll(left_page)
	_label(stats, L10n.text(labyrinth.display_name))
	var completion := 100.0 * labyrinth.walked_cells.size() / labyrinth.layout.passages.size()
	widgets["Completion"] = _label(stats, L10n.text("ui.map_completion_1f") % completion)
	var chart := Control.new()
	chart.set_script(CHART)
	chart.name = "MapCanvas"
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.custom_minimum_size = Vector2(0, 40)
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chart.ink_on_paper = true
	_label(right_page, "ui.map", 30)
	right_page.add_child(chart)
	chart.configure(labyrinth)
	widgets["MapCanvas"] = chart
	var landmarks: Array[LabyrinthLandmark] = chart.visible_landmarks()
	widgets["Landmarks"] = _label(stats, L10n.text("ui.discovered_landmarks_d") % landmarks.size())
	widgets["Items"] = _label(stats, L10n.text("ui.picked_up_items_d") % labyrinth.items_picked_up)
	_back(left_page)


func _build_characters() -> void:
	_label(left_page, "ui.characters", 30)
	var members := HBoxContainer.new()
	left_page.add_child(members)
	widgets["Characters"] = members
	for index in roster.size():
		var button := _button(members, roster[index].definition.display_name, _show_character.bind(index))
		button.toggle_mode = true
		button.clip_text = true
		button.tooltip_text = L10n.text(roster[index].definition.display_name)
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_page.add_child(portrait)
	widgets["CharacterPortrait"] = portrait
	_back(left_page)
	if not roster.is_empty():
		character_index = mini(character_index, roster.size() - 1)
		_show_character(character_index)


func _show_character(index: int) -> void:
	character_index = index
	var members := widget("Characters")
	for tab in members.get_child_count():
		members.get_child(tab).set_pressed_no_signal(tab == index)
	var portrait := widget("CharacterPortrait") as TextureRect
	portrait.texture = roster[index].definition.portrait
	for child in right_page.get_children():
		right_page.remove_child(child)
		child.queue_free()
	var tabs := HBoxContainer.new()
	right_page.add_child(tabs)
	for tab in 4:
		var button := _button(tabs, ["ui.character.overview", "ui.class", "ui.character.gear", "ui.character.abilities"][tab], func():
			character_tab = tab
			_show_character(character_index)
		)
		button.toggle_mode = true
		button.button_pressed = character_tab == tab
		button.clip_text = true
		button.tooltip_text = button.text
		widgets[["OverviewTab", "ClassTab", "EquipmentTab", "AbilitiesTab"][tab]] = button
	var content := _scroll(right_page)
	var character := roster[index]
	_label(content, character.definition.display_name, 30)
	match character_tab:
		0:
			widgets["CharacterDetails"] = _details(content, CharacterInformation.describe(character, MonsterCompendium.DAMAGE_TYPES, true, false, false))
		1:
			var lines := PackedStringArray()
			var job := character.character_class
			if job != null:
				lines.append(L10n.text(job.display_name))
				lines.append(L10n.text(job.description))
				var types := PackedStringArray()
				for kind in job.allowed_weapon_types:
					types.append(L10n.text(kind.display_name))
				lines.append(L10n.text("ui.allowed_types_s") % (", ".join(types) if not types.is_empty() else L10n.text("ui.none")))
			else:
				lines.append(L10n.text("ui.none"))
			widgets["ClassDetails"] = _details(content, "\n".join(lines))
		2: _build_equipment(content, character)
		3: _build_abilities(content, character)


func _build_monsters() -> void:
	_label(left_page, "ui.monsters", 32)
	var members := ItemList.new()
	members.size_flags_vertical = Control.SIZE_EXPAND_FILL
	members.add_theme_font_size_override("font_size", 22)
	left_page.add_child(members)
	widgets["Monsters"] = members
	var ids: Array[StringName] = []
	if knowledge != null:
		for id in knowledge.entries:
			ids.append(id)
			members.add_item(L10n.text(knowledge.entries[id].definition.display_name))
	members.item_selected.connect(func(index: int): _show_monster(ids[index]))
	_back(left_page)
	if ids.is_empty():
		_label(right_page, L10n.text("ui.field_notes"), 30)
		_label(right_page, L10n.text("ui.no_monsters_encountered_yet"))
	else:
		members.select(0)
		_show_monster(ids[0])


func _show_monster(id: StringName) -> void:
	for child in right_page.get_children():
		right_page.remove_child(child)
		child.queue_free()
	var content := _scroll(right_page)
	_label(content, L10n.text(knowledge.entries[id].definition.display_name), 30)
	var portrait := TextureRect.new()
	portrait.texture = knowledge.entries[id].definition.combat_texture
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(0, 130)
	content.add_child(portrait)
	var details := RichTextLabel.new()
	details.fit_content = true
	details.scroll_active = false
	details.text = knowledge.describe(id)
	content.add_child(details)
	widgets["MonsterDetails"] = details


func _build_options() -> void:
	_label(left_page, "ui.options", 32)
	_label(left_page, L10n.text("ui.sound_display"))
	_label(left_page, L10n.text("ui.make_yourself_comfortable"), 18)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_page.add_child(spacer)
	_back(left_page)
	_label(right_page, "ui.sound", 30)
	var volume_label := _label(right_page, L10n.text("ui.master_volume"))
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = AudioServer.get_bus_volume_linear(0)
	volume.custom_minimum_size.y = 30
	right_page.add_child(volume)
	volume.value_changed.connect(func(value: float):
		AudioServer.set_bus_volume_linear(0, value)
		volume_label.text = L10n.text("ui.master_volume_d") % roundi(value * 100.0)
	)
	widgets["Volume"] = volume
	_label(right_page, "ui.display", 30)
	var fullscreen := _button(right_page, "ui.fullscreen", func(): pass)
	fullscreen.toggle_mode = true
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(enabled: bool):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	)
	widgets["Fullscreen"] = fullscreen


func _details(parent: Node, text: String) -> RichTextLabel:
	var details := RichTextLabel.new()
	details.fit_content = true
	details.scroll_active = false
	details.text = text
	parent.add_child(details)
	return details


func _compact_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := _button(parent, text, callback)
	button.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBox
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		style.content_margin_left = 7
		style.content_margin_right = 7
		button.add_theme_stylebox_override(state, style)
	return button


func _compact_list(parent: Node, height: float) -> ItemList:
	var list := ItemList.new()
	list.custom_minimum_size.y = height
	list.add_theme_font_size_override("font_size", 18)
	list.add_theme_constant_override("line_separation", 4)
	list.add_theme_constant_override("v_separation", 2)
	parent.add_child(list)
	return list


func _build_equipment(content: VBoxContainer, character: CharacterState) -> void:
	var slots := _compact_list(content, 140)
	widgets["EquipmentSlots"] = slots
	slots.add_item(L10n.text("ui.common.label_value") % [L10n.text("ui.weapon"), L10n.text(character.equipped_weapon.display_name) if character.equipped_weapon != null else L10n.text("ui.unarmed")])
	var gear := character.get_equipped_gear()
	for slot in CharacterState.GEAR_LIMIT:
		var label := L10n.text(gear[slot].definition.display_name) if slot < gear.size() else L10n.text("ui.empty")
		slots.add_item(L10n.text("ui.equipment.slot") % [slot + 1, label])
	slots.select(equipment_slot + 1)
	_label(content, "ui.equipment.choices")
	var filters := HFlowContainer.new()
	content.add_child(filters)
	widgets["EquipmentFilters"] = filters
	if equipment_slot == -1:
		var families := character.get_allowed_weapon_types()
		# Unrestricted characters can use any of the supported families.
		if not character.has_weapon_restrictions():
			for id in ["dagger", "amplifier", "gun", "crossbow", "sword", "hammer", "spear"]:
				families.append(load("res://resources/rpg/weapon_types/%s.tres" % id))
		var ids: Array[StringName] = []
		for family in families:
			ids.append(family.id)
		if weapon_family not in ids:
			weapon_family = ids[0] if not ids.is_empty() else &""
		for family in families:
			var button := _compact_button(filters, family.display_name, func():
				weapon_family = family.id
				_show_character(character_index)
			)
			button.toggle_mode = true
			button.button_pressed = weapon_family == family.id
			button.set_meta("weapon_family", family.id)
	else:
		for kind in [GearDefinition.Kind.CONSUMABLE, GearDefinition.Kind.ARTIFACT, GearDefinition.Kind.MEDALLION]:
			var button := _compact_button(filters, ["ui.artifacts", "ui.medallions", "ui.consumables"][kind], func():
				gear_kind = kind
				_show_character(character_index)
			)
			button.toggle_mode = true
			button.button_pressed = gear_kind == kind
			button.set_meta("gear_kind", kind)
	var choices := _compact_list(content, 175)
	widgets["EquipmentChoices"] = choices
	slots.item_selected.connect(func(index: int):
		equipment_slot = index - 1
		_show_character(character_index)
	)
	_show_equipment_choices(choices, character)
	choices.item_selected.connect(func(index: int):
		if not choices.is_item_selectable(index):
			return
		var selected: Variant = choices.get_item_metadata(index)
		if equipment_slot == -1:
			character.equip_weapon(selected as WeaponDefinition)
		else:
			var carried := character.get_equipped_gear()
			var previous: GearInstance = carried[equipment_slot] if equipment_slot < carried.size() else null
			if selected == null:
				character.unequip_gear(previous)
			else:
				character.replace_gear(previous, selected as GearInstance)
		_show_character(character_index)
	)


func _equipment_choice(choices: ItemList, name_key: String, item: Variant, tooltip: String) -> void:
	var index := choices.add_item(L10n.text(name_key))
	choices.set_item_metadata(index, item)
	choices.set_item_tooltip(index, tooltip)


func _show_equipment_choices(choices: ItemList, character: CharacterState) -> void:
	choices.clear()
	if equipment_slot == -1:
		if character.equipped_weapon != null:
			_equipment_choice(choices, "ui.unequip", null, L10n.text(character.equipped_weapon.display_name))
		for weapon in weapons:
			var carried := false
			for member in roster:
				if member.equipped_weapon == weapon:
					carried = true
			if not carried and character.can_equip_weapon(weapon) and weapon.weapon_type.id == weapon_family:
				_equipment_choice(choices, weapon.display_name, weapon, L10n.text(weapon.weapon_type.display_name))
	else:
		var gear := character.get_equipped_gear()
		var previous: GearInstance = gear[equipment_slot] if equipment_slot < gear.size() else null
		if previous != null:
			_equipment_choice(choices, "ui.unequip", null, _gear_description(previous))
		if inventory != null:
			for item in inventory.get_available_items():
				if item.definition.kind == gear_kind and character.gear_equip_error(item, previous).is_empty():
					_equipment_choice(choices, item.definition.display_name, item, _gear_description(item))
	if choices.item_count == 0:
		var index := choices.add_item(L10n.text("ui.equipment.no_choices"))
		choices.set_item_selectable(index, false)


func _build_abilities(content: VBoxContainer, character: CharacterState) -> void:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	content.add_child(rows)
	widgets["AbilityDetails"] = rows
	for ability in character.get_abilities():
		var row := RichTextLabel.new()
		row.bbcode_enabled = true
		row.fit_content = true
		row.scroll_active = false
		row.add_theme_font_size_override("normal_font_size", 18)
		row.tooltip_text = CharacterInformation.ability_tooltip(ability)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var category := CharacterInformation.ability_category(ability)
		var color: Color = CharacterInformation.ABILITY_COLORS[category]
		var colored_type := "[color=#%s]%s[/color]" % [color.to_html(false), L10n.text(category).replace("[", "[lb]")]
		row.text = L10n.text("ui.ability.book_row") % [
			L10n.text(ability.display_name).replace("[", "[lb]"),
			L10n.text(CharacterInformation.ability_origin(character, ability)).replace("[", "[lb]"),
			colored_type, ability.mana_cost,
		]
		rows.add_child(row)
		row.set_meta("ability", ability)
	if rows.get_child_count() == 0:
		_label(rows, "ui.none")


func _gear_description(item: GearInstance) -> String:
	var gear := item.definition
	var lines := PackedStringArray([L10n.text(gear.display_name), gear.type_name(), L10n.text(gear.description)])
	for stat in gear.stat_modifiers:
		if stat in RPGStats.NAMES:
			lines.append(L10n.text("ui.equipment.stat_modifier") % [RPGStats.display_name(stat), gear.stat_modifiers[stat]])
	for resistance in gear.resistances:
		if resistance != null and resistance.damage_type != null:
			lines.append(L10n.text("ui.common.label_value") % [L10n.text(resistance.damage_type.display_name), L10n.text(DamageResistance.display_label(resistance.amount))])
	for spell in gear.spells:
		lines.append(L10n.text("ui.ability.mana_cost") % [L10n.text(spell.display_name), spell.mana_cost])
	if gear.kind == GearDefinition.Kind.CONSUMABLE:
		lines.append(L10n.text("ui.d_uses") % item.remaining_uses())
	return "\n".join(lines)


func _build_lessons() -> void:
	_label(left_page, "ui.lessons.title", 30)
	var topics := ItemList.new()
	topics.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_page.add_child(topics)
	widgets["Lessons"] = topics
	for lesson in LESSONS:
		topics.add_item(L10n.text(lesson[0]))
	topics.item_selected.connect(_show_lesson)
	_back(left_page)
	topics.select(0)
	_show_lesson(0)


func _show_lesson(index: int) -> void:
	for child in right_page.get_children():
		right_page.remove_child(child)
		child.queue_free()
	var lesson: Array = LESSONS[index]
	var content := _scroll(right_page)
	_label(content, lesson[0], 30)
	widgets["LessonDetails"] = _details(content, L10n.text(lesson[1]))
