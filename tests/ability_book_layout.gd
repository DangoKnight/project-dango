extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func settle() -> void:
	for frame in 5:
		await process_frame

func run() -> void:
	var characters: Array[CharacterState] = []
	for id in ["usami", "takane", "kurako", "koumi"]:
		characters.append(CharacterState.new(load("res://resources/rpg/characters/%s.tres" % id)))
	var book := load("res://scenes/ui/pause_menu.tscn").instantiate() as PauseBook
	root.add_child(book)
	book.configure(null, MonsterCompendium.new(), true, "ui.safe_zone", characters)
	book.page_fade_duration = 0
	book.character_tab = 3
	await book.open_page("characters")
	for dimensions in [Vector2i(800, 450), Vector2i(1280, 720), Vector2i(900, 1200), Vector2i(2423, 1363)]:
		root.size = dimensions
		for index in characters.size():
			book.widget("Characters").get_child(index).pressed.emit()
			await settle()
			for row in book.widget("AbilityDetails").get_children():
				var ability: AbilityDefinition = row.get_meta("ability")
				var origin := L10n.text(CharacterInformation.ability_origin(characters[index], ability))
				var category := L10n.text(CharacterInformation.ability_category(ability))
				check(row.get_parsed_text().contains("(" + origin + "/" + category + ")"), "Ability shows inline origin and type")
				check(book.right_page.get_global_rect().grow(1).encloses(row.get_global_rect()), "Ability text remains visible on the right page")
				check(row.size.y >= row.get_content_height(), "Wrapped ability text is not clipped")
				check(row.size.y <= 84, "Ability row stays compact")
	if "--screenshot" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 720)
		book.widget("Characters").get_child(0).pressed.emit()
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/dango-ability-colors.png")
	book.queue_free()
	await process_frame
	print("Ability book layout failures: ", failures)
	quit(failures)
