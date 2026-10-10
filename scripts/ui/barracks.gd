extends "res://scripts/ui/screen.gd"

const PARTY_SLOT := preload("res://scripts/ui/party_slot.gd")
signal sleep_requested
var _busy := false
var roster: Array[CharacterState] = []
var party: Array[CharacterState] = []
var selected_member: CharacterState
@onready var party_slots: VBoxContainer = $PartyPanel/Buttons/Content/Party/Slots
@onready var reserve_slots: VBoxContainer = $PartyPanel/Buttons/Content/Reserve/Scroll/Slots
@onready var feedback: Label = $PartyPanel/Buttons/Feedback
@onready var portrait: TextureRect = $PartyPanel/Buttons/Content/Character/Portrait
@onready var stats: RichTextLabel = $PartyPanel/Buttons/Content/Character/Stats


func _ready() -> void:
	super._ready()
	for area in [$PartyPanel/Buttons/Content/Reserve/Scroll, reserve_slots]:
		area.set_drag_forwarding(
			func(_position: Vector2): return null,
			func(_position: Vector2, data: Variant): return can_drop_character(data, false, 0),
			func(_position: Vector2, data: Variant): drop_character(data, false, 0))


func configure(available: Array[CharacterState], active_party: Array[CharacterState]) -> void:
	roster = available
	party = active_party
	_refresh()


func _refresh() -> void:
	for container in [party_slots, reserve_slots]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	if selected_member not in roster:
		selected_member = party[0] if not party.is_empty() else null
	for index in range(4):
		_add_slot(party_slots, party[index] if index < party.size() else null, true, index)
	for member in roster:
		if member not in party:
			_add_slot(reserve_slots, member, false, reserve_slots.get_child_count())
	if reserve_slots.get_child_count() == 0:
		_add_slot(reserve_slots, null, false, 0)
	$PartyPanel/Buttons/Content/Party/Title.text = "Party (%d / 4)" % party.size()
	select_member(selected_member)


func _add_slot(container: VBoxContainer, member: CharacterState, active: bool, index: int) -> void:
	var button := Button.new()
	button.set_script(PARTY_SLOT)
	button.manager = self
	button.member = member
	button.party_slot = active
	button.slot_index = index
	button.text = ("%d. %s" % [index + 1, member.definition.display_name] if active else member.definition.display_name) if member != null else ("%d. Empty" % [index + 1] if active else "No reserves")
	button.tooltip_text = member.definition.title if member != null else ""
	button.clip_text = true
	button.toggle_mode = true
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(select_member.bind(member))
	container.add_child(button)


func select_member(member: CharacterState) -> void:
	if member != null and member in roster:
		selected_member = member
	for container in [party_slots, reserve_slots]:
		for button in container.get_children():
			button.set_pressed_no_signal(button.member != null and button.member == selected_member)
	if selected_member == null:
		portrait.texture = null
		stats.text = ""
		return
	var character := selected_member
	$PartyPanel/Buttons/Content/Character/Name.text = character.definition.display_name
	$PartyPanel/Buttons/Content/Character/Title.text = character.definition.title
	portrait.texture = character.definition.portrait if character.definition.portrait != null else PortraitPresentation.FALLBACK
	var class_text := character.character_class.display_name if character.character_class != null else "None"
	var lines := PackedStringArray([
		"Level %d · %s" % [character.level, class_text],
		"HP %d / %d" % [character.current_hp, character.get_stat(&"max_hp")],
		"SP %d / %d" % [character.current_mp, character.get_stat(&"max_mp")],
	])
	for stat in RPGStats.NAMES:
		if stat not in [&"max_hp", &"max_mp"]:
			lines.append("%s: %d" % [RPGStats.display_name(stat), character.get_stat(stat)])
	stats.text = "\n".join(lines)


func sleep() -> void:
	if _busy:
		return
	sleep_requested.emit()


func apply_rest() -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	for member in roster:
		member.apply_stored_experience(reports)
		member.restore()
	$Panel/Buttons/Feedback.text = "Everyone is rested. HP and SP fully restored."
	select_member(selected_member)
	return reports


func open_party() -> void:
	if _busy or $PartyPanel.visible:
		return
	_busy = true
	await slide_card_out($Panel, 1)
	_refresh()
	slide_card_in($PartyPanel, 1)
	if card_slide_duration > 0.0:
		await _card_tweens[$PartyPanel].finished
	_busy = false
	party_slots.get_child(0).grab_focus()


func close_party() -> void:
	if _busy or not $PartyPanel.visible:
		return
	_busy = true
	await slide_card_out($PartyPanel, 1)
	slide_card_in($Panel, 1)
	if card_slide_duration > 0.0:
		await _card_tweens[$Panel].finished
	_busy = false
	$Panel/Buttons/ManageParty.grab_focus()


func is_busy() -> bool:
	return _busy


func hide_cards() -> void:
	_busy = true
	await slide_card_out($PartyPanel if $PartyPanel.visible else $Panel, 1)


func can_drop_character(data: Variant, active: bool, index: int) -> bool:
	if _busy:
		return false
	if not data is Dictionary or data.get("source") != self:
		return false
	var member = data.get("character")
	if not member is CharacterState or member not in roster:
		return false
	if not active:
		return member in party and party.size() > 1
	if index < 0 or index >= 4:
		return false
	if member in party:
		return party.find(member) != mini(index, party.size() - 1)
	return index < party.size() or party.size() < 4


func drop_character(data: Variant, active: bool, index: int) -> bool:
	if not can_drop_character(data, active, index):
		return false
	var member: CharacterState = data.character
	if not active:
		party.erase(member)
		feedback.text = member.definition.display_name + " is staying in reserve."
	elif member in party:
		var source := party.find(member)
		var destination := mini(index, party.size() - 1)
		var other := party[destination]
		party[destination] = member
		party[source] = other
		feedback.text = "Party order updated."
	elif index < party.size():
		# A reserve can replace an occupied slot even when the party is full.
		party[index] = member
		feedback.text = member.definition.display_name + " joined the active party."
	else:
		party.append(member)
		feedback.text = member.definition.display_name + " joined the active party."
	selected_member = member
	_refresh()
	return true


func _on_button_pressed(action: String) -> void:
	match action:
		"Sleep": sleep()
		"ManageParty": open_party()
		"CloseParty": close_party()
		"Save": pass
		_: super._on_button_pressed(action)
