extends Node

const MAIN_MENU := preload("res://scenes/ui/main_menu.tscn")
const LOCATION := preload("res://scenes/ui/services.tscn")
const BARRACKS := preload("res://scenes/ui/barracks.tscn")
const LEVEL_UP_NOTICE := preload("res://scenes/ui/level_up_notice.tscn")
const OPTIONS := preload("res://scenes/ui/options.tscn")
const PAUSE_MENU := preload("res://scenes/ui/pause_menu.tscn")
const HUD := preload("res://scenes/ui/exploration_hud.tscn")
const COMBAT := preload("res://scenes/battle/combat.tscn")
@export var starting_town: PackedScene = preload("res://scenes/ui/town.tscn")
@export var opening_conversation: ConversationEvent = preload("res://resources/conversations/station_check_in.tres")
var _opening_event: ConversationEvent
@export var starting_characters: Array[CharacterDefinition] = [
	preload("res://resources/rpg/characters/usami.tres"),
	preload("res://resources/rpg/characters/takane.tres"),
	preload("res://resources/rpg/characters/kurako.tres"),
]
## Remaining starting characters are available in the reserve roster.
@export_range(1, 4) var starting_party_size := 3

@export var starting_gear: Array[GearDefinition] = []
@export_range(0.0, 2.0, 0.05) var battle_fade_in_duration := 0.35
@export_range(0.0, 5.0, 0.1) var battle_reveal_duration := 2.0
@export_range(0.0, 2.0, 0.05) var battle_return_fade_duration := 0.35
@export_range(0.0, 2.0, 0.05) var navigation_fade_duration := 0.45
@export_range(0.0, 3.0, 0.05) var new_game_reveal_duration := 0.75
@export_range(0.0, 2.0, 0.05) var sleep_fade_duration := 0.5
var _module_intro_event: ConversationEvent
var _module_intro_town: Town
var _module_intro_location := ""
var _departure_event: ConversationEvent
var _departure_town: Town
var _departure_map: PackedScene
var _battle_transition := false
var level_up_notice: Control
@onready var battle_fade: ColorRect = $UI/BattleFade

var state: RunState:
	get:
		return get_node("/root/GameState") as RunState

@onready var ui: Control = $UI/Screens
@onready var world_container: Node3D = $World
var world: Map
var player: CharacterBody3D
var screen := "main"
var options_return := "main"
var pause_return := "explore"
var location_backgrounds: Dictionary[String, Texture2D] = {}
var current_town_name := "ui.safe_zone"


func _ready() -> void:
	Conversations.can_start = _can_start_conversation
	Conversations.finished.connect(_on_conversation_finished)
	state.flag_changed.connect(_on_run_flag_changed)
	# The initial menu is also visible when editing the main scene.
	ui.get_child(0).action_requested.connect(_on_action_requested)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _can_start_conversation() -> bool:
	return not _battle_transition and not is_instance_valid(level_up_notice)


func _on_run_flag_changed(key: StringName, value: Variant) -> void:
	if key == &"labyrinth_unlocked" and ui.get_child_count() > 0 and ui.get_child(0) is Town:
		ui.get_child(0).exploration_enabled = bool(value)


func _show_scene(scene: PackedScene, next_screen: String) -> Control:
	return _show_view(scene.instantiate() as Control, next_screen)


