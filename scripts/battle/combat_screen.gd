class_name CombatScreen
extends Control

signal finished(victory: bool)

const FALLBACK_PORTRAIT := preload("res://textures/UI/portrait.png")
const FALLBACK_ENEMY := preload("res://textures/NPCs/Enemies/rat.png")
@export var default_encounter: BattleEncounter
@export_range(0.0, 3.0, 0.05) var action_delay: float = 0.65
@export_range(0.0, 3.0, 0.05) var attack_animation_duration: float = 0.7
var effects: BattleEffects
@export_range(0.0, 1.0, 0.05) var menu_slide_duration := 0.25
var _panel_homes: Dictionary = {}
var _panel_progress: Dictionary = {}
var _panel_targets: Dictionary = {}
var _hovered_target: CharacterState
var _panel_tweens: Dictionary = {}
@onready var action_panel: PanelContainer = $ActionPanel
@onready var special_panel: PanelContainer = $SpecialDrawer/SpecialPanel
@onready var special_actions: GridContainer = $SpecialDrawer/SpecialPanel/Layout/Scroll/Abilities
@onready var round_counter: Label = $RoundCounter
@onready var party_cards: HBoxContainer = $Party
@onready var confirmation: PanelContainer = $Confirmation
var session: BattleSession
var enemy_slots: Array[Button] = []
var party_buttons: Array[Button] = []
var _special_open := false
var _waiting_for_drawer := false
var _menu_actor: CharacterState
var _ending := false
var _exiting := false
var _performing_round := false
var _ui_hidden := false
var _ui_hidden_focus: Control
@onready var enemy_stage: Control = $EnemySpots
@onready var battle_log: PanelContainer = $BattleLog
var _messages := PackedStringArray()

@onready var actions: GridContainer = $ActionPanel/Layout/Commands/ActionScroll/Actions
@onready var back: Button = $ActionPanel/Layout/Commands/Back
@onready var portrait: Control = $PortraitOverlay
@onready var portrait_image: TextureRect = $PortraitOverlay/Layout/Portrait
var _portrait_definition: CharacterDefinition
var _portrait_requested: CharacterDefinition
var _portrait_swapping := false
var _portrait_base_anchors: Vector4
var _portrait_default_stretch: int
var intro_playing := false
var _information_focus: Control
@onready var information: PanelContainer = $BattleInformation


func _ready() -> void:
	effects = BattleEffects.new()
	effects.name = "BattleEffects"
	add_child(effects)
	move_child(effects, party_cards.get_index() + 1)
	_portrait_base_anchors = Vector4(portrait_image.anchor_left, portrait_image.anchor_top, portrait_image.anchor_right, portrait_image.anchor_bottom)
	_portrait_default_stretch = portrait_image.stretch_mode
	portrait_image.resized.connect(_update_portrait_pivot)
	_update_portrait_pivot()
	resized.connect(_queue_drawer_alignment)
	actions.resized.connect(_queue_drawer_alignment)
	$ActionPanel/Layout/Commands/ActionScroll.item_rect_changed.connect(_queue_drawer_alignment)
	for marker in $EnemySpots.get_children():
		enemy_slots.append(marker.get_node("EnemySlot") as Button)
	for card in $Party.get_children():
		party_buttons.append(card as Button)
		card.disabled = true
		card.get_node("Name").text = "ui.empty"
		for stat in ["HP", "SP"]:
			card.get_node(stat).max_value = 1
			card.get_node(stat).value = 0
			card.get_node(stat + "/Value").text = stat + " —"
	for panel in [action_panel, special_panel, confirmation, portrait, round_counter, party_cards, battle_log, enemy_stage]:
		_panel_homes[panel.name] = Vector4(panel.anchor_left, panel.anchor_top, panel.anchor_right, panel.anchor_bottom)
		_panel_targets[panel.name] = panel == enemy_stage
		_set_panel_progress(1.0 if panel == enemy_stage else 0.0, panel)
	for button in [$Confirmation/Layout/Execute, $Confirmation/Layout/Return]:
		_style_command(button)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	resized.connect(func(): _layout_confirmation.call_deferred())
	confirmation.minimum_size_changed.connect(func(): _layout_confirmation.call_deferred())
	_layout_confirmation.call_deferred()
	$Confirmation/Layout/Execute.pressed.connect(_execute_round)
	$Confirmation/Layout/Return.pressed.connect(_back)
	back.pressed.connect(_back)
	information.closed.connect(_close_information)
	information.dismissed.connect(_restore_information_focus)
	information.visibility_changed.connect(func():
		$InformationBlocker.visible = information.visible and not _ui_hidden
		effects.suspended = information.visible
		_refresh_target_highlights())
	# F6 preview uses separate runtime instances; gameplay supplies the current party.
	if get_tree().current_scene == self:
		var preview_party: Array[CharacterState] = [
			CharacterState.new(load("res://resources/rpg/characters/usami.tres")),
			CharacterState.new(load("res://resources/rpg/characters/takane.tres")),
			CharacterState.new(load("res://resources/rpg/characters/kurako.tres")),
			CharacterState.new(load("res://resources/rpg/characters/koumi.tres")),
		]
		configure(preview_party, default_encounter)


