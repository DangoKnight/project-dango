extends "res://scripts/ui/screen.gd"


func configure(map: LabyrinthMap) -> void:
	$Panel/Layout/Title.text = map.display_name
	$Panel/Layout/Canvas.configure(map)
