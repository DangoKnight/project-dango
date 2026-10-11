class_name ConversationLine
extends Resource

enum Speaker { NARRATOR, LEFT, RIGHT }
enum Entrance { INSTANT, FROM_LEFT, FROM_RIGHT, FROM_TOP, FROM_BOTTOM, FADE }
enum Exit { INSTANT, TO_LEFT, TO_RIGHT, TO_TOP, TO_BOTTOM, FADE }

## Each line defines both visible slots. Empty slots hide that character.
@export var left_character: CharacterDefinition
@export var right_character: CharacterDefinition
## Optional portrait overrides, for expressions or characters outside the roster.
@export var left_portrait: Texture2D
@export var right_portrait: Texture2D
@export var left_name: String
@export var right_name: String
@export var speaker: Speaker = Speaker.NARRATOR
## Overrides the displayed speaker name, including narration.
@export var speaker_name: String
@export_multiline var text: String
## Advance after typing and portrait transitions finish. Empty text hides the dialogue card.
@export var auto_advance := false

@export_group("Slot 1 (Left) Entrance")
@export var left_entrance: Entrance = Entrance.INSTANT
@export_range(0.0, 3.0, 0.05) var left_entrance_duration := 0.4
@export_range(0.0, 3.0, 0.05) var left_entrance_delay := 0.0
## Otherwise only a new character entering this slot plays its entrance.
@export var left_repeat_entrance := false
@export_group("Slot 2 (Right) Entrance")
@export var right_entrance: Entrance = Entrance.INSTANT
@export_range(0.0, 3.0, 0.05) var right_entrance_duration := 0.4
@export_range(0.0, 3.0, 0.05) var right_entrance_delay := 0.0
@export var right_repeat_entrance := false
@export_group("Slot 1 (Left) Exit")
## Applied to the previous occupant when this line replaces or clears the slot.
@export var left_exit: Exit = Exit.INSTANT
@export_range(0.0, 3.0, 0.05) var left_exit_duration := 0.3
@export_group("Slot 2 (Right) Exit")
@export var right_exit: Exit = Exit.INSTANT
@export_range(0.0, 3.0, 0.05) var right_exit_duration := 0.3


func portrait_for(side: Speaker) -> Texture2D:
	var override := left_portrait if side == Speaker.LEFT else right_portrait
	var character := left_character if side == Speaker.LEFT else right_character
	return override if override != null else character.portrait if character != null else null


func name_for(side: Speaker) -> String:
	var override := left_name if side == Speaker.LEFT else right_name
	var character := left_character if side == Speaker.LEFT else right_character
	return override if not override.is_empty() else character.display_name if character != null else ""


func displayed_speaker() -> String:
	if not speaker_name.is_empty():
		return speaker_name
	return "" if speaker == Speaker.NARRATOR else name_for(speaker)
