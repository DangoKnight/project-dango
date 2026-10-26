class_name LabyrinthMap
extends Map

const CEILING_LIGHT := preload("res://scenes/world/labyrinth_ceiling_light.tscn")

signal safe_zone_requested(landmark: LabyrinthLandmark)
signal step_taken
signal encounter_requested
signal exploration_changed(completion: float)
signal reward_collected(reward: GearDefinition)

@export var definition: LabyrinthDefinition
@export_file("*.json") var definition_json: String = "res://resources/labyrinths/office.json"
@export_category("Ceiling Lighting")
@export_range(0.1, 8.0, 0.05) var lit_light_energy := 1.8
@export_range(0.01, 2.0, 0.01) var dim_light_energy := 0.3
var layout: LabyrinthLayout
var entry_landmark: StringName
var items_picked_up := 0
# Revealed map cells: walked cells plus known Safe Zone approaches.
var walked_cells: Dictionary[Vector2i, bool] = {}
# Shared across regenerated instances of this labyrinth by the game controller.
var discovered_landmarks: Dictionary[StringName, bool] = {}
var cell_lights: Dictionary[Vector2i, LabyrinthCeilingLight] = {}
var _light_materials: Array[StandardMaterial3D] = []
var _travel_requested := false
var _encounter_distance := 0.0
var _service_walk_distance := 0.0
var _encounter_steps := 0
var _encounter_pending := false
var _encounter_rng := RandomNumberGenerator.new()
var _reward_markers: Dictionary[Vector2i, Node3D] = {}
var _cell_labels: Dictionary[Vector2i, Array] = {}


func _ready() -> void:
	if layout == null:
		if definition == null:
			definition = LabyrinthDefinition.from_json(definition_json)
		layout = LabyrinthLayout.generate(definition)
	if not layout.error.is_empty():
		push_error(layout.error)
		super._ready()
		return
	definition = layout.definition
	map_id = definition.id
	display_name = definition.display_name
	encounter = layout.encounter
	_build_geometry()
	var entry := layout.landmark(entry_landmark if entry_landmark != &"" else definition.spawn_landmark)
	if entry == null:
		entry = layout.landmark(definition.spawn_landmark)
	entry_landmark = entry.id
	# The entry is known immediately; other refuges require prior discovery.
	discovered_landmarks[entry.id] = true
	_discover_safe_zone_approaches()
	_build_ceiling_lights()
	spawn_point.position = layout.world_position(entry.coordinate) + Vector3(0.0, 0.1, 0.0)
	var next: Vector2i = layout.passages[entry.coordinate][0]
	spawn_point.rotation.y = Vector3.FORWARD.signed_angle_to(layout.world_position(next - entry.coordinate).normalized(), Vector3.UP)
	super._ready()
	_encounter_rng.randomize()
	reset_encounters()
	player.walked.connect(_on_player_walked)
	_record_walked_cell()


func set_active(active: bool) -> void:
	# Capture the final movement frame before opening a menu or battle.
	if not active and player.movement_enabled:
		_record_walked_cell()
	super.set_active(active)


func _physics_process(_delta: float) -> void:
	if player.movement_enabled:
		_record_walked_cell()


func reset_encounters() -> void:
	_encounter_distance = 0.0
	_encounter_pending = false
	_encounter_steps = _encounter_rng.randi_range(definition.encounter_steps_min, definition.encounter_steps_max)


func _on_player_walked(distance: float) -> void:
	if not player.movement_enabled or _travel_requested:
		return
	var cell := Vector2i(floori(player.position.x / definition.cell_size + 0.5), floori(player.position.z / definition.cell_size + 0.5))
	if not layout.passages.has(cell):
		return
	_service_walk_distance += maxf(0.0, distance)
	while _service_walk_distance >= definition.cell_size:
		_service_walk_distance -= definition.cell_size
		step_taken.emit()
	if _encounter_pending or not definition.encounters_enabled:
		return
	for landmark in definition.landmarks:
		if landmark.kind == &"safe_zone" and landmark.coordinate == cell:
			return
	_encounter_distance += distance
	if _encounter_distance < _encounter_steps * definition.cell_size:
		return
	_encounter_pending = true
	encounter = definition.pick_encounter(_encounter_rng)
	encounter_requested.emit()


func _record_walked_cell() -> void:
	if layout == null or not layout.error.is_empty():
		return
	var cell := Vector2i(
		floori(player.position.x / definition.cell_size + 0.5),
		floori(player.position.z / definition.cell_size + 0.5))
	if layout.passages.has(cell):
		var changed := not walked_cells.has(cell)
		walked_cells[cell] = true
		for landmark in definition.landmarks:
			if landmark.coordinate == cell:
				changed = changed or not discovered_landmarks.has(landmark.id)
				discovered_landmarks[landmark.id] = true
		if changed:
			_discover_safe_zone_approaches()
			_refresh_cell_lighting()
			exploration_changed.emit(exploration_completion())


func exploration_completion() -> float:
	return float(walked_cells.size()) / layout.passages.size() if layout != null and not layout.passages.is_empty() else 0.0


