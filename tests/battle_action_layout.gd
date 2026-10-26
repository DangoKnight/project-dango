extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func settle() -> void:
	for frame in 6:
		await process_frame

func run() -> void:
	var battle := load("res://scenes/battle/combat.tscn").instantiate() as CombatScreen
	battle.menu_slide_duration = 0
	root.add_child(battle)
	var definition := load("res://resources/rpg/characters/usami.tres").duplicate() as CharacterDefinition
	definition.unique_abilities.clear()
	for path in DirAccess.get_files_at("res://resources/rpg/abilities"):
		if path.ends_with(".tres"):
			definition.unique_abilities.append(load("res://resources/rpg/abilities/" + path))
	# Stress scrolling even on tall windows where the shipped ability list can fit.
	for index in 30:
		var extra := definition.unique_abilities[0].duplicate() as AbilityDefinition
		extra.id = StringName("scroll_fixture_%d" % index)
		definition.unique_abilities.append(extra)
	var party: Array[CharacterState] = [CharacterState.new(definition)]
	battle.configure(party, battle.default_encounter)
	check(not battle.has_node("ActionPanel/Layout/Commands/Prompt"), "Action prompt is removed")
	check(battle.action_panel.get_theme_stylebox("panel") is StyleBoxEmpty and battle.special_panel.get_theme_stylebox("panel") is StyleBoxEmpty, "Menus have transparent backgrounds")
	for button in battle.actions.get_children():
		var style := button.get_theme_stylebox("normal") as StyleBoxFlat
		check(style != null and style.bg_color.a > 0 and style.corner_radius_top_left > 0, "Individual action buttons have rounded backgrounds")
	for dimensions in [Vector2i(800, 450), Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(900, 1200), Vector2i(2560, 1080)]:
		root.size = dimensions
		battle._open_special()
		await settle()
		check(battle.action_panel.size.x / battle.size.x < 0.2, "Action buttons use a narrower footprint")
		check(absf(battle.actions.get_global_rect().get_center().y - battle.action_panel.get_global_rect().get_center().y) < 2, "Actions are centered vertically")
		var abilities_button: Button
		for button in battle.actions.get_children():
			if button.text == "Abilities":
				abilities_button = button
		check(abilities_button != null, "Abilities button is available")
		var scroll := battle.get_node("SpecialDrawer/SpecialPanel/Layout/Scroll") as ScrollContainer
		check(absf(scroll.get_global_rect().position.y - abilities_button.get_global_rect().position.y) < 2, "Abilities list aligns with its button at %s" % dimensions)
		check(scroll.get_global_rect().end.y <= battle.party_cards.get_global_rect().position.y, "Abilities drawer stays above the party cards")
		check(battle.special_actions.get_child_count() == party[0].get_abilities().size(), "All abilities remain available")
		check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "Long ability lists overflow into a scrollbar")
		scroll.scroll_vertical = 100
		await settle()
		check(scroll.scroll_vertical > 0, "Ability list can scroll")
		check(battle.special_actions.get_child(0).get_theme_stylebox("normal") is StyleBoxFlat, "Abilities match the rounded action button style")
		battle._close_special()
		await settle()
	battle.queue_free()
	await process_frame
	print("Battle action layout failures: ", failures)
	quit(failures)
