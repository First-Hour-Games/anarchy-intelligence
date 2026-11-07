class_name RouteSubtitles
extends CanvasLayer
## Thomas's lines along the alt route, at the bottom of the screen the way the opening chapter shows them
## (scenes/chapters/main/opening_story.gd): one at a time, each held long enough to read, without stopping
## play. Anything can queue a line through the "route_subtitles" group: call_group("route_subtitles",
## "say", text).

var _queue: Array[String] = []
var _time := 0.0
var _label: Label


func _ready() -> void:
	add_to_group(&"route_subtitles")
	layer = 20
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_left = 48
	_label.offset_right = -48
	_label.offset_top = -200
	_label.offset_bottom = -135
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 21)
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	holder.add_child(_label)


func say(text: String) -> void:
	_queue.append(text)


func showing() -> String:
	return _label.text if is_instance_valid(_label) else ""


func _process(delta: float) -> void:
	_time = maxf(0.0, _time - delta)
	if _time > 0.0:
		return
	_label.text = ""
	if not _queue.is_empty():
		_label.text = _queue.pop_front()
		_time = maxf(4.0, _label.text.length() * 0.055)
