extends Control

const MAP: Texture2D = preload("res://img/items/cicely_town_map_board.png")
const COVER_FONT: Font = preload("res://fonts/HelveticaNeueCondensed.ttf")
const PAPER := Color(0.91, 0.87, 0.77)
const INK := Color(0.26, 0.20, 0.16)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var scale_factor := minf(size.x / 340.0, size.y / 440.0)
	var origin := (size - Vector2(340, 440) * scale_factor) * 0.5
	draw_set_transform(origin, -0.035, Vector2.ONE * scale_factor)
	# Two tucked panels and the offset paper edges give the folded cover depth.
	draw_colored_polygon(PackedVector2Array([Vector2(81, 43), Vector2(283, 64), Vector2(295, 395), Vector2(77, 382)]), Color(0, 0, 0, 0.45))
	draw_colored_polygon(PackedVector2Array([Vector2(67, 42), Vector2(259, 56), Vector2(275, 384), Vector2(67, 374)]), PAPER.darkened(0.22))
	draw_colored_polygon(PackedVector2Array([Vector2(73, 34), Vector2(281, 48), Vector2(275, 380), Vector2(73, 367)]), PAPER.darkened(0.10))
	draw_line(Vector2(274, 53), Vector2(269, 372), PAPER.lightened(0.12), 2.0)
	var cover := Rect2(59, 27, 199, 342)
	draw_rect(cover, PAPER)
	draw_rect(cover, INK.lightened(0.35), false, 1.0)
	draw_line(Vector2(64, 31), Vector2(64, 364), PAPER.lightened(0.18), 2.0)
	draw_line(Vector2(250, 30), Vector2(250, 365), INK, 1.0)
	draw_string(COVER_FONT, Vector2(79, 65), "WELCOME TO", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
	draw_string(COVER_FONT, Vector2(76, 111), "CICELY", HORIZONTAL_ALIGNMENT_LEFT, -1, 45, INK)
	draw_line(Vector2(79, 125), Vector2(238, 125), INK, 1.0)
	draw_string(COVER_FONT, Vector2(79, 149), "TOWN GUIDE & MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
	# A cropped section of the real town map is printed on the brochure cover.
	draw_texture_rect_region(MAP, Rect2(79, 167, 159, 147), Rect2(880, 220, 1180, 1090), PAPER)
	draw_line(Vector2(79, 324), Vector2(238, 324), INK.lightened(0.25), 1.0)
	draw_string(COVER_FONT, Vector2(79, 348), "WELCOME CENTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
	draw_set_transform(Vector2.ZERO)
