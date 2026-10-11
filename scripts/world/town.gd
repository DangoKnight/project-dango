class_name Town
extends "res://scripts/ui/screen.gd"

signal exploration_requested(map_scene: PackedScene)

@export var town_id: StringName
@export var display_name: String = "Safe Zone"
@export var background_texture: Texture2D
@export var exploration_map: PackedScene
@export var location_backgrounds: Dictionary[String, Texture2D] = {}
@export_group("Barterer")
@export var barter_artifacts: Array[GearDefinition] = [preload("res://resources/rpg/gear/iron_artifact.tres"), preload("res://resources/rpg/gear/wind_artifact.tres"), preload("res://resources/rpg/gear/vital_artifact.tres")]
@export_range(1, 20) var barter_artifact_min := 2
@export_range(1, 20) var barter_artifact_max := 4
@export var barter_consumables: Array[GearDefinition] = [preload("res://resources/rpg/gear/healing_draught.tres"), preload("res://resources/rpg/gear/rally_flask.tres"), preload("res://resources/rpg/gear/frailty_bomb.tres")]
## Walking steps per artifact refresh cycle, started by talking to the Barterer.
@export_range(1, 10000) var barter_restock_steps := 25
@export_group("Tinkerer")
@export var fabrication_ideas: Array[FabricationRecipe] = [preload("res://resources/rpg/recipes/sword.tres"), preload("res://resources/rpg/recipes/dagger.tres"), preload("res://resources/rpg/recipes/staff.tres"), preload("res://resources/rpg/recipes/spell_medallion.tres")]
@export_group("")
var module_view: Control
var _navigation_pending := false
var navigation_locked := false


func _ready() -> void:
	# Apply before the card is presented or its buttons receive initial focus.
	set_navigation_locked(navigation_locked)
	var initial_slide := card_slide_from
	var initial_focus := first_focus
	if navigation_locked:
		card_slide_from = 0
		first_focus = NodePath()
	super._ready()
	card_slide_from = initial_slide
	first_focus = initial_focus
	$Panel/Buttons/Title.text = display_name.to_upper()
	if background_texture != null:
		$Background.texture = background_texture


func set_navigation_locked(locked: bool) -> void:
	var was_locked := navigation_locked
	navigation_locked = locked
	if locked:
		$Panel.hide()
	for button in $Panel/Buttons.get_children():
		if button is Button:
			button.disabled = locked or (button.name == &"Explore" and exploration_map == null)
	if not locked and is_node_ready():
		if was_locked:
			slide_card_in($Panel, card_slide_from)
		$Panel/Buttons/Barracks.grab_focus()


func _on_button_pressed(action: String) -> void:
	if navigation_locked or _navigation_pending:
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
