class_name FabricationRecipe
extends Resource

@export var weapon: WeaponDefinition
@export var medallion: GearDefinition
## Species IDs and base kill counts. First commissions double these counts.
@export var required_kills: Dictionary[StringName, int] = {}
@export var enemy_names: Dictionary[StringName, String] = {}


func is_valid() -> bool:
	if (weapon == null) == (medallion == null) or required_kills.is_empty():
		return false
	if weapon != null and not weapon.is_valid():
		return false
	if medallion != null and (medallion.kind != GearDefinition.Kind.MEDALLION or not medallion.is_valid()):
		return false
	for species in required_kills:
		if species.is_empty() or required_kills[species] <= 0:
			return false
	return true


func product_key() -> StringName:
	return StringName("weapon:" + String(weapon.id)) if weapon != null else StringName("medallion:" + String(medallion.id)) if medallion != null else &""


func product_name() -> String:
	return weapon.display_name if weapon != null else medallion.display_name if medallion != null else ""
