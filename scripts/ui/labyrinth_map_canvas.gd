extends Control

const FLOOR_COLOR := Color(0.24, 0.28, 0.33)
const WALL_COLOR := Color(0.88, 0.9, 0.92)
const SAFE_ZONE_COLOR := Color(0.24, 0.85, 0.87)
const LANDMARK_COLOR := Color(0.78, 0.56, 1.0)
const PLAYER_COLOR := Color(1.0, 0.82, 0.3)
@export var ink_on_paper := false
var source: LabyrinthMapSnapshot
var _landmark_labels: Dictionary[StringName, Label] = {}


func _ready() -> void:
	resized.connect(queue_redraw)
	resized.connect(_position_landmark_labels)


func configure(map: Variant) -> void:
	source = LabyrinthMapSnapshot.capture(map) if map is LabyrinthMap else map
	for label in _landmark_labels.values():
		remove_child(label)
		label.queue_free()
	_landmark_labels.clear()
	for landmark in visible_landmarks():
		var label := Label.new()
		label.text = L10n.text(landmark.display_name)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.22, 0.16, 0.1) if ink_on_paper else WALL_COLOR)
		label.add_theme_color_override("font_outline_color", Color(0.88, 0.82, 0.65) if ink_on_paper else Color(0.025, 0.03, 0.04))
		label.add_theme_constant_override("outline_size", 4)
		add_child(label)
		_landmark_labels[landmark.id] = label
	_position_landmark_labels()
	queue_redraw()


func _position_landmark_labels() -> void:
	if not is_instance_valid(source):
		return
	var dimensions := Vector2(source.definition.size)
	var cell_size := minf(maxf(size.x - 24.0, 1.0) / dimensions.x, maxf(size.y - 24.0, 1.0) / dimensions.y)
	var origin := (size - dimensions * cell_size) * 0.5
	for landmark in visible_landmarks():
		var label: Label = _landmark_labels.get(landmark.id)
		if label == null:
			continue
		var center := origin + (Vector2(landmark.coordinate) + Vector2(0.5, 0.5)) * cell_size
		var width := minf(maxf(size.x - 8.0, 1.0), 180.0)
		label.size = Vector2(width, 0)
		label.size.y = label.get_minimum_size().y
		label.position = Vector2(
			clampf(center.x - width * 0.5, 4.0, maxf(4.0, size.x - width - 4.0)),
			clampf(center.y + cell_size * 0.3, 4.0, maxf(4.0, size.y - label.size.y - 4.0))
		)


func visible_landmarks() -> Array[LabyrinthLandmark]:
	var result: Array[LabyrinthLandmark] = []
	if not is_instance_valid(source):
		return result
	for landmark in source.definition.landmarks:
		if source.discovered_landmarks.has(landmark.id):
			result.append(landmark)
	return result


func visible_safe_zones() -> Array[LabyrinthLandmark]:
	var result: Array[LabyrinthLandmark] = []
	for landmark in visible_landmarks():
		if landmark.kind == &"safe_zone":
			result.append(landmark)
	return result

func visible_walls() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if not is_instance_valid(source):
		return result
	for cell in source.walked_cells:
		for direction in LabyrinthLayout.DIRECTIONS:
			if cell + direction in source.layout.passages[cell]:
				continue
			var midpoint := Vector2(cell) + Vector2(0.5, 0.5) + Vector2(direction) * 0.5
			var tangent := Vector2(-direction.y, direction.x) * 0.5
			result.append(PackedVector2Array([midpoint - tangent, midpoint + tangent]))
	return result


func _draw() -> void:
	if not is_instance_valid(source):
		return
	var floor_color := Color(0.65, 0.62, 0.52) if ink_on_paper else FLOOR_COLOR
	var wall_color := Color(0.22, 0.16, 0.1) if ink_on_paper else WALL_COLOR
	var safe_color := Color(0.05, 0.4, 0.36) if ink_on_paper else SAFE_ZONE_COLOR
	var landmark_color := Color(0.44, 0.24, 0.53) if ink_on_paper else LANDMARK_COLOR
	var player_color := Color(0.65, 0.31, 0.06) if ink_on_paper else PLAYER_COLOR
	var dimensions := Vector2(source.definition.size)
	var cell_size := minf(maxf(size.x - 24.0, 1.0) / dimensions.x, maxf(size.y - 24.0, 1.0) / dimensions.y)
	var origin := (size - dimensions * cell_size) * 0.5
	for cell in source.walked_cells:
		draw_rect(Rect2(origin + Vector2(cell) * cell_size, Vector2.ONE * cell_size).grow(-0.5), floor_color)
	for segment in visible_walls():
		draw_line(origin + segment[0] * cell_size, origin + segment[1] * cell_size, wall_color, clampf(cell_size * 0.07, 1.0, 3.0), true)
	for landmark in visible_landmarks():
		var center := origin + (Vector2(landmark.coordinate) + Vector2(0.5, 0.5)) * cell_size
		var marker_size := cell_size * 0.5
		if landmark.kind == &"safe_zone":
			draw_rect(Rect2(center - Vector2.ONE * marker_size * 0.5, Vector2.ONE * marker_size), safe_color, false, maxf(1.0, cell_size * 0.06))
		else:
			var radius := marker_size * 0.5
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -radius), center + Vector2(radius, 0),
				center + Vector2(0, radius), center + Vector2(-radius, 0),
			]), landmark_color)
	var position := source.player_position
	var center := origin + (Vector2(position.x, position.z) / source.definition.cell_size + Vector2(0.5, 0.5)) * cell_size
	var heading := Vector2(-sin(source.player_rotation), -cos(source.player_rotation))
	var tangent := Vector2(-heading.y, heading.x)
	var radius := cell_size * 0.3
	draw_colored_polygon(PackedVector2Array([
		center + heading * radius,
		center - heading * radius * 0.6 + tangent * radius * 0.6,
		center - heading * radius * 0.6 - tangent * radius * 0.6,
	]), player_color)
