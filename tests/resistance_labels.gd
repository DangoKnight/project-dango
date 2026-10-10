extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1


func run() -> void:
	var cases := {
		-1.0: "Very weak", -0.5: "Very weak", -0.499: "Weak",
		-0.001: "Weak", 0.0: "", 0.001: "Resistant",
		0.499: "Resistant", 0.5: "Very resistant", 0.999: "Very resistant",
		1.0: "Immune",
	}
	var slash: DamageType = load("res://resources/rpg/damage_types/slash.tres")
	var fire: DamageType = load("res://resources/rpg/damage_types/fire.tres")
	var definition := CharacterDefinition.new()
	var resistance := DamageResistance.new()
	resistance.damage_type = slash
	definition.resistances = [resistance]
	var unit := CharacterState.new(definition)
	var types: Array[DamageType] = [slash, fire]
	for amount in cases:
		var expected: String = cases[amount]
		check(DamageResistance.display_label(amount) == expected, "Affinity boundary: " + str(amount))
		resistance.amount = amount
		for include_description in [true, false]:
			var text := CharacterInformation.describe(unit, types, include_description)
			var affinities := text.get_slice("RESISTANCES AND WEAKNESSES\n", 1)
			check(not affinities.contains("%") and not affinities.contains("×"), "Town and battle hide exact resistance values")
			check(not affinities.contains("Fire:"), "Neutral damage types are omitted")
			check(affinities == ("None" if expected.is_empty() else "Slash: " + expected), "Character affinity label matches effective value")
	resistance.amount = 0.3
	var inventory := GearInventory.new()
	var iron := inventory.add(load("res://resources/rpg/gear/iron_artifact.tres"))
	unit.equip_gear(iron)
	check(CharacterInformation.describe(unit, types).contains("Slash: Very resistant"), "Unit labels use combined character and equipment resistance")
	var equipment = load("res://scenes/ui/equipment.tscn").instantiate()
	root.add_child(equipment)
	var party: Array[CharacterState] = [unit]
	equipment.configure(party, inventory)
	equipment._select(iron)
	check(equipment.details.text.contains("Slash: Resistant"), "Equipment describes its own resistance contribution")
	check(not equipment.details.text.contains("%"), "Equipment descriptions and details hide exact resistances")
	equipment.queue_free()
	await process_frame
	print("Resistance label tests complete: %d failure(s)" % failures)
	quit(1 if failures else 0)
