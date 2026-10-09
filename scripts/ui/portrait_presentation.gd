@tool
class_name PortraitPresentation
extends RefCounted

const FALLBACK := preload("res://textures/portrait.png")


## Shared by combat and the editor preview so their placement rules stay identical.
static func apply(image: TextureRect, character: CharacterDefinition, base_anchors: Vector4, default_stretch: int) -> void:
	var offset := character.portrait_offset if character != null else Vector2.ZERO
	image.texture = character.portrait if character != null and character.portrait != null else FALLBACK
	image.anchor_left = base_anchors.x + offset.x
	image.anchor_top = base_anchors.y + offset.y
	image.anchor_right = base_anchors.z + offset.x
	image.anchor_bottom = base_anchors.w + offset.y
	image.scale = Vector2.ONE * character.portrait_scale if character != null else Vector2.ONE
	image.stretch_mode = character.portrait_stretch_mode if character != null and character.portrait_stretch_mode != -1 else default_stretch
	image.pivot_offset = image.size * 0.5
