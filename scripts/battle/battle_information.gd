extends PanelContainer

signal closed
signal dismissed

@export_range(0.0, 1.0, 0.05) var slide_duration := 0.25
var is_open := false
var _slide_progress := 0.0
var _slide_tween: Tween

var damage_types: Array[DamageType] = [
	preload("res://resources/rpg/damage_types/slash.tres"),
	preload("res://resources/rpg/damage_types/pierce.tres"),
	preload("res://resources/rpg/damage_types/blunt.tres"),
	preload("res://resources/rpg/damage_types/fire.tres"),
	preload("res://resources/rpg/damage_types/frost.tres"),
	preload("res://resources/rpg/damage_types/lightning.tres"),
	preload("res://resources/rpg/damage_types/poison.tres"),
	preload("res://resources/rpg/damage_types/arcane.tres"),
]
var session: BattleSession
var showing_enemies := false
var _selected := [0, 0]
@onready var members: ItemList = $Layout/Content/Members
@onready var details: RichTextLabel = $Layout/Content/Details
@onready var enemy_tab: Button = $Layout/Tabs/Enemies


func _ready() -> void:
	_set_slide_progress(0.0)
	enemy_tab.pressed.connect(func(): show_side(not showing_enemies))
	members.item_selected.connect(_select_member)
	$Layout/Close.pressed.connect(func(): closed.emit())


func open(battle: BattleSession) -> void:
	if session != battle:
		_selected = [0, 0]
		showing_enemies = false
	session = battle
	show()
	show_side(showing_enemies)
	is_open = true
	_slide_to(1.0)
	enemy_tab.grab_focus()


func close() -> void:
	is_open = false
	_slide_to(0.0)


func close_immediately() -> void:
	if _slide_tween != null:
		_slide_tween.kill()
	is_open = false
	_set_slide_progress(0.0)
	hide()


func _slide_to(destination: float) -> void:
	if _slide_tween != null:
		_slide_tween.kill()
	if slide_duration <= 0.0:
		_set_slide_progress(destination)
		_complete_slide()
		return
	_slide_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_method(_set_slide_progress, _slide_progress, destination, slide_duration)
	_slide_tween.tween_callback(_complete_slide)


func _set_slide_progress(progress: float) -> void:
	_slide_progress = progress
	anchor_top = -1.02 * (1.0 - progress)
	anchor_bottom = anchor_top + 1.0


func _complete_slide() -> void:
	if not is_open:
		hide()
		dismissed.emit()


func show_side(enemies: bool) -> void:
	showing_enemies = enemies
	enemy_tab.text = "Friendlies" if enemies else "Hostiles"
	members.clear()
	var units: Array[CharacterState] = session.enemies if enemies else session.party
	for index in range(units.size()):
		var unit := units[index]
		var label := unit.definition.display_name
		if enemies:
			label += " %d" % (index + 1)
		if not unit.is_alive():
			label += " (defeated)"
		members.add_item(label)
	var selected: int = clampi(_selected[int(enemies)], 0, units.size() - 1)
	members.select(selected)
	_select_member(selected)


func _select_member(index: int) -> void:
	_selected[int(showing_enemies)] = index
	var units: Array[CharacterState] = session.enemies if showing_enemies else session.party
	details.text = CharacterInformation.describe(units[index], damage_types, false)
	details.scroll_to_line(0)
