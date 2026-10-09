class_name CombatScreen
extends Control

signal finished(victory: bool)

const FALLBACK_PORTRAIT := preload("res://textures/portrait.png")
const FALLBACK_ENEMY := preload("res://textures/enemy.png")
@export var default_encounter: BattleEncounter
@export_range(0.0, 3.0, 0.05) var action_delay: float = 0.65
@export_range(0.0, 1.0, 0.05) var menu_slide_duration := 0.25
var _panel_homes: Dictionary = {}
var _panel_progress: Dictionary = {}
var _panel_targets: Dictionary = {}
var _panel_tweens: Dictionary = {}
@onready var action_panel: PanelContainer = $ActionPanel
@onready var round_counter: Label = $RoundCounter
@onready var party_cards: HBoxContainer = $Party
@onready var confirmation: PanelContainer = $Confirmation
var session: BattleSession
var enemy_slots: Array[Button] = []
var party_buttons: Array[Button] = []
var _special_open := false
var _menu_actor: CharacterState
var _ending := false
var _exiting := false
@onready var enemy_stage: Control = $EnemySpots
@onready var battle_log: PanelContainer = $BattleLog
var _messages := PackedStringArray()

@onready var actions: GridContainer = $ActionPanel/Layout/Commands/ActionScroll/Actions
@onready var prompt: Label = $ActionPanel/Layout/Commands/Prompt
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
	_portrait_base_anchors = Vector4(portrait_image.anchor_left, portrait_image.anchor_top, portrait_image.anchor_right, portrait_image.anchor_bottom)
	_portrait_default_stretch = portrait_image.stretch_mode
	portrait_image.resized.connect(_update_portrait_pivot)
	_update_portrait_pivot()
	for marker in $EnemySpots.get_children():
		enemy_slots.append(marker.get_node("EnemySlot") as Button)
	for card in $Party.get_children():
		party_buttons.append(card as Button)
		card.disabled = true
		card.get_node("Name").text = "Empty"
		for stat in ["HP", "SP"]:
			card.get_node(stat).max_value = 1
			card.get_node(stat).value = 0
			card.get_node(stat + "/Value").text = stat + " —"
	for panel in [action_panel, confirmation, portrait, round_counter, party_cards, battle_log, enemy_stage]:
		_panel_homes[panel.name] = Vector4(panel.anchor_left, panel.anchor_top, panel.anchor_right, panel.anchor_bottom)
		_panel_targets[panel.name] = panel == enemy_stage
		_set_panel_progress(1.0 if panel == enemy_stage else 0.0, panel)
	$Confirmation/Layout/Execute.pressed.connect(_execute_round)
	$Confirmation/Layout/Return.pressed.connect(_back)
	back.pressed.connect(_back)
	information.closed.connect(_close_information)
	information.dismissed.connect(_restore_information_focus)
	information.visibility_changed.connect(func(): $InformationBlocker.visible = information.visible)
	# F6 preview uses separate runtime instances; gameplay supplies the current party.
	if get_tree().current_scene == self:
		var preview_party: Array[CharacterState] = [
			CharacterState.new(load("res://resources/rpg/characters/usami.tres")),
			CharacterState.new(load("res://resources/rpg/characters/takane.tres")),
			CharacterState.new(load("res://resources/rpg/characters/kurako.tres")),
			CharacterState.new(load("res://resources/rpg/characters/koumi.tres")),
		]
		configure(preview_party, default_encounter)


func configure(party: Array[CharacterState], encounter: BattleEncounter) -> bool:
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
	session = BattleSession.new(party, enemies)
	session.changed.connect(_refresh)
	session.action_resolved.connect(_log)
	for index in range(enemy_slots.size()):
		var slot := enemy_slots[index]
		slot.visible = index < enemies.size()
		if slot.visible:
			var enemy := enemies[index]
			slot.get_node("Image").texture = enemy.definition.combat_texture if enemy.definition.combat_texture != null else FALLBACK_ENEMY
			slot.pressed.connect(_select_target.bind(enemy))
	for index in range(party.size()):
		party_buttons[index].pressed.connect(_select_target.bind(party[index]))
	_refresh()
	return true


