class_name DamageResistance
extends Resource

@export var damage_type: DamageType
## Positive values reduce damage; negative values increase it. 1 means immunity.
@export_range(-1.0, 1.0, 0.05) var amount: float = 0.0


## Player-facing affinity; neutral damage types have no label.
static func display_label(resistance: float) -> String:
	if resistance >= 1.0:
		return "ui.immune"
	if resistance >= 0.5:
		return "ui.very_resistant"
	if resistance > 0.0:
		return "ui.resistant"
	if resistance <= -0.5:
		return "ui.very_weak"
	if resistance < 0.0:
		return "ui.weak"
	return ""
