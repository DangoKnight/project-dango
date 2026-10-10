extends Control

signal action_requested(action: String)

@export var first_focus: NodePath
@export_enum("None", "Left", "Right") var card_slide_from: int = 0
@export_range(0.0, 1.0, 0.05) var card_slide_duration := 0.25
var _card_homes: Dictionary = {}
var _card_tweens: Dictionary = {}
var _card_progress: Dictionary = {}


func _ready() -> void:
	for button in find_children("*", "Button", true, false):
		button.pressed.connect(_on_button_pressed.bind(String(button.name)))
	if not first_focus.is_empty():
		get_node(first_focus).grab_focus()
	if card_slide_from != 0 and has_node("Panel"):
		slide_card_in($Panel, card_slide_from)


func slide_card_in(panel: Control, from_side: int) -> void:
	if not _card_homes.has(panel):
		_card_homes[panel] = Vector4(panel.anchor_left, panel.anchor_top, panel.anchor_right, panel.anchor_bottom)
	var old_tween: Tween = _card_tweens.get(panel)
	if old_tween != null:
		old_tween.kill()
	panel.show()
	if card_slide_duration <= 0.0:
		_set_card_slide(1.0, panel, from_side)
		return
	_set_card_slide(0.0, panel, from_side)
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_card_tweens[panel] = tween
	tween.tween_method(_set_card_slide.bind(panel, from_side), 0.0, 1.0, card_slide_duration)


func _set_card_slide(progress: float, panel: Control, from_side: int) -> void:
	_card_progress[panel] = progress
	var home: Vector4 = _card_homes[panel]
	var shift := -(home.z + 0.02) if from_side == 1 else 1.02 - home.x
	shift *= 1.0 - progress
	panel.anchor_left = home.x + shift
	panel.anchor_top = home.y
	panel.anchor_right = home.z + shift
	panel.anchor_bottom = home.w


func slide_card_out(panel: Control, to_side: int) -> void:
	if not panel.visible:
		return
	var old_tween: Tween = _card_tweens.get(panel)
	if old_tween != null:
		old_tween.kill()
	if card_slide_duration > 0.0:
		var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_card_tweens[panel] = tween
		tween.tween_method(_set_card_slide.bind(panel, to_side), float(_card_progress.get(panel, 1.0)), 0.0, card_slide_duration)
		await tween.finished
	else:
		_set_card_slide(0.0, panel, to_side)
	panel.hide()


func hide_cards() -> void:
	await slide_card_out($Panel, card_slide_from)


func _on_button_pressed(action: String) -> void:
	action_requested.emit(action)
