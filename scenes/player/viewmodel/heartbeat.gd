@tool
extends Line2D
class_name Heartbeat

@export var spacing: float = 3.5
@export var speed: float = 1.4
@export var amp: float = 28.0
@export var change_speed: float = 12.0
@export_range(1, 2, 1) var cycles: int = 1
@export var trail_ratio: float = 0.40
@export var pause_time: float = 0.30
@export var point_count: int = 65:
	set(value):
		point_count = maxi(10, value)

@export var line_color: Color = Color(0.2, 1.0, 0.45, 1.0):
	set(value):
		line_color = value
		_update_gradient()

var r_amp: float = 28.0
var progress: float = 0.0


func _ready() -> void:
	r_amp = amp
	_update_gradient()


func _update_gradient() -> void:
	var grad := Gradient.new()
	# Tail fades out
	grad.set_color(0, Color(line_color.r, line_color.g, line_color.b, 0.0))
	grad.add_point(0.20, Color(line_color.r, line_color.g, line_color.b, line_color.a))
	# Main body is bright
	grad.add_point(0.88, Color(line_color.r, line_color.g, line_color.b, line_color.a))
	# Generating head fades in at the very front tip
	grad.set_color(grad.get_point_count() - 1, Color(line_color.r, line_color.g, line_color.b, 0.0))
	gradient = grad


func _physics_process(delta: float) -> void:
	r_amp = move_toward(r_amp, amp, change_speed * delta)

	# Progress sweeps from 0.0 to total_duration
	# where total_duration = 1.0 (screen width) + trail_ratio (tail to exit) + pause_time
	var total_duration := 1.0 + trail_ratio + pause_time
	progress += delta * speed
	if progress >= total_duration:
		progress = fmod(progress, total_duration)

	var total_w := float(point_count - 1) * spacing
	var h_u := minf(1.0, progress)
	var t_u := maxf(0.0, progress - trail_ratio)

	if progress >= (1.0 + trail_ratio) or t_u >= h_u:
		# In pause interval between heartbeats
		if not points.is_empty():
			points = PackedVector2Array()
		return

	var h_x := h_u * total_w
	var t_x := t_u * total_w

	var pts := PackedVector2Array()
	pts.append(Vector2(t_x, _get_ecg_y(t_u)))

	var i_start := clampi(int(ceil(t_u * float(point_count - 1))), 0, point_count - 1)
	var i_end := clampi(int(floor(h_u * float(point_count - 1))), 0, point_count - 1)

	for i in range(i_start, i_end + 1):
		var u := float(i) / float(point_count - 1)
		pts.append(Vector2(float(i) * spacing, _get_ecg_y(u)))

	pts.append(Vector2(h_x, _get_ecg_y(h_u)))
	points = pts


func _get_ecg_y(u: float) -> float:
	var val := 0.0
	if cycles == 1:
		if u >= 0.25 and u <= 0.70:
			var p := (u - 0.25) / 0.45
			var p_w := 0.12 * exp(-pow((p - 0.18) / 0.06, 2.0))
			var q_w := -0.18 * exp(-pow((p - 0.30) / 0.03, 2.0))
			var r_w := 1.00 * exp(-pow((p - 0.42) / 0.04, 2.0))
			var s_w := -0.30 * exp(-pow((p - 0.54) / 0.04, 2.0))
			var t_w := 0.45 * exp(-pow((p - 0.70) / 0.08, 2.0))
			val = -(p_w + q_w + r_w + s_w + t_w)
	else:
		# 2 cycles across the screen
		for c in 2:
			var start := 0.10 + float(c) * 0.45
			var end := start + 0.35
			if u >= start and u <= end:
				var p := (u - start) / 0.35
				var p_w := 0.12 * exp(-pow((p - 0.18) / 0.06, 2.0))
				var q_w := -0.18 * exp(-pow((p - 0.30) / 0.03, 2.0))
				var r_w := 1.00 * exp(-pow((p - 0.42) / 0.04, 2.0))
				var s_w := -0.30 * exp(-pow((p - 0.54) / 0.04, 2.0))
				var t_w := 0.45 * exp(-pow((p - 0.70) / 0.08, 2.0))
				val = -(p_w + q_w + r_w + s_w + t_w)
				break
	return val * r_amp


func set_params(new_spacing: float = spacing, new_speed: float = speed, new_amp: float = amp, new_cycles: int = cycles, new_pause: float = pause_time) -> void:
	spacing = new_spacing
	speed = new_speed
	amp = new_amp
	cycles = new_cycles
	pause_time = new_pause


func set_color(new_color: Color) -> void:
	line_color = new_color