func configure(party: Array[CharacterState], encounter: BattleEncounter, compendium: MonsterCompendium = null) -> bool:
	if encounter == null or encounter.enemies.is_empty() or encounter.enemies.size() > enemy_slots.size() or party.is_empty() or party.size() > party_buttons.size():
		push_error("Combat needs 1–%d characters and 1–%d enemies." % [party_buttons.size(), enemy_slots.size()])
		return false
	for character in party:
		if character == null:
			push_error("Party contains a missing character state.")
			return false
	for definition in encounter.enemies:
		if definition == null:
			push_error("Encounter contains a missing enemy definition.")
			return false
	var enemies: Array[CharacterState] = []
	for definition in encounter.enemies:
		enemies.append(CharacterState.new(definition, null, encounter.enemy_level))
	session = BattleSession.new(party, enemies, compendium)
	session.changed.connect(_refresh)
	session.action_resolved.connect(_log)
	session.action_performed.connect(_animate_action)
	for index in range(enemy_slots.size()):
		var slot := enemy_slots[index]
		slot.visible = index < enemies.size()
		if slot.visible:
			var enemy := enemies[index]
			slot.get_node("Image").texture = enemy.definition.combat_texture if enemy.definition.combat_texture != null else FALLBACK_ENEMY
			slot.pressed.connect(_select_target.bind(enemy))
			slot.mouse_entered.connect(_hover_target.bind(enemy))
			slot.mouse_exited.connect(_unhover_target.bind(enemy))
	for index in range(party.size()):
		party_buttons[index].pressed.connect(_select_target.bind(party[index]))
		party_buttons[index].mouse_entered.connect(_hover_target.bind(party[index]))
		party_buttons[index].mouse_exited.connect(_unhover_target.bind(party[index]))
	_refresh()
	return true


