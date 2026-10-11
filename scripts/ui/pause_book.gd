class_name PauseBook
extends Control

signal action_requested(action: String)

const CHART := preload("res://scripts/ui/labyrinth_map_canvas.gd")
@export_range(0.0, 1.0, 0.02) var page_fade_duration := 0.18
@onready var left_page: VBoxContainer = $Panel/LeftPage
@onready var right_page: VBoxContainer = $Panel/RightPage
var current_page := "index"
var transitioning := false
var map: Map
var knowledge: MonsterCompendium
var town_context := false
var commands: Dictionary[String, Button] = {}
var widgets: Dictionary[String, Control] = {}


func _ready() -> void:
	_build_index()


func configure(current_map: Map, compendium: MonsterCompendium, in_town: bool) -> void:
	map = current_map
	knowledge = compendium
	town_context = in_town
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
	if page == "map" and not map is LabyrinthMap:
		return
	transitioning = true
	await _fade_pages(0.0)
	_clear_pages()
	current_page = page
	match page:
		"map": _build_map()
		"monsters": _build_monsters()
		"options": _build_options()
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
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
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
			"Options": open_page("options")
			_: _leave(action)
	)
	button.name = action
	commands[action] = button
	return button


func _back(parent: Node) -> void:
	widgets["Back"] = _button(parent, "Back", func(): open_page("index"))
	widgets["Back"].tooltip_text = "Return to contents (Esc)"


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
	_label(left_page, "Field journal", 32)
	_label(left_page, "Safe Zone" if town_context else map.display_name if map != null else "Rest a moment", 18)
	_index_button(left_page, "Resume", "Return" if town_context else "Resume")
	var chart := _index_button(left_page, "Map", "Map")
	chart.visible = not town_context
	chart.disabled = not map is LabyrinthMap
	_index_button(left_page, "Monsters", "Monsters")
	_label(right_page, "Notes & settings", 30)
	_index_button(right_page, "Options", "Options")
	_index_button(right_page, "MainMenu", "Main Menu")
	command("Resume").grab_focus()


func _build_map() -> void:
	var labyrinth := map as LabyrinthMap
	_label(left_page, "Exploration", 30)
	var stats := _scroll(left_page)
	_label(stats, labyrinth.display_name)
	var completion := 100.0 * labyrinth.walked_cells.size() / labyrinth.layout.passages.size()
	widgets["Completion"] = _label(stats, "Map completion\n%.1f%%" % completion)
	var chart := Control.new()
	chart.set_script(CHART)
	chart.name = "MapCanvas"
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.custom_minimum_size = Vector2(0, 40)
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chart.ink_on_paper = true
	_label(right_page, "Map", 30)
	right_page.add_child(chart)
	chart.configure(labyrinth)
	widgets["MapCanvas"] = chart
	var landmarks: Array[LabyrinthLandmark] = chart.visible_landmarks()
	widgets["Landmarks"] = _label(stats, "Discovered landmarks\n%d" % landmarks.size())
	widgets["Items"] = _label(stats, "Picked up items\n%d" % labyrinth.items_picked_up)
	_back(left_page)


func _build_monsters() -> void:
	_label(left_page, "Monsters", 32)
	var members := ItemList.new()
	members.size_flags_vertical = Control.SIZE_EXPAND_FILL
	members.add_theme_font_size_override("font_size", 22)
	left_page.add_child(members)
	widgets["Monsters"] = members
	var ids: Array[StringName] = []
	if knowledge != null:
		for id in knowledge.entries:
			ids.append(id)
			members.add_item(knowledge.entries[id].definition.display_name)
	members.item_selected.connect(func(index: int): _show_monster(ids[index]))
	_back(left_page)
	if ids.is_empty():
		_label(right_page, "Field notes", 30)
		_label(right_page, "No monsters encountered yet.")
	else:
		members.select(0)
		_show_monster(ids[0])


func _show_monster(id: StringName) -> void:
	for child in right_page.get_children():
		right_page.remove_child(child)
		child.queue_free()
	var content := _scroll(right_page)
	_label(content, knowledge.entries[id].definition.display_name, 30)
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
	_label(left_page, "Options", 32)
	_label(left_page, "Sound & display")
	_label(left_page, "Make yourself comfortable.", 18)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_page.add_child(spacer)
	_back(left_page)
	_label(right_page, "Sound", 30)
	var volume_label := _label(right_page, "Master volume")
	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = AudioServer.get_bus_volume_linear(0)
	volume.custom_minimum_size.y = 30
	right_page.add_child(volume)
	volume.value_changed.connect(func(value: float):
		AudioServer.set_bus_volume_linear(0, value)
		volume_label.text = "Master volume · %d%%" % roundi(value * 100.0)
	)
	widgets["Volume"] = volume
	_label(right_page, "Display", 30)
	var fullscreen := _button(right_page, "Fullscreen", func(): pass)
	fullscreen.toggle_mode = true
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(enabled: bool):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	)
	widgets["Fullscreen"] = fullscreen
