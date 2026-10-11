extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func check_lights(map: LabyrinthMap) -> void:
	var seeds: Dictionary[Vector2i, bool] = map.walked_cells.duplicate()
	for landmark in map.definition.landmarks:
		if landmark.kind == &"safe_zone":
			seeds.erase(landmark.coordinate)
		elif map.discovered_landmarks.has(landmark.id):
			seeds[landmark.coordinate] = true
	var safe_cells: Array[Vector2i] = []
	for landmark in map.definition.landmarks:
		if landmark.kind == &"safe_zone":
				safe_cells.append(landmark.coordinate)
	for cell in map.layout.passages:
		var fixture := map.cell_lights[cell]
		var expected := LabyrinthCeilingLight.State.OFF
		if seeds.has(cell):
			expected = LabyrinthCeilingLight.State.LIT
		elif cell not in safe_cells:
			for neighbor: Vector2i in map.layout.passages[cell]:
				if seeds.has(neighbor):
					expected = LabyrinthCeilingLight.State.DIM
		check(fixture.state == expected, "Fixture state matches visited/known cells and one open passage of adjacency")
		if map._cell_labels.has(cell):
			for label: Label3D in map._cell_labels[cell]:
				check(label.visible == (expected != LabyrinthCeilingLight.State.OFF), "Labels are visible only in dim or fully lit rooms")
		check(fixture.source.visible == (expected != LabyrinthCeilingLight.State.OFF), "Off fixtures emit no direct light")
		var expected_energy := 0.0
		if expected == LabyrinthCeilingLight.State.LIT:
			expected_energy = map.lit_light_energy
		elif expected == LabyrinthCeilingLight.State.DIM:
			expected_energy = map.dim_light_energy
		check(is_equal_approx(fixture.source.light_energy, expected_energy), "Fixture energy matches its lighting state")
		var material := fixture.diffuser.material_override as StandardMaterial3D
		check(material.emission_enabled == (expected != LabyrinthCeilingLight.State.OFF), "Only lit/dim fixtures glow")
		check(fixture.source.shadow_enabled, "Walls occlude the ceiling lights")
		check(fixture.source.distance_fade_enabled, "Distant light sources use distance fading")
		check(fixture.position.is_equal_approx(map.layout.world_position(cell) + Vector3(0, map.definition.wall_height - 0.05, 0)), "Every fixture is centered beneath its cell's ceiling")


