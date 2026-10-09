class_name DamageResistance
extends Resource

@export var damage_type: DamageType
## Positive values reduce damage; negative values increase it. 1 means immunity.
@export_range(-1.0, 1.0, 0.05) var amount: float = 0.0
