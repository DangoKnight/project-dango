class_name SafeZoneServices
extends RefCounted

var stock: Array[GearInstance] = []
var artifact_pool: Array[GearDefinition] = []
var consumable_pool: Array[GearDefinition] = []
var artifact_min := 2
var artifact_max := 4
var restock_steps := 25
var recipes: Array[FabricationRecipe] = []
var commissions: Dictionary = {}
var made_designs: Dictionary[StringName, bool] = {}
var restock_pending := false
var steps_since_visit := 0
var rng := RandomNumberGenerator.new()


func configure(town: Town) -> void:
	artifact_pool = town.barter_artifacts.duplicate()
	consumable_pool = town.barter_consumables.duplicate()
	artifact_min = town.barter_artifact_min
	artifact_max = town.barter_artifact_max
	restock_steps = maxi(1, town.barter_restock_steps)
	recipes.clear()
	for recipe in town.fabrication_ideas:
		if recipe != null and recipe.is_valid():
			recipes.append(recipe)
	rng.randomize()
	_restock()


func _restock() -> void:
	stock.clear()
	_fill_stock(artifact_pool, artifact_min, artifact_max, GearDefinition.Kind.ARTIFACT)
	var seen: Dictionary[StringName, bool] = {}
	for definition in consumable_pool:
		if definition != null and definition.kind == GearDefinition.Kind.CONSUMABLE and definition.is_valid() and not seen.has(definition.id):
			stock.append(GearInstance.new(definition)) # Unlimited offer; never transferred to the player.
			seen[definition.id] = true
	restock_pending = false
	steps_since_visit = 0


func _fill_stock(pool: Array[GearDefinition], minimum: int, maximum: int, kind: GearDefinition.Kind) -> void:
	var valid: Array[GearDefinition] = []
	for definition in pool:
		if definition != null and definition.kind == kind and definition.is_valid():
			valid.append(definition)
	if valid.is_empty():
		return
	var count := rng.randi_range(maxi(0, minimum), maxi(maxi(0, minimum), maximum))
	for index in range(count):
		stock.append(GearInstance.new(valid[rng.randi_range(0, valid.size() - 1)]))


## Repeated conversations and trades do not restart an active cycle.
func talk() -> void:
	if not restock_pending:
		restock_pending = true
		steps_since_visit = 0


func advance_step() -> void:
	if not restock_pending:
		return
	steps_since_visit += 1
	if steps_since_visit >= restock_steps:
		_restock()


func _valid_goods(items: Array[GearInstance], available: Array[GearInstance]) -> bool:
	var seen: Dictionary = {}
	for item in items:
		if item == null or item not in available or seen.has(item) or item.is_destroyed() or item.definition.kind not in [GearDefinition.Kind.ARTIFACT, GearDefinition.Kind.CONSUMABLE]:
			return false
		seen[item] = true
	return not items.is_empty()


func trade_acceptable(offered: Array[GearInstance], requested: Array[GearInstance], inventory: GearInventory) -> bool:
	if inventory == null or not _valid_goods(offered, inventory.get_items()) or not _valid_goods(requested, stock):
		return false
	var offered_value := 0
	var requested_value := 0
	for item in offered:
		offered_value += item.definition.hidden_value
	for item in requested:
		requested_value += item.definition.hidden_value
	return offered_value >= requested_value * 2


func trade(offered: Array[GearInstance], requested: Array[GearInstance], inventory: GearInventory) -> bool:
	if not trade_acceptable(offered, requested, inventory):
		return false
	# Validate the whole exchange before transferring any goods.
	for item in offered:
		inventory.take(item)
	for item in requested:
		if item.definition.kind == GearDefinition.Kind.CONSUMABLE:
			inventory.add(item.definition)
		else:
			stock.erase(item)
			inventory.register(item)
	return true


func requirements(recipe: FabricationRecipe) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	if recipe == null or not recipe.is_valid():
		return result
	var multiplier := 1 if made_designs.has(recipe.product_key()) else 2
	for species in recipe.required_kills:
		result[species] = recipe.required_kills[species] * multiplier
	return result


func accept_commission(recipe: FabricationRecipe) -> bool:
	if recipe == null or recipe not in recipes or not recipe.is_valid() or commissions.has(recipe.product_key()):
		return false
	commissions[recipe.product_key()] = {"requirements": requirements(recipe), "kills": {}}
	return true


func record_kill(species: StringName) -> void:
	for commission in commissions.values():
		if commission.requirements.has(species):
			commission.kills[species] = mini(commission.requirements[species], commission.kills.get(species, 0) + 1)


func commission_complete(recipe: FabricationRecipe) -> bool:
	if recipe == null or not commissions.has(recipe.product_key()):
		return false
	var commission: Dictionary = commissions[recipe.product_key()]
	for species in commission.requirements:
		if commission.kills.get(species, 0) < commission.requirements[species]:
			return false
	return true


func claim_weapon(recipe: FabricationRecipe) -> WeaponDefinition:
	if recipe == null or recipe.weapon == null or not _complete_commission(recipe):
		return null
	return recipe.weapon


func claim_medallion(recipe: FabricationRecipe, inventory: GearInventory) -> GearInstance:
	if recipe == null or recipe.medallion == null or inventory == null or not _complete_commission(recipe):
		return null
	return inventory.add(recipe.medallion)


func _complete_commission(recipe: FabricationRecipe) -> bool:
	if recipe not in recipes or not recipe.is_valid() or not commission_complete(recipe):
		return false
	commissions.erase(recipe.product_key())
	made_designs[recipe.product_key()] = true
	return true
