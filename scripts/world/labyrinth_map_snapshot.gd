class_name LabyrinthMapSnapshot
extends RefCounted

## Chart data survives leaving a labyrinth without keeping its 3D scene alive.
var map_path: String
var definition: LabyrinthDefinition
var layout: LabyrinthLayout
var walked_cells: Dictionary[Vector2i, bool] = {}
var discovered_landmarks: Dictionary[StringName, bool] = {}
var items_picked_up := 0
var player_position := Vector3.ZERO
var player_rotation := 0.0
var display_name: String:
	get:
		return definition.display_name


static func capture(map: LabyrinthMap) -> LabyrinthMapSnapshot:
	var chart := LabyrinthMapSnapshot.new()
	chart.map_path = map.scene_file_path
	chart.definition = map.definition
	chart.layout = map.layout
	chart.walked_cells = map.walked_cells.duplicate()
	chart.discovered_landmarks = map.discovered_landmarks.duplicate()
	chart.items_picked_up = map.items_picked_up
	chart.player_position = map.player.position
	chart.player_rotation = map.player.rotation.y
	return chart
