class_name LabyrinthCeilingLight
extends Node3D

enum State { OFF, DIM, LIT }

var state: State = State.OFF
@onready var source: OmniLight3D = $Light
@onready var diffuser: MeshInstance3D = $Diffuser


func configure(cell_size: float, wall_height: float) -> void:
	var fixture_scale := clampf(cell_size / 6.0, 0.7, 1.6)
	$Housing.scale = Vector3(fixture_scale, 1.0, fixture_scale)
	diffuser.scale = Vector3(fixture_scale, 1.0, fixture_scale)
	# Reach the floor and corners, with walls occluding spill into other rooms.
	source.omni_range = Vector2(wall_height, cell_size * 0.71).length() + 0.4
	source.distance_fade_enabled = true
	source.distance_fade_begin = cell_size * 3.0
	source.distance_fade_length = cell_size
	source.distance_fade_shadow = source.distance_fade_begin + source.distance_fade_length


func set_state(value: State, material: StandardMaterial3D, energy: float) -> void:
	state = value
	diffuser.material_override = material
	source.light_energy = energy
	source.visible = value != State.OFF
