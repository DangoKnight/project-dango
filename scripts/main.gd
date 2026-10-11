extends Node

const MAIN_MENU := preload("res://scenes/ui/main_menu.tscn")
const LOCATION := preload("res://scenes/ui/services.tscn")
const BARRACKS := preload("res://scenes/ui/barracks.tscn")
const LEVEL_UP_NOTICE := preload("res://scenes/ui/level_up_notice.tscn")
const OPTIONS := preload("res://scenes/ui/options.tscn")
const PAUSE_MENU := preload("res://scenes/ui/pause_menu.tscn")
const HUD := preload("res://scenes/ui/exploration_hud.tscn")
const CHARACTERS := preload("res://scenes/ui/characters.tscn")
const EQUIPMENT := preload("res://scenes/ui/equipment.tscn")
const COMBAT := preload("res://scenes/battle/combat.tscn")
var compendium := MonsterCompendium.new()
@export var starting_town: PackedScene = preload("res://scenes/ui/town.tscn")
@export var opening_conversation: ConversationEvent = preload("res://resources/conversations/station_check_in.tres")
var _opening_event: ConversationEvent
@export var starting_characters: Array[CharacterDefinition] = [
	preload("res://resources/rpg/characters/usami.tres"),
	preload("res://resources/rpg/characters/takane.tres"),
	preload("res://resources/rpg/characters/kurako.tres"),
	preload("res://resources/rpg/characters/koumi.tres"),
]

@export var starting_gear: Array[GearDefinition] = [
	preload("res://resources/rpg/gear/iron_artifact.tres"),
	preload("res://resources/rpg/gear/wind_artifact.tres"),
	preload("res://resources/rpg/gear/vital_artifact.tres"),
	preload("res://resources/rpg/gear/spell_medallion.tres"),
	preload("res://resources/rpg/gear/rally_flask.tres"),
	preload("res://resources/rpg/gear/healing_draught.tres"),
	preload("res://resources/rpg/gear/frailty_bomb.tres"),
]
@export_range(0.0, 2.0, 0.05) var battle_fade_in_duration := 0.35
@export_range(0.0, 5.0, 0.1) var battle_reveal_duration := 2.0
@export_range(0.0, 2.0, 0.05) var battle_return_fade_duration := 0.35
@export_range(0.0, 2.0, 0.05) var navigation_fade_duration := 0.45
@export_range(0.0, 3.0, 0.05) var new_game_reveal_duration := 0.75
@export_range(0.0, 2.0, 0.05) var sleep_fade_duration := 0.5
var _battle_transition := false
var level_up_notice: Control
@onready var battle_fade: ColorRect = $UI/BattleFade

var gear_inventory := GearInventory.new()
var safe_zone_services: Dictionary[String, SafeZoneServices] = {}
var weapon_inventory: Array[WeaponDefinition] = []
var active_safe_zone_key := ""
# Keep the last visited refuge, but rebuild the labyrinth on each entry.
var labyrinth_entries: Dictionary[String, StringName] = {}
var labyrinth_discoveries: Dictionary[String, Dictionary] = {}
# Shared rest multiplier: highest completion across labyrinth visits since last rest.
var highest_labyrinth_completion := 0.0
var last_safe_zone_scene: PackedScene

@onready var ui: Control = $UI/Screens
@onready var world_container: Node3D = $World
var world: Map
var player: CharacterBody3D
var screen := "main"
var options_return := "main"
var pause_return := "explore"
var party: Array[CharacterState] = []
var roster: Array[CharacterState] = []
var current_town_scene: PackedScene
var current_map_scene: PackedScene
var location_backgrounds: Dictionary[String, Texture2D] = {}


