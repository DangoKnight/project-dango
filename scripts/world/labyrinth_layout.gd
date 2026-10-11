class_name LabyrinthLayout
extends RefCounted

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
var definition: LabyrinthDefinition
# Each cell contains the coordinates directly reachable without crossing a wall.
var passages: Dictionary[Vector2i, Array] = {}
var rewards: Dictionary[Vector2i, GearDefinition] = {}
var generation_seed: int
var reward_node_count: int
var encounter: BattleEncounter
var error: String


static func generate(source: LabyrinthDefinition) -> LabyrinthLayout:
	var layout := LabyrinthLayout.new()
	layout.definition = source
	if source == null:
		layout.error = "Missing labyrinth definition."
		return layout
	layout.error = source.validation_error()
	if not layout.error.is_empty():
		return layout
	var rng := RandomNumberGenerator.new()
	if source.generation_seed == 0:
		rng.randomize()
	else:
		rng.seed = source.generation_seed
	layout.generation_seed = rng.seed
	layout.reward_node_count = rng.randi_range(source.reward_node_min, source.reward_node_max)
	var reserved: Array[Vector2i] = []
	for landmark in source.landmarks:
		reserved.append(landmark.coordinate)
	# Bounded retries allow a strict endpoint count without hanging on impossible requests.
	for attempt in range(64):
		if not layout._carve(rng):
			continue
		var endpoints: Array[Vector2i] = []
		for cell in layout.passages:
			if layout.passages[cell].size() == 1 and cell not in reserved:
				endpoints.append(cell)
		if endpoints.size() < layout.reward_node_count:
			continue
		for index in range(layout.reward_node_count):
			var selected := rng.randi_range(0, endpoints.size() - 1)
			var cell := endpoints[selected]
			endpoints.remove_at(selected)
			layout.rewards[cell] = source.possible_rewards[rng.randi_range(0, source.possible_rewards.size() - 1)]
		layout.encounter = source.pick_encounter(rng)
		return layout
	layout.passages.clear()
	layout.error = "Could not connect the grid with Safe Zones as endpoints and %d reward endpoints. Reduce rewards, increase the grid, or move landmarks." % layout.reward_node_count
	return layout


func _carve(rng: RandomNumberGenerator) -> bool:
	passages.clear()
	var safe_cells: Array[Vector2i] = []
	for item in definition.landmarks:
		if item.kind == &"safe_zone":
			safe_cells.append(item.coordinate)
	var bounds := Rect2i(Vector2i.ZERO, definition.grid_size)
	var frontier: Array[Vector2i] = []
	for y in range(definition.grid_size.y):
		for x in range(definition.grid_size.x):
			var cell := Vector2i(x, y)
			if cell not in safe_cells:
				frontier.append(cell)
				break
		if not frontier.is_empty():
			break
	if frontier.is_empty():
		return false
	passages[frontier[0]] = []
	while not frontier.is_empty():
		var index := rng.randi_range(0, frontier.size() - 1)
		var cell := frontier[index]
		var candidates: Array[Vector2i] = []
		for direction in DIRECTIONS:
			var neighbor := cell + direction
			if bounds.has_point(neighbor) and neighbor not in safe_cells and not passages.has(neighbor):
				candidates.append(neighbor)
		if candidates.is_empty():
			frontier.remove_at(index)
			continue
		var next := candidates[rng.randi_range(0, candidates.size() - 1)]
		passages[cell].append(next)
		passages[next] = [cell]
		frontier.append(next)
	if passages.size() != definition.grid_size.x * definition.grid_size.y - safe_cells.size():
		return false
	# Attach each refuge once, so no route can pass through a Safe Zone.
	for cell in safe_cells:
		var candidates: Array[Vector2i] = []
		for direction in DIRECTIONS:
			var neighbor := cell + direction
			if passages.has(neighbor) and neighbor not in safe_cells:
				candidates.append(neighbor)
		if candidates.is_empty():
			return false
		var neighbor := candidates[rng.randi_range(0, candidates.size() - 1)]
		passages[cell] = [neighbor]
		passages[neighbor].append(cell)
	return true


func doorway_position(item: LabyrinthLandmark) -> Vector3:
	var neighbor: Vector2i = passages[item.coordinate][0]
	var away := world_position(item.coordinate - neighbor).normalized()
	return world_position(item.coordinate) + away * (definition.cell_size * 0.5 - 0.15)


func world_position(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * definition.cell_size, 0.0, cell.y * definition.cell_size)


func landmark(id: StringName) -> LabyrinthLandmark:
	for item in definition.landmarks:
		if item.id == id:
			return item
	return null
