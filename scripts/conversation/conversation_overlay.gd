class_name ConversationOverlay
extends CanvasLayer

signal dismissed
signal skip_requested
signal line_entered(index: int, line: ConversationLine)

var event: ConversationEvent
var line_index := 0
var _revealed := 0.0
var _line_elapsed := 0.0
var _closing := false
var _portrait_homes: Dictionary = {}
var _occupants: Dictionary = {}
var _requested_occupants: Dictionary = {}
var _requested_textures: Dictionary = {}
var _entrance_tweens: Dictionary = {}
@onready var left_portrait: TextureRect = $Root/LeftPortrait
@onready var right_portrait: TextureRect = $Root/RightPortrait
@onready var speaker_label: Label = $Root/Dialogue/Margin/Content/Speaker
@onready var body: RichTextLabel = $Root/Dialogue/Margin/Content/Text
@onready var next_button: Button = $Root/Dialogue/Margin/Content/Next
@onready var skip_button: Button = $Root/Skip


func _ready() -> void:
	next_button.pressed.connect(advance)
	skip_button.pressed.connect(skip)
	for portrait in [left_portrait, right_portrait]:
		_portrait_homes[portrait] = Vector4(portrait.anchor_left, portrait.anchor_top, portrait.anchor_right, portrait.anchor_bottom)


func configure(value: ConversationEvent) -> void:
	event = value
	line_index = 0
	_show_line()
	next_button.grab_focus()


func _show_line() -> void:
	var line := event.lines[line_index]
	line_entered.emit(line_index, line)
	if not line.notification_text.is_empty():
		$Root/Notification.present(line.notification_text, line.notification_duration)
	_present_portrait(left_portrait, line, ConversationLine.Speaker.LEFT)
	_present_portrait(right_portrait, line, ConversationLine.Speaker.RIGHT)
	left_portrait.modulate = Color.WHITE if line.speaker != ConversationLine.Speaker.RIGHT else Color(0.55, 0.55, 0.6)
	right_portrait.modulate = Color.WHITE if line.speaker != ConversationLine.Speaker.LEFT else Color(0.55, 0.55, 0.6)
	speaker_label.text = L10n.text(line.displayed_speaker())
	body.text = line.formatted_text()
	_revealed = 0.0
	_line_elapsed = 0.0
	body.visible_characters = -1 if event.characters_per_second <= 0.0 else 0
	next_button.text = L10n.text("ui.finish") if line_index == event.lines.size() - 1 else L10n.text("ui.continue")
	$Root/Dialogue.visible = not (line.auto_advance and line.text.strip_edges().is_empty())
	next_button.visible = not line.auto_advance


func _present_portrait(portrait: TextureRect, line: ConversationLine, side: ConversationLine.Speaker) -> void:
	var is_left := side == ConversationLine.Speaker.LEFT
	var texture := line.portrait_for(side)
	var character := line.left_character if is_left else line.right_character
	var occupant: Resource = character if character != null else texture
	var changed: bool = _occupants.get(portrait) != occupant
	var repeat := line.left_repeat_entrance if is_left else line.right_repeat_entrance
	_requested_textures[portrait] = texture
	# Preserve a pending replacement across lines instead of restarting its exit.
	if _requested_occupants.has(portrait) and _requested_occupants[portrait] == occupant and not repeat:
		if not changed:
			portrait.texture = texture
			portrait.visible = texture != null
		return
	_requested_occupants[portrait] = occupant
	var old_tween: Tween = _entrance_tweens.get(portrait)
	if old_tween != null:
		old_tween.kill()
	var entrance := line.left_entrance if is_left else line.right_entrance
	var duration := line.left_entrance_duration if is_left else line.right_entrance_duration
	var delay := line.left_entrance_delay if is_left else line.right_entrance_delay
	var exit := line.left_exit if is_left else line.right_exit
	var exit_duration := line.left_exit_duration if is_left else line.right_exit_duration
	var exiting := changed and portrait.texture != null and portrait.visible and exit != ConversationLine.Exit.INSTANT and exit_duration > 0.0
	var entering := texture != null and (changed or repeat) and entrance != ConversationLine.Entrance.INSTANT and duration > 0.0
	if not exiting and not entering:
		_install_portrait(portrait, occupant, ConversationLine.Entrance.INSTANT)
		return
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_entrance_tweens[portrait] = tween
	if exiting:
		var start := Vector4(portrait.anchor_left, portrait.anchor_top, portrait.anchor_right, portrait.anchor_bottom)
		tween.tween_method(_set_exit_progress.bind(portrait, exit, start, portrait.self_modulate.a), 0.0, 1.0, exit_duration).set_ease(Tween.EASE_IN)
		tween.tween_callback(_install_portrait.bind(portrait, occupant, entrance if entering else ConversationLine.Entrance.INSTANT))
	else:
		_install_portrait(portrait, occupant, entrance)
	if entering:
		if delay > 0.0:
			tween.tween_interval(delay)
		tween.tween_method(_set_entrance_progress.bind(portrait, entrance), 0.0, 1.0, duration)


