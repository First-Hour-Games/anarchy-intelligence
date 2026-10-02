extends Node
## Optional health/respawn component; existing movement controller is unchanged.
signal health_changed(value: float)
@export var max_health: float = 100.0
var health: float = 100.0
var is_dead: bool = false
var immunity: float = 0.0
var spawn: Transform3D
var status: Label
var retry: Button
var death_scare: CanvasLayer
const DEATH_SCARE := preload("res://scenes/ui/death_scare.gd")

func _ready() -> void:
	health = max_health
	spawn = get_parent().global_transform
	var canvas := CanvasLayer.new()
	canvas.layer = 21
	add_child(canvas)

	var safe_area := AspectRatioContainer.new()
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_area.ratio = 4.0 / 3.0
	safe_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(safe_area)

	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_area.add_child(content)

	status = Label.new()
	status.position = Vector2(24.0, 222.0)
	status.size = Vector2(220.0, 30.0)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_color_override(&"font_color", Color(0.84, 0.93, 0.86, 0.94))
	status.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	status.add_theme_constant_override(&"shadow_offset_x", 2)
	status.add_theme_constant_override(&"shadow_offset_y", 2)
	status.add_theme_font_size_override(&"font_size", 18)
	var hud_font := load("res://fonts/JainiPurva.ttf") as Font
	if hud_font:
		status.add_theme_font_override(&"font", hud_font)
	content.add_child(status)

	retry = Button.new()
	retry.text = "You were caught — try again"
	retry.position = Vector2(24.0, 250.0)
	retry.size = Vector2(220.0, 42.0)
	if hud_font:
		retry.add_theme_font_override(&"font", hud_font)
	retry.add_theme_font_size_override(&"font_size", 18)
	retry.hide()
	content.add_child(retry)
	retry.pressed.connect(respawn)
	_refresh()

func _process(delta: float) -> void:
	immunity = maxf(0.0, immunity - delta)

func take_damage(amount: float, attacker: Node3D = null) -> void:
	if is_dead or immunity > 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	immunity = 0.6
	health_changed.emit(health)
	_refresh()
	if health == 0.0:
		is_dead = true
		get_parent().set_physics_process(false)
		get_parent().set_process_unhandled_input(false)
		get_parent().freeze()
		if is_instance_valid(attacker) and attacker.has_node("Visual"):
			death_scare = DEATH_SCARE.new()
			add_child(death_scare)
			death_scare.finished.connect(respawn)
			death_scare.start(attacker)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			retry.show()

func respawn() -> void:
	if not is_dead:
		return
	if is_instance_valid(death_scare):
		death_scare.restore_world()
		death_scare = null
	get_parent().global_transform = spawn
	get_parent().velocity = Vector3.ZERO
	health = max_health
	is_dead = false
	immunity = 1.0
	get_parent().set_physics_process(true)
	get_parent().set_process_unhandled_input(true)
	get_parent().unfreeze()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	retry.hide()
	get_tree().call_group("corrupted_friend", "reset_enemy")
	health_changed.emit(health)
	_refresh()

func _refresh() -> void:
	status.text = "HEALTH  %d / %d" % [health, max_health]
