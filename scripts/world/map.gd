class_name Map
extends Node3D

@export var map_id: StringName
@export var display_name: String = "Map"
@export var encounter: BattleEncounter

@onready var player: CharacterBody3D = $Player
@onready var spawn_point: Marker3D = $SpawnPoint


func _ready() -> void:
	reset_player()


func reset_player() -> void:
	player.global_transform = spawn_point.global_transform
	player.velocity = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO


func set_active(active: bool) -> void:
	player.movement_enabled = active
	if not active:
		player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if active else Input.MOUSE_MODE_VISIBLE


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
