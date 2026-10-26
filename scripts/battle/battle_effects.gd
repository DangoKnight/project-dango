class_name BattleEffects
extends Control

signal completed

const FRAMES: SpriteFrames = preload("res://resources/battle/effects.tres")
# Clip, tint, relative size. All clips are third-party frame animations, not drawn effects.
const PROFILES := {
	"slash": [["slash", Color.WHITE, 1.0]],
	"pierce": [["pierce", Color.WHITE, 1.0]],
	"blunt": [["blunt", Color.WHITE, 1.1]],
	"fire": [["fire", Color.WHITE, 1.25]],
	"frost": [["frost", Color.WHITE, 1.1]],
	"lightning": [["lightning", Color.WHITE, 1.0]],
	"poison": [["poison", Color.WHITE, 1.0]],
	"arcane": [["arcane", Color.WHITE, 1.1]],
	"heal": [["heal", Color.WHITE, 1.0]],
	"buff": [["buff", Color.WHITE, 0.9]],
	"debuff": [["debuff", Color.WHITE, 1.1]],
	"jolly_cheer": [["jolly_cheer", Color.WHITE, 1.1]],
	"caring_friend": [["caring_friend", Color.WHITE, 1.3]],
	"lock_on": [["lock_on", Color.WHITE, 1.0]],
	"ride_the_gale": [["ride_the_gale", Color.WHITE, 1.2]],
	"graceful_assault": [["graceful_assault", Color.WHITE, 1.3]],
	"painful_stab": [["painful_stab", Color.WHITE, 1.0]],
	"immobilizing_stab": [["immobilizing_stab", Color.WHITE, 1.3]],
	"i_am_scary": [["i_am_scary", Color.WHITE, 1.5]],
	"bonk": [["bonk", Color.WHITE, 1.5]],
	"cover": [["cover", Color.WHITE, 1.5]],
}
var active: Array[Dictionary] = []
var enemy_frames := SpriteFrames.new()
var suspended := false:
	set(value):
		suspended = value
		for effect in active:
			var sprite: AnimatedSprite2D = effect.sprite
			if value:
				sprite.pause()
			else:
				sprite.play()


static func preset_for(ability: AbilityDefinition) -> String:
	if ability.battle_animation != "Auto" and PROFILES.has(ability.battle_animation):
		return ability.battle_animation
	if ability.effect == AbilityDefinition.Effect.HEAL:
		return "heal"
	if ability.effect == AbilityDefinition.Effect.STATUS or ability.status_effect != null:
		return "debuff" if ability.status_effect != null and ability.status_effect.is_harmful() else "buff"
	return String(ability.damage_type.id) if ability.damage_type != null and PROFILES.has(String(ability.damage_type.id)) else "blunt"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func play_effect(preset: String, target: Control, duration: float) -> void:
	if duration <= 0.0 or not is_instance_valid(target):
		return
	var layers: Array = PROFILES.get(preset, PROFILES.blunt)
	for layer in layers:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = FRAMES if target.has_node("SP") else _enemy_frames(layer[0])
		sprite.modulate = layer[1]
		add_child(sprite)
		var effect := {"sprite": sprite, "target": target, "size": float(layer[2])}
		active.append(effect)
		sprite.animation_finished.connect(_finish.bind(effect), CONNECT_ONE_SHOT)
		sprite.play(layer[0], 0.7 / duration)
		if suspended:
			sprite.pause()
		_position(effect)


func _finish(effect: Dictionary) -> void:
	active.erase(effect)
	effect.sprite.queue_free()
	if active.is_empty():
		completed.emit()


func _process(_delta: float) -> void:
	for effect in active:
		_position(effect)


func _position(effect: Dictionary) -> void:
	if not is_instance_valid(effect.target):
		return
	var target: Control = effect.target
	var sprite: AnimatedSprite2D = effect.sprite
	sprite.visible = target.is_visible_in_tree()
	var rect := target.get_global_rect()
	var center := get_global_transform().affine_inverse() * rect.get_center()
	var side := minf(size.x, size.y) * 0.3 * float(effect.size)
	if target.has_node("SP"):
		# Center on the card and size relative to its footprint.
		side = minf(rect.size.x, rect.size.y) * minf(float(effect.size), 1.0)
		sprite.position = center
	else:
		sprite.position = Vector2(clampf(center.x, side * 0.5, maxf(side * 0.5, size.x - side * 0.5)), clampf(center.y, side * 0.5, maxf(side * 0.5, size.y - side * 0.5)))
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	sprite.scale = Vector2.ONE * side / maxf(texture.get_width(), texture.get_height())


func is_playing() -> bool:
	return not active.is_empty()


func wait_until_finished() -> void:
	while is_playing():
		await completed


# Cache downsampled clips without changing the source pack or their screen footprint.
func _enemy_frames(clip: StringName) -> SpriteFrames:
	if not enemy_frames.has_animation(clip):
		enemy_frames.add_animation(clip)
		enemy_frames.set_animation_loop(clip, FRAMES.get_animation_loop(clip))
		enemy_frames.set_animation_speed(clip, FRAMES.get_animation_speed(clip))
		for index in FRAMES.get_frame_count(clip):
			var image := FRAMES.get_frame_texture(clip, index).get_image()
			image.resize(maxi(1, image.get_width() / 2), maxi(1, image.get_height() / 2), Image.INTERPOLATE_NEAREST)
			enemy_frames.add_frame(clip, ImageTexture.create_from_image(image), FRAMES.get_frame_duration(clip, index))
	return enemy_frames
