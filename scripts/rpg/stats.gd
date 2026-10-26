class_name RPGStats
extends Resource

const NAMES: Array[StringName] = [&"max_hp", &"max_mp", &"strength", &"defense", &"mental_acuity", &"mental_resilience", &"speed"]

const COMBAT_NAMES: Array[StringName] = [&"critical_rate", &"critical_damage", &"accuracy", &"evasion", &"aggro"]
const ALL_NAMES: Array[StringName] = [&"max_hp", &"max_mp", &"strength", &"defense", &"mental_acuity", &"mental_resilience", &"speed", &"critical_rate", &"critical_damage", &"accuracy", &"evasion", &"aggro"]

@export_range(0, 9999, 0.1) var max_hp: float = 0
@export_range(0, 9999, 0.1) var max_mp: float = 0
@export_range(0, 9999, 0.1) var strength: float = 0
@export_range(0, 9999, 0.1) var defense: float = 0
@export_range(0, 9999, 0.1) var mental_acuity: float = 0
@export_range(0, 9999, 0.1) var mental_resilience: float = 0
@export_range(0, 9999, 0.1) var speed: float = 0


func value(stat: StringName) -> float:
	return float(get(stat)) if stat in NAMES else 0.0


## Shared labels for stat keys used by resources and gameplay.
static func display_name(stat: StringName) -> String:
	match stat:
		&"mental_acuity": return L10n.text("ui.mental_acuity")
		&"mental_resilience": return L10n.text("ui.mental_resilience")
		&"max_hp": return L10n.text("ui.max_hp")
		&"max_mp": return L10n.text("ui.max_mp")
		&"strength": return L10n.text("ui.strength")
		&"defense": return L10n.text("ui.defense")
		&"speed": return L10n.text("ui.speed")
	return L10n.text(String(stat).capitalize())
