class_name BattleSession
extends RefCounted

signal changed
signal action_resolved(message: String)

enum Phase { ACTION_SELECTION, TARGET_SELECTION, READY, RESOLVING, FINISHED }

var party: Array[CharacterState] = []
var enemies: Array[CharacterState] = []
var phase: Phase = Phase.ACTION_SELECTION
var round_number := 1
var victory := false
var escaped := false
var rng := RandomNumberGenerator.new()
var planned_actions: Array[BattleAction] = []
var _planners: Array[CharacterState] = []
var _planner_index := 0
var _selected_ability: AbilityDefinition
var _selected_consumable: GearInstance
var _selected_basic := false
var _queue: Array[BattleAction] = []
var _queue_index := 0


func _init(allies: Array[CharacterState], opponents: Array[CharacterState]) -> void:
	party = allies.duplicate()
	enemies = opponents.duplicate()
	rng.randomize()
	for character in party + enemies:
		character.bind_battle(self)
	_start_round()


func passives_active() -> bool:
	return phase != Phase.FINISHED


func active_character() -> CharacterState:
	return _planners[_planner_index] if _planner_index < _planners.size() else null


func selected_ability() -> AbilityDefinition:
	return RPGCombat.BASIC_ATTACK if _selected_basic else _selected_ability


func choose_attack() -> bool:
	if phase != Phase.ACTION_SELECTION or not active_character().can_act():
		return false
	_selected_consumable = null
	_selected_basic = true
	_selected_ability = null
	phase = Phase.TARGET_SELECTION
	changed.emit()
	return true


func choose_ability(ability: AbilityDefinition) -> bool:
	if phase != Phase.ACTION_SELECTION or not active_character().can_act() or ability == null or ability not in active_character().get_abilities() or active_character().current_mp < ability.mana_cost:
		return false
	_selected_ability = ability
	_selected_consumable = null
	_selected_basic = false
	phase = Phase.TARGET_SELECTION
	changed.emit()
	return true


func selected_consumable() -> GearInstance:
	return _selected_consumable


func choose_consumable(item: GearInstance) -> bool:
	if phase != Phase.ACTION_SELECTION or not active_character().can_act() or item == null or item not in active_character().get_equipped_gear() or item.is_destroyed() or not item.definition.is_valid() or item.definition.kind != GearDefinition.Kind.CONSUMABLE:
		return false
	_selected_consumable = item
	_selected_ability = null
	_selected_basic = false
	phase = Phase.TARGET_SELECTION
	changed.emit()
	return true


func _item_targets(actor: CharacterState, item: GearInstance) -> Array[CharacterState]:
	if item.definition.consumable_target == GearDefinition.Target.SELF:
		return _living([actor])
	var friendly := item.definition.consumable_target in [GearDefinition.Target.ALLY, GearDefinition.Target.PARTY]
	var friends: Array[CharacterState] = party if actor in party else enemies
	var foes: Array[CharacterState] = enemies if actor in party else party
	return _living(friends if friendly else foes)


func valid_targets() -> Array[CharacterState]:
	if phase != Phase.TARGET_SELECTION:
		return []
	if _selected_consumable != null:
		return _item_targets(active_character(), _selected_consumable)
	return _targets_for(active_character(), selected_ability())


func _targets_for(actor: CharacterState, ability: AbilityDefinition) -> Array[CharacterState]:
	var friends: Array[CharacterState] = party if actor in party else enemies
	var foes: Array[CharacterState] = enemies if actor in party else party
	var candidates: Array[CharacterState] = []
	match ability.targeting:
		AbilityDefinition.Target.ENEMY, AbilityDefinition.Target.ENEMIES: candidates = foes
		AbilityDefinition.Target.ALLY, AbilityDefinition.Target.PARTY: candidates = friends
		AbilityDefinition.Target.SELF: candidates = [actor]
		AbilityDefinition.Target.ANY: candidates = friends + foes
	var result: Array[CharacterState] = []
	for character in candidates:
		if character.is_alive():
			result.append(character)
	return result


func select_target(target: CharacterState) -> bool:
	if phase != Phase.TARGET_SELECTION or target not in valid_targets():
		return false
	var action := BattleAction.new(active_character(), target, _selected_ability, _selected_basic)
	action.consumable = _selected_consumable
	planned_actions.append(action)
	_advance_planner()
	return true


