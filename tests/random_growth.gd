extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func make_unit(name_text: String, seed_value: int = 42, starting_level: int = 1) -> CharacterState:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return CharacterState.new(load("res://resources/rpg/characters/" + name_text + ".tres"), null, starting_level, rng)


func run() -> void:
	for name_text in ["usami", "takane", "kurako", "koumi"]:
		var unit := make_unit(name_text)
		var variation := 1.0 if name_text == "koumi" else 0.5
		check(is_equal_approx(unit.definition.growth_variation, variation), "Natural variation for " + name_text)
		var info := CharacterInformation.describe(unit, [])
		check(not info.to_lower().contains("growth") and not info.to_lower().contains("variation") and not info.contains("±"), "Player information hides all growth values and variation")
		check(info.contains("Strength: %d" % unit.get_stat(&"strength")), "Player information still shows current effective stats")
		var positive := false
		var negative := false
		var fractional := false
		var offsets: Dictionary = {}
		for level in range(2, 30):
			var before := unit._permanent_stats.duplicate()
			unit.set_level(level)
			for stat in RPGStats.NAMES:
				var gain: float = unit._permanent_stats[stat] - before[stat]
				var deviation := gain - unit.get_growth(stat)
				check(absf(deviation) <= variation + 0.000001, "Growth stays within the natural range")
				positive = positive or deviation > 0.0
				negative = negative or deviation < 0.0
				fractional = fractional or not is_equal_approx(gain, round(gain))
				offsets[deviation] = true
		check(positive and negative and fractional and offsets.size() > 7, "Independent rolls vary both ways and retain decimals")
		var bulk := make_unit(name_text, 91)
		var stepped := make_unit(name_text, 91)
		bulk.set_level(10)
		for level in range(2, 11):
			stepped.set_level(level)
		check(bulk._permanent_stats == stepped._permanent_stats, "Bulk leveling matches independent per-level rolls")
		var seeded_start := make_unit(name_text, 91, 10)
		check(seeded_start._permanent_stats == bulk._permanent_stats, "Higher starting level rolls every earned level")
		var earned := bulk._permanent_stats.duplicate()
		var rng_state := bulk._growth_rng.state
		bulk.set_level(10)
		bulk.set_level(1)
		bulk.set_class(load("res://resources/rpg/classes/arcanist.tres"))
		check(bulk._permanent_stats == earned and bulk._growth_rng.state == rng_state, "Repeated levels and class changes cannot reroll earned stats")
		var center := bulk.get_growth(&"mental_acuity")
		bulk.set_level(11)
		check(absf(bulk._permanent_stats[&"mental_acuity"] - earned[&"mental_acuity"] - center) <= variation, "Future rolls use the new class growth")
	# Equipment growth is separate from temporary stat boosts, and only applies while equipped.
	var equipped := make_unit("usami", 123)
	var plain := make_unit("usami", 123)
	var gear := GearDefinition.new()
	gear.id = &"growth_fixture"
	gear.stat_modifiers = {&"strength": 100.0}
	gear.stat_growth_modifiers = {&"strength": 0.25}
	var item := GearInstance.new(gear)
	var initial_growth := equipped.get_growth(&"strength")
	check(equipped.equip_gear(item), "Valid growth equipment can be equipped")
	check(is_equal_approx(equipped.get_growth(&"strength"), initial_growth + 0.25), "Equipment contributes to base growth")
	equipped.set_level(5)
	plain.set_level(5)
	equipped.unequip_gear(item)
	check(is_equal_approx(equipped._permanent_stats[&"strength"] - plain._permanent_stats[&"strength"], 1.0), "Earned equipment growth stays permanent while the flat stat boost is removed")
	check(is_equal_approx(equipped.get_growth(&"strength"), initial_growth), "Unequipping removes future growth contribution")
	gear.stat_growth_modifiers = {&"critical_rate": 0.5}
	check(not gear.is_valid(), "Growth modifiers only accept primary stats")
	print("Random growth tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
