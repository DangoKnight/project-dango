class_name BattleEncounter
extends Resource

@export var display_name: String = "Encounter"
@export var enemies: Array[CharacterDefinition] = []
@export_range(1, 99) var enemy_level: int = 1
