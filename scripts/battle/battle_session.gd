class_name BattleSession
extends RefCounted

signal changed
signal action_resolved(message: String)
signal enemy_defeated(species: StringName)

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
var _rewarded_enemies: Dictionary = {}
var _escape_failures: Dictionary = {}
var compendium: MonsterCompendium


func _init(allies: Array[CharacterState], opponents: Array[CharacterState], knowledge: MonsterCompendium = null) -> void:
	compendium = knowledge if knowledge != null else MonsterCompendium.new()
	party = allies.duplicate()
	enemies = opponents.duplicate()
	rng.randomize()
	for character in party + enemies:
		character.bind_battle(self)
	for enemy in enemies:
		compendium.encounter(enemy.definition)
		if not enemy.is_alive():
			_rewarded_enemies[enemy] = true
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


func toggle_observe() -> void:
	if phase != Phase.ACTION_SELECTION or active_character() == null:
		return
	var actor := active_character()
	actor.set_observing(not actor.observing)
	changed.emit()


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
		AbilityDefinition.Target.ENEMY, AbilityDefinition.Target.ENEMIES, AbilityDefinition.Target.ENEMY_ROW: candidates = foes
		AbilityDefinition.Target.ALLY, AbilityDefinition.Target.PARTY: candidates = friends
		AbilityDefinition.Target.SELF: candidates = [actor]
		AbilityDefinition.Target.ANY: candidates = friends + foes
	var result: Array[CharacterState] = []
	for character in candidates:
		if character.is_alive():
			result.append(character)
	return result


## Enemy spots 1–3 form the upper row, 4–6 the lower row. Dead slots never shift rows.
func affected_targets(target: CharacterState) -> Array[CharacterState]:
	if target not in valid_targets():
		return []
	if _selected_consumable != null:
		if _selected_consumable.definition.consumable_target in [GearDefinition.Target.PARTY, GearDefinition.Target.ENEMIES]:
			return valid_targets()
		return [target]
	return _ability_recipients(active_character(), selected_ability(), target)


func _ability_recipients(actor: CharacterState, ability: AbilityDefinition, target: CharacterState) -> Array[CharacterState]:
	if ability.targeting in [AbilityDefinition.Target.PARTY, AbilityDefinition.Target.ENEMIES]:
		return _targets_for(actor, ability)
	if ability.targeting == AbilityDefinition.Target.ENEMY_ROW:
		var opponents: Array[CharacterState] = enemies if actor in party else party
		var row := opponents.find(target) / 3
		var result: Array[CharacterState] = []
		for index in range(opponents.size()):
			if index / 3 == row and opponents[index].is_alive():
				result.append(opponents[index])
		return result
	return [target]


## Each runner has their own accumulated failure bonus for this encounter.
func escape_chance(actor: CharacterState) -> float:
	var opponents: Array[CharacterState] = enemies if actor in party else party
	var fastest := 0.0
	var living_opponents := _living(opponents)
	for opponent in living_opponents:
		fastest = maxf(fastest, opponent.get_stat(&"speed"))
	if living_opponents.is_empty():
		return 1.0
	return clampf(0.6 * actor.get_stat(&"speed") / maxf(1.0, fastest) + 0.15 * _escape_failures.get(actor, 0), 0.2, 1.0)


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
	var round_experience := 0.0
	for enemy in _living(enemies):
		round_experience += _enemy_round_experience(enemy)
	for character in party:
		character.store_experience(get_instance_id(), round_experience * character.experience_multiplier())
	changed.emit()
	return true


