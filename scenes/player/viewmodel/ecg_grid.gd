@tool
extends Control
class_name ECGGrid

@export var horizontal_lines: int = 5:
	set(value):
		horizontal_lines = maxi(0, value)
		queue_redraw()

@export var vertical_lines: int = 5:
	set(value):
		vertical_lines = maxi(0, value)
		queue_redraw()

@export var grid_color: Color = Color(0.12, 0.45, 0.22, 0.35):
	set(value):
		grid_color = value
		queue_redraw()

@export var line_width: float = 1.0:
	set(value):
		line_width = maxf(0.5, value)
		queue_redraw()


func _draw() -> void:
	var s := size
	if horizontal_lines > 0:
		var h_step := s.y / float(horizontal_lines + 1)
		for i in range(1, horizontal_lines + 1):
			var y := h_step * float(i)
			draw_line(Vector2(6.0, y), Vector2(s.x - 6.0, y), grid_color, line_width)

	if vertical_lines > 0:
		var v_step := s.x / float(vertical_lines + 1)
		for i in range(1, vertical_lines + 1):
			var x := v_step * float(i)
			draw_line(Vector2(x, 6.0), Vector2(x, s.y - 6.0), grid_color, line_width)


func set_color(new_color: Color) -> void:
	grid_color = Color(new_color.r * 0.5, new_color.g * 0.5, new_color.b * 0.5, 0.35)
