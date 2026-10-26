extends Control

signal dismissed

var reports: Array[Dictionary] = []
var index := 0


func _ready() -> void:
	$Panel/Layout/Continue.pressed.connect(_advance)


func configure(level_reports: Array[Dictionary]) -> void:
	reports = level_reports
	index = 0
	_present()


func _present() -> void:
	var report := reports[index]
	var character: CharacterDefinition = report.definition
	$Panel/Layout/Title.text = L10n.text("ui.level_up.character_levels") % [L10n.text(character.display_name), report.from_level, report.to_level]
	$Panel/Layout/Content/Portrait.texture = character.portrait if character.portrait != null else PortraitPresentation.FALLBACK
	var lines := PackedStringArray([L10n.text("ui.stat_changes"), ""])
	for stat in RPGStats.NAMES:
		var before: int = report.before[stat]
		var after: int = report.after[stat]
		var label := L10n.text("ui.max_sp") if stat == &"max_mp" else L10n.text("ui.max_hp_2") if stat == &"max_hp" else RPGStats.display_name(stat)
		lines.append(L10n.text("ui.level_up.stat_change") % [label, before, after, after - before])
	lines.append(L10n.text("ui.abilities_learned"))
	if report.learned.is_empty():
		lines.append(L10n.text("ui.none"))
	for ability in report.learned:
		lines.append(L10n.text(ability.display_name))
	$Panel/Layout/Content/Details.text = "\n".join(lines)
	$Panel/Layout/Content/Details.scroll_to_line(0)
	$Panel/Layout/Continue.text = L10n.text("ui.return_to_barracks") if index == reports.size() - 1 else L10n.text("ui.continue")
	$Panel/Layout/Continue.grab_focus()


func _advance() -> void:
	if index >= reports.size():
		return
	index += 1
	if index < reports.size():
		_present()
	else:
		dismissed.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_advance()
