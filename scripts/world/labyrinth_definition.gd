class_name LabyrinthDefinition
extends Resource

@export var id: StringName = &"labyrinth"
@export var display_name: String = "Labyrinth"
@export_category("Labyrinth Size")
@export var size := Vector2i(12, 12)
# Compatibility for existing callers; size is the single stored source of truth.
var grid_size: Vector2i:
	get: return size
	set(value): size = value
var world_size: Vector2:
	get: return Vector2(size) * cell_size
@export_range(4.0, 20.0) var cell_size := 8.0
@export_range(3.0, 10.0) var wall_height := 4.0
@export_category("Contents")
@export var landmarks: Array[LabyrinthLandmark] = []
@export var spawn_landmark: StringName
@export_range(0, 100) var reward_node_min := 4
@export_range(0, 100) var reward_node_max := 8
# Legacy callers can still request an exact count.
var reward_node_count: int:
	get: return reward_node_max
	set(value):
		reward_node_min = value
		reward_node_max = value
@export var encounters: Array[BattleEncounter] = []
## Supply caches may only contain consumables.
@export var possible_rewards: Array[GearDefinition] = []
# One step is cell_size units actually walked outside Safe Zones.
@export var encounters_enabled := true
@export_range(1, 1000) var encounter_steps_min := 8
@export_range(1, 1000) var encounter_steps_max := 14
# Zero creates a fresh layout on every entry. This is a design seed, never a saved RNG state.
@export var generation_seed: int = 0


func validation_error() -> String:
	if grid_size.x < 2 or grid_size.y < 2 or grid_size.x > 64 or grid_size.y > 64:
		return "Grid dimensions must be between 2 and 64."
	if not is_finite(cell_size) or cell_size < 4.0 or not is_finite(wall_height) or wall_height < 3.0:
		return "Cells must be at least 4 units wide and walls at least 3 units high."
	var coordinates: Array[Vector2i] = []
	var ids: Array[StringName] = []
	for landmark in landmarks:
		if landmark == null or landmark.id == &"" or landmark.id in ids or landmark.coordinate in coordinates:
			return "Landmarks need unique nonempty IDs and coordinates."
		if not Rect2i(Vector2i.ZERO, grid_size).has_point(landmark.coordinate):
			return "Landmark coordinates must be inside the grid."
		if not landmark.town_scene_path.is_empty() and not ResourceLoader.exists(landmark.town_scene_path, "PackedScene"):
			return "A landmark town scene could not be loaded."
		coordinates.append(landmark.coordinate)
		ids.append(landmark.id)
	if spawn_landmark not in ids:
		return "Spawn landmark must refer to a defined landmark."
	if reward_node_min < 0 or reward_node_max < reward_node_min or reward_node_max > grid_size.x * grid_size.y - landmarks.size():
		return "Reward minimum/maximum must be ordered, nonnegative, and fit the available cells."
	if reward_node_max > 0 and possible_rewards.is_empty():
		return "Reward nodes require a reward pool."
	for reward in possible_rewards:
		if reward == null or not reward.is_valid() or reward.kind != GearDefinition.Kind.CONSUMABLE:
			return "Supply rewards must be valid consumables."
	if encounters.is_empty():
		return "Provide at least one predefined encounter."
	for encounter in encounters:
		if encounter == null or encounter.enemies.is_empty() or encounter.enemies.size() > 6 or encounter.enemy_level < 1 or encounter.enemy_level > 99:
			return "Each encounter requires 1–6 enemies and a level of 1–99."
		for enemy in encounter.enemies:
			if enemy == null:
				return "An encounter contains an invalid enemy definition."
	if encounter_steps_min < 1 or encounter_steps_max < encounter_steps_min:
		return "Encounter steps must have a positive minimum and a maximum at least as large."
	return ""


# Copy the encounter container so a battle cannot modify its configured preset.
func pick_encounter(rng: RandomNumberGenerator) -> BattleEncounter:
	var preset := encounters[rng.randi_range(0, encounters.size() - 1)]
	var result := BattleEncounter.new()
	result.display_name = preset.display_name
	result.enemy_level = preset.enemy_level
	result.enemies.assign(preset.enemies)
	return result


static func from_json(path: String) -> LabyrinthDefinition:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open labyrinth JSON: " + path)
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		push_error("Invalid labyrinth JSON: " + path)
		return null
	var definition := from_dictionary(parser.data)
	if definition == null:
		push_error("Invalid labyrinth configuration: " + path)
	return definition


# Reject malformed values before constructing typed Godot resources.
static func from_dictionary(data: Dictionary) -> LabyrinthDefinition:
	var definition := LabyrinthDefinition.new()
	for key in ["id", "display_name", "spawn_landmark"]:
		if not data.get(key) is String:
			return null
	definition.id = StringName(data.id)
	definition.display_name = data.display_name
	definition.spawn_landmark = StringName(data.spawn_landmark)
	var dimensions: Variant = data.get("size", data.get("grid_size"))
	if not _coordinate_valid(dimensions):
		return null
	if data.has("size") and data.has("grid_size") and data["size"] != data["grid_size"]:
		return null
	definition.size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	for key in ["cell_size", "wall_height", "reward_node_count", "reward_node_min", "reward_node_max", "generation_seed", "encounter_steps_min", "encounter_steps_max"]:
		if data.has(key):
			var value: Variant = data[key]
			if not (value is float or value is int) or not is_finite(float(value)):
				return null
			if key not in ["cell_size", "wall_height"] and float(value) != floorf(float(value)):
				return null
			definition.set(key, value)
	if data.has("encounters_enabled"):
		if not data.encounters_enabled is bool:
			return null
		definition.encounters_enabled = data.encounters_enabled
	if data.has("reward_node_count") and (data.has("reward_node_min") or data.has("reward_node_max")):
		return null
	if not data.get("landmarks") is Array:
		return null
	for item in data.landmarks:
		if not item is Dictionary or not _coordinate_valid(item.get("coordinate")):
			return null
		for key in ["id", "display_name", "kind"]:
			if not item.get(key) is String:
				return null
		if not item.get("town_scene_path", "") is String:
			return null
		var landmark := LabyrinthLandmark.new()
		landmark.id = StringName(item.id)
		landmark.display_name = item.display_name
		landmark.kind = StringName(item.kind)
		landmark.coordinate = Vector2i(int(item.coordinate[0]), int(item.coordinate[1]))
		landmark.town_scene_path = item.get("town_scene_path", "")
		definition.landmarks.append(landmark)
	for key in ["encounters", "possible_rewards"]:
		if not data.get(key) is Array:
			return null
		for path in data[key]:
			if not path is String or not path.begins_with("res://") or not ResourceLoader.exists(path):
				return null
			var resource := load(path)
			if key == "encounters":
				if not resource is BattleEncounter:
					return null
				definition.encounters.append(resource)
			else:
				if not resource is GearDefinition:
					return null
				definition.possible_rewards.append(resource)
	return definition if definition.validation_error().is_empty() else null


static func _coordinate_valid(value: Variant) -> bool:
	if not value is Array or value.size() != 2:
		return false
	for number in value:
		if not (number is float or number is int) or not is_finite(float(number)) or float(number) != floorf(float(number)) or absf(float(number)) > 100000:
			return false
	return true