func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game(false)
	game.explore()
	var map := game.world as LabyrinthMap
	map.definition.encounters_enabled = false
	check(map.cell_lights.size() == map.layout.passages.size(), "Every cell has a ceiling fixture")
	check(map.lit_light_energy > map.dim_light_energy and map.dim_light_energy > 0.0, "Dim lights remain weaker than full lights")
	var environment: Environment = map.get_node("WorldEnvironment").environment
	check(environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and environment.ambient_light_energy > 0.0 and environment.ambient_light_energy <= 0.02, "Low color ambient lighting keeps dark cells visible")
	check(not map.has_node("DirectionalLight3D"), "Global directional lighting cannot wash out dark cells")
	for safe_zone in map.definition.landmarks:
		if safe_zone.kind == &"safe_zone":
			var approach: Vector2i = map.layout.passages[safe_zone.coordinate][0]
			var sign: Label3D
			for candidate: Label3D in map._cell_labels[approach]:
				if candidate.get_parent() == map.get_node(String(safe_zone.id)):
					sign = candidate
			check(sign != null and sign.text == safe_zone.display_name, "Safe Zone labels display their configured names")
			check(sign.visible == (map.cell_lights[approach].state != LabyrinthCeilingLight.State.OFF), "Safe Zone name visibility follows the approach room's light")
			if map.discovered_landmarks.has(safe_zone.id):
				check(map.walked_cells.has(approach) and map.cell_lights[approach].state == LabyrinthCeilingLight.State.LIT, "Known Safe Zone approaches are revealed and lit immediately")
			else:
				check(not map.walked_cells.has(approach) and map.cell_lights[approach].state == LabyrinthCeilingLight.State.OFF, "Unknown unvisited Safe Zone approaches remain hidden and unlit")
	check_lights(map)
	var entry := map.layout.landmark(map.definition.spawn_landmark)
	check(entry.display_name == "Station 45-B", "The initial Safe Zone is named Station 45-B")
	var neighbor: Vector2i = map.layout.passages[entry.coordinate][0]
	check(map.cell_lights[entry.coordinate].state == LabyrinthCeilingLight.State.OFF, "Safe Zone endpoints keep their own ceiling lights off")
	check(map.cell_lights[neighbor].state == LabyrinthCeilingLight.State.LIT, "The cell in front of the Safe Zone starts fully lit")
	for direction in LabyrinthLayout.DIRECTIONS:
		var blocked := entry.coordinate + direction
		if blocked != neighbor and map.cell_lights.has(blocked):
			check(map.cell_lights[blocked].state == LabyrinthCeilingLight.State.OFF, "Lighting does not spread through closed walls")
	for beyond: Vector2i in map.layout.passages[neighbor]:
		if beyond != entry.coordinate:
			check(map.cell_lights[beyond].state == LabyrinthCeilingLight.State.DIM, "Neighbors of the approach room start dim")
	Input.action_press("move_forward")
	for frame in range(150):
		if map.player.position.distance_to(map.layout.world_position(neighbor)) < map.definition.cell_size * 0.45:
			break
		await physics_frame
	Input.action_release("move_forward")
	check(map.cell_lights[neighbor].state == LabyrinthCeilingLight.State.LIT, "Walking into the already discovered approach keeps it fully lit")
	check_lights(map)
	game.show_pause()
	check_lights(map)
	game.resume_exploration()
	check_lights(map)

	var landmark := map.layout.landmark(&"service_hub")
	var refuge := map.layout.landmark(&"distant_refuge")
	for destination in [landmark, refuge]:
		map.player.position = map.layout.world_position(destination.coordinate)
		map._record_walked_cell()
	var refuge_approach: Vector2i = map.layout.passages[refuge.coordinate][0]
	check(map.walked_cells.has(refuge_approach) and map.cell_lights[refuge_approach].state == LabyrinthCeilingLight.State.LIT, "Discovering a Safe Zone immediately reveals and lights its approach")
	check_lights(map)
	var original_map := map
	game.show_town()
	game.explore()
	map = game.world as LabyrinthMap
	check(map != original_map and map.walked_cells.size() >= 2, "Reentry generates a fresh map with revealed Safe Zone approaches")
	check(map.cell_lights[landmark.coordinate].state == LabyrinthCeilingLight.State.LIT and map.cell_lights[refuge.coordinate].state == LabyrinthCeilingLight.State.OFF, "Remembered landmarks stay lit while Safe Zone endpoints remain dark")
	check(not map.walked_cells.has(landmark.coordinate) and not map.walked_cells.has(refuge.coordinate), "Lighting discovered landmarks does not reveal unwalked map floors")
	var remembered_approach: Vector2i = map.layout.passages[refuge.coordinate][0]
	check(map.walked_cells.has(remembered_approach) and map.cell_lights[remembered_approach].state == LabyrinthCeilingLight.State.LIT, "Known Safe Zones reveal their new approaches after regeneration")
	check_lights(map)
	game.new_game(false)
	game.explore()
	map = game.world as LabyrinthMap
	check(map.discovered_landmarks.size() == 1, "New Game clears persistent landmark light seeds")
	var forgotten_approach: Vector2i = map.layout.passages[refuge.coordinate][0]
	check(not map.walked_cells.has(forgotten_approach) and map.cell_lights[forgotten_approach].state == LabyrinthCeilingLight.State.OFF, "New Game stops automatically lighting previously known refuges")
	check_lights(map)
	# Exercise the dark -> dim -> lit -> dark transitions for every item/landmark label.
	map.definition.encounters_enabled = false
	var label_cells: Array = map.layout.rewards.keys()
	label_cells.append(map.layout.landmark(&"service_hub").coordinate)
	check(not label_cells.is_empty(), "Labyrinth contains item and landmark labels")
	for cell: Vector2i in label_cells:
		var label: Label3D
		for candidate: Label3D in map._cell_labels[cell]:
			if candidate.get_parent().position.is_equal_approx(map.layout.world_position(cell)):
				label = candidate
				break
		if map.layout.rewards.has(cell):
			check(label.text == "Collect [E]", "Item labels use the generic collect prompt")
		else:
			check(label.text == map.layout.landmark(&"service_hub").display_name, "Landmarks retain their names")
		map.walked_cells.clear()
		map.discovered_landmarks.clear()
		map._refresh_cell_lighting()
		check(not label.visible, "Labels start hidden in unlit rooms")
		var adjacent: Vector2i = map.layout.passages[cell][0]
		map.player.position = map.layout.world_position(adjacent)
		map._record_walked_cell()
		check(map.cell_lights[cell].state == LabyrinthCeilingLight.State.DIM and label.visible, "Walking into a neighboring room reveals dim-room labels")
		map.player.position = map.layout.world_position(cell)
		map._record_walked_cell()
		check(map.cell_lights[cell].state == LabyrinthCeilingLight.State.LIT and label.visible, "Labels remain visible when their own room becomes fully lit")
		map.walked_cells.clear()
		map.discovered_landmarks.clear()
		map._refresh_cell_lighting()
		check(not label.visible, "Labels hide when their room returns to darkness")
	var reward_cell: Vector2i = map.layout.rewards.keys()[0]
	map.player.position = map.layout.world_position(reward_cell)
	map._record_walked_cell()
	var collected_label: Label3D = map._cell_labels[reward_cell][0]
	map.interact()
	check(not map._cell_labels.has(reward_cell), "Collecting an item removes its label from lighting updates")
	await process_frame
	check(not is_instance_valid(collected_label), "Collected item prompts disappear with their cache")
	map._refresh_cell_lighting()
	print("Labyrinth lighting test complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
