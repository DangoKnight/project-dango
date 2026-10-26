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
	game.new_game(false)
	# These checks exercise module UI after its introductory dialogue.
	for introduction in game.ui.get_child(0).module_conversations.values():
		game.state.completed_conversations[introduction.id] = true
	await game.show_characters()
	var characters = game.ui.get_child(0)
	var damage_types: Array[DamageType] = MonsterCompendium.DAMAGE_TYPES
	for index in range(game.state.roster.size()):
		characters._show_character(index)
		check_hidden(characters.widget("CharacterDetails").text, "Character information")
		for ability in game.state.roster[index].get_abilities():
			check_hidden(L10n.text(ability.description), "Ability tooltip")
	game.show_location("Barracks")
	var barracks = game.ui.get_child(0).module_view
	barracks.open_party()
	for member in game.state.roster:
		barracks.select_member(member)
		check_hidden(barracks.stats.text, "Manage Party")
		check(barracks.stats.text.contains("Strength") and barracks.stats.text.contains("SP"), "Primary stats and vitals remain visible")
	var gear := GearDefinition.new()
	gear.id = &"hidden_stats_fixture"
	gear.display_name = "Test artifact"
	gear.stat_modifiers = {&"strength": 3.0}
	for stat in RPGStats.COMBAT_NAMES:
		gear.stat_modifiers[stat] = 987.123
	var item: GearInstance = game.state.gear_inventory.add(gear)
	await game.show_equipment()
	var equipment := game.ui.get_child(0) as PauseBook
	equipment.widget("EquipmentSlots").item_selected.emit(1)
	var details := equipment._gear_description(item)
	check_hidden(details, "Equipment details")
	check(not details.contains("987"), "Hidden equipment modifiers do not leak their values")
	check(details.contains("Strength: +3.0"), "Primary equipment modifiers remain visible")
	game.show_town()
	game.explore()
	game.start_combat(false)
	var battle := game.ui.get_child(0) as CombatScreen
	battle.information.open(battle.session)
	for enemies in [false, true]:
		var units := battle.session.enemies if enemies else battle.session.party
		for member in units:
			check_hidden(CharacterInformation.describe(member, damage_types, false), "Friendly and hostile battle information")
	var takane: CharacterState = game.state.roster[1]
	takane.apply_status(load("res://resources/rpg/statuses/lock_on.tres"))
	check(is_equal_approx(takane.get_combat_stat(&"critical_rate"), 0.7) and is_equal_approx(takane.get_combat_stat(&"critical_damage"), 2.5), "Hidden stats and their buffs still work internally")
	game.queue_free()
	await process_frame
	print("Hidden stat tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
