extends Control


func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var cover := StyleBoxFlat.new()
	cover.bg_color = Color(0.19, 0.105, 0.06)
	cover.border_color = Color(0.43, 0.28, 0.12)
	cover.set_border_width_all(3)
	cover.set_corner_radius_all(10)
	cover.shadow_color = Color(0, 0, 0, 0.65)
	cover.shadow_size = 16
	cover.shadow_offset = Vector2(0, 8)
	draw_style_box(cover, Rect2(Vector2.ZERO, size))
	var inset := size * Vector2(0.012, 0.018)
	var paper := Rect2(inset, size - inset * 2.0)
	for offset in [6.0, 4.0, 2.0]:
		draw_rect(Rect2(paper.position + Vector2(0, offset), paper.size), Color(0.65 + offset * 0.02, 0.59 + offset * 0.02, 0.46 + offset * 0.02))
	draw_rect(paper, Color(0.91, 0.86, 0.72))
	draw_rect(Rect2(paper.position, Vector2(paper.size.x * 0.5, paper.size.y)), Color(0.94, 0.9, 0.78))
	var middle := size.x * 0.5
	for index in range(18):
		var alpha := 0.23 * pow(1.0 - float(index) / 18.0, 2.0)
		draw_rect(Rect2(Vector2(middle - index - 1, paper.position.y), Vector2(1, paper.size.y)), Color(0.25, 0.15, 0.07, alpha))
		draw_rect(Rect2(Vector2(middle + index, paper.position.y), Vector2(1, paper.size.y)), Color(0.25, 0.15, 0.07, alpha))
	draw_line(Vector2(middle, paper.position.y), Vector2(middle, paper.end.y), Color(0.36, 0.23, 0.12, 0.4), 1.0)
	# Faint ruled lines give the pages the feel of a handwritten field journal.
	for side in range(2):
		var left := size.x * (0.055 + side * 0.5)
		var right := size.x * (0.445 + side * 0.5)
		var y := size.y * 0.2
		while y < size.y * 0.88:
			draw_line(Vector2(left, y), Vector2(right, y), Color(0.37, 0.29, 0.19, 0.055), 1.0)
			y += 30.0
	var ribbon_x := size.x * 0.54
	draw_colored_polygon(PackedVector2Array([
		Vector2(ribbon_x, 0), Vector2(ribbon_x + 14, 0),
		Vector2(ribbon_x + 14, 40), Vector2(ribbon_x + 7, 34), Vector2(ribbon_x, 40)
	]), Color(0.48, 0.14, 0.11))
