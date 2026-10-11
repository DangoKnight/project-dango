extends Button

@export_range(0.0, 3.0, 0.1) var death_fade_duration := 1.4
var _dying := false
var _group_highlight := false
var _fade: Tween
var _pulse: Tween
var _highlight: ShaderMaterial


func _ready() -> void:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float highlight : hint_range(0.0, 1.0) = 0.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    COLOR = vec4(mix(tex.rgb, vec3(1.0), highlight), tex.a) * tint;
}"""
	_highlight = ShaderMaterial.new()
	_highlight.shader = shader
	$Image.material = _highlight
	mouse_entered.connect(_update_highlight)
	mouse_exited.connect(_stop_highlight)


func present(alive: bool, targetable: bool) -> void:
	disabled = not targetable or not alive
	if not alive and not _dying:
		_dying = true
		_stop_highlight()
		_fade = create_tween()
		_fade.tween_property(self, "modulate:a", 0.0, death_fade_duration)
	elif alive and _dying:
		_dying = false
		if _fade != null:
			_fade.kill()
		modulate = Color.WHITE
	_update_highlight()


func set_group_highlight(active: bool) -> void:
	_group_highlight = active
	_update_highlight()


func _update_highlight() -> void:
	if disabled or _dying or not (is_hovered() or _group_highlight):
		_stop_highlight()
		return
	if _pulse != null and _pulse.is_running():
		return
	_pulse = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_method(_set_highlight, 0.0, 0.6, 0.45)
	_pulse.tween_method(_set_highlight, 0.6, 0.0, 0.45)


func _set_highlight(amount: float) -> void:
	_highlight.set_shader_parameter("highlight", amount)


func _stop_highlight() -> void:
	if _pulse != null:
		_pulse.kill()
	if _highlight != null:
		_set_highlight(0.0)


func wait_for_disappearance() -> void:
	if _dying and _fade != null and _fade.is_running():
		await _fade.finished
