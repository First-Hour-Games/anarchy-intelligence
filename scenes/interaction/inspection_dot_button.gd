class_name InspectionDotButton extends Control

## A clean, glowing circular interactive dot for inspection mode.

signal clicked()

var dot_color: Color = Color(1.0, 1.0, 1.0, 0.95)
var glow_color: Color = Color(0.25, 0.75, 1.0, 0.55)
var dot_radius: float = 7.0
var glow_radius: float = 16.0

var _is_hovered: bool = false
var _hover_scale: float = 1.0
var _pulse_time: float = 0.0


func _init() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(48.0, 48.0)
	size = Vector2(48.0, 48.0)
	pivot_offset = Vector2(24.0, 24.0)


func _process(delta: float) -> void:
	_pulse_time += delta * 2.8
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		clicked.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_is_hovered = true
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "_hover_scale", 1.35, 0.15)
	elif what == NOTIFICATION_MOUSE_EXIT:
		_is_hovered = false
		var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "_hover_scale", 1.0, 0.15)


func _draw() -> void:
	var center := size * 0.5
	var pulse := sin(_pulse_time) * 0.18 + 0.82
	var outer_r := glow_radius * _hover_scale * pulse
	var inner_r := dot_radius * _hover_scale

	# Soft outer glow halos
	draw_circle(center, outer_r * 1.4, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.2))
	draw_circle(center, outer_r, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.6))
	# Delicate outer ring
	draw_arc(center, inner_r + 4.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.55 * (_hover_scale / 1.35)), 1.5, true)
	# Crisp core dot
	draw_circle(center, inner_r, dot_color)
