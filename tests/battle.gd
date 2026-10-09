extends SceneTree

const FRONTLINER = preload("res://tests/fixtures/frontliner.tres")
const CASTER = preload("res://tests/fixtures/caster.tres")
const SENTINEL = preload("res://resources/rpg/enemies/sentinel.tres")
const ENCOUNTER = preload("res://resources/rpg/encounters/training.tres")
const EMBER = preload("res://resources/rpg/abilities/ember.tres")
const MEND = preload("res://resources/rpg/abilities/mend.tres")
const FORTIFY = preload("res://resources/rpg/abilities/fortify.tres")
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func fighter(name_text: String, hp: int, strength: int, speed: int) -> CharacterState:
	var definition := CharacterDefinition.new()
	definition.id = StringName(name_text)
	definition.display_name = name_text
	definition.base_stats = RPGStats.new()
	definition.base_stats.max_hp = hp
	definition.base_stats.strength = strength
	definition.base_stats.speed = speed
	return CharacterState.new(definition)


func attack(session: BattleSession, target: CharacterState) -> void:
	check(session.choose_attack(), "Attack should enter target selection")
	check(session.select_target(target), "Living enemy should be selectable")


func resolve_round(session: BattleSession) -> void:
	check(session.begin_resolution(), "Committed round should begin resolution")
	while session.phase == BattleSession.Phase.RESOLVING:
		session.resolve_next_action()


func press_command(view: CombatScreen, title: String) -> void:
	for child in view.actions.get_children() + [view.get_node("Confirmation/Layout/Execute"), view.get_node("Confirmation/Layout/Return")]:
		if child is Button and child.text == title:
			child.pressed.emit()
			return
	check(false, "Missing combat command: " + title)


