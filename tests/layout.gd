extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func fits(control: Control, bounds: Rect2, label: String) -> void:
	var rect := control.get_global_rect()
	check(bounds.grow(1).encloses(rect), "%s exceeds viewport: %s inside %s" % [label, rect, bounds])


func settle() -> void:
	# Containers may need another layout pass after the window resizes.
	for frame in range(3):
		await process_frame


func snapshot(name_text: String) -> void:
	if "--screenshots" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/negi-layout-" + name_text + ".png")


func run() -> void:
	if not Engine.is_embedded_in_editor():
		check(not root.unresizable, "Standalone game window should allow user resizing")
		if DisplayServer.get_name() != "headless":
			check(not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED), "Native window must not disable border resizing")
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.new_game()
	var adjusted_portrait := game.party[0].definition.duplicate() as CharacterDefinition
	adjusted_portrait.portrait_offset = Vector2(-0.1, 0.05)
	adjusted_portrait.portrait_scale = 0.85
	adjusted_portrait.portrait_stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	game.party[0].definition = adjusted_portrait
	game.explore()
	var full_encounter := BattleEncounter.new()
	for index in range(6):
		full_encounter.enemies.append(load("res://resources/rpg/enemies/sentinel.tres"))
	game.world.encounter = full_encounter
	game.start_combat(false)
	var battle := game.ui.get_child(0) as CombatScreen
	await create_timer(battle.menu_slide_duration + 0.05).timeout
	var initial_hp: int = game.party[0].current_hp
	var sizes: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(1024, 768), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(900, 1200)]
	for window_size in sizes:
		root.size = window_size
		await settle()
		var bounds := Rect2(Vector2.ZERO, battle.size)
		for path in ["RoundCounter", "EnemySpots", "Party", "ActionPanel", "PortraitOverlay", "ActionPanel/Layout/Commands", "BattleLog/Log"]:
			if battle.get_node(path).is_visible_in_tree():
				fits(battle.get_node(path), bounds, "%s at %s" % [path, window_size])
		check(not battle.get_node("Party").get_global_rect().intersects(battle.get_node("ActionPanel").get_global_rect()), "Party and commands should not overlap at %s" % window_size)
		check(is_equal_approx(battle.portrait.size.x / battle.size.x, 0.6) and is_equal_approx(battle.portrait.get_rect().end.x, battle.size.x), "Portrait should cover the right 60 percent at %s" % window_size)
		check(battle.portrait.get_index() < battle.get_node("ActionPanel").get_index() and battle.portrait.get_index() > battle.get_node("EnemySpots").get_index(), "Portrait should render over enemies and behind the game UI")
		for card in battle.party_buttons:
			for bar_name in ["HP", "SP"]:
				fits(card.get_node(bar_name), card.get_global_rect(), "%s bar at %s" % [bar_name, window_size])
		var stage: Control = battle.get_node("EnemySpots")
		for slot in battle.enemy_slots:
			if slot.visible:
				fits(slot, stage.get_global_rect(), "Enemy slot at %s" % window_size)
				for child_name in ["Image", "Name", "HP"]:
					fits(slot.get_node(child_name), slot.get_global_rect(), "%s in enemy slot at %s" % [child_name, window_size])
		for first in range(battle.enemy_slots.size()):
			for second in range(first + 1, battle.enemy_slots.size()):
				check(not battle.enemy_slots[first].get_global_rect().intersects(battle.enemy_slots[second].get_global_rect()), "Enemy target regions should not overlap at %s" % window_size)
		check(battle.portrait_image.pivot_offset.is_equal_approx(battle.portrait_image.size * 0.5), "Portrait scale pivot should track resized bounds")
		check(battle.portrait_image.scale.is_equal_approx(Vector2(0.85, 0.85)) and is_equal_approx(battle.portrait_image.anchor_left, -0.1) and is_equal_approx(battle.portrait_image.anchor_top, 0.05), "Resizing should preserve per-character portrait adjustments")
		check(battle.session.active_character() == game.party[0] and battle.portrait.visible, "Resizing should preserve action selection")
		await snapshot("%dx%d-actions" % [window_size.x, window_size.y])
		battle.session.choose_attack()
		await create_timer(battle.menu_slide_duration + 0.05).timeout
		await settle()
		check(not battle.portrait.visible, "Target selection should hide the anchored portrait")
		fits(battle.enemy_slots[0], bounds, "Selectable target at %s" % window_size)
		await snapshot("%dx%d-targets" % [window_size.x, window_size.y])
		battle.session.cancel_target()
		await create_timer(battle.menu_slide_duration + 0.05).timeout
	check(game.party[0].current_hp == initial_hp and battle.session.planned_actions.is_empty(), "Resizing must not alter combat state")
	game.show_town()
	for window_size in sizes:
		root.size = window_size
		game.show_town()
		await settle()
		var view: Control = game.ui.get_child(0)
		fits(view.get_node("Panel"), Rect2(Vector2.ZERO, view.size), "Town panel at %s" % window_size)
		game.show_characters()
		await settle()
		view = game.ui.get_child(0)
		fits(view.get_node("Panel"), Rect2(Vector2.ZERO, view.size), "Character panel at %s" % window_size)
		fits(view.get_node("Panel/Buttons/Content/Details"), Rect2(Vector2.ZERO, view.size), "Character details at %s" % window_size)
		game.show_equipment()
		await settle()
		view = game.ui.get_child(0)
		for path in ["Panel", "Panel/Layout/Members", "Panel/Layout/Lists", "Panel/Layout/Details", "Panel/Layout/Feedback", "Panel/Layout/Actions"]:
			fits(view.get_node(path), Rect2(Vector2.ZERO, view.size), "Equipment %s at %s" % [path, window_size])
		await snapshot("%dx%d-equipment" % [window_size.x, window_size.y])
		game.show_main()
		await settle()
		view = game.ui.get_child(0)
		fits(view.get_node("Panel"), Rect2(Vector2.ZERO, view.size), "Main menu at %s" % window_size)
		game.show_options("main")
		await settle()
		view = game.ui.get_child(0)
		fits(view.get_node("Panel"), Rect2(Vector2.ZERO, view.size), "Options at %s" % window_size)
		game.show_pause()
		await settle()
		view = game.ui.get_child(0)
		fits(view.get_node("Panel"), Rect2(Vector2.ZERO, view.size), "Pause menu at %s" % window_size)
		game.show_location("Inn")
		await settle()
		view = game.ui.get_child(0)
		fits(view.get_node("Panel"), Rect2(Vector2.ZERO, view.size), "Location at %s" % window_size)
	print("Layout tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