func _install_portrait(portrait: TextureRect, occupant: Resource, entrance: ConversationLine.Entrance) -> void:
	_occupants[portrait] = occupant
	portrait.texture = _requested_textures.get(portrait)
	portrait.visible = portrait.texture != null
	_set_entrance_progress(1.0 if entrance == ConversationLine.Entrance.INSTANT else 0.0, portrait, entrance)


func _set_exit_progress(progress: float, portrait: TextureRect, exit: ConversationLine.Exit, start: Vector4, start_alpha: float) -> void:
	var home: Vector4 = _portrait_homes[portrait]
	var shift := _offscreen_shift(home, exit)
	var destination := start if exit == ConversationLine.Exit.FADE else home + Vector4(shift.x, shift.y, shift.x, shift.y)
	var anchors := start.lerp(destination, progress)
	portrait.anchor_left = anchors.x
	portrait.anchor_top = anchors.y
	portrait.anchor_right = anchors.z
	portrait.anchor_bottom = anchors.w
	portrait.self_modulate.a = lerpf(start_alpha, 0.0, progress) if exit == ConversationLine.Exit.FADE else start_alpha


func _set_entrance_progress(progress: float, portrait: TextureRect, entrance: ConversationLine.Entrance) -> void:
	var home: Vector4 = _portrait_homes[portrait]
	var shift := _offscreen_shift(home, entrance) * (1.0 - progress)
	portrait.anchor_left = home.x + shift.x
	portrait.anchor_right = home.z + shift.x
	portrait.anchor_top = home.y + shift.y
	portrait.anchor_bottom = home.w + shift.y
	portrait.self_modulate.a = progress if entrance == ConversationLine.Entrance.FADE else 1.0


func _offscreen_shift(home: Vector4, direction: int) -> Vector2:
	# Entrance and Exit enums share direction values.
	match direction:
		1: return Vector2(-home.z - 0.02, 0.0)
		2: return Vector2(1.02 - home.x, 0.0)
		3: return Vector2(0.0, -home.w - 0.02)
		4: return Vector2(0.0, 1.02 - home.y)
	return Vector2.ZERO


func _process(delta: float) -> void:
	if event == null or _closing:
		return
	_line_elapsed += delta
	if body.visible_characters >= 0:
		_revealed += delta * event.characters_per_second
		body.visible_characters = mini(int(_revealed), body.get_total_character_count())
	if event.lines[line_index].auto_advance and _line_elapsed >= event.lines[line_index].minimum_duration and (body.visible_characters < 0 or body.visible_characters >= body.get_total_character_count()):
		for tween: Tween in _entrance_tweens.values():
			if tween.is_running():
				return
		_advance_line()


func advance() -> void:
	if _closing or event == null:
		return
	if event.lines[line_index].auto_advance or _line_elapsed < event.lines[line_index].minimum_duration:
		return
	if body.visible_characters >= 0 and body.visible_characters < body.get_total_character_count():
		body.visible_characters = -1
		return
	_advance_line()


## Bypasses typing, holds, and portrait transitions, including automatic steps.
func skip() -> void:
	if _closing or event == null:
		return
	_closing = true
	skip_requested.emit()
	dismissed.emit()


func _advance_line() -> void:
	if line_index + 1 < event.lines.size():
		line_index += 1
		_show_line()
	else:
		_closing = true
		dismissed.emit()


func _input(input_event: InputEvent) -> void:
	# Let the text scrollbar receive wheel and drag input within the modal overlay.
	if input_event is InputEventMouseMotion:
		return
	if input_event is InputEventMouseButton:
		if skip_button.get_global_rect().has_point(input_event.position):
			return
		var scrollbar := body.get_v_scroll_bar()
		if not input_event.pressed or input_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] or (scrollbar.visible and scrollbar.get_global_rect().has_point(input_event.position)):
			return
	if input_event is InputEventKey and input_event.echo:
		get_viewport().set_input_as_handled()
		return
	if input_event.is_action_pressed("ui_accept") and skip_button.has_focus():
		get_viewport().set_input_as_handled()
		skip()
		return
	if input_event.is_action_pressed("ui_focus_next") or input_event.is_action_pressed("ui_focus_prev"):
		# Let keyboard focus reach Skip without passing Tab to gameplay.
		return
	if input_event.is_action_pressed("ui_accept") or (input_event is InputEventMouseButton and input_event.pressed and input_event.button_index == MOUSE_BUTTON_LEFT):
		advance()
	# Keep Escape, Tab, mouse input and gameplay shortcuts inside the conversation.
	get_viewport().set_input_as_handled()
