extends SceneTree

var failures := 0
const BLUNT = preload("res://resources/rpg/damage_types/blunt.tres")
const FIRE = preload("res://resources/rpg/damage_types/fire.tres")


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func unit(id: StringName, speed: float = 10.0) -> CharacterState:
	var definition := CharacterDefinition.new()
	definition.id = id
	definition.display_name = String(id)
	definition.base_stats = RPGStats.new()
	definition.base_stats.max_hp = 1000
	definition.base_stats.max_mp = 30
	definition.base_stats.speed = speed
	return CharacterState.new(definition)


func resolve(session: BattleSession) -> void:
	while session.phase == BattleSession.Phase.ACTION_SELECTION:
		session.choose_wait()
	session.begin_resolution()
	for step in range(20):
		if session.phase != BattleSession.Phase.RESOLVING:
			break
		session.resolve_next_action()
	check(session.phase != BattleSession.Phase.RESOLVING, "Resolution finishes within its action count")


func run() -> void:
	var knowledge := MonsterCompendium.new()
	var actor := unit(&"explorer")
	var enemy := unit(&"rat")
	var bite := load("res://resources/rpg/abilities/bite.tres") as AbilityDefinition
	enemy.definition.unique_abilities = [bite]
	var session := BattleSession.new([actor], [enemy], knowledge)
	check(knowledge.entries.size() == 1 and knowledge.entries[&"rat"].resistances.is_empty() and knowledge.entries[&"rat"].abilities.is_empty(), "Encounter reveals identity without revealing resistances or abilities")
	check(knowledge.describe(&"rat").contains("Pierce: ???"), "Undiscovered affinities have named unknown rows")
	session.choose_attack()
	session.select_target(enemy)
	check(knowledge.entries[&"rat"].resistances.is_empty(), "Planning does not reveal knowledge")
	resolve(session)
	check(knowledge.entries[&"rat"].resistances[BLUNT.id].label == "Normal", "Landing a basic attack discovers normal affinity")
	check(knowledge.entries[&"rat"].abilities.has(bite.id), "Enemy ability execution reveals the ability")
	for label in ["HP", "SP", "MP", "Strength", "Speed", "Level", "STATS", "1000", "30"]:
		check(not knowledge.describe(&"rat").contains(label), "Compendium excludes hidden monster detail: " + label)
	var miss := bite.duplicate() as AbilityDefinition
	miss.id = &"miss"
	miss.damage_type = FIRE
	miss.hit_chance = 0.0
	actor.definition.unique_abilities = [miss]
	session.choose_ability(miss)
	session.select_target(enemy)
	resolve(session)
	check(not knowledge.entries[&"rat"].resistances.has(FIRE.id), "Misses do not reveal resistances")
	var resistance := DamageResistance.new()
	resistance.damage_type = FIRE
	resistance.amount = 1.0
	enemy.definition.resistances = [resistance]
	miss.guaranteed_hit = true
	session.choose_ability(miss)
	session.select_target(enemy)
	resolve(session)
	check(knowledge.entries[&"rat"].resistances[FIRE.id].label == "Immune", "Zero-damage immune hits still reveal affinity")
	var affinity_monster := unit(&"affinities")
	var affinity := DamageResistance.new()
	affinity.damage_type = FIRE
	affinity_monster.definition.resistances = [affinity]
	var amounts := [-0.75, -0.25, 0.0, 0.25, 0.75, 1.0]
	var labels := ["Very weak", "Weak", "Normal", "Resistant", "Very resistant", "Immune"]
	for index in range(amounts.size()):
		affinity.amount = amounts[index]
		knowledge.learn_resistance(affinity_monster, FIRE)
		check(knowledge.entries[&"affinities"].resistances[FIRE.id].label == labels[index], "Compendium uses qualitative affinity: " + labels[index])
	knowledge.entries.erase(&"affinities")
	# Group attacks must discover every monster actually hit, sharing species knowledge.
	var orb := unit(&"orb")
	var other_rat := unit(&"rat")
	var group := miss.duplicate() as AbilityDefinition
	group.id = &"group"
	group.targeting = AbilityDefinition.Target.ENEMIES
	actor.definition.unique_abilities = [group]
	session = BattleSession.new([actor], [other_rat, orb], knowledge)
	session.choose_ability(group)
	session.select_target(orb)
	resolve(session)
	check(knowledge.entries.size() == 2 and knowledge.entries[&"orb"].resistances[FIRE.id].label == "Normal", "Group hits reveal affinities for each species across encounters")
	check(knowledge.entries[&"rat"].abilities.has(bite.id), "Previously observed abilities persist across fights")
	# Consumables also reveal their damage type, even if the hit defeats the monster.
	var gear := GearDefinition.new()
	gear.id = &"bomb"
	gear.kind = GearDefinition.Kind.CONSUMABLE
	gear.consumable_target = GearDefinition.Target.ENEMY
	var effect := ConsumableEffect.new()
	effect.kind = ConsumableEffect.Kind.DAMAGE
	effect.damage_type = BLUNT
	effect.amount = 2000
	gear.effects = [effect]
	var item := GearInstance.new(gear)
	actor.equip_gear(item)
	session.choose_consumable(item)
	session.select_target(orb)
	resolve(session)
	check(knowledge.entries[&"orb"].resistances.has(BLUNT.id), "Lethal consumable hit reveals its damage type")
	# An enemy defeated before acting must not reveal an unexecuted ability.
	var hidden := unit(&"hidden", 1)
	hidden.current_hp = 1
	hidden.definition.unique_abilities = [bite]
	session = BattleSession.new([actor], [hidden], knowledge)
	actor.definition.unique_abilities = [miss]
	session.choose_ability(miss)
	session.select_target(hidden)
	resolve(session)
	check(not knowledge.entries[&"hidden"].abilities.has(bite.id), "Queued but unexecuted abilities remain unknown")
	# Actual navigation uses the same compendium and resets it only for a new game.
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game(false)
	game.state.compendium = knowledge
	game.show_pause("town")
	game.ui.get_child(0).command("Monsters").pressed.emit()
	await create_timer(0.45).timeout
	var page = game.ui.get_child(0)
	check(game.screen == "pause" and page.current_page == "monsters" and page.widget("Monsters").item_count == 3, "Escape menu opens collected monster entries")
	check(page.widget("MonsterDetails").text.contains("Bite"), "Compendium page displays learned abilities")
	for size in [Vector2i(800, 450), Vector2i(900, 1200)]:
		root.size = size
		await process_frame
		await process_frame
		var panel: Control = page.get_node("Panel")
		check(panel.get_global_rect().end.x <= root.get_visible_rect().end.x and panel.get_global_rect().end.y <= root.get_visible_rect().end.y, "Compendium fits resized window")
	page.widget("Back").pressed.emit()
	await create_timer(0.45).timeout
	check(game.screen == "pause" and game.pause_return == "town", "Compendium returns to its menu context")
	game.new_game(false)
	check(game.state.compendium.entries.is_empty(), "New Game clears compendium knowledge")
	game.queue_free()
	await process_frame
	print("Compendium tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