func _refresh() -> void:
	if session == null:
		return
	var presenting_actions := _performing_round
	if session.phase != BattleSession.Phase.TARGET_SELECTION:
		_waiting_for_drawer = false
	_refresh_target_highlights()
	round_counter.text = L10n.text("ui.battle.round_counter") % session.round_number
	if session.phase == BattleSession.Phase.ACTION_SELECTION:
		var actor := session.active_character()
		_present_portrait(actor.definition)
	var targets := session.valid_targets()
	if _waiting_for_drawer:
		targets = []
	for index in range(session.enemies.size()):
		var enemy := session.enemies[index]
		var slot := enemy_slots[index]
		slot.get_node("HP").max_value = 1.0
		slot.get_node("HP").value = float(enemy.current_hp) / enemy.get_stat(&"max_hp")
		slot.present(enemy.is_alive(), enemy in targets)
	for index in range(session.party.size()):
		var character := session.party[index]
		var card := party_buttons[index]
		card.get_node("Name").text = L10n.text(character.definition.display_name)
		card.get_node("HP").max_value = character.get_stat(&"max_hp")
		card.get_node("HP").value = character.current_hp
		card.get_node("HP/Value").text = L10n.text("ui.hp_d_d") % [character.current_hp, character.get_stat(&"max_hp")]
		# SP is the combat UI name for the existing MP pool.
		card.get_node("SP").max_value = maxi(1, character.get_stat(&"max_mp"))
		card.get_node("SP").value = character.current_mp
		card.get_node("SP/Value").text = L10n.text("ui.sp_d_d") % [character.current_mp, character.get_stat(&"max_mp")]
		card.disabled = character not in targets
	if session.phase == BattleSession.Phase.TARGET_SELECTION:
		for child in actions.get_children():
			child.disabled = true
	else:
		for child in actions.get_children():
			actions.remove_child(child)
			child.queue_free()
	actions.columns = 1
	if session.active_character() != _menu_actor:
		_special_open = false
		_menu_actor = session.active_character()
	if session.phase != BattleSession.Phase.ACTION_SELECTION:
		_special_open = false
	back.visible = false
	var previous_name := L10n.text(session.planned_actions[-1].actor.definition.display_name) if not session.planned_actions.is_empty() else ""
	match session.phase:
		BattleSession.Phase.ACTION_SELECTION:
			var actor := session.active_character()
			var attack := _command("ui.attack", session.choose_attack)
			attack.disabled = not actor.can_act()
			if not _ui_hidden:
				attack.grab_focus()
			_command("ui.defend", session.choose_defend).disabled = not actor.can_act()
			_command("ui.character.abilities", _open_special).disabled = not actor.can_act()
			var has_consumable := false
			for item in actor.get_equipped_gear():
				if item.definition.kind == GearDefinition.Kind.CONSUMABLE and not item.is_destroyed():
					has_consumable = true
					var button := _command(L10n.text(item.definition.display_name), session.choose_consumable.bind(item))
					button.tooltip_text = L10n.text("ui.consumable.name_and_uses") % [L10n.text(item.definition.description), item.remaining_uses()]
					button.disabled = not actor.can_act()
			if not has_consumable:
				_command("ui.consumable", func(): pass).disabled = true
			var observe := _command("ui.observe", _toggle_observe)
			observe.toggle_mode = true
			observe.set_pressed_no_signal(actor.observing)
			observe.tooltip_text = L10n.text("ui.battle.observe_description")
			var previous := _command(L10n.text("ui.battle.return_to_character") % previous_name if not previous_name.is_empty() else L10n.text("ui.battle.return_previous"), _back)
			previous.disabled = previous_name.is_empty()
			_command("ui.run", session.choose_run).disabled = not actor.can_act()
			if not actor.can_act():
				_command("ui.wait", session.choose_wait)

		BattleSession.Phase.TARGET_SELECTION:
			for index in range(session.enemies.size()):
				if session.enemies[index] in targets:
					enemy_slots[index].grab_focus()
					break
			for index in range(session.party.size()):
				if session.party[index] in targets:
					party_buttons[index].grab_focus()
					break
		BattleSession.Phase.READY:
			$Confirmation/Layout/Return.text = L10n.text("ui.battle.return_to_character") % previous_name
			if not _ui_hidden:
				$Confirmation/Layout/Execute.grab_focus()
		BattleSession.Phase.RESOLVING:
			pass
		BattleSession.Phase.FINISHED:
			if not _ending:
				_ending = true
				call_deferred("_finish_battle")

	_slide_panel(special_panel, not intro_playing and not presenting_actions and _special_open)
	_slide_panel(action_panel, not intro_playing and not presenting_actions and (session.phase == BattleSession.Phase.ACTION_SELECTION or _waiting_for_drawer))
	_slide_panel(confirmation, not intro_playing and not presenting_actions and session.phase == BattleSession.Phase.READY)
	_slide_panel(portrait, not intro_playing and not presenting_actions and not _portrait_swapping and session.phase == BattleSession.Phase.ACTION_SELECTION)
	_slide_panel(battle_log, not intro_playing and not _exiting and (presenting_actions or session.phase in [BattleSession.Phase.RESOLVING, BattleSession.Phase.FINISHED]))
	_slide_panel(round_counter, not intro_playing and not presenting_actions and session.phase not in [BattleSession.Phase.RESOLVING, BattleSession.Phase.FINISHED])
	_slide_panel(party_cards, not intro_playing and not _exiting)
	_slide_panel(enemy_stage, not _exiting)
	_queue_drawer_alignment()