func _build_ceiling_lights() -> void:
	var fixtures := Node3D.new()
	fixtures.name = "CeilingLights"
	add_child(fixtures)
	# Shared materials keep one fixture per grid cell inexpensive.
	for brightness in [0.0, 0.22, 1.0]:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.22, 0.23, 0.2).lerp(Color(0.95, 0.94, 0.82), brightness)
		material.emission_enabled = brightness > 0.0
		material.emission = Color(1.0, 0.94, 0.79) * brightness
		material.emission_energy_multiplier = 1.5
		_light_materials.append(material)
	for cell in layout.passages:
		var fixture := CEILING_LIGHT.instantiate() as LabyrinthCeilingLight
		fixture.name = "Cell_%d_%d" % [cell.x, cell.y]
		fixture.position = layout.world_position(cell) + Vector3(0, definition.wall_height - 0.05, 0)
		fixtures.add_child(fixture)
		fixture.configure(definition.cell_size, definition.wall_height)
		cell_lights[cell] = fixture
	_refresh_cell_lighting()


func _discover_safe_zone_approaches() -> void:
	for landmark in definition.landmarks:
		if landmark.kind == &"safe_zone" and discovered_landmarks.has(landmark.id):
			var approach: Vector2i = layout.passages[landmark.coordinate][0]
			walked_cells[approach] = true


func _refresh_cell_lighting() -> void:
	var lit_cells: Dictionary[Vector2i, bool] = walked_cells.duplicate()
	var safe_cells: Dictionary[Vector2i, bool] = {}
	for landmark in definition.landmarks:
		if landmark.kind == &"safe_zone":
			safe_cells[landmark.coordinate] = true
			lit_cells.erase(landmark.coordinate)
		elif discovered_landmarks.has(landmark.id):
			lit_cells[landmark.coordinate] = true
	var dim_cells: Dictionary[Vector2i, bool] = {}
	# Only full lights spread dimness, through open passages and exactly one cell.
	for cell in lit_cells:
		for neighbor: Vector2i in layout.passages[cell]:
			if not lit_cells.has(neighbor) and not safe_cells.has(neighbor):
				dim_cells[neighbor] = true
	for cell in cell_lights:
		var state := LabyrinthCeilingLight.State.OFF
		var energy := 0.0
		if lit_cells.has(cell):
			state = LabyrinthCeilingLight.State.LIT
			energy = lit_light_energy
		elif dim_cells.has(cell):
			state = LabyrinthCeilingLight.State.DIM
			energy = dim_light_energy
		cell_lights[cell].set_state(state, _light_materials[state], energy)
		if _cell_labels.has(cell):
			for label: Label3D in _cell_labels[cell]:
				label.visible = state != LabyrinthCeilingLight.State.OFF


func _build_geometry() -> void:
	var ground := load("res://resources/materials/ground.tres").duplicate() as StandardMaterial3D
	var wall := load("res://resources/materials/wall.tres").duplicate() as StandardMaterial3D
	var ceiling := load("res://resources/materials/ceiling.tres").duplicate() as StandardMaterial3D
	var width := definition.grid_size.x * definition.cell_size
	var depth := definition.grid_size.y * definition.cell_size
	var height := definition.wall_height
	var center := layout.world_position(definition.grid_size - Vector2i.ONE) * 0.5
	ground.uv1_scale = Vector3(width / 4.0, depth / 4.0, 1)
	ceiling.uv1_scale = ground.uv1_scale
	wall.uv1_scale = Vector3(definition.cell_size / 4.0, height / 4.0, 1)
	_box("Ground", center + Vector3(0, -0.25, 0), Vector3(width, 0.5, depth), ground)
	_box("Ceiling", center + Vector3(0, height + 0.25, 0), Vector3(width, 0.5, depth), ceiling)
	var walls := Node3D.new()
	walls.name = "Walls"
	add_child(walls)
	# Build refuge enclosures first, then deduplicate shared boundaries globally.
	# Every closed side receives a complete textured wall and collision shape.
	var cells: Array[Vector2i] = []
	for landmark in definition.landmarks:
		if landmark.kind == &"safe_zone":
			cells.append(landmark.coordinate)
	for cell in layout.passages:
		if cell not in cells:
			cells.append(cell)
	var built_boundaries: Dictionary[Vector2i, bool] = {}
	for cell in cells:
		for direction in LabyrinthLayout.DIRECTIONS:
			if cell + direction in layout.passages[cell]:
				continue
			var boundary := cell * 2 + direction
			if built_boundaries.has(boundary):
				continue
			built_boundaries[boundary] = true
			var position := layout.world_position(cell) + layout.world_position(direction) * 0.5 + Vector3(0, height * 0.5, 0)
			var size := Vector3(definition.cell_size + 0.2, height, 0.2) if direction.x == 0 else Vector3(0.2, height, definition.cell_size + 0.2)
			_box("Wall", position, size, wall, walls)
	for landmark in definition.landmarks:
		var marker := Marker3D.new()
		marker.name = String(landmark.id)
		marker.position = layout.world_position(landmark.coordinate)
		add_child(marker)
		if landmark.kind == &"safe_zone":
			_build_doorway(landmark)
			# Endpoint fixtures remain off; the entrance-facing room controls its sign.
			_label(marker, landmark.display_name, 2.8, layout.passages[landmark.coordinate][0])
		else:
			_label(marker, landmark.display_name, 2.8, landmark.coordinate)
	for cell in layout.rewards:
		var marker := Node3D.new()
		marker.name = "Reward"
		marker.position = layout.world_position(cell)
		add_child(marker)
		_reward_markers[cell] = marker
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.7, 0.55, 0.24)
		_box("SupplyCache", Vector3(0, 0.35, 0), Vector3(0.8, 0.7, 0.6), material, marker)
		_label(marker, "ui.collect_e", 1.3, cell)