func _ready() -> void:
	Conversations.can_start = _can_start_conversation
	Conversations.finished.connect(_on_conversation_finished)
	# The initial menu is also visible when editing the main scene.
	ui.get_child(0).action_requested.connect(_on_action_requested)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _can_start_conversation() -> bool:
	return not _battle_transition and not is_instance_valid(level_up_notice)


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
		"Characters": show_characters()
		"Equipment": show_equipment()
		"Battle": start_combat()
		"Map": show_labyrinth_map()
		"MapBack": show_pause(pause_return)
		"Monsters", "Compendium": show_compendium()
		"CompendiumBack": show_pause(pause_return)
		"MainMenu": show_main()
		"Barracks", "Tinkerer", "Barterer": show_location(action)
		"Options": show_options(screen)
		"Resume": _resume_pause()
		"Back": _options_back()
		"Exit": get_tree().quit()


func _remove_world() -> void:
	if is_instance_valid(world):
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
	var destination := town_scene if town_scene != null else current_town_scene
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
	current_town_scene = destination
	location_backgrounds = town.location_backgrounds.duplicate()
	current_map_scene = town.exploration_map
	_remove_world()
	_show_view(town, "town")


func new_game(with_opening_conversation: bool = true) -> void:
	Conversations.reset()
	_opening_event = opening_conversation if with_opening_conversation and opening_conversation != null and opening_conversation.is_valid() else null
	highest_labyrinth_completion = 0.0
	safe_zone_services.clear()
	weapon_inventory.clear()
	active_safe_zone_key = starting_town.resource_path
	last_safe_zone_scene = starting_town
	labyrinth_entries.clear()
	labyrinth_discoveries.clear()
	compendium = MonsterCompendium.new()
	current_town_scene = starting_town
	party.clear()
	roster.clear()
	gear_inventory = GearInventory.new()
	for gear in starting_gear:
		gear_inventory.add(gear)
	for character in starting_characters:
		if character != null:
			var member := CharacterState.new(character)
			roster.append(member)
			if party.size() < 4:
				party.append(member)
	for member in roster:
		for item in member.get_equipped_gear():
			gear_inventory.register(item)
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
	if event != _opening_event:
		return
	_opening_event = null
	if ui.get_child_count() > 0 and ui.get_child(0) is Town:
		ui.get_child(0).set_navigation_locked(false)


func show_equipment() -> void:
	var view := _show_scene(EQUIPMENT, "equipment")
	view.configure(roster, gear_inventory)


func show_characters() -> void:
	var view := _show_scene(CHARACTERS, "characters")
	view.configure(roster)


func show_location(location: String) -> void:
	if ui.get_child_count() == 0 or not ui.get_child(0) is Town:
		show_town()
	var town := ui.get_child(0) as Town
	if town.module_view != null and town.module_view.get_meta("location", "") == location:
		town._navigation_pending = true
		await town.dismiss_module()
		town._navigation_pending = false
		screen = "town"
		return
	var view := (BARRACKS if location == "Barracks" else LOCATION).instantiate() as Control
	view.set_meta("location", location)
	view.get_node("Background").texture = location_backgrounds.get(location)
	town.open_module(view)
	view.action_requested.connect(_on_action_requested)
	if location == "Barracks":
		view.configure(roster, party)
		view.sleep_requested.connect(_sleep_at_barracks.bind(view))
	else:
		if not safe_zone_services.has(active_safe_zone_key):
			var services := SafeZoneServices.new()
			services.configure(town)
			safe_zone_services[active_safe_zone_key] = services
		view.configure(safe_zone_services[active_safe_zone_key], gear_inventory, roster, weapon_inventory, location)
	screen = "location"


func _module_busy() -> bool:
	if _opening_event != null:
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
	var reports: Array[Dictionary] = view.apply_rest(highest_labyrinth_completion)
	highest_labyrinth_completion = 0.0
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
	if _battle_transition or (map_scene == null and current_map_scene == null):
		return
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
	labyrinth_entries[map_path] = landmark.id
	active_safe_zone_key = map_path + "#" + String(landmark.id)
	last_safe_zone_scene = load(landmark.town_scene_path) as PackedScene if not landmark.town_scene_path.is_empty() else current_town_scene
	show_town(last_safe_zone_scene)
	await _fade_battle_to(0.0, navigation_fade_duration)
	battle_fade.hide()
	_battle_transition = false


