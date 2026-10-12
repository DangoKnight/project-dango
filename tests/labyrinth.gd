extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func run() -> void:
	var definition := LabyrinthDefinition.from_json("res://resources/labyrinths/office.json")
	check(definition != null and definition.validation_error().is_empty(), "JSON initializes a valid Godot resource")
	if definition == null:
		quit(1)
		return
	check(definition.world_size == Vector2(definition.size) * definition.cell_size, "Definition contains grid dimensions and derived world size")
	var invalid_supplies := definition.duplicate() as LabyrinthDefinition
	invalid_supplies.possible_rewards = [load("res://resources/rpg/gear/iron_artifact.tres")]
	check(not invalid_supplies.validation_error().is_empty(), "Artifact supply rewards are rejected")
	invalid_supplies.possible_rewards = [load("res://resources/rpg/gear/spell_medallion.tres")]
	check(not invalid_supplies.validation_error().is_empty(), "Medallion supply rewards are rejected")
	var cell_count := definition.size.x * definition.size.y
	var landmark_cells: Dictionary[StringName, Vector2i] = {}
	for landmark in definition.landmarks:
		landmark_cells[landmark.id] = landmark.coordinate
	var reward_counts: Dictionary[int, bool] = {}
	for seed_value in range(1, 31):
		definition.generation_seed = seed_value
		var layout := LabyrinthLayout.generate(definition)
		check(layout.error.is_empty(), "Generation succeeds for seed %d" % seed_value)
		if not layout.error.is_empty():
			continue
		reward_counts[layout.rewards.size()] = true
		check(layout.passages.size() == cell_count, "Every grid cell exists")
		var visited: Array[Vector2i] = [definition.landmarks[0].coordinate]
		var index := 0
		var edges := 0
		while index < visited.size():
			var cell := visited[index]
			index += 1
			for neighbor: Vector2i in layout.passages[cell]:
				edges += 1
				check(abs(neighbor.x - cell.x) + abs(neighbor.y - cell.y) == 1, "Passages join adjacent grid cells")
				check(cell in layout.passages.get(neighbor, []), "Passages are reciprocal")
				if neighbor not in visited:
					visited.append(neighbor)
		check(visited.size() == cell_count and edges == (cell_count - 1) * 2, "The entire maze is one connected spanning tree")
		check(layout.landmark(&"entry_refuge").coordinate == landmark_cells[&"entry_refuge"], "Entry remains fixed")
		check(layout.landmark(&"distant_refuge").coordinate == landmark_cells[&"distant_refuge"], "Relative Safe Zone positions remain fixed")
		check(layout.landmark(&"service_hub").coordinate == landmark_cells[&"service_hub"], "Other notable landmarks remain fixed")
		for landmark in definition.landmarks:
			if landmark.kind == &"safe_zone":
				check(layout.passages[landmark.coordinate].size() == 1, "Every Safe Zone is an endpoint")
		check(layout.rewards.size() >= definition.reward_node_min and layout.rewards.size() <= definition.reward_node_max, "Reward count stays inside the configured range")
		for cell in layout.rewards:
			check(layout.passages[cell].size() == 1, "Rewards only appear at endpoints")
			check(layout.rewards[cell] in definition.possible_rewards, "Rewards come from the configured pool")
			check(layout.rewards[cell].kind == GearDefinition.Kind.CONSUMABLE, "Supply caches always contain consumables")
			for landmark in definition.landmarks:
				check(cell != landmark.coordinate, "Rewards never replace landmarks")
		var matched := false
		for preset in definition.encounters:
			if layout.encounter.enemies == preset.enemies and layout.encounter.enemy_level == preset.enemy_level:
				matched = true
		check(matched, "Layout encounters match a complete configured preset")
		var repeat := LabyrinthLayout.generate(definition)
		check(layout.passages == repeat.passages and layout.rewards == repeat.rewards, "An explicit design seed reproduces the maze")
	check(reward_counts.size() > 1, "Item counts vary across generated labyrinths")
	definition.reward_node_min = 9
	definition.reward_node_max = 4
	check(not definition.validation_error().is_empty(), "Inverted item count bounds are rejected")
	definition.reward_node_count = 141
	check(not LabyrinthLayout.generate(definition).error.is_empty(), "Impossible endpoint counts fail within bounded retries")
	definition.reward_node_count = 6
	definition.landmarks[1].coordinate = Vector2i(1, 1)
	check(not definition.validation_error().is_empty(), "Duplicate landmark coordinates are rejected")
	check(LabyrinthDefinition.from_dictionary({"grid_size": "invalid"}) == null, "Malformed JSON data is rejected")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/labyrinths/office.json"))
	raw.encounters = ["res://resources/rpg/gear/healing_draught.tres"]
	check(LabyrinthDefinition.from_dictionary(raw) == null, "Incorrect resource types are rejected")
	raw = JSON.parse_string(FileAccess.get_file_as_string("res://resources/labyrinths/office.json"))
	raw["size"] = [4, 3]
	raw.reward_node_min = 0
	raw.reward_node_max = 0
	raw.landmarks = [
		{"id": "entry", "display_name": "Entry", "kind": "safe_zone", "coordinate": [0, 0]},
		{"id": "exit", "display_name": "Exit", "kind": "safe_zone", "coordinate": [3, 2]}
	]
	raw.spawn_landmark = "entry"
	var small := LabyrinthDefinition.from_dictionary(raw)
	check(small != null and small.world_size == Vector2(4, 3) * small.cell_size, "Custom labyrinth dimensions load from JSON")
	check(LabyrinthLayout.generate(small).passages.size() == 12, "Generation honors custom dimensions")
	raw["grid_size"] = [12, 12]
	check(LabyrinthDefinition.from_dictionary(raw) == null, "Conflicting legacy and current size values are rejected")
	raw.erase("grid_size")
	raw["size"] = [2, 3]
	raw.landmarks[0].coordinate = [0, 1]
	raw.landmarks[1].coordinate = [1, 1]
	check(not LabyrinthLayout.generate(LabyrinthDefinition.from_dictionary(raw)).error.is_empty(), "A Safe Zone barrier that prevents connectivity is rejected")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game(false)
	# Exercise navigation after the first-departure conversation.
	game.state.completed_conversations[game.ui.get_child(0).departure_conversation.id] = true
	game.state.set_flag(&"labyrinth_unlocked", true)
	game.enter_labyrinth()
	check(game.battle_fade.visible and game._battle_transition and game.world == null, "Entry fades before creating the labyrinth")
	await create_timer(0.2).timeout
	check(game.battle_fade.color.a > 0.0 and game.screen == "town", "Town fades to black before entry")
	for frame in range(100):
		if not game._battle_transition:
			break
		await create_timer(0.02).timeout
	check(game.screen == "explore" and not game.battle_fade.visible and game.player.movement_enabled, "Entry reveals the labyrinth before enabling movement")
	await physics_frame
	await physics_frame
	var map := game.world as LabyrinthMap
	check(map != null and map.has_node("Walls") and map.has_node("Ground"), "Explore builds the procedural Map geometry")
	if map == null:
		game.queue_free()
		quit(1)
		return
	check(map.get_node("Walls").get_child_count() == map.definition.size.x * map.definition.size.y + map.definition.size.x + map.definition.size.y + 1, "Each closed grid boundary has exactly one wall")
	var state := map.get_world_3d().direct_space_state
	for cell in map.layout.passages:
		for direction in LabyrinthLayout.DIRECTIONS:
			var from := map.layout.world_position(cell) + Vector3(0, 1, 0)
			var to := from + map.layout.world_position(direction) * 0.6
			var query := PhysicsRayQueryParameters3D.create(from, to)
			query.exclude = [map.player.get_rid()]
			var hit := state.intersect_ray(query)
			check(hit.is_empty() == (cell + direction in map.layout.passages[cell]), "Collision matches the passage graph")
	for landmark in map.definition.landmarks:
		if landmark.kind != &"safe_zone":
			continue
		var doorway: Node3D = map.get_node(String(landmark.id) + "Doorway")
		var back: MeshInstance3D = doorway.get_node("BlackFade")
		var black: StandardMaterial3D = back.mesh.material
		check(black.albedo_color == Color.BLACK and black.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Safe Zone back wall is fully black independent of lighting")
		check(back.mesh.size.is_equal_approx(Vector2(map.definition.cell_size - 0.2, map.definition.wall_height)), "Black back wall covers the full room width and height")
		check(is_equal_approx(doorway.get_node("Entrance").get_child(0).shape.size.x, back.mesh.size.x), "Walking into any part of the black endpoint triggers Safe Zone travel")
		var shared_darkness: ShaderMaterial = doorway.get_node("FloorFade").mesh.material
		var gradient_origin: Vector3 = shared_darkness.get_shader_parameter("back_wall_origin")
		var gradient_axis: Vector3 = shared_darkness.get_shader_parameter("entrance_direction")
		var fade_length: float = shared_darkness.get_shader_parameter("fade_length")
		check(gradient_origin.is_equal_approx(doorway.global_position) and gradient_axis.is_equal_approx(doorway.global_basis.z.normalized()), "Darkness gradient follows this Safe Zone's orientation")
		for title in ["LeftFade", "RightFade", "FloorFade", "CeilingFade"]:
			var surface: MeshInstance3D = doorway.get_node(title)
			check(surface.mesh.material == shared_darkness, "Side walls, floor, and ceiling share one continuous darkness gradient")
			var near_back := INF
			var near_entrance := -INF
			for vertex in surface.mesh.get_faces():
				var distance: float = (surface.global_transform * vertex - gradient_origin).dot(gradient_axis)
				near_back = minf(near_back, distance)
				near_entrance = maxf(near_entrance, distance)
			check(is_zero_approx(near_back) and is_equal_approx(near_entrance, fade_length), "Every faded surface spans from the black back wall to the lit entrance")
		var closed_sides := 0
		var open_sides := 0
		for direction in LabyrinthLayout.DIRECTIONS:
			var center := map.layout.world_position(landmark.coordinate) + Vector3(0, 1, 0)
			var query := PhysicsRayQueryParameters3D.create(center, center + map.layout.world_position(direction) * 0.6)
			query.exclude = [map.player.get_rid()]
			var hit := state.intersect_ray(query)
			if hit.is_empty():
				open_sides += 1
			else:
				closed_sides += 1
				var visual: MeshInstance3D = hit.collider.get_child(0)
				check(visual.mesh.material.albedo_texture != null and visual.mesh.size.y == map.definition.wall_height, "Safe Zone walls are textured and extend from floor to ceiling")
		check(closed_sides == 3 and open_sides == 1, "Each Safe Zone is physically enclosed on three sides with one open side")
	var original_layout := map.layout
	var cell: Vector2i = original_layout.rewards.keys()[0]
	var inventory_count: int = game.state.gear_inventory.get_items().size()
	map.player.position = map.layout.world_position(cell)
	map.interact()
	check(game.state.gear_inventory.get_items().size() == inventory_count + 1 and not original_layout.rewards.has(cell), "Interacting collects a reward exactly once into inventory")
	map.interact()
	check(game.state.gear_inventory.get_items().size() == inventory_count + 1, "Collected rewards cannot be collected twice")
	var refuge := map.layout.landmark(&"distant_refuge")
	check(map.has_node("distant_refugeDoorway/BlackFade"), "Safe Zone has a black gradient doorway")
	map.player.position = map.layout.world_position(refuge.coordinate)
	await physics_frame
	await physics_frame
	check(game.screen == "explore" and not game._battle_transition, "Standing in the endpoint room does not teleport")
	map.interact()
	check(game.screen == "explore", "Safe Zone travel does not require the interact button")
	var door := map.layout.doorway_position(refuge)
	var toward_door := (door - map.player.position).normalized()
	map.player.rotation.y = Vector3.FORWARD.signed_angle_to(toward_door, Vector3.UP)
	Input.action_press("move_forward")
	for frame in range(90):
		await physics_frame
		if game._battle_transition:
			break
	Input.action_release("move_forward")
	check(game._battle_transition and not map.player.movement_enabled and game.battle_fade.visible, "Walking into the doorway triggers travel and blocks input")
	for frame in range(100):
		if not game._battle_transition:
			break
		await create_timer(0.02).timeout
	check(game.screen == "town" and game.world == null and not game.battle_fade.visible, "Doorway teleports to its Safe Zone with a completed fade")
	game.explore()
	check(game.world.layout != original_layout, "Reentry creates a fresh layout instead of reusing the previous map")
	check(game.world.layout.generation_seed != original_layout.generation_seed and game.world.layout.passages != original_layout.passages, "A randomized labyrinth changes on reentry")
	check(game.world.layout.rewards.size() >= 4 and game.world.layout.rewards.size() <= 8, "Every entry regenerates rewards within the configured range")
	check(game.state.gear_inventory.get_items().size() == inventory_count + 1, "Previously collected gear remains in inventory")
	check(game.world.player.position.is_equal_approx(game.world.layout.world_position(game.world.layout.landmark(&"distant_refuge").coordinate) + Vector3(0, 0.1, 0)), "Reentry starts at the last visited Safe Zone")
	for frame in range(8):
		await physics_frame
	check(game.screen == "explore" and not game._battle_transition, "Reentry cannot immediately trigger the doorway")
	game.new_game(false)
	check(game.state.labyrinth_entries.is_empty(), "New Game resets the last visited refuges")
	game.queue_free()
	await process_frame
	print("Labyrinth tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
