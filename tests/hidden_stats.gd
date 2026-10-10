extends SceneTree

const HIDDEN_TERMS := ["critical rate", "critical damage", "crit rate", "crit damage", "accuracy", "evasion", "aggro"]
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func check_hidden(text: String, context: String) -> void:
	for term in HIDDEN_TERMS:
		check(not text.to_lower().contains(term), context + " hides " + term)


func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	game.show_characters()
	var characters = game.ui.get_child(0)
	var damage_types: Array[DamageType] = characters.damage_types
	for index in range(game.roster.size()):
		characters._show_character(index)
		check_hidden(characters.details.text, "Character information")
		for ability in game.roster[index].get_abilities():
			check_hidden(ability.description, "Ability tooltip")
	game.show_location("Barracks")
	var barracks = game.ui.get_child(0).module_view
	barracks.open_party()
	for member in game.roster:
		barracks.select_member(member)
		check_hidden(barracks.stats.text, "Manage Party")
		check(barracks.stats.text.contains("Strength") and barracks.stats.text.contains("SP"), "Primary stats and vitals remain visible")
	var gear := GearDefinition.new()
	gear.id = &"hidden_stats_fixture"
	gear.display_name = "Test artifact"
	gear.stat_modifiers = {&"strength": 3.0}
	for stat in RPGStats.COMBAT_NAMES:
		gear.stat_modifiers[stat] = 987.123
	var item: GearInstance = game.gear_inventory.add(gear)
	game.show_equipment()
	var equipment = game.ui.get_child(0)
	equipment._select(item)
	check_hidden(equipment.details.text, "Equipment details")
	check(not equipment.details.text.contains("987"), "Hidden equipment modifiers do not leak their values")
	check(equipment.details.text.contains("Strength: +3.0"), "Primary equipment modifiers remain visible")
	game.show_town()
	game.explore()
	game.start_combat(false)
	var battle := game.ui.get_child(0) as CombatScreen
	battle.information.open(battle.session)
	for enemies in [false, true]:
		var units := battle.session.enemies if enemies else battle.session.party
		for member in units:
			check_hidden(CharacterInformation.describe(member, damage_types, false), "Friendly and hostile battle information")
	var takane: CharacterState = game.roster[1]
	takane.apply_status(load("res://resources/rpg/statuses/lock_on.tres"))
	check(is_equal_approx(takane.get_combat_stat(&"critical_rate"), 0.7) and is_equal_approx(takane.get_combat_stat(&"critical_damage"), 2.5), "Hidden stats and their buffs still work internally")
	game.queue_free()
	await process_frame
	print("Hidden stat tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
