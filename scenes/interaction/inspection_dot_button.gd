class_name InspectionDotButton extends Control

## An interactive eye icon button for inspection mode.
## Displays a square frame with semi-transparent black background and white outline,
## with res://img/player/eyeInteract.png centered inside.
## Scales up and highlights with a smooth animation when hovered.

signal clicked()

const EYE_TEXTURE: Texture2D = preload("res://img/player/eyeInteract.png")
const COLOR_UNHOVERED: Color = Color(0.85, 0.85, 0.85, 0.95)
const COLOR_HOVERED: Color = Color(1.0, 1.0, 1.0, 1.0)
const SCALE_UNHOVERED: Vector2 = Vector2(1.0, 1.0)
const SCALE_HOVERED: Vector2 = Vector2(1.28, 1.28)
const HOVER_DURATION: float = 0.16

# Square frame styling
const FRAME_BG_COLOR: Color = Color(0.0, 0.0, 0.0, 0.65)
const FRAME_OUTLINE_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const FRAME_OUTLINE_WIDTH: float = 2.0
const ICON_PADDING: float = 5.0

# Backwards compatibility properties for InspectionHotspot3D
var dot_color: Color = COLOR_UNHOVERED
var glow_color: Color = Color(0.25, 0.75, 1.0, 0.55)
var dot_radius: float = 7.0
var glow_radius: float = 16.0

var _is_hovered: bool = false
var _hover_tween: Tween = null


func _init() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(40.0, 40.0)
	size = Vector2(40.0, 40.0)
	pivot_offset = Vector2(20.0, 20.0)
	scale = SCALE_UNHOVERED
	modulate = COLOR_UNHOVERED
	gui_input.connect(_on_gui_input)


func _gui_input(event: InputEvent) -> void:
	_on_gui_input(event)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_play_click_pop()
		clicked.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_set_hovered(true)
	elif what == NOTIFICATION_MOUSE_EXIT:
		_set_hovered(false)
	elif what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree():
			_set_hovered(false)


func _set_hovered(hovered: bool) -> void:
	if _is_hovered == hovered:
		return
	_is_hovered = hovered
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	_hover_tween = create_tween().set_parallel(true)
	if hovered:
		_hover_tween.tween_property(self, "scale", SCALE_HOVERED, HOVER_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(self, "modulate", COLOR_HOVERED, HOVER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_hover_tween.tween_property(self, "scale", SCALE_UNHOVERED, HOVER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(self, "modulate", COLOR_UNHOVERED, HOVER_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_click_pop() -> void:
	var click_tween := create_tween()
	click_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	click_tween.tween_property(self, "scale", SCALE_HOVERED if _is_hovered else SCALE_UNHOVERED, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var frame_rect := Rect2(Vector2.ZERO, size)

	# 1. Square frame background: semi-transparent black
	draw_rect(frame_rect, FRAME_BG_COLOR, true)

	# 2. Square frame outline: white outline
	draw_rect(frame_rect, FRAME_OUTLINE_COLOR, false, FRAME_OUTLINE_WIDTH)

	# 3. Centered eye icon inside frame
	if EYE_TEXTURE:
		var pad := ICON_PADDING
		var icon_rect := Rect2(Vector2(pad, pad), size - Vector2(pad * 2.0, pad * 2.0))
		# Subtle shadow for extra depth
		draw_texture_rect(EYE_TEXTURE, Rect2(icon_rect.position + Vector2(1.0, 1.0), icon_rect.size), false, Color(0.0, 0.0, 0.0, 0.4))
		# Main eye icon
		draw_texture_rect(EYE_TEXTURE, icon_rect, false, Color.WHITE)

