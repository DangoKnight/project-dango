extends SceneTree

const FRONTLINER = preload("res://tests/fixtures/frontliner.tres")
const CASTER = preload("res://tests/fixtures/caster.tres")
const IRON = preload("res://resources/rpg/gear/iron_artifact.tres")
const WIND = preload("res://resources/rpg/gear/wind_artifact.tres")
const VITAL = preload("res://resources/rpg/gear/vital_artifact.tres")
const MEDALLION = preload("res://resources/rpg/gear/spell_medallion.tres")
const RALLY = preload("res://resources/rpg/gear/rally_flask.tres")
const HEAL = preload("res://resources/rpg/gear/healing_draught.tres")
const BOMB = preload("res://resources/rpg/gear/frailty_bomb.tres")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor := CharacterState.new(FRONTLINER)
	var ally := CharacterState.new(CASTER)
	var inventory := GearInventory.new()
	var iron := inventory.add(IRON)
	var wind := inventory.add(WIND)
	var vital := inventory.add(VITAL)
	var medallion := inventory.add(MEDALLION)
	var rally := inventory.add(RALLY)
	var strength := actor.get_stat(&"strength")
	var speed := actor.get_stat(&"speed")
	var resistance := actor.get_resistance(load("res://resources/rpg/damage_types/slash.tres"))
	check(actor.equip_gear(iron), "Equip artifact")
	check(actor.get_stat(&"strength") == strength + 3 and actor.get_stat(&"speed") == speed - 1, "Positive and negative artifact modifiers")
	check(is_equal_approx(actor.get_resistance(load("res://resources/rpg/damage_types/slash.tres")), resistance + 0.2), "Artifact resistance")
	check(not ally.equip_gear(iron), "One item cannot have two carriers")
	check(actor.equip_gear(wind) and actor.equip_gear(vital), "Three artifacts allowed")
	check(not actor.equip_gear(GearInstance.new(IRON)), "Fourth artifact rejected")
	check(actor.equip_gear(medallion), "Three artifacts plus medallion allowed")
	check(not actor.equip_gear(rally), "Fifth total gear rejected")
	actor.current_hp = actor.get_stat(&"max_hp")
	actor.unequip_gear(vital)
	check(actor.current_hp == actor.get_stat(&"max_hp"), "Removing max HP artifact clamps current HP")
	check(actor.equip_gear(rally), "Two artifacts, medallion and consumable allowed")
	check(not actor.equip_gear(GearInstance.new(RALLY)), "Second consumable rejected")
	actor.unequip_gear(wind)
	check(not actor.equip_gear(GearInstance.new(MEDALLION)), "Second medallion rejected with room available")
	var ember: AbilityDefinition = load("res://resources/rpg/abilities/ember.tres")
	check(ember in actor.get_abilities(), "Medallion grants spells")
	actor.current_mp = 0
	check(not RPGCombat.use_ability(actor, ally, ember).success, "Medallion spell requires MP")
	actor.current_mp = actor.get_stat(&"max_mp")
	check(RPGCombat.use_ability(actor, ally, ember).success, "Equipped medallion spell executes with sufficient MP")
	actor.unequip_gear(medallion)
	check(ember not in actor.get_abilities(), "Unequipping removes medallion spells")
	ally.equip_gear(medallion)
	ally.unequip_gear(medallion)
	check(ember in ally.get_abilities(), "Innate class spell survives medallion removal")
	actor.current_hp -= 20
	ally.current_hp -= 20
	var before := actor.current_hp
	check(not RPGConsumables.use_item(actor, rally, [actor, actor]).success and rally.remaining_uses() == 3 and actor.current_hp == before, "Invalid targets cause no changes")
	var result := RPGConsumables.use_item(actor, rally, [actor, ally])
	check(result.success and result.healing == 36 and rally.remaining_uses() == 2, "Party effects spend one use")
	check(actor.get_stat(&"strength") == int(floor((strength + 3) * 1.25)) and ally.get_active_statuses().size() == 1, "Party attack buff")
	actor.unequip_gear(rally)
	check(ally.equip_gear(rally) and rally.remaining_uses() == 2, "Transfer keeps remaining uses")
	RPGConsumables.use_item(ally, rally, [actor, ally])
	RPGConsumables.use_item(ally, rally, [actor, ally])
	check(rally.is_destroyed() and rally not in ally.get_equipped_gear() and rally not in inventory.get_items(), "Final use destroys item and removes it from inventory")
	check(not actor.equip_gear(rally), "Destroyed gear cannot be re-equipped")
	check(GearInstance.new(RALLY).remaining_uses() == 3, "Separate copies have independent uses")
	var healing := inventory.add(HEAL)
	actor.equip_gear(healing)
	actor.restore()
	ally.restore()
	ally.current_hp -= 10
	var enemy := CharacterState.new(FRONTLINER)
	var session := BattleSession.new([actor, ally], [enemy])
	check(session.choose_consumable(healing), "Choose friendly consumable")
	check(enemy not in session.valid_targets() and ally in session.valid_targets(), "Friendly targeting enforces faction")
	session.cancel_target()
	check(healing.remaining_uses() == 3, "Cancel does not spend use")
	session.choose_consumable(healing)
	session.select_target(ally)
	check(healing.remaining_uses() == 3, "Planning does not spend use")
	session.choose_wait()
	session.begin_resolution()
	while session.phase == BattleSession.Phase.RESOLVING:
		session.resolve_next_action()
	check(healing.remaining_uses() == 2 and ally.current_hp == ally.get_stat(&"max_hp"), "Queued single-ally healing executes")
	actor.unequip_gear(healing)
	var bomb := inventory.add(BOMB)
	actor.equip_gear(bomb)
	actor.restore()
	ally.restore()
	enemy.restore()
	session = BattleSession.new([actor, ally], [enemy])
	session.choose_consumable(bomb)
	check(enemy in session.valid_targets() and ally not in session.valid_targets(), "Offensive targeting enforces faction")
	session.select_target(enemy)
	session.choose_wait()
	session.begin_resolution()
	while session.phase == BattleSession.Phase.RESOLVING:
		session.resolve_next_action()
	check(bomb.remaining_uses() == 2 and enemy.current_hp < enemy.get_stat(&"max_hp") and not enemy.get_active_statuses().is_empty(), "Bomb deals damage and debuffs")
	var resisted_target := CharacterState.new(FRONTLINER)
	var custom_definition := FRONTLINER.duplicate(true) as CharacterDefinition
	var fire_resistance := DamageResistance.new()
	fire_resistance.damage_type = load("res://resources/rpg/damage_types/fire.tres")
	fire_resistance.amount = 0.5
	custom_definition.resistances = [fire_resistance]
	custom_definition.starting_class = null
	resisted_target = CharacterState.new(custom_definition)
	var resisted := RPGConsumables.use_item(actor, bomb, [resisted_target])
	check(resisted.success and resisted.damage == 10, "Consumable damage honors 50 percent resistance")
	var hp := actor.current_hp
	check(not RPGConsumables.use_item(actor, healing, [actor]).success and actor.current_hp == hp, "Unequipped consumable cannot execute")
	var all_enemies := BOMB.duplicate(true) as GearDefinition
	all_enemies.id = &"all_bomb"
	all_enemies.consumable_target = GearDefinition.Target.ENEMIES
	actor.unequip_gear(bomb)
	var area := GearInstance.new(all_enemies)
	actor.equip_gear(area)
	enemy.restore()
	var second_enemy := CharacterState.new(FRONTLINER)
	session = BattleSession.new([actor], [enemy, second_enemy])
	session.choose_consumable(area)
	session.select_target(enemy)
	session.begin_resolution()
	while session.phase == BattleSession.Phase.RESOLVING:
		session.resolve_next_action()
	check(area.remaining_uses() == 2 and second_enemy.current_hp < second_enemy.get_stat(&"max_hp"), "All-enemy effects spend a single use")
	# A defeated actor or invalidated single target must not spend an item.
	actor.restore()
	ally.restore()
	enemy.restore()
	session = BattleSession.new([actor, ally], [enemy])
	session.choose_consumable(area)
	session.select_target(enemy)
	session.choose_wait()
	session.begin_resolution()
	actor.current_hp = 0
	while session.phase == BattleSession.Phase.RESOLVING:
		session.resolve_next_action()
	check(area.remaining_uses() == 2, "Defeated actor does not spend a queued use")
	actor.restore()
	ally.restore()
	actor.unequip_gear(area)
	actor.equip_gear(healing)
	session = BattleSession.new([actor, ally], [enemy])
	session.choose_consumable(healing)
	session.select_target(ally)
	session.choose_wait()
	session.begin_resolution()
	ally.current_hp = 0
	while session.phase == BattleSession.Phase.RESOLVING:
		session.resolve_next_action()
	check(healing.remaining_uses() == 2, "Defeated single target does not spend a use")
	# Self-targeted SP restoration uses the same configurable effect system.
	actor.unequip_gear(healing)
	var restorative := GearDefinition.new()
	restorative.id = &"restorative"
	restorative.kind = GearDefinition.Kind.CONSUMABLE
	restorative.consumable_target = GearDefinition.Target.SELF
	var restore_effect := ConsumableEffect.new()
	restore_effect.kind = ConsumableEffect.Kind.RESTORE_MP
	restore_effect.amount = 5
	restorative.effects = [restore_effect]
	var tonic := GearInstance.new(restorative)
	actor.equip_gear(tonic)
	actor.current_mp = 0
	ally.restore()
	check(not RPGConsumables.use_item(actor, tonic, [ally]).success and tonic.remaining_uses() == 1, "Self-only item rejects another ally")
	check(RPGConsumables.use_item(actor, tonic, [actor]).sp_restored == 5 and tonic.is_destroyed(), "SP restoration and single-use destruction")
	# Exercise actual navigation and UI handlers.
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.new_game()
	main.show_equipment()
	var view = main.ui.get_child(0)
	check(view.stash.item_count == 7, "Starter stash is available through equipment UI")
	view._select(view.stash.get_item_metadata(0))
	view._on_button_pressed("Equip")
	check(view.equipped.item_count == 1 and view.stash.item_count == 6, "Equipment UI equips actual instances")
	view._select(view.equipped.get_item_metadata(0))
	view._on_button_pressed("Unequip")
	check(view.stash.item_count == 7, "Equipment UI returns gear to stash")
	var ui_bomb: GearInstance = main.gear_inventory.get_available_items()[-1]
	main.party[0].equip_gear(ui_bomb)
	main.explore()
	main.start_combat(false)
	var battle := main.ui.get_child(0) as CombatScreen
	var command: Button
	for button in battle.actions.get_children():
		if button is Button and button.text.begins_with("Frailty Bomb"):
			command = button
	check(command != null, "Consumable command appears in battle UI")
	command.pressed.emit()
	await create_timer(battle.menu_slide_duration + 0.05).timeout
	check(not battle.portrait.visible and battle.prompt.text.is_empty() and not battle.enemy_slots[0].disabled and battle.party_buttons[0].disabled, "Consumable targets hide portrait and enable enemies only")
	battle.enemy_slots[0].pressed.emit()
	while battle.session.phase == BattleSession.Phase.ACTION_SELECTION:
		battle.session.choose_wait()
	check(battle.session.phase == BattleSession.Phase.READY, "Consumable actions display in review UI")
	battle.session.begin_resolution()
	while battle.session.phase == BattleSession.Phase.RESOLVING:
		battle.session.resolve_next_action()
	check(ui_bomb.remaining_uses() == 2, "Consumable executes through combat screen")
	main.queue_free()
	print("Gear tests: %d failures" % failures)
	quit(1 if failures else 0)
