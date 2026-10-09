extends "res://scripts/ui/screen.gd"

@onready var volume: HSlider = $Panel/Buttons/Volume
@onready var fullscreen: CheckButton = $Panel/Buttons/Fullscreen


func _ready() -> void:
	super._ready()
	volume.value = AudioServer.get_bus_volume_linear(0)
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	volume.value_changed.connect(_on_volume_changed)
	fullscreen.toggled.connect(_on_fullscreen_toggled)


func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(0, value)


func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)