## Resolve one queued action; presentation decides the delay between actions.
func resolve_next_action() -> void:
	if phase != Phase.RESOLVING:
		return
	var action := _queue[_queue_index]
	_queue_index += 1
	var message := L10n.text("%s cannot act.") % L10n.text(action.actor.definition.display_name)
	if action.actor.can_act():
		if action.running:
			if rng.randf() < escape_chance(action.actor):
				escaped = true
				for character in party:
					character.discard_encounter_experience(get_instance_id())
				phase = Phase.FINISHED
				_clear_battle_effects()
				action_resolved.emit(L10n.text("%s leads the party to safety.") % L10n.text(action.actor.definition.display_name))
				changed.emit()
				return
			_escape_failures[action.actor] = _escape_failures.get(action.actor, 0) + 1
			message = L10n.text("%s fails to escape.") % L10n.text(action.actor.definition.display_name)
		elif action.defending:
			message = L10n.text("%s defends.") % L10n.text(action.actor.definition.display_name)
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
				if action.actor in party:
					for effect in item.definition.effects:
						var damage_type: DamageType = effect.damage_type if effect.kind == ConsumableEffect.Kind.DAMAGE else effect.status.damage_type if effect.kind == ConsumableEffect.Kind.APPLY_STATUS and effect.status.turn_damage > 0 else null
						for recipient in recipients:
							if recipient in enemies and damage_type != null:
								compendium.learn_resistance(recipient, damage_type)
				message = L10n.text("%s uses %s: %d healing, %d damage, %d SP restored; effects applied. %d uses left%s.") % [L10n.text(action.actor.definition.display_name), L10n.text(item.definition.display_name), result.healing, result.damage, result.sp_restored, result.remaining_uses, L10n.text(" (destroyed)") if result.destroyed else ""]
			else:
				message = L10n.text("%s: %s failed (%s).") % [L10n.text(action.actor.definition.display_name), L10n.text(item.definition.display_name), L10n.text(result.reason)]
		elif action.ability == null and not action.basic_attack:
			message = L10n.text("%s waits.") % L10n.text(action.actor.definition.display_name)
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
			var group := ability.targeting in [AbilityDefinition.Target.PARTY, AbilityDefinition.Target.ENEMIES, AbilityDefinition.Target.ENEMY_ROW]
			var recipients: Array[CharacterState] = []
			if group:
				recipients = _ability_recipients(action.actor, ability, action.target)
			else:
				recipients.append(action.target)
			if action.basic_attack:
				result = RPGCombat.use_basic_attack(action.actor, action.target, rng)
			elif group:
				result = RPGCombat.use_ability_on_targets(action.actor, recipients, ability, rng)
			else:
				result = RPGCombat.use_ability(action.actor, action.target, ability, rng)
			_record_knowledge(action.actor, recipients, ability, result)
			if not result.success:
				message = L10n.text("%s: %s failed (%s).") % [L10n.text(action.actor.definition.display_name), L10n.text(ability.display_name), L10n.text(result.reason)]
			elif result.missed:
				message = L10n.text("%s uses %s on %s: miss.") % [L10n.text(action.actor.definition.display_name), L10n.text(ability.display_name), L10n.text("the party") if ability.targeting == AbilityDefinition.Target.PARTY else L10n.text("all enemies") if ability.targeting == AbilityDefinition.Target.ENEMIES else L10n.text("an enemy row") if ability.targeting == AbilityDefinition.Target.ENEMY_ROW else L10n.text(action.target.definition.display_name)]
			elif ability.effect == AbilityDefinition.Effect.STATUS:
				message = L10n.text("%s uses %s on %s.") % [L10n.text(action.actor.definition.display_name), L10n.text(ability.display_name), L10n.text("the party") if ability.targeting == AbilityDefinition.Target.PARTY else L10n.text("all enemies") if ability.targeting == AbilityDefinition.Target.ENEMIES else L10n.text("an enemy row") if ability.targeting == AbilityDefinition.Target.ENEMY_ROW else L10n.text(action.target.definition.display_name)]
			else:
				message = L10n.text("%s uses %s on %s: %d %s.") % [L10n.text(action.actor.definition.display_name), L10n.text(ability.display_name), L10n.text("the party") if ability.targeting == AbilityDefinition.Target.PARTY else L10n.text("all enemies") if ability.targeting == AbilityDefinition.Target.ENEMIES else L10n.text("an enemy row") if ability.targeting == AbilityDefinition.Target.ENEMY_ROW else L10n.text(action.target.definition.display_name), result.amount, L10n.text("healing") if ability.effect == AbilityDefinition.Effect.HEAL else L10n.text("critical damage") if result.critical else L10n.text("damage")]
	elif action.actor.is_alive():
		message = L10n.text("%s is paralyzed and cannot act.") % L10n.text(action.actor.definition.display_name)
	if action.actor.is_alive():
		var tick := action.actor.advance_status_turn()
		if tick.damage > 0:
			message += L10n.text(" %s takes %d status damage.") % [L10n.text(action.actor.definition.display_name), tick.damage]
	_reward_defeated_enemies()
	action_resolved.emit(message)
	if _check_finished():
		return
	if _queue_index == _queue.size():
		round_number += 1
		_start_round()
	else:
		changed.emit()


func _record_knowledge(actor: CharacterState, recipients: Array[CharacterState], ability: AbilityDefinition, result: Dictionary) -> void:
	if not result.success:
		return
	if actor in enemies:
		compendium.learn_ability(actor.definition, ability)
		return
	var damage_type: DamageType = ability.damage_type if ability.effect == AbilityDefinition.Effect.DAMAGE else ability.status_effect.damage_type if ability.effect == AbilityDefinition.Effect.STATUS and ability.status_effect.turn_damage > 0 else null
	if damage_type == null:
		return
	var hits: Array = result.get("targets", [result])
	for index in range(recipients.size()):
		if recipients[index] in enemies and not hits[index].get("missed", false):
			compendium.learn_resistance(recipients[index], damage_type)


func _enemy_round_experience(enemy: CharacterState) -> float:
	return enemy.definition.base_experience_reward / pow(4.0, round_number - 1)


## Each enemy defeat pays its current round reward again, once per living member.
func _reward_defeated_enemies() -> void:
	for enemy in enemies:
		if not enemy.is_alive() and not _rewarded_enemies.has(enemy):
			_rewarded_enemies[enemy] = true
			enemy_defeated.emit(enemy.definition.id)
			for character in party:
				character.store_experience(get_instance_id(), _enemy_round_experience(enemy) * character.experience_multiplier())


## Max HP sets the base weight; gear and statuses such as Cover modify that weight.
func _aggro_target(candidates: Array[CharacterState], fallback: CharacterState) -> CharacterState:
	if candidates.is_empty():
		return fallback
	var total := 0.0
	for candidate in candidates:
		total += candidate.get_combat_stat(&"aggro")
	var roll := rng.randf() * total
	for candidate in candidates:
		roll -= candidate.get_combat_stat(&"aggro")
		if roll < 0.0:
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
