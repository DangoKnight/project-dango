class_name RunState
extends Node

## GameState autoload: owns the current run independently of gameplay scenes.
signal run_started
signal flag_changed(key: StringName, value: Variant)

var has_started := false
var party: Array[CharacterState] = []
var roster: Array[CharacterState] = []
var gear_inventory := GearInventory.new()
var weapon_inventory: Array[WeaponDefinition] = []
var compendium := MonsterCompendium.new()
var safe_zone_services: Dictionary[String, SafeZoneServices] = {}
var active_safe_zone_key := ""
var current_town_scene: PackedScene
var current_map_scene: PackedScene
var last_safe_zone_scene: PackedScene
var labyrinth_entries: Dictionary[String, StringName] = {}
var labyrinth_discoveries: Dictionary[String, Dictionary] = {}
var highest_labyrinth_completion := 0.0
var completed_conversations: Dictionary[StringName, bool] = {}
var flags: Dictionary[StringName, Variant] = {}


func reset() -> void:
	has_started = false
	party.clear()
	roster.clear()
	gear_inventory = GearInventory.new()
	weapon_inventory.clear()
	compendium = MonsterCompendium.new()
	safe_zone_services.clear()
	active_safe_zone_key = ""
	current_town_scene = null
	current_map_scene = null
	last_safe_zone_scene = null
	labyrinth_entries.clear()
	labyrinth_discoveries.clear()
	highest_labyrinth_completion = 0.0
	completed_conversations.clear()
	flags.clear()


func start_new_game(town: PackedScene, characters: Array[CharacterDefinition], gear: Array[GearDefinition], active_party_size: int = 4) -> void:
	reset()
	current_town_scene = town
	last_safe_zone_scene = town
	active_safe_zone_key = town.resource_path if town != null else ""
	for definition in gear:
		gear_inventory.add(definition)
	for character in characters:
		if character != null:
			var member := CharacterState.new(character)
			roster.append(member)
			if party.size() < clampi(active_party_size, 1, 4):
				party.append(member)
	for member in roster:
		for item in member.get_equipped_gear():
			gear_inventory.register(item)
	has_started = true
	run_started.emit()


## Recruitment is idempotent; a full party sends the recruit to reserve.
func recruit_character(definition: CharacterDefinition) -> CharacterState:
	if definition == null:
		return null
	for member in roster:
		if member.definition.id == definition.id:
			return member
	var member := CharacterState.new(definition)
	roster.append(member)
	if party.size() < 4:
		party.append(member)
	for item in member.get_equipped_gear():
		gear_inventory.register(item)
	return member


func set_flag(key: StringName, value: Variant) -> void:
	flags[key] = value
	flag_changed.emit(key, value)


func get_flag(key: StringName, default_value: Variant = null) -> Variant:
	return flags.get(key, default_value)


func discoveries_for(map_path: String) -> Dictionary[StringName, bool]:
	if not labyrinth_discoveries.has(map_path):
		var discoveries: Dictionary[StringName, bool] = {}
		labyrinth_discoveries[map_path] = discoveries
	return labyrinth_discoveries[map_path]


func record_exploration_completion(completion: float) -> void:
	highest_labyrinth_completion = maxf(highest_labyrinth_completion, clampf(completion, 0.0, 1.0))


func services_for(town: Town) -> SafeZoneServices:
	if not safe_zone_services.has(active_safe_zone_key):
		var services := SafeZoneServices.new()
		services.configure(town)
		safe_zone_services[active_safe_zone_key] = services
	return safe_zone_services[active_safe_zone_key]


## Keep the starting refuge's services when its labyrinth doorway becomes known.
func adopt_initial_safe_zone(town: PackedScene, entry_key: String) -> void:
	if town != null and active_safe_zone_key == town.resource_path:
		if safe_zone_services.has(active_safe_zone_key):
			safe_zone_services[entry_key] = safe_zone_services[active_safe_zone_key]
			safe_zone_services.erase(active_safe_zone_key)
		active_safe_zone_key = entry_key


func advance_service_step() -> void:
	for services in safe_zone_services.values():
		services.advance_step()


func record_service_kill(species: StringName) -> void:
	for services in safe_zone_services.values():
		services.record_kill(species)


func recover_from_party_wipe() -> void:
	highest_labyrinth_completion = 0.0
	for member in roster:
		for item in member.get_equipped_gear():
			if item.definition.kind == GearDefinition.Kind.CONSUMABLE:
				item.destroy_consumable()
	gear_inventory.discard_consumables()
	for member in roster:
		member.restore()
