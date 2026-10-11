class_name LabyrinthLandmark
extends Resource

@export var id: StringName
@export var display_name: String = "Landmark"
@export var kind: StringName = &"landmark"
@export var coordinate: Vector2i
# Empty means the current town; useful until each Safe Zone has its own services.
@export_file("*.tscn") var town_scene_path: String
