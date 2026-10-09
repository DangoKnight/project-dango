class_name Town
extends "res://scripts/ui/screen.gd"

signal exploration_requested(map_scene: PackedScene)

@export var town_id: StringName
@export var display_name: String = "Safe Zone"
@export var background_texture: Texture2D
@export var exploration_map: PackedScene
@export var location_backgrounds: Dictionary[String, Texture2D] = {}


func _ready() -> void:
	super._ready()
	$Panel/Buttons/Title.text = display_name.to_upper()
	if background_texture != null:
		$Background.texture = background_texture
	$Panel/Buttons/Explore.disabled = exploration_map == null


func _on_button_pressed(action: String) -> void:
	if action == "Explore":
		if exploration_map != null:
			exploration_requested.emit(exploration_map)
	else:
		super._on_button_pressed(action)
