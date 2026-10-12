extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func goods(value: int, kind: int = 0) -> GearDefinition:
	var definition: GearDefinition = load("res://resources/rpg/gear/healing_draught.tres" if kind == GearDefinition.Kind.CONSUMABLE else "res://resources/rpg/gear/iron_artifact.tres").duplicate(true)
	definition.hidden_value = value
	return definition


func click_item(list: ItemList, index: int, shift := false) -> void:
	var position := list.get_global_transform_with_canvas() * list.get_item_rect(index).get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = position
	click.shift_pressed = shift
	click.pressed = true
	root.push_input(click, true)
	await process_frame
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	await process_frame


func run() -> void:
	var town: Town = load("res://scenes/ui/town.tscn").instantiate()
	var services := SafeZoneServices.new()
	services.configure(town)
	var artifact_count := 0
	for item in services.stock:
		if item.definition.kind == GearDefinition.Kind.ARTIFACT:
			artifact_count += 1
	check(artifact_count >= town.barter_artifact_min and artifact_count <= town.barter_artifact_max, "Safe Zone controls artifact stock count")
	for index in range(50):
		services.advance_step()
	check(not services.restock_pending and services.steps_since_visit == 0, "Stock timer waits for the first conversation")
	services.talk()
	services.advance_step()
	services.talk()
	check(services.steps_since_visit == 1, "Talking again does not reset a running timer")
	var inventory := GearInventory.new()
	var low := inventory.add(goods(19))
	var exact := inventory.add(goods(20))
	var request := GearInstance.new(goods(10))
	services.stock = [request]
	check(not services.trade_acceptable([low], [request], inventory), "Below twice the requested value is unacceptable")
	check(services.trade_acceptable([exact], [request], inventory), "Exactly twice the requested value is acceptable")
	check(not services.trade([exact, exact], [request], inventory), "Duplicate offers cannot inflate value")
	check(not services.trade([exact], [request, request], inventory), "Duplicate requests are rejected atomically")
	check(exact in inventory.get_items() and request in services.stock, "Rejected exchanges leave both inventories intact")
	var character := CharacterState.new(load("res://resources/rpg/characters/usami.tres"))
	character.equip_gear(exact)
	check(services.trade([exact], [request], inventory), "Valid trade executes")
	check(exact not in inventory.get_items() and exact not in character.get_equipped_gear() and request in inventory.get_items() and request not in services.stock, "Trade removes offered gear, unequips it, and transfers requested gear once")
	check(not services.trade([low], [request], inventory), "Purchased goods cannot be bought twice")
	check(services.steps_since_visit == 1, "Trading does not reset the conversation timer")
	for index in range(23):
		services.advance_step()
	check(services.stock.is_empty(), "Purchased stock remains absent for 24 steps")
	services.advance_step()
	check(not services.stock.is_empty() and not services.restock_pending, "Stock resets at 25 steps")
	var refreshed := services.stock.duplicate()
	for index in range(100):
		services.advance_step()
	check(services.stock == refreshed and services.steps_since_visit == 0, "After refresh, timer waits for another conversation")
	services.talk()
	check(services.restock_pending and services.steps_since_visit == 0, "First conversation after refresh starts a new cycle")
	var unlimited: GearInstance
	for item in services.stock:
		if item.definition.kind == GearDefinition.Kind.CONSUMABLE:
			unlimited = item
	check(unlimited != null, "Configured consumables are always available")
	var first_payment := inventory.add(goods(100))
	var second_payment := inventory.add(goods(100))
	check(services.trade([first_payment], [unlimited], inventory) and services.trade([second_payment], [unlimited], inventory), "Consumable offers can be purchased repeatedly")
	check(unlimited in services.stock and unlimited not in inventory.get_items(), "Unlimited offer remains stocked and is not transferred")
	var copies := 0
	for item in inventory.get_items():
		if item.definition == unlimited.definition:
			copies += 1
	check(copies == 2, "Each consumable purchase creates an independent full-use item")
	var medallion := inventory.add(load("res://resources/rpg/gear/spell_medallion.tres"))
	check(not services.trade_acceptable([medallion], [services.stock[0]], inventory), "Medallions cannot be bartered")
	var consumable := inventory.add(goods(100, GearDefinition.Kind.CONSUMABLE))
	check(services.trade_acceptable([low, consumable], [services.stock[0]], inventory), "Bundles may mix consumables and artifacts")
	var recipe: FabricationRecipe = services.recipes[0]
	var species: StringName = recipe.required_kills.keys()[0]
	services.record_kill(species)
	check(services.accept_commission(recipe), "An idea can become an accepted commission")
	check(not services.accept_commission(recipe), "Cannot duplicate an active commission")
	check(services.commissions[recipe.product_key()].requirements[species] == recipe.required_kills[species] * 2, "First weapon requires double the base kills")
	check(services.commissions[recipe.product_key()].kills.is_empty(), "Kills before acceptance are not banked")
	services.record_kill(&"irrelevant_species")
	check(services.commissions[recipe.product_key()].kills.is_empty(), "Unrelated species do not advance commissions")
	check(services.claim_weapon(recipe) == null, "Incomplete commission cannot award a weapon")
	for enemy_id in recipe.required_kills:
		for index in range(recipe.required_kills[enemy_id] * 2):
			services.record_kill(enemy_id)
	check(services.commission_complete(recipe), "Required kills finish the commission")
	check(services.claim_weapon(recipe) == recipe.weapon and services.claim_weapon(recipe) == null, "Weapon can be collected exactly once")
	services.accept_commission(recipe)
	check(services.commissions[recipe.product_key()].requirements[species] == recipe.required_kills[species], "Previously made weapons use base requirements")
	var medallion_recipe: FabricationRecipe = load("res://resources/rpg/recipes/spell_medallion.tres")
	check(medallion_recipe.is_valid() and services.accept_commission(medallion_recipe), "Medallion design accepts a commission")
	check(services.claim_weapon(medallion_recipe) == null and services.claim_medallion(medallion_recipe, inventory) == null, "Wrong product type and incomplete medallion claims award nothing")
	for enemy_id in medallion_recipe.required_kills:
		for index in range(medallion_recipe.required_kills[enemy_id] * 2):
			services.record_kill(enemy_id)
	check(services.claim_medallion(medallion_recipe, null) == null and services.commission_complete(medallion_recipe), "Missing stash cannot consume a completed medallion commission")
	var fabricated := services.claim_medallion(medallion_recipe, inventory)
	check(fabricated != null and fabricated in inventory.get_available_items() and fabricated.definition == medallion_recipe.medallion, "Completed medallion enters the shared stash")
	check(services.claim_medallion(medallion_recipe, inventory) == null, "Medallion commission can be claimed only once")
	services.accept_commission(medallion_recipe)
	for enemy_id in medallion_recipe.required_kills:
		check(services.commissions[medallion_recipe.product_key()].requirements[enemy_id] == medallion_recipe.required_kills[enemy_id], "Repeat medallions use base requirements")
		for index in range(medallion_recipe.required_kills[enemy_id]):
			services.record_kill(enemy_id)
	var second_medallion := services.claim_medallion(medallion_recipe, inventory)
	check(second_medallion != null and second_medallion != fabricated, "Repeated fabrication produces independent medallion instances")
	var invalid_recipe := medallion_recipe.duplicate() as FabricationRecipe
	invalid_recipe.weapon = recipe.weapon
	check(not invalid_recipe.is_valid(), "Recipe cannot fabricate both a weapon and medallion")
	invalid_recipe.weapon = null
	invalid_recipe.medallion = load("res://resources/rpg/gear/iron_artifact.tres")
	check(not invalid_recipe.is_valid(), "Medallion recipe rejects artifacts")
	var other_services := SafeZoneServices.new()
	town.barter_artifacts = [load("res://resources/rpg/gear/wind_artifact.tres")]
	town.barter_artifact_min = 1
	town.barter_artifact_max = 1
	town.barter_consumables = []
	town.barter_restock_steps = 7
	other_services.configure(town)
	check(other_services.stock.size() == 1 and other_services.stock[0].definition.id == &"wind_artifact", "Each Safe Zone can define its own pool and stock range")
	other_services.talk()
	for index in range(6):
		other_services.advance_step()
	check(other_services.restock_pending and other_services.steps_since_visit == 6, "Safe Zone can use a custom seven-step timer")
	other_services.advance_step()
	check(not other_services.restock_pending, "Custom timer resets stock at its configured limit")
	check(other_services.requirements(recipe)[species] == recipe.required_kills[species] * 2, "Another Tinkerer has independent design history")
	town.free()

	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.starting_gear.assign([
		load("res://resources/rpg/gear/iron_artifact.tres"),
		load("res://resources/rpg/gear/wind_artifact.tres"),
		load("res://resources/rpg/gear/vital_artifact.tres"),
		load("res://resources/rpg/gear/rally_flask.tres"),
		load("res://resources/rpg/gear/healing_draught.tres"),
		load("res://resources/rpg/gear/frailty_bomb.tres"),
	])
	game.new_game(false)
	# These checks exercise module UI after its introductory dialogue.
	for introduction in game.ui.get_child(0).module_conversations.values():
		game.state.completed_conversations[introduction.id] = true
	game.show_location("Barterer")
	town = game.ui.get_child(0)
	var barter: Control = town.module_view
	check(town.has_node("Panel/Buttons/Barterer") and not town.has_node("Panel/Buttons/Chemist"), "Safe Zone renames Chemist to Barterer")
	check(barter.offered_list.item_count > 0 and barter.stock_list.item_count > 0, "Barterer displays owned and available goods")
	check(barter.feedback.text == "Not acceptable", "Barterer feedback contains no values or hints")
	await create_timer(barter.card_slide_duration + 0.05).timeout
	await click_item(barter.offered_list, 0)
	await click_item(barter.offered_list, 1)
	check(barter.offered_list.is_selected(0) and barter.offered_list.is_selected(1), "Plain clicks add items without clearing the offer")
	await click_item(barter.offered_list, 1)
	check(barter.offered_list.is_selected(0) and not barter.offered_list.is_selected(1), "Clicking an offered item again deselects it")
	await click_item(barter.offered_list, 3, true)
	check(barter.offered_list.is_selected(1) and barter.offered_list.is_selected(2) and barter.offered_list.is_selected(3), "Shift click selects a range from the last clicked item")
	await click_item(barter.stock_list, 0)
	await click_item(barter.stock_list, 1)
	check(barter.stock_list.is_selected(0) and barter.stock_list.is_selected(1), "Requested goods also toggle without Ctrl")
	barter.stock_list.deselect_all()
	barter.offered_list.deselect_all()
	for index in range(barter.offered_list.item_count):
		barter.offered_list.select(index, false)
	barter.stock_list.select(0)
	barter.stock_list.multi_selected.emit(0, true)
	check(barter.feedback.text == "Acceptable" and not barter.exchange.disabled, "Selecting a sufficient bundle enables the exchange without showing its value")
	var stock_before: int = barter.stock_list.item_count
	barter.exchange.pressed.emit()
	check(barter.stock_list.item_count == stock_before - 1 and barter.feedback.text == "Acceptable", "Barterer UI performs the accepted exchange")
	var initial_service: SafeZoneServices = game.state.safe_zone_services[game.state.active_safe_zone_key]
	game.show_location("Tinkerer")
	var workshop: Control = town.module_view
	check(workshop.ideas.item_count == initial_service.recipes.size(), "Tinkerer lists Safe Zone weapon ideas")
	workshop._accept()
	recipe = initial_service.recipes[0]
	for enemy_id in recipe.required_kills:
		for index in range(recipe.required_kills[enemy_id] * 2):
			game._record_service_kill(enemy_id)
	workshop._claim()
	check(game.state.weapon_inventory.size() == 1 and not initial_service.commissions.has(recipe.product_key()), "Completed commission awards a weapon to shared stash")
	check(workshop.get("owned_weapons") == null and workshop.get("equip_button") == null, "Tinkerer does not expose weapon stash or equipment controls")
	var medallion_index := initial_service.recipes.find(medallion_recipe)
	check(medallion_index >= 0, "Tinkerer offers the sample medallion design")
	workshop.ideas.select(medallion_index)
	workshop._refresh_commission()
	check(workshop.claim_button.text == "Collect medallion", "Medallion commission uses the appropriate collection action")
	workshop._accept()
	for enemy_id in medallion_recipe.required_kills:
		for index in range(medallion_recipe.required_kills[enemy_id] * 2):
			game._record_service_kill(enemy_id)
	var old_gear: Array = game.state.gear_inventory.get_items()
	workshop._claim()
	var crafted_medallion: GearInstance
	for item in game.state.gear_inventory.get_items():
		if item not in old_gear:
			crafted_medallion = item
	check(crafted_medallion != null and crafted_medallion.definition.kind == GearDefinition.Kind.MEDALLION, "Tinkerer UI delivers the fabricated medallion")
	check(game.state.party[0].equip_gear(crafted_medallion), "Fabricated medallion can be equipped")
	check(load("res://resources/rpg/abilities/ember.tres") in game.state.party[0].get_abilities(), "Fabricated medallion grants its spells while equipped")
	game.state.party[0].unequip_gear(crafted_medallion)
	# Stock and quests survive navigation; walking counts even with encounters disabled.
	initial_service.restock_pending = true
	initial_service.steps_since_visit = 0
	initial_service.stock.clear()
	await create_timer(0.35).timeout # Let outgoing module cards finish sliding.
	game.explore()
	var map: LabyrinthMap = game.world
	check(game.state.safe_zone_services[game.state.active_safe_zone_key] == initial_service, "Initial Safe Zone identity survives first departure")
	map.definition.encounters_enabled = false
	var entry := map.layout.landmark(map.entry_landmark)
	map.player.position = map.layout.world_position(map.layout.passages[entry.coordinate][0])
	map._on_player_walked(map.definition.cell_size * 24)
	check(initial_service.steps_since_visit == 24 and initial_service.stock.is_empty(), "Labyrinth steps advance restock independently of random encounters")
	map.set_active(false)
	map._on_player_walked(map.definition.cell_size * 100)
	check(initial_service.steps_since_visit == 24, "Paused movement cannot advance restocking")
	map.set_active(true)
	map._on_player_walked(map.definition.cell_size)
	check(not initial_service.stock.is_empty(), "Twenty-fifth labyrinth step restocks the Barterer")
	# Actual battle defeat signal advances accepted commissions exactly once, including poison.
	initial_service.accept_commission(recipe)
	map.encounter = load("res://resources/rpg/encounters/training.tres")
	game.start_combat(false)
	var battle: CombatScreen = game.ui.get_child(0)
	var matching: CharacterState
	for enemy in battle.session.enemies:
		if enemy.definition.id == species:
			matching = enemy
	check(matching != null, "Starter encounter includes the commission species")
	if matching != null:
		matching.current_hp = 1
		matching.apply_status(load("res://resources/rpg/statuses/painful_poison.tres"))
		matching.advance_status_turn()
		battle.session._reward_defeated_enemies()
		battle.session._reward_defeated_enemies()
		check(initial_service.commissions[recipe.product_key()].kills.get(species, 0) == 1, "Poison defeat counts once through live battle integration")
	game.new_game(false)
	# These checks exercise module UI after its introductory dialogue.
	for introduction in game.ui.get_child(0).module_conversations.values():
		game.state.completed_conversations[introduction.id] = true
	check(game.state.safe_zone_services.is_empty() and game.state.weapon_inventory.is_empty(), "New Game resets service stock, quest history, and crafted weapon stash")
	game.queue_free()
	await process_frame
	print("Safe Zone services tests complete: %d failure(s)" % failures)
	call_deferred("finish")


func finish() -> void:
	quit(1 if failures else 0)
