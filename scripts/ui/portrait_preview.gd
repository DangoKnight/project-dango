@tool
extends Control

## Drag a character .tres here, then expand it to edit Portrait Presentation live.
@export var preview_character: CharacterDefinition = preload("res://resources/rpg/characters/usami.tres"):
	set(value):
		_disconnect_character()
		preview_character = value
		if is_node_ready():
			_connect_character()
			_refresh()

var _base_anchors: Vector4
var _default_stretch: int
@onready var image: TextureRect = $Combat/PortraitOverlay/Layout/Portrait


func _ready() -> void:
	_base_anchors = Vector4(image.anchor_left, image.anchor_top, image.anchor_right, image.anchor_bottom)
	_default_stretch = image.stretch_mode
	image.resized.connect(_update_pivot)
	_connect_character()
	_refresh()


func _exit_tree() -> void:
	_disconnect_character()


func _connect_character() -> void:
	if preview_character != null and not preview_character.changed.is_connected(_refresh):
		preview_character.changed.connect(_refresh)


func _disconnect_character() -> void:
	if preview_character != null and preview_character.changed.is_connected(_refresh):
		preview_character.changed.disconnect(_refresh)


func _refresh() -> void:
	if not is_node_ready():
		return
	PortraitPresentation.apply(image, preview_character, _base_anchors, _default_stretch)
	$Combat/PortraitOverlay.show()
	$Combat/RoundCounter.text = "PORTRAIT PREVIEW"
	$Combat/ActionPanel/Layout/Commands/Prompt.text = "Select the PortraitPreview root"
	$Combat/BattleLog/Log.text = "In the Inspector, expand Preview Character → Portrait Presentation.\nChanges update immediately in the 2D viewport.\nDrag another character .tres onto Preview Character to switch.\nSave the character resource to keep your adjustments."
	$Combat/ActionPanel/Layout/Commands/Back.hide()


func _update_pivot() -> void:
	image.pivot_offset = image.size * 0.5
