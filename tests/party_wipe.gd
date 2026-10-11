extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game(false)
	game.navigation_fade_duration = 0.0
	game.battle_return_fade_duration = 0.0
	game.explore()
	var map_scene: PackedScene = game.state.current_map_scene
	var map := game.world as LabyrinthMap
	var map_path := map_scene.resource_path
	check(game.state.last_safe_zone_scene == game.starting_town and game.state.labyrinth_entries[map_path] == &"entry_refuge", "Initial entry establishes a Safe Zone checkpoint")
	# Give the distant refuge a different town scene, with the same exploration map.
	var town := game.starting_town.instantiate() as Town
	town.town_id = &"wipe_refuge"
	town.display_name = "Wipe Refuge"
	town.exploration_map = map_scene
	var refuge_scene := PackedScene.new()
	check(refuge_scene.pack(town) == OK, "Custom Safe Zone fixture packs")
	town.free()
	var town_path := "/tmp/dango-wipe-refuge.tscn"
	check(ResourceSaver.save(refuge_scene, town_path) == OK, "Custom Safe Zone fixture saves")
	var refuge := map.layout.landmark(&"distant_refuge")
	refuge.town_scene_path = town_path
	await game._enter_safe_zone(map_path, refuge)
	check(game.screen == "town" and game.ui.get_child(0).town_id == &"wipe_refuge", "Doorway visits the custom distant refuge")
	check(game.state.labyrinth_entries[map_path] == refuge.id and game.state.last_safe_zone_scene.resource_path == town_path, "Last visited Safe Zone records its scene and entrance")
	game.explore()
	map = game.world as LabyrinthMap
	check(map.entry_landmark == refuge.id, "Departure starts at the visited refuge")
	var reserve := CharacterState.new(game.starting_characters[0])
	game.state.roster.append(reserve)
	var tonic := load("res://resources/rpg/gear/healing_draught.tres") as GearDefinition
	var carried := game.state.gear_inventory.add(tonic) as GearInstance
	var reserve_item := GearInstance.new(tonic)
	var stash_item := game.state.gear_inventory.add(tonic) as GearInstance
	# Remove existing consumables to ensure these fixture items occupy their slots.
	for member in [game.state.party[0], reserve]:
		for item in member.get_equipped_gear():
			if item.definition.kind == GearDefinition.Kind.CONSUMABLE:
				member.unequip_gear(item)
	check(game.state.party[0].equip_gear(carried) and reserve.equip_gear(reserve_item), "Active and reserve consumable fixture items equip")
	check(reserve_item not in game.state.gear_inventory.get_items(), "Reserve fixture also covers unregistered carried items")
	var retained_items: Array[GearInstance] = []
	for item in game.state.gear_inventory.get_items():
		if item.definition.kind != GearDefinition.Kind.CONSUMABLE:
			retained_items.append(item)
	var retained_equipment: Array = game.state.party[0].get_equipped_gear().filter(func(item): return item.definition.kind != GearDefinition.Kind.CONSUMABLE)
	var actor: CharacterState = game.state.party[0]
	actor.experience = 17.5
	var level_before := actor.level
	var strength_before := actor.get_stat(&"strength")
	actor.store_experience(100, 70.0)
	reserve.current_hp = 1
	reserve.current_mp = 0
	game.state.highest_labyrinth_completion = 0.75
	# A single knockout still leaves the global exploration peak untouched.
	actor.current_hp = 0
	check(game.state.highest_labyrinth_completion == 0.75 and actor.stored_experience() == 0.0, "An individual knockout preserves exploration and clears only its bank")
	actor.restore()
	game.start_combat(false)
	var battle := game.ui.get_child(0) as CombatScreen
	battle.menu_slide_duration = 0.0
	for member in game.state.party:
		member.store_experience(101, 20.0)
		member.current_mp = 0
		member.current_hp = 0
	battle.session._check_finished()
	for frame in range(120):
		if game.screen == "town" and not game._battle_transition:
			break
		await create_timer(0.02).timeout
	check(game.screen == "town" and game.world == null and game.ui.get_child(0).town_id == &"wipe_refuge", "A real full-party defeat returns to the last visited Safe Zone")
	check(game.state.highest_labyrinth_completion == 0.0, "A full party wipe resets the global exploration multiplier")
	for member in game.state.roster:
		check(member.current_hp == member.get_stat(&"max_hp") and member.current_mp == member.get_stat(&"max_mp"), "The entire roster returns fully healed")
		for item in member.get_equipped_gear():
			check(item.definition.kind != GearDefinition.Kind.CONSUMABLE, "Wipes remove all equipped consumables, including reserves")
	for item in game.state.gear_inventory.get_items():
		check(item.definition.kind != GearDefinition.Kind.CONSUMABLE, "Wipes also remove stash consumables")
	check(carried.is_destroyed() and reserve_item.is_destroyed() and stash_item.is_destroyed(), "Lost consumables are destroyed rather than merely unequipped")
	for item in retained_items:
		check(item in game.state.gear_inventory.get_items(), "Artifacts and medallions remain in the shared inventory")
	for item in retained_equipment:
		check(item in actor.get_equipped_gear(), "Non-consumable equipment stays equipped")
	check(actor.level == level_before and actor.experience == 17.5 and actor.get_stat(&"strength") == strength_before, "Wipes preserve permanent progress and applied XP")
	for member in game.state.party:
		check(member.stored_experience() == 0.0, "Downed party members do not recover lost stored XP")
	check(not game.battle_fade.visible and not game._battle_transition, "Defeat recovery completes its fade")
	game.explore()
	map = game.world as LabyrinthMap
	check(map.entry_landmark == refuge.id and map.player.position.is_equal_approx(map.layout.world_position(refuge.coordinate) + Vector3(0, 0.1, 0)), "Exploring after a wipe departs from the last visited refuge")
	check(game.state.highest_labyrinth_completion == map.exploration_completion(), "The next exploration begins a fresh multiplier")
	game.new_game(false)
	check(game.state.last_safe_zone_scene == game.starting_town and game.state.labyrinth_entries.is_empty(), "New Game resets the recovery checkpoint")
	print("Party wipe tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
