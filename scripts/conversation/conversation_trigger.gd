class_name ConversationTrigger
extends Node

## Place under a Town, Map, combat scene, or any other gameplay node.
## Manual triggers can connect an Area3D.body_entered or another gameplay signal.
@export var event: ConversationEvent
@export var on_scene_entry := false
@export var once_per_instance := true
var _triggered := false


func _ready() -> void:
	if on_scene_entry:
		trigger.call_deferred()


## Optional argument accepts a signal's payload, e.g. a body or defeated species.
func trigger(_payload: Variant = null) -> bool:
	if once_per_instance and _triggered:
		return false
	var accepted: bool = get_node("/root/Conversations").play(event)
	if accepted:
		_triggered = true
	return accepted
