extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func run() -> void:
	var preview = load("res://scenes/ui/portrait_preview.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	var first := load("res://resources/rpg/characters/usami.tres").duplicate() as CharacterDefinition
	var second := load("res://resources/rpg/characters/takane.tres").duplicate() as CharacterDefinition
	preview.preview_character = first
	check(preview.image.texture == first.portrait, "Preview should show selected character")
	first.portrait_offset = Vector2(-0.15, 0.1)
	first.portrait_scale = 0.75
	first.portrait_stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check(is_equal_approx(preview.image.anchor_left, -0.15) and is_equal_approx(preview.image.anchor_top, 0.1), "Editing offset should immediately update preview")
	check(preview.image.scale.is_equal_approx(Vector2(0.75, 0.75)), "Editing scale should immediately update preview")
	check(preview.image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Editing fit should immediately update preview")
	var replacement := load("res://textures/portrait.png") as Texture2D
	first.portrait = replacement
	check(preview.image.texture == replacement, "Editing texture should immediately update preview")
	preview.size = Vector2(1000, 900)
	for frame in range(3):
		await process_frame
	check(preview.image.pivot_offset.is_equal_approx(preview.image.size * 0.5), "Preview resizing should update scale pivot")
	preview.preview_character = second
	check(preview.image.texture == second.portrait and preview.image.scale == Vector2.ONE * second.portrait_scale, "Switching characters should apply their own presentation")
	first.portrait_scale = 2.0
	check(preview.image.scale == Vector2.ONE * second.portrait_scale, "Previously selected resource should no longer update preview")
	preview.preview_character = null
	check(preview.image.texture == PortraitPresentation.FALLBACK and preview.image.scale == Vector2.ONE, "Empty preview selection should reset safely")
	preview.queue_free()
	await process_frame
	first.portrait_scale = 1.0
	print("Portrait preview tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