func run() -> void:
	var frontliner := CharacterState.new(FRONTLINER, null, 2)
	var caster := CharacterState.new(CASTER, null, 2)
	var enemy := CharacterState.new(SENTINEL)
	var session := BattleSession.new([frontliner, caster], [enemy])
	check(not session.begin_resolution(), "Resolution cannot start before all player choices")
	check(not session.choose_ability(EMBER), "Characters cannot plan unknown abilities")
	check(session.choose_ability(FORTIFY), "Learned status abilities should be selectable")
	check(frontliner in session.valid_targets() and caster in session.valid_targets() and enemy not in session.valid_targets(), "Ally-target abilities should use party targets")
	check(not session.select_target(enemy), "Invalid targets should be rejected")
	session.cancel_target()
	check(session.phase == BattleSession.Phase.ACTION_SELECTION and session.planned_actions.is_empty(), "Cancel should restore action selection without queuing")
	var hp := enemy.current_hp
	var mp := frontliner.current_mp
	attack(session, enemy)
	check(enemy.current_hp == hp and frontliner.current_mp == mp, "Planning must not deal damage or spend MP")
	check(session.active_character() == caster, "The next living party member should choose")
	check(session.choose_ability(MEND), "Healing should be selectable")
	check(frontliner in session.valid_targets() and enemy not in session.valid_targets(), "Healing should target allies")
	session.select_target(frontliner)
	check(session.phase == BattleSession.Phase.READY and enemy.current_hp == hp, "All queued actions should wait for confirmation")
	session.undo_choice()
	check(session.active_character() == caster and session.phase == BattleSession.Phase.ACTION_SELECTION, "Review should allow editing the last action")
	caster.current_mp = 0
	check(not session.choose_ability(MEND), "Unaffordable abilities should not be queued")
	session.choose_wait()
	resolve_round(session)
	check(session.round_number == 2 and session.phase == BattleSession.Phase.ACTION_SELECTION, "Surviving sides should start the next planning round")
	# Equal speeds use stable party/enemy order; no action changes speed mid-round.
	var a := fighter("A", 100, 10, 5)
	var b := fighter("B", 100, 10, 5)
	var c := fighter("C", 100, 10, 5)
	var tie := BattleSession.new([a, b], [c])
	var messages: Array[String] = []
	tie.action_resolved.connect(func(message: String): messages.append(message))
	attack(tie, c)
	attack(tie, c)
	resolve_round(tie)
	check(messages[0].begins_with("A ") and messages[1].begins_with("B ") and messages[2].begins_with("C "), "Speed ties should resolve deterministically")
	var fast := fighter("Fast", 100, 100, 10)
	var slow := fighter("Slow", 100, 100, 9)
	var first := fighter("First", 1, 1, 0)
	var second := fighter("Second", 1, 1, 0)
	var retarget := BattleSession.new([fast, slow], [first, second])
	attack(retarget, first)
	attack(retarget, first)
	resolve_round(retarget)
	check(retarget.phase == BattleSession.Phase.FINISHED and retarget.victory and not second.is_alive(), "Attacks should retarget after their original enemy dies")
	var doomed := fighter("Doomed", 1, 10, 0)
	var survivor := fighter("Survivor", 100, 1, 0)
	var killer := fighter("Killer", 100, 10, 10)
	var skipped := BattleSession.new([doomed, survivor], [killer])
	messages.clear()
	skipped.action_resolved.connect(func(message: String): messages.append(message))
	attack(skipped, killer)
	skipped.choose_wait()
	resolve_round(skipped)
	check(messages[0].begins_with("Killer ") and "Doomed cannot act." in messages, "Fast enemies should act first and defeated actors should be skipped")
	frontliner = CharacterState.new(FRONTLINER, null, 2)
	frontliner.apply_status(FORTIFY.status_effect)
	var ticking := BattleSession.new([frontliner], [fighter("Durable", 999, 0, 0)])
	ticking.choose_wait()
	resolve_round(ticking)
	check(frontliner.get_active_statuses()[0].remaining_turns == 2, "Statuses should advance at the end of the affected character's turn")
	# Actual scene/UI transitions, including portrait visibility and fixed enemy spots.
	var view := load("res://scenes/battle/combat.tscn").instantiate() as CombatScreen
	root.add_child(view)
	var adjusted_character := FRONTLINER.duplicate() as CharacterDefinition
	adjusted_character.portrait_offset = Vector2(-0.1, 0.05)
	adjusted_character.portrait_scale = 0.8
	adjusted_character.portrait_stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check(view.configure([CharacterState.new(adjusted_character), CharacterState.new(CASTER)], ENCOUNTER), "Combat scene should accept the encounter")
	check(view.enemy_slots.size() == 6 and view.party_buttons.size() == 4, "Combat should provide six enemy spots and four character cards")
	check(view._panel_targets[view.portrait.name] and view.session.active_character().definition.display_name == "Test Frontliner", "Choosing actions should overlay the active portrait")
	check(view.portrait_image.scale.is_equal_approx(Vector2(0.8, 0.8)), "Character portrait should use its own scale")
	check(is_equal_approx(view.portrait_image.anchor_left, -0.1) and is_equal_approx(view.portrait_image.anchor_top, 0.05), "Character portrait should use proportional offsets")
	check(view.portrait_image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Character portrait should use its own fit mode")
	var spot := view.enemy_slots[0].get_parent() as Control
	check(is_equal_approx(spot.anchor_left, 0.12) and is_equal_approx(spot.anchor_right, 0.38), "Enemies should use their scene-defined anchor bounds")
	for index in range(2, 6):
		check(not view.enemy_slots[index].visible, "Unused enemy spots should be hidden")
	for index in range(2, 4):
		check(view.party_buttons[index].disabled and view.party_buttons[index].get_node("Name").text == "Empty" and view.party_buttons[index].get_node("HP").value == 0, "Empty character slots should remain visible, disabled, and empty")
	check(view.party_buttons[0].get_node("HP").value == 80 and view.party_buttons[0].get_node("HP").max_value == 80, "Party HP bars should show current and maximum HP")
	check(view.party_buttons[1].get_node("SP").value == 35 and view.party_buttons[1].get_node("SP").max_value == 35, "Party SP bars should use the existing ability-point pool")
	view.session.party[1].set_level(2)
	press_command(view, "Attack")
	check(not view._panel_targets[view.portrait.name] and view.session.phase == BattleSession.Phase.TARGET_SELECTION, "Target selection should hide the portrait")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	view._input(right_click)
	check(view.session.phase == BattleSession.Phase.ACTION_SELECTION and view._panel_targets[view.portrait.name], "Right-click cancels targeting and restores the portrait")
	press_command(view, "Attack")
	view.enemy_slots[0].pressed.emit()
	check(view._panel_targets[view.portrait.name] and view.session.active_character().definition.display_name == "Test Caster", "Next character should display their portrait")
	check(view.portrait_image.scale == Vector2.ONE and is_zero_approx(view.portrait_image.anchor_left) and is_zero_approx(view.portrait_image.anchor_top), "Switching characters should reset portrait adjustments")
	check(view.portrait_image.stretch_mode == view._portrait_default_stretch, "Scene-default fit mode should reset for the next character")
	press_command(view, "Special")
	press_command(view, "Mend (4 SP)")
	check(not view.party_buttons[0].disabled, "Party cards should remain selectable ally targets while the portrait hides")
	view.party_buttons[0].pressed.emit()
	check(view.session.phase == BattleSession.Phase.READY and not view._panel_targets[view.portrait.name], "Portrait should stay hidden during review")
	view.action_delay = 0.0
	press_command(view, "Execute round")
	check(not view._panel_targets[view.portrait.name], "Portrait should stay hidden during resolution")
	while view.session.phase == BattleSession.Phase.RESOLVING:
		await process_frame
	check(view.session.round_number == 2 and view._panel_targets[view.portrait.name], "Scene should return to portrait action selection after the round")
	check(view.party_buttons[1].get_node("HP").value == view.session.party[1].current_hp, "HP bars should refresh after round damage")
	check(view.party_buttons[1].get_node("SP").value == 31, "SP bars should refresh after spending ability points")
	view.session.party[1].current_mp = 0
	view._refresh()
	check(view.party_buttons[1].get_node("SP").value == 0, "SP bars should display a depleted pool")
	view.queue_free()
	await process_frame
	# Fill every spot and verify the last enemy is reachable and all four characters plan.
	var full_encounter := BattleEncounter.new()
	for index in range(6):
		full_encounter.enemies.append(SENTINEL)
	view = load("res://scenes/battle/combat.tscn").instantiate() as CombatScreen
	root.add_child(view)
	check(view.configure([CharacterState.new(FRONTLINER), CharacterState.new(CASTER), CharacterState.new(FRONTLINER), CharacterState.new(CASTER)], full_encounter), "Combat should accept six enemies and four characters")
	for slot in view.enemy_slots:
		check(slot.visible, "All six occupied enemy slots should be visible")
	press_command(view, "Attack")
	view.enemy_slots[5].pressed.emit()
	check(view.session.planned_actions[0].target == view.session.enemies[5], "The sixth enemy should be selectable")
	for index in range(3):
		view.session.choose_wait()
	check(view.session.phase == BattleSession.Phase.READY and view.session.planned_actions.size() == 4, "All four party characters must plan before execution")
	resolve_round(view.session)
	check(view.session.enemies[5].current_hp < view.session.enemies[0].current_hp, "The sixth enemy should receive its queued attack")
	view.queue_free()
	await process_frame
	# Map → combat → victory → same map, then defeat → originating town.
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	# Keep the two-member defeat fixture: this encounter has two enemy actions.
	var fixture_characters: Array[CharacterDefinition] = [FRONTLINER, CASTER]
	game.starting_characters = fixture_characters
	game.new_game()
	game.explore()
	await create_timer(0.3).timeout
	var original_map: Map = game.world
	var original_position: Vector3 = game.player.position
	game.start_combat(false)
	view = game.ui.get_child(0) as CombatScreen
	check(game.screen == "combat" and not game.world.visible and not game.player.movement_enabled, "Entering battle should hide and deactivate the map")
	for opponent in view.session.enemies:
		opponent.current_hp = 1
	for ally in view.session.party:
		ally.apply_status(FORTIFY.status_effect)
	while view.session.phase != BattleSession.Phase.READY:
		attack(view.session, view.session.enemies[0])
	resolve_round(view.session)
	check(view.session.victory, "Defeating all enemies should end battle in victory")
	check(view.session.party[0].get_active_statuses().is_empty(), "Combat statuses should clear after battle")
	await create_timer(2.1).timeout
	check(game.screen == "explore" and game.world == original_map and game.player.position.is_equal_approx(original_position), "Victory should return to the existing map and player position")
	check(game.world.visible and game.player.movement_enabled, "Returning from battle should restore map controls")
	if DisplayServer.get_name() != "headless":
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Victory should recapture the first-person mouse")
	for ally in game.party:
		ally.current_hp = 1
	game.start_combat(false)
	view = game.ui.get_child(0) as CombatScreen
	while view.session.phase != BattleSession.Phase.READY:
		view.session.choose_wait()
	resolve_round(view.session)
	check(view.session.phase == BattleSession.Phase.FINISHED and not view.session.victory, "Defeated party should end combat")
	await create_timer(2.1).timeout
	check(game.screen == "town" and game.world == null, "Defeat should return to the originating town")
	await process_frame
	# Guard protects even against faster enemies, expires, and does not spend MP.
	var defender := fighter("Defender", 200, 10, 1)
	var aggressor := fighter("Aggressor", 200, 20, 30)
	var guard_session := BattleSession.new([defender], [aggressor])
	var normal_damage := RPGCombat.calculate_amount(aggressor, defender, RPGCombat.BASIC_ATTACK)
	var guard_hp := defender.current_hp
	var guard_mp := defender.current_mp
	check(guard_session.choose_defend(), "Defend should commit without selecting a target")
	check(guard_session.begin_resolution() and defender.defending, "Guard starts before initiative resolves")
	guard_session.resolve_next_action()
	check(guard_hp - defender.current_hp == int(ceil(normal_damage * 0.5)), "Defend halves faster enemy damage")
	while guard_session.phase == BattleSession.Phase.RESOLVING:
		guard_session.resolve_next_action()
	check(not defender.defending and defender.current_mp == guard_mp, "Guard expires next round without spending MP")
	check(guard_session.choose_run(), "Run should commit without a target")
	resolve_round(guard_session)
	check(guard_session.escaped and not guard_session.victory and guard_session.phase == BattleSession.Phase.FINISHED, "Run ends combat without victory")
	# Retreat returns to the same map and preserves resources.
	game.new_game()
	game.explore()
	var retreat_map: Node = game.world
	game.start_combat(false)
	view = game.ui.get_child(0) as CombatScreen
	var retreat_hp: int = game.party[0].current_hp
	var consumable_placeholder: Button
	for command in view.actions.get_children():
		if command is Button and command.text == "Consumable":
			consumable_placeholder = command
	check(consumable_placeholder != null and consumable_placeholder.disabled, "Characters without consumables show a disabled placeholder")
	view.session.choose_wait()
	var return_index := -1
	var run_index := -1
	for command in view.actions.get_children():
		if command is Button and command.text == "Return to Test Frontliner":
			return_index = command.get_index()
		if command is Button and command.text == "Run":
			run_index = command.get_index()
	check(return_index >= 0 and return_index + 1 == run_index, "Named previous-character command sits immediately above Run")
	press_command(view, "Return to Test Frontliner")
	check(view.session.active_character() == game.party[0] and view.session.planned_actions.is_empty(), "Return reopens the previous character choice")

	press_command(view, "Special")
	check(view._special_open and view._panel_targets[view.portrait.name], "Special expands skills while retaining the portrait")
	view.back.pressed.emit()
	check(not view._special_open, "Back closes Special before editing choices")
	press_command(view, "Run")
	while view.session.phase != BattleSession.Phase.READY:
		view.session.choose_defend()
	resolve_round(view.session)
	check(view.session.escaped, "Queued party Run should escape")
	var escaped_hp: int = game.party[0].current_hp
	await create_timer(2.1).timeout
	check(game.screen == "explore" and game.world == retreat_map and game.party[0].current_hp == escaped_hp and escaped_hp <= retreat_hp, "Retreat restores map without healing the party")
	print("Battle tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
