extends Node3D

@export var move_speed: float = 6.0
@export var sprint_factor: float = 2.5
@export var mouse_sensitivity: float = 0.002

@onready var camera: Camera3D = $Camera3D
@onready var fog_volume: FogVolume = $FogVolume
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D
@onready var warm_light: OmniLight3D = $EnvironmentProps/WarmLantern/OmniLight3D
@onready var cool_light: OmniLight3D = $EnvironmentProps/CoolBeacon/OmniLight3D
@onready var hud: CanvasLayer = $HUD

# UI elements
@onready var density_slider: HSlider = $HUD/Panel/VBox/DensityRow/HSlider
@onready var density_label: Label = $HUD/Panel/VBox/DensityRow/ValueLabel
@onready var height_slider: HSlider = $HUD/Panel/VBox/HeightRow/HSlider
@onready var height_label: Label = $HUD/Panel/VBox/HeightRow/ValueLabel
@onready var fade_dist_slider: HSlider = $HUD/Panel/VBox/FadeDistRow/HSlider
@onready var fade_dist_label: Label = $HUD/Panel/VBox/FadeDistRow/ValueLabel
@onready var height_fade_check: CheckBox = $HUD/Panel/VBox/HeightFadeCheck
@onready var lights_check: CheckBox = $HUD/Panel/VBox/LightsCheck

var _fog_mat: ShaderMaterial
var _mouse_captured: bool = false
var _cam_rot_x: float = -0.3
var _cam_rot_y: float = 0.0


func _ready() -> void:
	if fog_volume and fog_volume.material is ShaderMaterial:
		# Duplicate material so preview changes don't permanently alter the disk file during runtime
		_fog_mat = fog_volume.material.duplicate()
		fog_volume.material = _fog_mat
		_sync_ui_from_material()

	_setup_ui_signals()
	_update_mouse_mode(false)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			_update_mouse_mode(not _mouse_captured)
		elif event.keycode == KEY_H:
			if hud:
				hud.visible = not hud.visible
		elif event.keycode == KEY_1:
			_set_camera_preset(Vector3(0, 3.5, 12), -0.2, 0.0)
		elif event.keycode == KEY_2:
			_set_camera_preset(Vector3(0, 0.6, 6), 0.05, 0.0)
		elif event.keycode == KEY_3:
			_set_camera_preset(Vector3(12, 8, 12), -0.5, 0.785)

	if _mouse_captured and event is InputEventMouseMotion:
		_cam_rot_y -= event.relative.x * mouse_sensitivity
		_cam_rot_x -= event.relative.y * mouse_sensitivity
		_cam_rot_x = clamp(_cam_rot_x, -1.4, 1.4)
		_apply_camera_rotation()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		_update_mouse_mode(true)


func _process(delta: float) -> void:
	_handle_movement(delta)


func _handle_movement(delta: float) -> void:
	if not _mouse_captured or not camera:
		return

	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1.0
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
		input_dir.y -= 1.0

	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		var speed := move_speed
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= sprint_factor

		# Transform relative to camera orientation
		var forward := -camera.global_transform.basis.z
		var right := camera.global_transform.basis.x
		var up := Vector3.UP

		var move_vec := (forward * (-input_dir.z) + right * input_dir.x + up * input_dir.y) * speed * delta
		camera.global_position += move_vec


func _update_mouse_mode(captured: bool) -> void:
	_mouse_captured = captured
	if captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _apply_camera_rotation() -> void:
	if camera:
		camera.rotation = Vector3(_cam_rot_x, _cam_rot_y, 0.0)


func _set_camera_preset(pos: Vector3, rot_x: float, rot_y: float) -> void:
	if camera:
		camera.position = pos
		_cam_rot_x = rot_x
		_cam_rot_y = rot_y
		_apply_camera_rotation()


func _sync_ui_from_material() -> void:
	if not _fog_mat:
		return
	var density = _fog_mat.get_shader_parameter("base_density")
	if density != null and density_slider:
		density_slider.value = float(density)
		if density_label:
			density_label.text = "%.2f" % float(density)

	var height = _fog_mat.get_shader_parameter("fade_out_height")
	if height != null and height_slider:
		height_slider.value = float(height)
		if height_label:
			height_label.text = "%.1fm" % float(height)

	var dist = _fog_mat.get_shader_parameter("fade_out_distance")
	if dist != null and fade_dist_slider:
		fade_dist_slider.value = float(dist)
		if fade_dist_label:
			fade_dist_label.text = "%.1fm" % float(dist)

	var height_fade_enabled = _fog_mat.get_shader_parameter("enable_height_fade")
	if height_fade_enabled != null and height_fade_check:
		height_fade_check.button_pressed = bool(height_fade_enabled)


func _setup_ui_signals() -> void:
	if density_slider:
		density_slider.value_changed.connect(func(val: float):
			if _fog_mat:
				_fog_mat.set_shader_parameter("base_density", val)
			if density_label:
				density_label.text = "%.2f" % val
		)

	if height_slider:
		height_slider.value_changed.connect(func(val: float):
			if _fog_mat:
				_fog_mat.set_shader_parameter("fade_out_height", val)
			if height_label:
				height_label.text = "%.1fm" % val
		)

	if fade_dist_slider:
		fade_dist_slider.value_changed.connect(func(val: float):
			if _fog_mat:
				_fog_mat.set_shader_parameter("fade_out_distance", val)
			if fade_dist_label:
				fade_dist_label.text = "%.1fm" % val
		)

	if height_fade_check:
		height_fade_check.toggled.connect(func(toggled_on: bool):
			if _fog_mat:
				_fog_mat.set_shader_parameter("enable_height_fade", toggled_on)
		)

	if lights_check:
		lights_check.toggled.connect(func(toggled_on: bool):
			if warm_light:
				warm_light.visible = toggled_on
			if cool_light:
				cool_light.visible = toggled_on
		)

	var btn_white: Button = get_node_or_null("HUD/Panel/VBox/ColorRow/BtnWhite")
	var btn_blue: Button = get_node_or_null("HUD/Panel/VBox/ColorRow/BtnBlue")
	var btn_green: Button = get_node_or_null("HUD/Panel/VBox/ColorRow/BtnGreen")
	var btn_warm: Button = get_node_or_null("HUD/Panel/VBox/ColorRow/BtnWarm")

	if btn_white:
		btn_white.pressed.connect(func(): _set_fog_color(Color(0.85, 0.88, 0.95)))
	if btn_blue:
		btn_blue.pressed.connect(func(): _set_fog_color(Color(0.2, 0.45, 0.85)))
	if btn_green:
		btn_green.pressed.connect(func(): _set_fog_color(Color(0.25, 0.65, 0.35)))
	if btn_warm:
		btn_warm.pressed.connect(func(): _set_fog_color(Color(0.9, 0.6, 0.3)))


func _set_fog_color(c: Color) -> void:
	if _fog_mat:
		_fog_mat.set_shader_parameter("base_color", c)