func _refresh() -> void:
	if session == null:
		return
	round_counter.text = "Round %d" % session.round_number
	if session.phase == BattleSession.Phase.ACTION_SELECTION:
		var actor := session.active_character()
		_present_portrait(actor.definition)
	var targets := session.valid_targets()
	for index in range(session.enemies.size()):
		var enemy := session.enemies[index]
		var slot := enemy_slots[index]
		slot.get_node("Name").text = "%s %d%s" % [enemy.definition.display_name, index + 1, "" if enemy.is_alive() else " (defeated)"]
		slot.tooltip_text = slot.get_node("Name").text
		slot.get_node("HP").text = "HP %d/%d" % [enemy.current_hp, enemy.get_stat(&"max_hp")]
		slot.disabled = enemy not in targets
		slot.modulate = Color.WHITE if enemy.is_alive() else Color(0.4, 0.4, 0.4)
	for index in range(session.party.size()):
		var character := session.party[index]
		var card := party_buttons[index]
		card.get_node("Name").text = character.definition.display_name
		card.get_node("HP").max_value = character.get_stat(&"max_hp")
		card.get_node("HP").value = character.current_hp
		card.get_node("HP/Value").text = "HP  %d / %d" % [character.current_hp, character.get_stat(&"max_hp")]
		# SP is the combat UI name for the existing MP pool.
		card.get_node("SP").max_value = maxi(1, character.get_stat(&"max_mp"))
		card.get_node("SP").value = character.current_mp
		card.get_node("SP/Value").text = "SP  %d / %d" % [character.current_mp, character.get_stat(&"max_mp")]
		card.disabled = character not in targets
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	actions.columns = 1
	if session.active_character() != _menu_actor:
		_special_open = false
		_menu_actor = session.active_character()
	back.visible = session.phase == BattleSession.Phase.ACTION_SELECTION and _special_open
	back.disabled = session.phase == BattleSession.Phase.ACTION_SELECTION and session.planned_actions.is_empty() and not _special_open
	var previous_name := session.planned_actions[-1].actor.definition.display_name if not session.planned_actions.is_empty() else ""
	back.text = "Back to actions" if session.phase == BattleSession.Phase.TARGET_SELECTION or _special_open else "Return to " + previous_name
	match session.phase:
		BattleSession.Phase.ACTION_SELECTION:
			var actor := session.active_character()
			prompt.text = actor.definition.display_name + " — choose an action"
			if _special_open:
				prompt.text = actor.definition.display_name + " — Special"
				for ability in actor.get_abilities():
					var button := _command("%s (%d SP)" % [ability.display_name, ability.mana_cost], session.choose_ability.bind(ability))
					button.disabled = not actor.can_act() or actor.current_mp < ability.mana_cost
					button.tooltip_text = ability.description
					if actions.get_child_count() == 1:
						button.grab_focus()
				if actor.get_abilities().is_empty():
					_command("No abilities available", func(): pass).disabled = true
			else:
				var attack := _command("Attack", session.choose_attack)
				attack.disabled = not actor.can_act()
				attack.grab_focus()
				_command("Defend", session.choose_defend).disabled = not actor.can_act()
				_command("Special", _open_special).disabled = not actor.can_act()
				var has_consumable := false
				for item in actor.get_equipped_gear():
					if item.definition.kind == GearDefinition.Kind.CONSUMABLE and not item.is_destroyed():
						has_consumable = true
						var button := _command(item.definition.display_name, session.choose_consumable.bind(item))
						button.tooltip_text = "%s (%d uses)" % [item.definition.description, item.remaining_uses()]
						button.disabled = not actor.can_act()
				if not has_consumable:
					_command("Consumable", func(): pass).disabled = true
				if not previous_name.is_empty():
					_command("Return to " + previous_name, _back)
				_command("Run", session.choose_run).disabled = not actor.can_act()
				if not actor.can_act():
					prompt.text = actor.definition.display_name + " — paralyzed (choose Wait)"
					_command("Wait", session.choose_wait)

		BattleSession.Phase.TARGET_SELECTION:
			var item := session.selected_consumable()
			prompt.text = "Choose a target for " + (item.definition.display_name if item != null else session.selected_ability().display_name)
			if item == null and session.selected_ability().targeting in [AbilityDefinition.Target.PARTY, AbilityDefinition.Target.ENEMIES]:
				prompt.text += " (affects the whole group)"
			if item != null and item.definition.consumable_target in [GearDefinition.Target.PARTY, GearDefinition.Target.ENEMIES]:
				prompt.text += " (affects the whole group)"
			for index in range(session.enemies.size()):
				if session.enemies[index] in targets:
					enemy_slots[index].grab_focus()
					break
			for index in range(session.party.size()):
				if session.party[index] in targets:
					party_buttons[index].grab_focus()
					break
		BattleSession.Phase.READY:
			prompt.text = "All actions chosen"
			$Confirmation/Layout/Return.text = "Return to " + previous_name
			$Confirmation/Layout/Execute.grab_focus()
		BattleSession.Phase.RESOLVING:
			prompt.text = "Actions are resolving…"
		BattleSession.Phase.FINISHED:
			if not _ending:
				_ending = true
				call_deferred("_finish_battle")

	$TargetHint.visible = not intro_playing and session.phase == BattleSession.Phase.TARGET_SELECTION
	$TargetHint.text = prompt.text + " · Right-click or Esc to cancel"
	_slide_panel(action_panel, not intro_playing and session.phase == BattleSession.Phase.ACTION_SELECTION)
	_slide_panel(confirmation, not intro_playing and session.phase == BattleSession.Phase.READY)
	_slide_panel(portrait, not intro_playing and not _portrait_swapping and session.phase == BattleSession.Phase.ACTION_SELECTION)
	_slide_panel(battle_log, not intro_playing and not _exiting and session.phase in [BattleSession.Phase.RESOLVING, BattleSession.Phase.FINISHED])
	_slide_panel(round_counter, not intro_playing and session.phase not in [BattleSession.Phase.RESOLVING, BattleSession.Phase.FINISHED])
	_slide_panel(party_cards, not intro_playing and not _exiting)
	_slide_panel(enemy_stage, not _exiting)


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
	if not shown or intro_playing or information.visible or panel not in [action_panel, confirmation]:
		return
	if panel == confirmation:
		$Confirmation/Layout/Execute.grab_focus()
	else:
		for command in actions.get_children():
			if command is Button and not command.disabled:
				command.grab_focus()
				break


