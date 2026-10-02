extends Control

var heading: Label
var detail: Label
var hold: float = 0.0
const GOLD := Color(0.84, 0.71, 0.39)
const TITLES: Array[String] = ["A SILENT TOWN", "CARRIE'S TRAIL", "THE SAFE PLACE", "SHELTER RECORDS", "THE EVACUATION", "A TRACE OF HOPE"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading = Label.new()
	heading.position = Vector2(38, 0)
	heading.add_theme_font_size_override("font_size", 18)
	heading.add_theme_color_override("font_color", Color(0.9, 0.87, 0.76))
	add_child(heading)
	detail = Label.new()
	detail.position = Vector2(38, 28)
	detail.size = Vector2(282, 65)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 15)
	detail.add_theme_color_override("font_color", Color(0.76, 0.77, 0.69))
	for label: Label in [heading, detail]:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(detail)

func set_objective(stage: int, words: String) -> void:
	heading.text = TITLES[clampi(stage, 0, 5)]
	detail.text = words
	hold = 8.0
	modulate.a = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	hold = maxf(0, hold - delta)
	modulate.a = move_toward(modulate.a, 1.0 if hold > 0 else 0.65, delta * 0.4)

func _draw() -> void:
	draw_circle(Vector2(16, 12), 8, GOLD, false, 1.5)
	draw_circle(Vector2(16, 12), 2, GOLD)
	draw_polyline(PackedVector2Array([Vector2(9, 18), Vector2(16, 31), Vector2(23, 18)]), GOLD, 1.5)