## Defend protects for the entire committed round; Run resolves on the actor's turn.
func choose_defend() -> bool:
	return _choose_simple(true)


func choose_run() -> bool:
	return _choose_simple(false)


func _choose_simple(guard: bool) -> bool:
	if phase != Phase.ACTION_SELECTION or not active_character().can_act():
		return false
	var action := BattleAction.new(active_character())
	action.defending = guard
	action.running = not guard
	planned_actions.append(action)
	_advance_planner()
	return true


func choose_wait() -> bool:
	if phase != Phase.ACTION_SELECTION:
		return false
	planned_actions.append(BattleAction.new(active_character()))
	_advance_planner()
	return true


func _advance_planner() -> void:
	_planner_index += 1
	_selected_ability = null
	_selected_consumable = null
	_selected_basic = false
	phase = Phase.READY if _planner_index == _planners.size() else Phase.ACTION_SELECTION
	changed.emit()


func cancel_target() -> void:
	if phase == Phase.TARGET_SELECTION:
		_selected_ability = null
		_selected_consumable = null
		_selected_basic = false
		phase = Phase.ACTION_SELECTION
		changed.emit()


func undo_choice() -> void:
	if phase not in [Phase.ACTION_SELECTION, Phase.READY] or planned_actions.is_empty():
		return
	planned_actions.pop_back()
	_planner_index -= 1
	phase = Phase.ACTION_SELECTION
	changed.emit()


func begin_resolution() -> bool:
	if phase != Phase.READY:
		return false
	_queue = planned_actions.duplicate()
	for action in planned_actions:
		action.actor.defending = action.defending and action.actor.can_act()
	# Enemies commit their actions before any queued action is executed.
	var targets := _living(party)
	for index in range(enemies.size()):
		var enemy := enemies[index]
		if not enemy.is_alive():
			continue
		var skill: AbilityDefinition
		for ability in enemy.get_abilities():
			if ability.effect == AbilityDefinition.Effect.DAMAGE and ability.targeting == AbilityDefinition.Target.ENEMY and ability.mana_cost <= enemy.current_mp:
				skill = ability
				break
		_queue.append(BattleAction.new(enemy, targets[index % targets.size()], skill, skill == null))
	for index in range(_queue.size()):
		_queue[index].priority = _queue[index].actor.get_stat(&"speed")
		_queue[index].sequence = index
	_queue.sort_custom(func(a: BattleAction, b: BattleAction):
		return a.priority > b.priority if a.priority != b.priority else a.sequence < b.sequence)
	_queue_index = 0
	phase = Phase.RESOLVING
	changed.emit()
	return true