func _slide_panel(panel: Control, shown: bool) -> void:
	if _panel_targets[panel.name] == shown:
		return
	_panel_targets[panel.name] = shown
	var old_tween: Tween = _panel_tweens.get(panel.name)
	if old_tween != null:
		old_tween.kill()
	if shown:
		panel.show()
	var destination := 1.0 if shown else 0.0
	if menu_slide_duration <= 0.0:
		_set_panel_progress(destination, panel)
		_focus_panel(panel, shown)
		return
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_panel_tweens[panel.name] = tween
	tween.tween_method(_set_panel_progress.bind(panel), float(_panel_progress[panel.name]), destination, menu_slide_duration)
	tween.tween_callback(_focus_panel.bind(panel, shown))


func _focus_panel(panel: Control, shown: bool) -> void:
	if _ui_hidden or not shown or intro_playing or information.visible or panel not in [action_panel, special_panel, confirmation]:
		return
	if panel == confirmation:
		$Confirmation/Layout/Execute.grab_focus()
	else:
		var commands := special_actions if _special_open else actions
		for command in commands.get_children():
			if command is Button and not command.disabled:
				command.grab_focus()
				break


func _set_panel_progress(progress: float, panel: Control) -> void:
	_panel_progress[panel.name] = progress
	var home: Vector4 = _panel_homes[panel.name]
	var shift := Vector2(0.0, 1.05 - home.y)
	if panel == special_panel:
		shift = Vector2(-1.02, 0.0)
	elif panel == action_panel:
		shift = Vector2(-(home.z + 0.02), 0.0)
	elif panel in [round_counter, battle_log, enemy_stage]:
		var panel_height := maxf(home.w - home.y, panel.get_combined_minimum_size().y / maxf(size.y, 1.0))
		shift = Vector2(0.0, -(home.y + panel_height + 0.02))
	elif panel == portrait:
		# Account for artwork that extends past its parent due to character adjustments.
		var overhang := maxf(0.0, (portrait_image.scale.x - 1.0) * 0.5) + maxf(0.0, -portrait_image.anchor_left)
		shift = Vector2(1.05 - home.x + (home.z - home.x) * overhang, 0.0)
	shift *= 1.0 - progress
	panel.anchor_left = home.x + shift.x
	panel.anchor_top = home.y + shift.y
	panel.anchor_right = home.z + shift.x
	panel.anchor_bottom = home.w + shift.y
	panel.visible = progress > 0.0 and (not intro_playing or panel == enemy_stage) and (not _ui_hidden or panel == enemy_stage)


## The battlefield remains visible while the presentation and input are suspended.
func set_intro_playing(playing: bool) -> void:
	intro_playing = playing
	_waiting_for_drawer = false
	_portrait_swapping = false
	for panel in [action_panel, special_panel, confirmation, portrait, round_counter, party_cards, battle_log]:
		var tween: Tween = _panel_tweens.get(panel.name)
		if tween != null:
			tween.kill()
		_panel_targets[panel.name] = false
		_set_panel_progress(0.0, panel)
	process_mode = Node.PROCESS_MODE_DISABLED if playing else Node.PROCESS_MODE_INHERIT
	_refresh()


func _present_portrait(character: CharacterDefinition) -> void:
	_portrait_requested = character
	if _portrait_swapping or character == _portrait_definition:
		return
	if float(_panel_progress[portrait.name]) > 0.0 and menu_slide_duration > 0.0:
		_portrait_swapping = true
		_slide_panel(portrait, false)
		var tween: Tween = _panel_tweens.get(portrait.name)
		# Target selection may already have started this outgoing tween.
		# Observe completion without changing the running tween sequence.
		tween.finished.connect(_finish_portrait_swap, CONNECT_ONE_SHOT)
	else:
		_apply_portrait(character)
		_portrait_definition = character


