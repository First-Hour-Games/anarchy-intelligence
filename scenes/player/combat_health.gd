extends Node
## Optional health/respawn component; existing movement controller is unchanged.
signal health_changed(value: float)
@export var max_health: float = 100.0
@export_range(-40.0, 6.0, 0.5) var impact_volume_db: float = -3.0
const IMPACT_SOUNDS: Array[AudioStream] = [
	preload("res://sounds/player/impact/punching_short_impact_hits_1.ogg"),
	preload("res://sounds/player/impact/punching_short_impact_hits_2.ogg"),
	preload("res://sounds/player/impact/punching_short_impact_hits_3.ogg"),
	preload("res://sounds/player/impact/punching_short_impact_hits_4.ogg"),
	preload("res://sounds/player/impact/punching_short_impact_hits_5.ogg"),
	preload("res://sounds/player/impact/punching_short_impact_hits_6.ogg"),
	preload("res://sounds/player/impact/punching_short_impact_hits_7.ogg"),
	preload("res://sounds/player/impact/punching_short_impact_hits_8.ogg"),
	preload("res://sounds/player/impact/punching_short_impact_hits_9.ogg"),
]
var impact_audio: AudioStreamPlayer
var health: float = 100.0
var is_dead: bool = false
var immunity: float = 0.0
var spawn: Transform3D
var status: Label
## The knockdown after a lethal hit (death_scare.gd): falls, lies still, blacks out.
var death_scare: CanvasLayer
## The ringing phone after a death; its TRY AGAIN comes back here as respawn().
var game_over: CanvasLayer
const DEATH_SCARE := preload("res://scenes/ui/death_scare.gd")
const PHONE_GAME_OVER := preload("res://scenes/ui/game_over/phone_game_over.gd")
const ACCUM_BLUR := preload("res://scenes/player/accum_blur_effect.gd")
## Hit daze: strong motion blur and camera shake that fade out after a hit.
const DAZE_TIME := 3.2
const DAZE_BLUR := 0.94
const DAZE_ROLL := deg_to_rad(6.0)
var daze: float = 0.0
var daze_blur: CompositorEffect
var daze_camera: Camera3D

func _ready() -> void:
	health = max_health
	spawn = get_parent().global_transform
	var impacts := AudioStreamRandomizer.new()
	impacts.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	for sound in IMPACT_SOUNDS:
		impacts.add_stream(-1, sound)
	impact_audio = AudioStreamPlayer.new()
	impact_audio.name = "ImpactAudio"
	impact_audio.stream = impacts
	impact_audio.bus = &"Effects"
	add_child(impact_audio)
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
	_setup_daze()
	_refresh()

func _setup_daze() -> void:
	daze_camera = get_parent().get_node_or_null("Head/Camera3D") as Camera3D
	if not daze_camera:
		return
	if not daze_camera.compositor:
		daze_camera.compositor = Compositor.new()
	daze_blur = ACCUM_BLUR.new()
	var effects := daze_camera.compositor.compositor_effects.duplicate()
	effects.append(daze_blur)
	daze_camera.compositor.compositor_effects = effects

func _apply_daze() -> void:
	var fade := daze
	if daze_blur:
		daze_blur.set(&"alpha", DAZE_BLUR * fade)
	if daze_camera:
		var t := Time.get_ticks_msec() * 0.001
		daze_camera.rotation.z = sin(t * 8.0) * DAZE_ROLL * fade

func _process(delta: float) -> void:
	immunity = maxf(0.0, immunity - delta)
	if daze > 0.0:
		daze = maxf(0.0, daze - delta / DAZE_TIME)
		_apply_daze()

func take_damage(amount: float, attacker: Node3D = null) -> void:
	if is_dead or immunity > 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	immunity = 0.6
	if is_instance_valid(attacker):
		impact_audio.volume_db = impact_volume_db
		impact_audio.play()
	health_changed.emit(health)
	_refresh()
	if health > 0.0:
		InputDevice.rumble_pad(0.35, 0.65, 0.25)
		daze = 1.0
		_apply_daze()
	if health == 0.0:
		var spot := get_parent().get("hiding_spot") as Node3D
		if is_instance_valid(spot):
			spot.force_out()
		is_dead = true
		daze = 0.0
		_apply_daze()
		InputDevice.rumble_pad(0.8, 1.0, 0.7)
		get_parent().set_physics_process(false)
		get_parent().set_process_unhandled_input(false)
		# Never two at once: anything left from an earlier death goes first.
		if is_instance_valid(death_scare):
			death_scare.restore_world()
		if is_instance_valid(game_over):
			game_over.queue_free()
		death_scare = DEATH_SCARE.new()
		add_child(death_scare)
		death_scare.finished.connect(_show_game_over, CONNECT_ONE_SHOT)
		# Before freezing, which snaps the body to the ground: the fall starts from the view as it was.
		death_scare.start(attacker)
		get_parent().freeze()

func _show_game_over() -> void:
	if is_instance_valid(game_over) or not is_dead:
		return
	# The view has blacked out; the phone screen takes over from it.
	if is_instance_valid(death_scare):
		death_scare.hide()
	game_over = PHONE_GAME_OVER.new()
	game_over.try_again.connect(respawn)
	add_child(game_over)

func respawn() -> void:
	if not is_dead:
		return
	if is_instance_valid(game_over):
		game_over.queue_free()
		game_over = null
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
	get_tree().call_group("corrupted_friend", "reset_enemy")
	health_changed.emit(health)
	_refresh()

func _refresh() -> void:
	status.text = "HEALTH  %d / %d" % [health, max_health]