## Resolve one queued action; presentation decides the delay between actions.
func resolve_next_action() -> void:
	if phase != Phase.RESOLVING:
		return
	var action := _queue[_queue_index]
	_queue_index += 1
	var message := "%s cannot act." % action.actor.definition.display_name
	if action.actor.can_act():
		if action.running:
			escaped = true
			phase = Phase.FINISHED
			_clear_battle_effects()
			action_resolved.emit("%s leads the party to safety." % action.actor.definition.display_name)
			changed.emit()
			return
		elif action.defending:
			message = "%s defends." % action.actor.definition.display_name
		elif action.consumable != null:
			var item := action.consumable
			var recipients: Array[CharacterState] = []
			var allowed := _item_targets(action.actor, item)
			if item.definition.consumable_target in [GearDefinition.Target.PARTY, GearDefinition.Target.ENEMIES]:
				recipients = allowed
			elif action.target in allowed:
				recipients = [action.target]
			var result := RPGConsumables.use_item(action.actor, item, recipients)
			if result.success:
				message = "%s uses %s: %d healing, %d damage, %d SP restored; effects applied. %d uses left%s." % [action.actor.definition.display_name, item.definition.display_name, result.healing, result.damage, result.sp_restored, result.remaining_uses, " (destroyed)" if result.destroyed else ""]
			else:
				message = "%s: %s failed (%s)." % [action.actor.definition.display_name, item.definition.display_name, result.reason]
		elif action.ability == null and not action.basic_attack:
			message = "%s waits." % action.actor.definition.display_name
		else:
			var ability := RPGCombat.BASIC_ATTACK if action.basic_attack else action.ability
			# Enemy intent is committed during planning; current aggro can redirect it at execution.
			if action.actor in enemies and ability.targeting == AbilityDefinition.Target.ENEMY:
				action.target = _aggro_target(_living(party), action.target)
			# Attacks retarget if an earlier action defeated the chosen enemy.
			if not action.target.is_alive() and ability.targeting == AbilityDefinition.Target.ENEMY:
				var replacements := _targets_for(action.actor, ability)
				if not replacements.is_empty():
					action.target = replacements[0]
			var result: Dictionary
			var group := ability.targeting in [AbilityDefinition.Target.PARTY, AbilityDefinition.Target.ENEMIES]
			if action.basic_attack:
				result = RPGCombat.use_basic_attack(action.actor, action.target, rng)
			elif group:
				result = RPGCombat.use_ability_on_targets(action.actor, _targets_for(action.actor, ability), ability, rng)
			else:
				result = RPGCombat.use_ability(action.actor, action.target, ability, rng)
			if not result.success:
				message = "%s: %s failed (%s)." % [action.actor.definition.display_name, ability.display_name, result.reason]
			elif result.missed:
				message = "%s uses %s on %s: miss." % [action.actor.definition.display_name, ability.display_name, "the party" if ability.targeting == AbilityDefinition.Target.PARTY else "all enemies" if ability.targeting == AbilityDefinition.Target.ENEMIES else action.target.definition.display_name]
			elif ability.effect == AbilityDefinition.Effect.STATUS:
				message = "%s uses %s on %s." % [action.actor.definition.display_name, ability.display_name, "the party" if ability.targeting == AbilityDefinition.Target.PARTY else "all enemies" if ability.targeting == AbilityDefinition.Target.ENEMIES else action.target.definition.display_name]
			else:
				message = "%s uses %s on %s: %d %s." % [action.actor.definition.display_name, ability.display_name, "the party" if ability.targeting == AbilityDefinition.Target.PARTY else "all enemies" if ability.targeting == AbilityDefinition.Target.ENEMIES else action.target.definition.display_name, result.amount, "healing" if ability.effect == AbilityDefinition.Effect.HEAL else "critical damage" if result.critical else "damage"]
	elif action.actor.is_alive():
		message = "%s is paralyzed and cannot act." % action.actor.definition.display_name
	if action.actor.is_alive():
		var tick := action.actor.advance_status_turn()
		if tick.damage > 0:
			message += " %s takes %d status damage." % [action.actor.definition.display_name, tick.damage]
	action_resolved.emit(message)
	if _check_finished():
		return
	if _queue_index == _queue.size():
		round_number += 1
		_start_round()
	else:
		changed.emit()


## Neutral weights preserve the existing enemy spread. Increased aggro uses weighted targeting.
func _aggro_target(candidates: Array[CharacterState], fallback: CharacterState) -> CharacterState:
	var increased := false
	var total := 0.0
	for candidate in candidates:
		var weight := candidate.get_combat_stat(&"aggro")
		increased = increased or not is_equal_approx(weight, 1.0)
		total += weight
	if not increased:
		return fallback if fallback in candidates else candidates[0]
	var roll := rng.randf() * total
	for candidate in candidates:
		roll -= candidate.get_combat_stat(&"aggro")
		if roll <= 0.0:
			return candidate
	return candidates[-1]


func _living(characters: Array[CharacterState]) -> Array[CharacterState]:
	var result: Array[CharacterState] = []
	for character in characters:
		if character.is_alive():
			result.append(character)
	return result


func _check_finished() -> bool:
	if not _living(party).is_empty() and not _living(enemies).is_empty():
		return false
	victory = not _living(party).is_empty()
	phase = Phase.FINISHED
	_clear_battle_effects()
	changed.emit()
	return true


func _clear_battle_effects() -> void:
	for character in party + enemies:
		character.defending = false
		character.bind_battle(null)
		for status in character.get_active_statuses():
			character.remove_status(status.definition.id)


func _start_round() -> void:
	for character in party + enemies:
		character.defending = false
		character._clamp_vitals()
	if _check_finished():
		return
	_planners = _living(party)
	_planner_index = 0
	planned_actions.clear()
	_selected_ability = null
	_selected_consumable = null
	_selected_basic = false
	phase = Phase.ACTION_SELECTION
	changed.emit()