func _finish_portrait_swap() -> void:
	_portrait_swapping = false
	if intro_playing or session.phase != BattleSession.Phase.ACTION_SELECTION:
		return
	_apply_portrait(_portrait_requested)
	_portrait_definition = _portrait_requested
	_slide_panel(portrait, true)


func _apply_portrait(character: CharacterDefinition) -> void:
	PortraitPresentation.apply(portrait_image, character, _portrait_base_anchors, _portrait_default_stretch)


func _update_portrait_pivot() -> void:
	portrait_image.pivot_offset = portrait_image.size * 0.5


func _command(title: String, callback: Callable, container: GridContainer = null) -> Button:
	var button := Button.new()
	button.text = L10n.text(title)
	_style_command(button)
	button.pressed.connect(callback)
	(container if container != null else actions).add_child(button)
	return button


func _style_command(button: Button) -> void:
	button.clip_text = true
	button.tooltip_text = L10n.text(button.text)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 32
	button.add_theme_font_size_override("font_size", 18)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("outline_size", 4)
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	var backgrounds := {
		"normal": Color(0.12, 0.14, 0.18, 0.95),
		"hover": Color(0.22, 0.27, 0.34, 0.98),
		"pressed": Color(0.14, 0.26, 0.37, 0.98),
		"hover_pressed": Color(0.20, 0.34, 0.47, 0.98),
		"disabled": Color(0.10, 0.11, 0.13, 0.80),
		"focus": Color.TRANSPARENT,
	}
	for state in backgrounds:
		var style := StyleBoxFlat.new()
		style.bg_color = backgrounds[state]
		style.set_corner_radius_all(8)
		style.set_border_width_all(1)
		style.border_color = Color(0.42, 0.49, 0.58, 0.8)
		if state == "focus":
			style.draw_center = false
			style.border_color = Color(0.78, 0.86, 0.96)
		elif state == "disabled":
			style.border_color = Color(0.25, 0.27, 0.31, 0.65)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		button.add_theme_stylebox_override(state, style)


func _hover_target(character: CharacterState) -> void:
	_hovered_target = character
	_refresh_target_highlights()


func _unhover_target(character: CharacterState) -> void:
	if _hovered_target == character:
		_hovered_target = null
	_refresh_target_highlights()


func _refresh_target_highlights() -> void:
	var affected: Array[CharacterState] = []
	if session != null and not intro_playing and not _waiting_for_drawer and not information.visible:
		affected = session.affected_targets(_hovered_target)
	for index in range(enemy_slots.size()):
		enemy_slots[index].set_group_highlight(session != null and index < session.enemies.size() and session.enemies[index] in affected)
	for index in range(party_buttons.size()):
		party_buttons[index].self_modulate = Color(1.4, 1.4, 1.1) if session != null and index < session.party.size() and session.party[index] in affected else Color.WHITE


func _select_target(character: CharacterState) -> void:
	if not _waiting_for_drawer:
		session.select_target(character)


func _toggle_observe() -> void:
	session.toggle_observe()
	for command in actions.get_children():
		if command.text == L10n.text("ui.observe"):
			command.grab_focus()
			break


func _open_special() -> void:
	if _special_open:
		_close_special()
		return
	for child in special_actions.get_children():
		special_actions.remove_child(child)
		child.queue_free()
	var actor := session.active_character()
	for ability in actor.get_abilities():
		var button := _command(L10n.text("ui.battle.ability_cost") % [L10n.text(ability.display_name), ability.mana_cost], _choose_special.bind(ability), special_actions)
		button.disabled = not actor.can_act() or actor.current_mp < ability.mana_cost
		button.tooltip_text = CharacterInformation.ability_tooltip(ability)
	if special_actions.get_child_count() == 0:
		_command(L10n.text("ui.no_abilities_available"), func(): pass, special_actions).disabled = true
	_special_open = true
	_refresh()
	$SpecialDrawer/SpecialPanel/Layout/Scroll.scroll_vertical = 0
	_focus_panel(special_panel, true)


