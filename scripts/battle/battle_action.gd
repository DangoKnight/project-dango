class_name BattleAction
extends RefCounted

var actor: CharacterState
var target: CharacterState
var ability: AbilityDefinition
var consumable: GearInstance
var basic_attack := false
var defending := false
var running := false
var priority := 0
var sequence := 0


func _init(user: CharacterState, recipient: CharacterState = null, skill: AbilityDefinition = null, basic: bool = false) -> void:
	actor = user
	target = recipient
	ability = skill
	basic_attack = basic
