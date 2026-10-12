extends PanelContainer

var _tween: Tween


func present(message: String, duration: float) -> void:
	if _tween != null:
		_tween.kill()
	$Text.text = L10n.text(message)
	modulate.a = 0.0
	show()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(maxf(0.0, duration - 0.45))
	_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(hide)
