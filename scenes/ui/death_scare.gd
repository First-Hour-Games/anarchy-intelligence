extends CanvasLayer
## The player's death: the killing lunge knocks Thomas backward, his view falls and tumbles to
## the ground in the real level, lies there a few seconds, then blacks out. CombatHealth shows
## the phone game over on finished. Only lethal hits start it.
##
## The view is a temporary RigidBody3D with a sphere collider and its own camera, started from
## the gameplay camera's exact transform; the gameplay player stays put (frozen, uncollidable)
## so retry can restore it. Speeds are clamped, the fall depth is bounded and the sequence runs
## on its own clock, so the phone appears even if the physics never settles.

## Emitted once the view has blacked out; CombatHealth then shows the game over.
signal finished
const CRT_SHADER := preload("res://shaders/crt.gdshader")
## The black bars round the TV's 4:3 picture on wide screens, in every chapter scene.
const SCREEN_BARS := &"AspectRatioBars"
const SOUNDS := {
	"wrapper": preload("res://sounds/entities/death_scares/wrapper_kill.wav"),
	"clawman": preload("res://sounds/entities/death_scares/clawman_kill.wav"),
	"ridgeback": preload("res://sounds/entities/death_scares/ridgeback_kill.wav"),
}
## Held items (pipe, flashlight body) render on this layer; the fallen view leaves them out.
const VIEWMODEL_LAYER := 2
## Head-sized collider: the camera stays this far from floors and walls.
const HEAD_RADIUS := 0.18
const HEAD_MASS := 4.5
## Knockback away from the attacker and the lift off the feet (m/s).
const KNOCKBACK_SPEED := 2.4
const KNOCKBACK_LIFT := 1.1
## Backward tip and a little sideways roll (rad/s); spin and speed are clamped to these.
const TIP_SPEED := 3.2
const ROLL_SPEED := 1.2
const MAX_SPIN := 5.0
const MAX_SPEED := 6.0
## The fall never goes deeper than this below where it started (a ledge or a hole).
const MAX_DROP := 3.0
## Seconds: tumbling, lying still, and blacking out.
const FALL_TIME := 1.2
const DOWN_TIME := 2.4
const BLACKOUT_TIME := 1.3

var viewport: Viewport
var previous_camera: Camera3D
## The temporary physics view: body, and the camera riding it.
var rig: RigidBody3D
var camera: Camera3D
var attacker_visual: Node3D
var audio: AudioStreamPlayer
var blackout: ColorRect
var hidden_layers: Array[CanvasLayer] = []
var stopped_mobs: Dictionary = {}
var entity_kind: String = ""
var elapsed: float = 0.0
var settled: bool = false
var _player: CollisionObject3D
var _player_layers := Vector2i.ZERO
var _visual_mode: ProcessMode = PROCESS_MODE_INHERIT
var _start_height: float = 0.0
var _rest := Transform3D.IDENTITY
var _finished: bool = false
var _restored: bool = false


func start(attacker: Node3D) -> void:
	# Under the CRT (100) and the save screen (99), so both still filter and cover it.
	layer = 98
	process_mode = Node.PROCESS_MODE_ALWAYS
	var player := get_parent().get_parent() as Node3D
	if is_instance_valid(attacker):
		entity_kind = "ridgeback" if attacker is CorruptedFriend else "clawman" if attacker.get("encounter_kind") == 1 else "wrapper"
	_stop_enemies(attacker)
	_hide_hud()
	blackout = ColorRect.new()
	blackout.color = Color(0, 0, 0, 0)
	blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(blackout)
	if SOUNDS.has(entity_kind):
		audio = AudioStreamPlayer.new()
		audio.bus = &"Effects"
		audio.volume_db = -3.0
		audio.stream = SOUNDS[entity_kind]
		add_child(audio)
		audio.play()
	viewport = get_viewport()
	previous_camera = viewport.get_camera_3d()
	if is_instance_valid(previous_camera) and player != null:
		_build_rig(player, attacker)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The enemies stop where they are; the killer keeps playing its lunge.
func _stop_enemies(attacker: Node3D) -> void:
	for mob: Node in get_tree().get_nodes_in_group("corrupted_friend"):
		stopped_mobs[mob] = mob.process_mode
		mob.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(attacker):
		attacker_visual = attacker.get_node_or_null("Visual") as Node3D
	if attacker_visual != null:
		_visual_mode = attacker_visual.process_mode
		attacker_visual.process_mode = Node.PROCESS_MODE_ALWAYS
		if attacker_visual.has_method("play"):
			attacker_visual.call("play", "attack")


## The HUD goes; the CRT the whole game is seen through, and the bars round its 4:3 picture, stay.
func _hide_hud() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for node: Node in scene.find_children("*", "CanvasLayer", true, false):
		var canvas := node as CanvasLayer
		if canvas != self and canvas.visible and not holds_crt(canvas) and canvas.name != SCREEN_BARS:
			hidden_layers.append(canvas)
			canvas.hide()


