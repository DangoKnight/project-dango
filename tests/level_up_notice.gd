extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func run() -> void:
	var member := CharacterState.new(load("res://tests/fixtures/frontliner.tres"))
	member.store_experience(1, 350)
	var reports: Array[Dictionary] = []
	check(member.apply_stored_experience(reports) == 2 and reports.size() == 2, "Rest records each earned level independently")
	check(reports[0].from_level == 1 and reports[0].to_level == 2 and reports[1].to_level == 3, "Reports preserve level order")
	check(reports[0].learned.size() == 1 and reports[0].learned[0].id == &"fortify", "Level two reports the newly learned ability")
	check(reports[1].learned.size() == 1 and reports[1].learned[0].id == &"cleave", "Level three excludes previously learned abilities")
	check(reports[0].before[&"max_hp"] == 80 and reports[0].after[&"max_hp"] == 92 and reports[1].after[&"max_hp"] == 104, "Reports capture actual stats at each level")
	check(reports[0].after == reports[1].before, "Consecutive reports share the same intermediate stats")
	var empty: Array[Dictionary] = []
	check(member.apply_stored_experience(empty) == 0 and empty.is_empty(), "Rest without another level produces no notification")
	var notice = load("res://scenes/ui/level_up_notice.tscn").instantiate()
	root.add_child(notice)
	notice.configure(reports)
	await process_frame
	var details: String = notice.get_node("Panel/Layout/Content/Details").text
	check(details.contains("80 → 92 (+12)") and details.contains("Fortify") and not details.contains("Cleave"), "Card displays that level's actual gain and ability name")
	check(not details.contains("Critical") and not details.contains("variation") and not details.contains("growth"), "Card keeps hidden stats and growth rules hidden")
	root.size = Vector2i(800, 450)
	await process_frame
	await process_frame
	var panel: Control = notice.get_node("Panel")
	check(panel.get_global_rect().end.x <= root.get_visible_rect().end.x and panel.get_global_rect().end.y <= root.get_visible_rect().end.y, "Notice fits the minimum supported window")
	var dismissals := [0]
	notice.dismissed.connect(func(): dismissals[0] += 1)
	notice._advance()
	check(notice.get_node("Panel/Layout/Content/Details").text.contains("Cleave"), "Continue displays the next learned ability")
	notice._advance()
	notice._advance()
	check(dismissals[0] == 1, "Final report dismisses exactly once")
	notice.queue_free()
	await process_frame
	print("Level-up notice tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
