extends Control

signal action_requested(action: String)

@export var first_focus: NodePath


func _ready() -> void:
	for button in find_children("*", "Button", true, false):
		button.pressed.connect(_on_button_pressed.bind(String(button.name)))
	if not first_focus.is_empty():
		get_node(first_focus).grab_focus()


func _on_button_pressed(action: String) -> void:
	action_requested.emit(action)