func _box(title: String, position: Vector3, size: Vector3, material: Material, parent: Node = self) -> void:
	var body := StaticBody3D.new()
	body.name = title
	body.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	body.add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _label(parent: Node3D, text: String, height: float, cell: Vector2i) -> void:
	var label := Label3D.new()
	label.visible = false
	label.text = L10n.text(text)
	label.position.y = height
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.008
	parent.add_child(label)
	if not _cell_labels.has(cell):
		_cell_labels[cell] = []
	_cell_labels[cell].append(label)


func interact() -> void:
	if not player.movement_enabled or layout == null or not layout.error.is_empty():
		return
	for cell in layout.rewards:
		if _near(cell):
			var reward := layout.rewards[cell]
			layout.rewards.erase(cell)
			items_picked_up += 1
			var marker: Node3D = _reward_markers[cell]
			for label: Label3D in _cell_labels[cell].duplicate():
				if label.get_parent() == marker:
					_cell_labels[cell].erase(label)
			if _cell_labels[cell].is_empty():
				_cell_labels.erase(cell)
			marker.queue_free()
			_reward_markers.erase(cell)
			reward_collected.emit(reward)
			return


func _build_doorway(landmark: LabyrinthLandmark) -> void:
	var doorway := Node3D.new()
	doorway.name = String(landmark.id) + "Doorway"
	doorway.position = layout.doorway_position(landmark)
	var toward_room := (layout.world_position(landmark.coordinate) - doorway.position).normalized()
	doorway.rotation.y = Vector3.BACK.signed_angle_to(toward_room, Vector3.UP)
	add_child(doorway)
	var height := definition.wall_height
	var width := definition.cell_size - 0.2
	var depth := definition.cell_size - 0.15
	# An opaque, unlit back wall stays black under ambient and direct lighting.
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	black.cull_mode = BaseMaterial3D.CULL_DISABLED
	_darkness_surface(doorway, black, "BlackFade", Vector3(0, height * 0.5, 0), Vector3.ZERO, Vector2(width, height))
	# One spatial gradient runs continuously over both sides, the floor, and ceiling.
	var darkness := ShaderMaterial.new()
	darkness.shader = preload("res://resources/shaders/safe_zone_darkness.gdshader")
	darkness.set_shader_parameter("back_wall_origin", doorway.global_position)
	darkness.set_shader_parameter("entrance_direction", doorway.global_basis.z.normalized())
	darkness.set_shader_parameter("fade_length", depth)
	_darkness_surface(doorway, darkness, "LeftFade", Vector3(-width * 0.5 + 0.01, height * 0.5, depth * 0.5), Vector3(0, PI * 0.5, 0), Vector2(depth, height))
	_darkness_surface(doorway, darkness, "RightFade", Vector3(width * 0.5 - 0.01, height * 0.5, depth * 0.5), Vector3(0, -PI * 0.5, 0), Vector2(depth, height))
	_darkness_surface(doorway, darkness, "FloorFade", Vector3(0, 0.01, depth * 0.5), Vector3(-PI * 0.5, 0, 0), Vector2(width, depth))
	_darkness_surface(doorway, darkness, "CeilingFade", Vector3(0, height - 0.01, depth * 0.5), Vector3(PI * 0.5, 0, 0), Vector2(width, depth))
	var area := Area3D.new()
	area.name = "Entrance"
	area.position = Vector3(0, height * 0.5, 0.4)
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.8)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	doorway.add_child(area)
	area.body_entered.connect(_enter_safe_zone.bind(landmark))


func _darkness_surface(parent: Node3D, material: Material, title: String, position: Vector3, rotation: Vector3, size: Vector2) -> void:
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.name = title
	visual.mesh = mesh
	visual.position = position
	visual.rotation = rotation
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)


func _enter_safe_zone(body: Node3D, landmark: LabyrinthLandmark) -> void:
	if body != player or not player.movement_enabled or _travel_requested:
		return
	_travel_requested = true
	set_active(false)
	safe_zone_requested.emit(landmark)


func _near(cell: Vector2i) -> bool:
	var offset := player.position - layout.world_position(cell)
	return Vector2(offset.x, offset.z).length() < 2.5