func _close_special() -> void:
	_special_open = false
	_slide_panel(special_panel, false)
	if session.phase == BattleSession.Phase.ACTION_SELECTION:
		for command in actions.get_children():
			if command.text == L10n.text("ui.character.abilities"):
				command.grab_focus()
				break


func _choose_special(ability: AbilityDefinition) -> void:
	if not _special_open:
		return
	_waiting_for_drawer = menu_slide_duration > 0.0 and float(_panel_progress[special_panel.name]) > 0.0
	_close_special()
	if not session.choose_ability(ability):
		_waiting_for_drawer = false
		_refresh()
		return
	if _waiting_for_drawer:
		var tween: Tween = _panel_tweens[special_panel.name]
		tween.finished.connect(_finish_drawer_collapse, CONNECT_ONE_SHOT)


func _finish_drawer_collapse() -> void:
	_waiting_for_drawer = false
	_refresh()


func _back() -> void:
	if session.phase == BattleSession.Phase.ACTION_SELECTION and _special_open:
		_close_special()
	elif session.phase == BattleSession.Phase.TARGET_SELECTION:
		_waiting_for_drawer = false
		session.cancel_target()
	else:
		session.undo_choice()


func _effect_target(character: CharacterState) -> Control:
	var index := session.enemies.find(character)
	if index >= 0:
		return enemy_slots[index].get_node("Image") as Control
	index = session.party.find(character)
	return party_buttons[index] if index >= 0 else null


func _animate_action(action: BattleAction, targets: Array[CharacterState], result: Dictionary) -> void:
	if not result.get("success", false):
		return
	if action.defending:
		effects.play_effect("cover", _effect_target(action.actor), attack_animation_duration * 0.65)
		return
	var hits: Array = result.get("targets", [result])
	for index in range(targets.size()):
		if index < hits.size() and hits[index].get("missed", false):
			continue
		var target := _effect_target(targets[index])
		if action.consumable != null:
			for effect in action.consumable.definition.effects:
				var preset := "heal"
				if effect.kind == ConsumableEffect.Kind.DAMAGE:
					preset = String(effect.damage_type.id)
				elif effect.kind == ConsumableEffect.Kind.APPLY_STATUS:
					preset = "debuff" if effect.status.is_harmful() else "buff"
				effects.play_effect(preset, target, attack_animation_duration)
		else:
			var ability := RPGCombat.BASIC_ATTACK if action.basic_attack else action.ability
			if ability != null:
				effects.play_effect(BattleEffects.preset_for(ability), target, attack_animation_duration)


func _execute_round() -> void:
	if _performing_round:
		return
	_performing_round = true
	if not session.begin_resolution():
		_performing_round = false
		return
	_messages.clear()
	$BattleLog/Log.text = ""
	while session.phase == BattleSession.Phase.RESOLVING:
		while information.visible or get_tree().paused:
			await get_tree().process_frame
			if not is_inside_tree():
				return
		session.resolve_next_action()
		await effects.wait_until_finished()
		if not is_inside_tree():
			return
		if session.phase == BattleSession.Phase.RESOLVING:
			await get_tree().create_timer(action_delay, false).timeout
			if not is_inside_tree():
				return
	_performing_round = false
	_refresh()


func _finish_battle() -> void:
	await effects.wait_until_finished()
	if not is_inside_tree():
		return
	information.close_immediately()
	_log(L10n.text("ui.escaped") if session.escaped else L10n.text("ui.victory") if session.victory else L10n.text("ui.defeat"))
	await get_tree().create_timer(1.0, false).timeout
	if not is_inside_tree():
		return
	for slot in enemy_slots:
		await slot.wait_for_disappearance()
		if not is_inside_tree():
			return
	_exiting = true
	_refresh()
	await get_tree().create_timer(maxf(menu_slide_duration, 0.001), false).timeout
	if is_inside_tree():
		finished.emit(session.victory or session.escaped)


