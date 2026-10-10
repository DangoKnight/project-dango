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
	$Panel/Layout/Title.text = "%s · Level %d → %d" % [character.display_name, report.from_level, report.to_level]
	$Panel/Layout/Content/Portrait.texture = character.portrait if character.portrait != null else PortraitPresentation.FALLBACK
	var lines := PackedStringArray(["STAT CHANGES", ""])
	for stat in RPGStats.NAMES:
		var before: int = report.before[stat]
		var after: int = report.after[stat]
		var label := "Max SP" if stat == &"max_mp" else "Max HP" if stat == &"max_hp" else RPGStats.display_name(stat)
		lines.append("%s: %d → %d (%+d)" % [label, before, after, after - before])
	lines.append("\nABILITIES LEARNED")
	if report.learned.is_empty():
		lines.append("None")
	for ability in report.learned:
		lines.append(ability.display_name)
	$Panel/Layout/Content/Details.text = "\n".join(lines)
	$Panel/Layout/Content/Details.scroll_to_line(0)
	$Panel/Layout/Continue.text = "Return to Barracks" if index == reports.size() - 1 else "Continue"
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
