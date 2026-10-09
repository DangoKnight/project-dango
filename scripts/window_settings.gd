extends Node


func _ready() -> void:
	# Keep text and controls usable; canvas_items scales the anchored UI below its base size.
	var window := get_window()
	window.min_size = Vector2i(800, 450)
	# Embedded play is sized by the editor's Game view, not the native window border.
	if not Engine.is_embedded_in_editor():
		window.unresizable = false