func _log(message: String) -> void:
	_messages.append(message.replace("\n", " "))
	if _messages.size() > 2:
		_messages.remove_at(0)
	$BattleLog/Log.text = "\n".join(_messages)
	$BattleLog/Log.tooltip_text = $BattleLog/Log.text


func _input(event: InputEvent) -> void:
	if session != null and event.is_action_pressed("toggle_battle_ui"):
		_toggle_ui_visibility()
		get_viewport().set_input_as_handled()
		return
	if _ui_hidden:
		get_viewport().set_input_as_handled()
		return
	if intro_playing or _ending or session == null:
		return
	if not information.visible:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if _special_open:
					_close_special()
				elif session.phase == BattleSession.Phase.TARGET_SELECTION:
					_waiting_for_drawer = false
					session.cancel_target()
				else:
					return
				get_viewport().set_input_as_handled()
				return
			var click_position: Vector2 = get_canvas_transform().affine_inverse() * event.position
			if _special_open and event.button_index == MOUSE_BUTTON_LEFT and not special_panel.get_global_rect().intersection($SpecialDrawer.get_global_rect()).has_point(click_position):
				_close_special()
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("ui_cancel") and (_special_open or session.phase == BattleSession.Phase.TARGET_SELECTION):
			_back()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("battle_information"):
		if information.is_open:
			_close_information()
		else:
			if not information.visible:
				_information_focus = get_viewport().gui_get_focus_owner()
			information.open(session)
		get_viewport().set_input_as_handled()
	elif information.visible and event.is_action_pressed("ui_cancel"):
		_close_information()
		get_viewport().set_input_as_handled()


func _close_information() -> void:
	information.close()


func _restore_information_focus() -> void:
	if not _ui_hidden and is_instance_valid(_information_focus) and _information_focus.is_visible_in_tree():
		_information_focus.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _ui_hidden or intro_playing or _ending or information.visible:
		return
	if session != null and event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()


func _queue_drawer_alignment() -> void:
	_align_special_drawer.call_deferred()


func _align_special_drawer() -> void:
	if not is_inside_tree():
		return
	var action_scroll: ScrollContainer = $ActionPanel/Layout/Commands/ActionScroll
	action_scroll.custom_minimum_size.y = minf(actions.get_combined_minimum_size().y, action_panel.size.y)
	for button in actions.get_children():
		if button.text == L10n.text("ui.character.abilities"):
			var drawer: Control = $SpecialDrawer
			var top: float = (get_global_transform().affine_inverse() * button.get_global_rect().position).y / maxf(size.y, 1.0)
			drawer.anchor_top = clampf(top, 0.1, drawer.anchor_bottom - 0.1)
			return


func _layout_confirmation() -> void:
	if not is_inside_tree() or not _panel_homes.has(confirmation.name):
		return
	var height := confirmation.get_combined_minimum_size().y
	var half := height * 0.5 / maxf(size.y, 1.0)
	var home: Vector4 = _panel_homes[confirmation.name]
	home.y = 0.5 - half
	home.w = 0.5 + half
	_panel_homes[confirmation.name] = home
	_set_panel_progress(float(_panel_progress[confirmation.name]), confirmation)


func _toggle_ui_visibility() -> void:
	_ui_hidden = not _ui_hidden
	if _ui_hidden:
		_ui_hidden_focus = get_viewport().gui_get_focus_owner()
		if is_instance_valid(_ui_hidden_focus):
			_ui_hidden_focus.release_focus()
		_hovered_target = null
		_refresh_target_highlights()
	for panel in [action_panel, special_panel, confirmation, portrait, round_counter, party_cards, battle_log]:
		_set_panel_progress(float(_panel_progress[panel.name]), panel)
	information.modulate.a = 0.0 if _ui_hidden else 1.0
	$InformationBlocker.visible = information.visible and not _ui_hidden
	if not _ui_hidden and is_instance_valid(_ui_hidden_focus) and _ui_hidden_focus.is_visible_in_tree():
		_ui_hidden_focus.grab_focus()
	elif not _ui_hidden and not information.visible:
		_focus_panel(confirmation if session.phase == BattleSession.Phase.READY else special_panel if _special_open else action_panel, true)