func _build_rig(player: Node3D, attacker: Node3D) -> void:
	var view := previous_camera.global_transform.orthonormalized()
	_start_height = view.origin.y
	rig = RigidBody3D.new()
	rig.name = "DeathFallRig"
	rig.top_level = true
	rig.mass = HEAD_MASS
	rig.continuous_cd = true
	rig.linear_damp = 0.6
	rig.angular_damp = 2.5
	var surface := PhysicsMaterial.new()
	surface.friction = 1.0
	surface.rough = true
	surface.bounce = 0.05
	rig.physics_material_override = surface
	var head := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = HEAD_RADIUS
	head.shape = sphere
	rig.add_child(head)
	camera = Camera3D.new()
	camera.fov = previous_camera.fov
	camera.near = minf(previous_camera.near, 0.05)
	camera.far = previous_camera.far
	camera.environment = previous_camera.environment
	camera.attributes = previous_camera.attributes
	camera.compositor = previous_camera.compositor
	camera.cull_mask = previous_camera.cull_mask & ~(1 << (VIEWMODEL_LAYER - 1))
	rig.add_child(camera)
	add_child(rig)
	rig.global_transform = view
	# The standing player and the killer must not shove the falling head about.
	_player = player as CollisionObject3D
	if _player != null:
		rig.add_collision_exception_with(_player)
		_player_layers = Vector2i(_player.collision_layer, _player.collision_mask)
		_player.collision_layer = 0
		_player.collision_mask = 0
	if is_instance_valid(attacker) and attacker is PhysicsBody3D:
		rig.add_collision_exception_with(attacker)
	var away := -view.basis.z
	if is_instance_valid(attacker):
		away = player.global_position - attacker.global_position
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.0001 else Vector3.BACK
	rig.linear_velocity = away * KNOCKBACK_SPEED + Vector3.UP * KNOCKBACK_LIFT
	# Tips backward (the view swings up and over) with a little roll to one side.
	var tip := Vector3.UP.cross(away).normalized()
	rig.angular_velocity = tip * TIP_SPEED + away * ROLL_SPEED * (1.0 if randf() < 0.5 else -1.0)
	camera.current = true


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(rig) or settled:
		return
	if rig.angular_velocity.length() > MAX_SPIN:
		rig.angular_velocity = rig.angular_velocity.normalized() * MAX_SPIN
	if rig.linear_velocity.length() > MAX_SPEED:
		rig.linear_velocity = rig.linear_velocity.normalized() * MAX_SPEED
	# No floor under it: stop at the bound instead of falling forever.
	if rig.global_position.y < _start_height - MAX_DROP:
		_settle()
	elif elapsed >= FALL_TIME and (rig.sleeping or rig.linear_velocity.length() < 0.25):
		_settle()
	elif elapsed >= FALL_TIME * 2.0:
		_settle()


## Lying still: physics stops and the view only breathes and drifts a little.
func _settle() -> void:
	settled = true
	rig.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	rig.freeze = true
	rig.linear_velocity = Vector3.ZERO
	rig.angular_velocity = Vector3.ZERO
	_rest = camera.transform


func _process(delta: float) -> void:
	elapsed += delta
	if settled and is_instance_valid(camera):
		var t := elapsed - FALL_TIME
		var breath := sin(t * 1.7) * 0.006
		var sway := Basis.from_euler(Vector3(sin(t * 0.9) * 0.012, sin(t * 0.6) * 0.008, sin(t * 0.75) * 0.015))
		camera.transform = Transform3D(_rest.basis * sway, _rest.origin + Vector3.UP * breath)
	var dark := clampf((elapsed - FALL_TIME - DOWN_TIME) / BLACKOUT_TIME, 0.0, 1.0)
	if is_instance_valid(blackout):
		blackout.color.a = dark
	if is_instance_valid(audio):
		audio.volume_db = lerpf(-3.0, -60.0, dark)
	if dark >= 1.0 and not _finished:
		_finish()


## Pause and the other menus wait for the next life.
func _input(event: InputEvent) -> void:
	if _finished or not event.is_pressed():
		return
	var key := event as InputEventKey
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel") \
			or (key != null and key.keycode in [KEY_ESCAPE, KEY_TAB, KEY_I]):
		get_viewport().set_input_as_handled()


func _finish() -> void:
	_finished = true
	if is_instance_valid(audio):
		audio.stop()
	finished.emit()


## True for the layer that holds the gameplay CRT filter, found the way SaveSlotScreen finds it.
static func holds_crt(canvas: CanvasLayer) -> bool:
	for node: Node in canvas.find_children("*", "ColorRect", true, false):
		var material := (node as ColorRect).material as ShaderMaterial
		if material != null and material.shader == CRT_SHADER:
			return true
	return false


## Puts the world back for retry and removes every temporary node with this layer.
func restore_world() -> void:
	if _restored:
		return
	_restored = true
	if is_instance_valid(previous_camera):
		previous_camera.make_current()
	if is_instance_valid(rig):
		rig.queue_free()
	rig = null
	camera = null
	if is_instance_valid(_player):
		_player.collision_layer = _player_layers.x
		_player.collision_mask = _player_layers.y
	if is_instance_valid(attacker_visual):
		attacker_visual.process_mode = _visual_mode
	for canvas in hidden_layers:
		if is_instance_valid(canvas):
			canvas.show()
	for mob: Node in stopped_mobs:
		if is_instance_valid(mob):
			mob.process_mode = stopped_mobs[mob]
	queue_free()
