extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func run() -> void:
	var slot = load("res://scenes/battle/enemy_slot.tscn").instantiate()
	root.add_child(slot)
	slot.present(true, false)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_final_transform() * slot.get_global_transform_with_canvas() * (slot.size * 0.5)
	Input.parse_input_event(motion)
	await process_frame
	await create_timer(0.1).timeout
	check(is_zero_approx(float(slot._highlight.get_shader_parameter("highlight"))), "Hover outside target selection does not highlight")
	slot.present(true, true)
	Input.parse_input_event(motion)
	await process_frame
	await create_timer(0.25).timeout
	var peak: float = slot._highlight.get_shader_parameter("highlight")
	check(peak > 0.0, "Hovering a valid target whitens its sprite")
	await create_timer(0.35).timeout
	var next: float = slot._highlight.get_shader_parameter("highlight")
	check(not is_equal_approx(peak, next), "Target highlight pulses over time")
	slot.present(true, false)
	check(is_zero_approx(float(slot._highlight.get_shader_parameter("highlight"))), "Leaving target selection clears the pulse immediately")
	var green: Color = slot.get_node("HP").get_theme_stylebox("fill").bg_color
	check(green.g > green.r and green.g > green.b, "Enemy health bar is green")
	slot.death_fade_duration = 0.4
	slot.present(false, false)
	check(slot.modulate == Color.WHITE, "Death starts from the normal sprite color without instant darkening")
	await create_timer(0.15).timeout
	var alpha: float = slot.modulate.a
	check(alpha > 0.0 and alpha < 1.0 and slot.modulate.r == 1.0, "Defeated enemy fades gradually without darkening RGB")
	slot.present(false, false)
	await create_timer(0.3).timeout
	check(is_zero_approx(slot.modulate.a) and slot.disabled, "Repeated refreshes do not restart death fade; defeated enemy becomes transparent and untargetable")
	slot.present(true, false)
	check(slot.modulate == Color.WHITE, "Reusing an enemy slot restores its opacity")
	slot.queue_free()
	await process_frame
	print("Enemy presentation tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