func _show_view(view: Control, next_screen: String) -> Control:
	screen = next_screen
	if is_instance_valid(world):
		world.set_active(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	ui.add_child(view)
	if view.has_signal("action_requested"):
		view.action_requested.connect(_on_action_requested)
	if view is Town:
		view.exploration_requested.connect(enter_labyrinth)
	return view


func _on_action_requested(action: String) -> void:
	if _battle_transition or _module_busy():
		return
	match action:
		"NewGame": new_game()
		"Town": show_town()
		"ReturnToHub": show_town()
		"Characters": show_characters()
		"Equipment": show_equipment()
		"Battle": start_combat()
		"Map": show_labyrinth_map()
		"Monsters": show_compendium()
		"MainMenu": show_main()
		"Barracks", "Tinkerer", "Barterer": show_location(action)
		"Options": show_options(screen)
		"Resume": _resume_pause()
		"Back": _options_back()
		"Exit": get_tree().quit()


func _remove_world() -> void:
	if is_instance_valid(world):
		if world is LabyrinthMap and world.layout != null and world.layout.error.is_empty():
			state.labyrinth_maps[world.scene_file_path] = LabyrinthMapSnapshot.capture(world)
		world_container.remove_child(world)
		world.queue_free()
	world = null
	player = null


func show_main() -> void:
	_remove_world()
	_show_scene(MAIN_MENU, "main")


func show_town(town_scene: PackedScene = null) -> void:
	if town_scene == null and ui.get_child_count() > 0 and ui.get_child(0) is Town:
		ui.get_child(0).close_module()
		screen = "town"
		return
	var destination := town_scene if town_scene != null else state.current_town_scene
	if destination == null:
		destination = starting_town
	if destination == null:
		return
	# Validate before removing the current map or screen.
	var instance := destination.instantiate()
	if not instance is Town:
		instance.free()
		push_error("Town scenes must inherit scenes/base/town.tscn")
		return
	var town := instance as Town
	town.navigation_locked = _opening_event != null
	town.exploration_enabled = bool(state.get_flag(&"labyrinth_unlocked", false))
	state.current_town_scene = destination
	current_town_name = town.display_name
	location_backgrounds = town.location_backgrounds.duplicate()
	state.current_map_scene = town.exploration_map
	_remove_world()
	_show_view(town, "town")


func new_game(with_opening_conversation: bool = true) -> void:
	_departure_event = null
	_departure_town = null
	_departure_map = null
	_module_intro_event = null
	_module_intro_town = null
	_module_intro_location = ""
	Conversations.reset()
	_opening_event = opening_conversation if with_opening_conversation and opening_conversation != null and opening_conversation.is_valid() else null
	_remove_world()
	state.start_new_game(starting_town, starting_characters, starting_gear, starting_party_size)
	if with_opening_conversation:
		_battle_transition = true
		battle_fade.color.a = 1.0
		battle_fade.show()
	show_town(starting_town)
	if _opening_event != null and not Conversations.play(_opening_event):
		_on_conversation_finished(_opening_event)
	if with_opening_conversation:
		_reveal_new_game()


func _reveal_new_game() -> void:
	await _fade_battle_to(0.0, new_game_reveal_duration)
	battle_fade.hide()
	_battle_transition = false


func _on_conversation_finished(event: ConversationEvent) -> void:
	if event == _departure_event:
		var town := _departure_town
		var destination := _departure_map
		_departure_event = null
		_departure_town = null
		_departure_map = null
		if is_instance_valid(town) and town.is_inside_tree() and ui.get_child_count() > 0 and ui.get_child(0) == town:
			town.set_navigation_locked(false)
			town._navigation_pending = true
			# Allow the conversation director to restore the scene before the fade.
			_enter_after_departure.call_deferred(destination, town)
		return
	if event == _module_intro_event:
		var town := _module_intro_town
		var location := _module_intro_location
		_module_intro_event = null
		_module_intro_town = null
		_module_intro_location = ""
		if is_instance_valid(town) and town.is_inside_tree() and ui.get_child(0) == town:
			town.set_navigation_locked(false)
			show_location(location)
		return
	if event != _opening_event:
		return
	_opening_event = null
	if ui.get_child_count() > 0 and ui.get_child(0) is Town:
		ui.get_child(0).set_navigation_locked(false)


func show_equipment() -> void:
	var view := _pause_book()
	view.character_tab = 2
	await view.open_page("characters")


func show_characters() -> void:
	await _pause_book().open_page("characters")


func show_location(location: String) -> void:
	if _module_intro_event != null:
		return
	if ui.get_child_count() == 0 or not ui.get_child(0) is Town:
		show_town()
	var town := ui.get_child(0) as Town
	if town.module_view != null and town.module_view.get_meta("location", "") == location:
		town._navigation_pending = true
		await town.dismiss_module()
		town._navigation_pending = false
		screen = "town"
		return
	var introduction: ConversationEvent = town.module_conversations.get(location)
	if introduction != null and introduction.is_valid() and not state.completed_conversations.has(introduction.id):
		_module_intro_event = introduction
		_module_intro_town = town
		_module_intro_location = location
		town.close_module(false)
		town.set_navigation_locked(true)
		town.get_node("Background").texture = town.location_backgrounds.get(location, town.background_texture)
		if Conversations.play(introduction):
			return
		_module_intro_event = null
		_module_intro_town = null
		_module_intro_location = ""
		town.set_navigation_locked(false)
	var view := (BARRACKS if location == "Barracks" else LOCATION).instantiate() as Control
	view.set_meta("location", location)
	view.get_node("Background").texture = location_backgrounds.get(location)
	town.open_module(view)
	view.action_requested.connect(_on_action_requested)
	if location == "Barracks":
		view.configure(state.roster, state.party)
		view.sleep_requested.connect(_sleep_at_barracks.bind(view))
	else:
		view.configure(state.services_for(town), state.gear_inventory, state.roster, state.weapon_inventory, location)
	_record_module_visit(location)
	screen = "location"


func _record_module_visit(location: String) -> void:
	var key := StringName("safe_zone_modules:" + state.active_safe_zone_key)
	var visits: Dictionary = state.get_flag(key, {}).duplicate()
	visits[location] = true
	state.set_flag(key, visits)
	for required_module in ["Barracks", "Tinkerer", "Barterer"]:
		if not visits.has(required_module):
			return
	state.set_flag(&"labyrinth_unlocked", true)


func _module_busy() -> bool:
	if _opening_event != null or _module_intro_event != null or _departure_event != null:
		return true
	if ui.get_child_count() > 0 and ui.get_child(0) is Town:
		if ui.get_child(0)._navigation_pending:
			return true
		var module: Control = ui.get_child(0).module_view
		return module != null and module.has_method("is_busy") and module.is_busy()
	return false


func _sleep_at_barracks(view: Control) -> void:
	if _battle_transition or view.is_busy():
		return
	_battle_transition = true
	view._busy = true
	battle_fade.color.a = 0.0
	battle_fade.show()
	await _fade_battle_to(1.0, sleep_fade_duration)
	var reports: Array[Dictionary] = view.apply_rest(state.highest_labyrinth_completion)
	state.highest_labyrinth_completion = 0.0
	if not reports.is_empty():
		level_up_notice = LEVEL_UP_NOTICE.instantiate()
		$UI.add_child(level_up_notice)
		level_up_notice.configure(reports)
		await level_up_notice.dismissed
		level_up_notice.queue_free()
		level_up_notice = null
	await _fade_battle_to(0.0, sleep_fade_duration)
	battle_fade.hide()
	view._busy = false
	_battle_transition = false
	view.get_node("Panel/Buttons/Sleep").grab_focus()


func show_options(return_to: String) -> void:
	options_return = return_to
	if return_to == "pause":
		_pause_book().open_page("options")
	else:
		_show_scene(OPTIONS, "options")


func _options_back() -> void:
	match options_return:
		"town": show_town()
		"pause": show_pause(pause_return)
		_: show_main()


func enter_labyrinth(map_scene: PackedScene = null) -> void:
	if _battle_transition or _module_busy() or Conversations.is_active() or (map_scene == null and state.current_map_scene == null):
		return
	if ui.get_child_count() > 0 and ui.get_child(0) is Town:
		var town := ui.get_child(0) as Town
		if not town.exploration_enabled or town.module_view != null:
			return
		var departure := town.departure_conversation
		if departure != null and departure.is_valid() and (not departure.once_per_game or not state.completed_conversations.has(departure.id)):
			_departure_event = departure
			_departure_town = town
			_departure_map = map_scene if map_scene != null else state.current_map_scene
			town.set_navigation_locked(true)
			if Conversations.play(departure):
				return
			_departure_event = null
			_departure_town = null
			_departure_map = null
			town.set_navigation_locked(false)
	_begin_labyrinth_entry(map_scene)


func _enter_after_departure(map_scene: PackedScene, town: Town) -> void:
	if not is_instance_valid(town) or not town.is_inside_tree() or ui.get_child_count() == 0 or ui.get_child(0) != town:
		return
	town._navigation_pending = false
	_begin_labyrinth_entry(map_scene)


func _begin_labyrinth_entry(map_scene: PackedScene) -> void:
	_battle_transition = true
	battle_fade.color.a = 0.0
	battle_fade.show()
	await _fade_battle_to(1.0, navigation_fade_duration)
	explore(map_scene)
	if is_instance_valid(world):
		world.set_active(false)
	await _fade_battle_to(0.0, navigation_fade_duration)
	battle_fade.hide()
	_battle_transition = false
	if screen == "explore" and is_instance_valid(world):
		world.set_active(true)


func _enter_safe_zone(map_path: String, landmark: LabyrinthLandmark) -> void:
	if _battle_transition:
		return
	_battle_transition = true
	world.set_active(false)
	battle_fade.color.a = 0.0
	battle_fade.show()
	await _fade_battle_to(1.0, navigation_fade_duration)
	state.labyrinth_entries[map_path] = landmark.id
	state.active_safe_zone_key = map_path + "#" + String(landmark.id)
	state.last_safe_zone_scene = load(landmark.town_scene_path) as PackedScene if not landmark.town_scene_path.is_empty() else state.current_town_scene
	show_town(state.last_safe_zone_scene)
	await _fade_battle_to(0.0, navigation_fade_duration)
	battle_fade.hide()
	_battle_transition = false


func explore(map_scene: PackedScene = null) -> void:
	var destination := map_scene if map_scene != null else state.current_map_scene
	if destination == null:
		return
	var instance := destination.instantiate()
	if not instance is Map:
		instance.free()
		push_error("Map scenes must inherit scenes/base/map.tscn")
		return
	state.current_map_scene = destination
	_remove_world()
	world = instance as Map
	if world is LabyrinthMap:
		var labyrinth := world as LabyrinthMap
		labyrinth.discovered_landmarks = state.discoveries_for(destination.resource_path)
		labyrinth.entry_landmark = state.labyrinth_entries.get(destination.resource_path, &"")
		labyrinth.step_taken.connect(_advance_service_step)
		labyrinth.encounter_requested.connect(start_combat)
		labyrinth.exploration_changed.connect(_record_exploration_completion)
		labyrinth.reward_collected.connect(func(reward: GearDefinition): state.gear_inventory.add(reward))
		labyrinth.safe_zone_requested.connect(func(landmark: LabyrinthLandmark):
			_enter_safe_zone(destination.resource_path, landmark)
		)
	world_container.add_child(world)
	if world is LabyrinthMap:
		if not world.layout.error.is_empty():
			show_town()
			return
		# Give the initial town the same identity when its doorway is revisited.
		var entry_key := destination.resource_path + "#" + String(world.entry_landmark)
		state.adopt_initial_safe_zone(starting_town, entry_key)
		_record_exploration_completion(world.exploration_completion())
		# Remember the initial refuge as well as doorways visited later.
		state.labyrinth_entries[destination.resource_path] = world.entry_landmark
	state.last_safe_zone_scene = state.current_town_scene
	player = world.player
	resume_exploration()


func _record_exploration_completion(completion: float) -> void:
	state.record_exploration_completion(completion)


func resume_exploration() -> void:
	_show_scene(HUD, "explore")
	world.set_active(true)


func _pause_book() -> PauseBook:
	if ui.get_child_count() == 0 or not ui.get_child(0) is PauseBook:
		show_pause("explore" if is_instance_valid(world) else "town")
	return ui.get_child(0) as PauseBook


func show_labyrinth_map() -> void:
	if (world is LabyrinthMap and world.layout.error.is_empty()) or not state.labyrinth_maps.is_empty():
		_pause_book().open_page("map")


func show_compendium() -> void:
	_pause_book().open_page("monsters")


func show_pause(return_to: String = "explore") -> void:
	pause_return = return_to
	var view := _show_scene(PAUSE_MENU, "pause") as PauseBook
	view.configure(world, state.compendium, return_to == "town", current_town_name, state.roster, state.labyrinth_maps.values(), state.current_map_scene.resource_path if state.current_map_scene != null else "")
	view.inventory = state.gear_inventory
	view.weapons = state.weapon_inventory

func _resume_pause() -> void:
	if pause_return == "town":
		show_town()
	else:
		resume_exploration()


func start_combat(animated: bool = true) -> void:
	if _battle_transition or screen != "explore" or world == null or world.encounter == null:
		return
	_battle_transition = true
	if animated:
		screen = "combat_transition"
		world.set_active(false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		battle_fade.color.a = 0.0
		battle_fade.show()
		await _fade_battle_to(1.0, battle_fade_in_duration)
	var view := COMBAT.instantiate() as CombatScreen
	world.visible = false
	_show_view(view, "combat")
	view.finished.connect(_on_combat_finished)
	if not view.configure(state.party, world.encounter, state.compendium):
		battle_fade.hide()
		_battle_transition = false
		world.visible = true
		if world is LabyrinthMap:
			world.reset_encounters()
		resume_exploration()
		return
	view.session.enemy_defeated.connect(_record_service_kill)
	if animated:
		view.set_intro_playing(true)
		await _fade_battle_to(0.0, battle_reveal_duration)
		view.set_intro_playing(false)
	battle_fade.hide()
	_battle_transition = false


func _fade_battle_to(alpha: float, duration: float) -> void:
	if duration <= 0.0:
		battle_fade.color.a = alpha
		return
	var tween := create_tween()
	tween.tween_property(battle_fade, "color:a", alpha, duration)
	await tween.finished


func _on_combat_finished(victory: bool) -> void:
	_battle_transition = true
	battle_fade.color.a = 0.0
	battle_fade.show()
	await _fade_battle_to(1.0, battle_return_fade_duration)
	if victory and is_instance_valid(world):
		world.visible = true
		if world is LabyrinthMap:
			world.reset_encounters()
		resume_exploration()
		world.set_active(false)
	elif not victory:
		_recover_from_party_wipe()
		show_town(state.last_safe_zone_scene)
	else:
		show_town()
	await _fade_battle_to(0.0, battle_return_fade_duration)
	battle_fade.hide()
	_battle_transition = false
	if screen == "explore" and is_instance_valid(world):
		world.set_active(true)


func _recover_from_party_wipe() -> void:
	state.recover_from_party_wipe()


func _input(event: InputEvent) -> void:
	if is_instance_valid(level_up_notice):
		return
	if _battle_transition or _module_busy():
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("party_information"):
		if screen == "explore":
			get_viewport().set_input_as_handled()
			show_labyrinth_map()
		elif screen == "pause" and pause_return == "explore":
			get_viewport().set_input_as_handled()
			var book := ui.get_child(0) as PauseBook
			if not book.transitioning:
				if book.current_page == "map":
					_resume_pause()
				else:
					book.open_page("map")


func _unhandled_input(event: InputEvent) -> void:
	if _battle_transition or _module_busy():
		get_viewport().set_input_as_handled()
		return
	if screen == "explore" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E and world is LabyrinthMap:
		world.interact()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		match screen:
			"explore": show_pause()
			"pause":
				var book := ui.get_child(0) as PauseBook
				if book.transitioning:
					return
				if book.current_page != "index":
					book.open_page("index")
				else:
					_resume_pause()
			"map", "compendium": show_pause(pause_return)
			"options": _options_back()
			"equipment": show_characters()
			"location":
				var town := ui.get_child(0) as Town
				if town.module_view != null and town.module_view.has_method("close_party") and town.module_view.get_node("PartyPanel").visible:
					town.module_view.close_party()
				else:
					show_pause("town")
			"characters": show_town()
			"town": show_pause("town")
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen == "explore" and not _battle_transition and not Conversations.is_active():
		show_pause()


func _advance_service_step() -> void:
	state.advance_service_step()


func _record_service_kill(species: StringName) -> void:
	state.record_service_kill(species)
