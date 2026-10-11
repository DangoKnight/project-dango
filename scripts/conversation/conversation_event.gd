class_name ConversationEvent
extends Resource

## Stable ID used for completion tracking. Required for once-per-game events.
@export var id: StringName
@export var once_per_game := false
@export var lines: Array[ConversationLine] = []
@export_range(0.0, 150.0, 1.0) var characters_per_second := 40.0


func is_valid() -> bool:
	if lines.is_empty() or (once_per_game and id == &""):
		return false
	for line in lines:
		if line == null:
			return false
	return true