func explore(map_scene: PackedScene = null) -> void:
	var destination := map_scene if map_scene != null else current_map_scene
	if destination == null:
		return
	var instance := destination.instantiate()
	if not instance is Map:
		instance.free()
		push_error("Map scenes must inherit scenes/base/map.tscn")
		return
	current_map_scene = destination
	_remove_world()
	world = instance as Map
	if world is LabyrinthMap:
		var labyrinth := world as LabyrinthMap
		if not labyrinth_discoveries.has(destination.resource_path):
			var discoveries: Dictionary[StringName, bool] = {}
			labyrinth_discoveries[destination.resource_path] = discoveries
		labyrinth.discovered_landmarks = labyrinth_discoveries[destination.resource_path]
		labyrinth.entry_landmark = labyrinth_entries.get(destination.resource_path, &"")
		labyrinth.step_taken.connect(_advance_service_step)
		labyrinth.encounter_requested.connect(start_combat)
		labyrinth.exploration_changed.connect(_record_exploration_completion)
		labyrinth.reward_collected.connect(func(reward: GearDefinition): gear_inventory.add(reward))
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
		if active_safe_zone_key == starting_town.resource_path:
			if safe_zone_services.has(active_safe_zone_key):
				safe_zone_services[entry_key] = safe_zone_services[active_safe_zone_key]
				safe_zone_services.erase(active_safe_zone_key)
			active_safe_zone_key = entry_key
		_record_exploration_completion(world.exploration_completion())
		# Remember the initial refuge as well as doorways visited later.
		labyrinth_entries[destination.resource_path] = world.entry_landmark
	last_safe_zone_scene = current_town_scene
	player = world.player
	resume_exploration()


func _record_exploration_completion(completion: float) -> void:
	highest_labyrinth_completion = maxf(highest_labyrinth_completion, clampf(completion, 0.0, 1.0))


func resume_exploration() -> void:
	_show_scene(HUD, "explore")
	world.set_active(true)


func _pause_book() -> PauseBook:
	if ui.get_child_count() == 0 or not ui.get_child(0) is PauseBook:
		show_pause("explore" if is_instance_valid(world) else "town")
	return ui.get_child(0) as PauseBook


func show_labyrinth_map() -> void:
	if world is LabyrinthMap and world.layout.error.is_empty():
		_pause_book().open_page("map")


func show_compendium() -> void:
	_pause_book().open_page("monsters")


func show_pause(return_to: String = "explore") -> void:
	pause_return = return_to
	var view := _show_scene(PAUSE_MENU, "pause") as PauseBook
	view.configure(world, compendium, return_to == "town")

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
	if not view.configure(party, world.encounter, compendium):
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
		show_town(last_safe_zone_scene)
	else:
		show_town()
	await _fade_battle_to(0.0, battle_return_fade_duration)
	battle_fade.hide()
	_battle_transition = false
	if screen == "explore" and is_instance_valid(world):
		world.set_active(true)


func _recover_from_party_wipe() -> void:
	highest_labyrinth_completion = 0.0
	for member in roster:
		for item in member.get_equipped_gear():
			if item.definition.kind == GearDefinition.Kind.CONSUMABLE:
				item.destroy_consumable()
	gear_inventory.discard_consumables()
	for member in roster:
		member.restore()


func _input(event: InputEvent) -> void:
	if is_instance_valid(level_up_notice):
		return
	if _battle_transition or _module_busy():
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("party_information") and screen in ["town", "location", "characters"]:
		get_viewport().set_input_as_handled()
		if screen in ["town", "location"]:
			if screen == "location":
				_battle_transition = true
				await ui.get_child(0).dismiss_module()
				_battle_transition = false
			show_characters()
		else:
			show_town()


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
					show_town()
			"characters": show_town()
			"town": show_pause("town")
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen == "explore" and not _battle_transition and not Conversations.is_active():
		show_pause()


func _advance_service_step() -> void:
	for services in safe_zone_services.values():
		services.advance_step()


func _record_service_kill(species: StringName) -> void:
	for services in safe_zone_services.values():
		services.record_kill(species)