func _set_panel_progress(progress: float, panel: Control) -> void:
	_panel_progress[panel.name] = progress
	var home: Vector4 = _panel_homes[panel.name]
	var shift := Vector2(0.0, 1.05 - home.y)
	if panel == action_panel:
		shift = Vector2(-(home.z + 0.02), 0.0)
	elif panel in [round_counter, battle_log]:
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
	panel.visible = progress > 0.0 and (not intro_playing or panel == enemy_stage)


## The battlefield remains visible while the presentation and input are suspended.
func set_intro_playing(playing: bool) -> void:
	intro_playing = playing
	_portrait_swapping = false
	for panel in [action_panel, confirmation, portrait, round_counter, party_cards, battle_log]:
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


func _command(title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.clip_text = true
	button.tooltip_text = title
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 32
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	actions.add_child(button)
	return button


func _select_target(character: CharacterState) -> void:
	session.select_target(character)


func _open_special() -> void:
	_special_open = true
	_refresh()


func _back() -> void:
	if session.phase == BattleSession.Phase.ACTION_SELECTION and _special_open:
		_special_open = false
		_refresh()
	elif session.phase == BattleSession.Phase.TARGET_SELECTION:
		session.cancel_target()
	else:
		session.undo_choice()


func _execute_round() -> void:
	if not session.begin_resolution():
		return
	_messages.clear()
	$BattleLog/Log.text = ""
	while session.phase == BattleSession.Phase.RESOLVING:
		while information.visible:
			await get_tree().process_frame
			if not is_inside_tree():
				return
		session.resolve_next_action()
		if session.phase == BattleSession.Phase.RESOLVING:
			await get_tree().create_timer(action_delay).timeout
			if not is_inside_tree():
				return


func _finish_battle() -> void:
	information.close_immediately()
	_log("Escaped!" if session.escaped else "Victory!" if session.victory else "Defeat.")
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	_exiting = true
	_refresh()
	await get_tree().create_timer(maxf(menu_slide_duration, 0.001)).timeout
	if is_inside_tree():
		finished.emit(session.victory or session.escaped)


func _log(message: String) -> void:
	_messages.append(message.replace("\n", " "))
	if _messages.size() > 2:
		_messages.remove_at(0)
	$BattleLog/Log.text = "\n".join(_messages)
	$BattleLog/Log.tooltip_text = $BattleLog/Log.text


func _input(event: InputEvent) -> void:
	if intro_playing or _ending or session == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not information.visible and session.phase == BattleSession.Phase.TARGET_SELECTION:
		session.cancel_target()
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
	if is_instance_valid(_information_focus) and _information_focus.is_visible_in_tree():
		_information_focus.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if intro_playing or _ending or information.visible:
		return
	if session != null and event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
