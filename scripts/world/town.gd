class_name Town
extends "res://scripts/ui/screen.gd"

signal exploration_requested(map_scene: PackedScene)

@export var town_id: StringName
@export var display_name: String = "Safe Zone"
@export var background_texture: Texture2D
@export var exploration_map: PackedScene
@export var location_backgrounds: Dictionary[String, Texture2D] = {}
var module_view: Control
var _navigation_pending := false


func _ready() -> void:
	super._ready()
	$Panel/Buttons/Title.text = display_name.to_upper()
	if background_texture != null:
		$Background.texture = background_texture
	$Panel/Buttons/Explore.disabled = exploration_map == null


func _on_button_pressed(action: String) -> void:
	if _navigation_pending:
		return
	if module_view != null and module_view.has_method("is_busy") and module_view.is_busy():
		return
	if action == "Explore":
		if exploration_map != null:
			if module_view != null:
				_navigation_pending = true
				await dismiss_module()
				_navigation_pending = false
			exploration_requested.emit(exploration_map)
	else:
		super._on_button_pressed(action)


func open_module(view: Control) -> void:
	close_module()
	module_view = view
	# The module uses the same full-screen anchor space as the navigation card.
	# Ignore its empty area so the Safe Zone buttons remain clickable.
	view.name = "Module"
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	$Panel.move_to_front()
	$Background.texture = view.get_node("Background").texture
	view.get_node("Background").hide()


func close_module() -> void:
	if is_instance_valid(module_view):
		var outgoing := module_view
		outgoing.name = "RetiringModule"
		for control in outgoing.find_children("*", "Control", true, false):
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if control is BaseButton:
				control.disabled = true
		_retire_module(outgoing)
	module_view = null
	if background_texture != null:
		$Background.texture = background_texture
	$Panel/Buttons/Barracks.grab_focus()


func _retire_module(view: Control) -> void:
	await view.hide_cards()
	if is_instance_valid(view):
		remove_child(view)
		view.queue_free()


func dismiss_module() -> void:
	var outgoing := module_view
	close_module()
	if is_instance_valid(outgoing) and outgoing.is_inside_tree():
		await outgoing.tree_exited
