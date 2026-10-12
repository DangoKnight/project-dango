extends Node

signal started(event: ConversationEvent)
signal finished(event: ConversationEvent)

const OVERLAY := preload("res://scenes/ui/conversation.tscn")

## The game supplies a readiness check to wait for scene fades and rest notices.
var can_start: Callable
var active_event: ConversationEvent
var overlay: ConversationOverlay
var completed: Dictionary[StringName, bool]:
	get:
		return get_node("/root/GameState").completed_conversations
var _pending: Array[ConversationEvent] = []
var _previous_pause := false
var _previous_mouse_mode: Input.MouseMode
var _previous_focus: WeakRef
var _finishing := false
var _rewarded_lines: Dictionary[int, bool] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Returns false for invalid or already completed/queued once-per-game events.
## Multiple requests are queued and played in order without resuming between them.
func play(event: ConversationEvent) -> bool:
	if event == null or not event.is_valid():
		return false
	if event.once_per_game:
		if completed.has(event.id) or (active_event != null and active_event.id == event.id):
			return false
		for pending in _pending:
			if pending.id == event.id:
				return false
	_pending.append(event)
	_try_start()
	return true


func is_active() -> bool:
	return active_event != null


func _process(_delta: float) -> void:
	_try_start()


func _try_start() -> void:
	if _finishing or is_active() or _pending.is_empty():
		return
	if can_start.is_valid() and not can_start.call():
		return
	_previous_pause = get_tree().paused
	_previous_mouse_mode = Input.mouse_mode
	_previous_focus = weakref(get_viewport().gui_get_focus_owner())
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_start_next()


func _start_next() -> void:
	active_event = _pending.pop_front()
	_rewarded_lines.clear()
	overlay = OVERLAY.instantiate() as ConversationOverlay
	add_child(overlay)
	overlay.line_entered.connect(_on_line_entered)
	overlay.configure(active_event)
	overlay.dismissed.connect(_finish, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	started.emit(active_event)


func _on_line_entered(index: int, line: ConversationLine) -> void:
	if _rewarded_lines.has(index):
		return
	_rewarded_lines[index] = true
	var state := get_node("/root/GameState") as RunState
	if line.reward_gear != null:
		for item in range(line.reward_quantity):
			state.gear_inventory.add(line.reward_gear)
	if line.recruit_character != null:
		state.recruit_character(line.recruit_character)


func _finish() -> void:
	var event := active_event
	if event == null:
		return
	if event.id != &"":
		completed[event.id] = true
	_remove_overlay()
	active_event = null
	# Completion callbacks may queue another event; keep the scene paused throughout.
	_finishing = true
	finished.emit(event)
	_finishing = false
	if not _pending.is_empty():
		_start_next()
	else:
		_restore_scene()


func _remove_overlay() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay = null


func _restore_scene() -> void:
	get_tree().paused = _previous_pause
	Input.mouse_mode = _previous_mouse_mode
	if _previous_focus != null:
		var focus = _previous_focus.get_ref()
		if is_instance_valid(focus) and focus.is_inside_tree() and focus.is_visible_in_tree():
			focus.grab_focus()
	_previous_focus = null


## Cancel pending events and clear completion history when starting a new game.
func reset() -> void:
	_pending.clear()
	if is_active():
		_remove_overlay()
		active_event = null
		_restore_scene()
	completed.clear()
