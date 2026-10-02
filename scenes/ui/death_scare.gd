extends CanvasLayer
## A staged attacker close-up rendered in the same World3D as gameplay.
signal finished
const SOUNDS := {
	"wrapper": preload("res://sounds/entities/death_scares/wrapper_kill.wav"),
	"clawman": preload("res://sounds/entities/death_scares/clawman_kill.wav"),
	"ridgeback": preload("res://sounds/entities/death_scares/ridgeback_kill.wav"),
}
var viewport: Viewport
var previous_camera: Camera3D
var stage: Node3D
var original_visual: Node3D
var original_visible: bool
var camera: Camera3D
var actor: Node3D
var actor_mount: Node3D
var audio: AudioStreamPlayer
var retry_button: Button
var hidden_layers: Array[CanvasLayer] = []
var stopped_mobs: Dictionary = {}
var entity_kind: String
var head_skeleton: Skeleton3D
var head_bone: int = -1

func start(attacker: Node3D) -> void:
	layer = 110
	entity_kind = "ridgeback" if attacker is CorruptedFriend else "clawman" if int(attacker.get("encounter_kind")) == 1 else "wrapper"
	for mob: Node in get_tree().get_nodes_in_group("corrupted_friend"):
		stopped_mobs[mob] = mob.process_mode
		mob.process_mode = Node.PROCESS_MODE_DISABLED
	var scene := get_tree().current_scene
	if scene:
		for node: Node in scene.find_children("*", "CanvasLayer", true, false):
			var canvas := node as CanvasLayer
			if canvas != self and canvas.visible:
				hidden_layers.append(canvas)
				canvas.hide()
	viewport = get_viewport()
	previous_camera = viewport.get_camera_3d()
	var player := get_parent().get_parent() as Node3D
	var direction := attacker.global_position - player.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = -player.global_basis.z
	direction = direction.normalized()
	var distance := 1.3 if entity_kind == "wrapper" else 0.85 if entity_kind == "ridgeback" else 1.05
	stage = Node3D.new()
	get_tree().current_scene.add_child(stage)
	stage.global_transform = Transform3D(Basis(Vector3.UP, atan2(direction.x, direction.z)), player.global_position + direction * distance)
	original_visual = attacker.get_node("Visual")
	original_visible = original_visual.visible
	actor = attacker.get_node("Visual").duplicate() as Node3D
	actor_mount = Node3D.new()
	stage.add_child(actor_mount)
	actor_mount.add_child(actor)
	if entity_kind == "wrapper":
		# Keep facing outside the imported animation's root transform tracks.
		actor_mount.rotation.y = PI
		actor.rotation.y = 0.0
	actor.show()
	original_visual.hide()
	actor.position = Vector3.ZERO
	# Preserve the visual's model-specific forward correction.
	if actor.has_method("play"):
		actor.call("play", "windup" if entity_kind == "clawman" else "attack")
	else:
		var players := actor.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			var animations := players[0] as AnimationPlayer
			for clip: StringName in animations.get_animation_list():
				if "attack" in str(clip).to_lower() or "scream" in str(clip).to_lower():
					animations.play(clip)
					break
	var face := Vector3(0, 1.6, 0)
	for node: Node in actor.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		for index in skeleton.get_bone_count():
			if "head" in skeleton.get_bone_name(index).to_lower():
				head_skeleton = skeleton
				head_bone = index
				face = stage.to_local(skeleton.global_transform * skeleton.get_bone_global_pose(index).origin)
				break
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.03
	stage.add_child(camera)
	camera.position = face + Vector3(0, 0.02, -distance)
	camera.look_at(stage.to_global(face))
	camera.current = true
	var light := OmniLight3D.new()
	light.position = face + Vector3(-0.65, 0.45, -1.0)
	light.light_color = Color(0.9, 0.78, 0.65)
	light.light_energy = 1.6
	stage.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = face + Vector3(0.3, 0.05, -0.75)
	fill.light_color = Color(0.65, 0.75, 0.85)
	fill.light_energy = 1.0
	stage.add_child(fill)
	var picture := ColorRect.new()
	picture.color = Color(0, 0, 0, 0)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(picture)
	audio = AudioStreamPlayer.new()
	audio.bus = &"Effects"
	audio.volume_db = -3.0
	audio.stream = SOUNDS[entity_kind]
	add_child(audio)
	audio.play()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_property(actor_mount, "position:z", -0.48, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(actor_mount, "rotation:x", -0.09, 0.18)
	tween.tween_interval(0.85)
	tween.tween_property(audio, "volume_db", -60.0, 0.4)
	tween.parallel().tween_property(picture, "color", Color.BLACK, 0.4)
	tween.tween_callback(_show_retry)

func _process(_delta: float) -> void:
	if is_instance_valid(head_skeleton) and is_instance_valid(camera):
		var face := stage.to_local(head_skeleton.global_transform * head_skeleton.get_bone_global_pose(head_bone).origin)
		camera.position.y = face.y + 0.02
		camera.look_at(stage.to_global(face))

func _show_retry() -> void:
	audio.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)
	var title := Label.new()
	title.text = "CAUGHT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	column.add_child(title)
	retry_button = Button.new()
	retry_button.text = "RETRY FROM CHECKPOINT"
	retry_button.pressed.connect(func() -> void: finished.emit())
	column.add_child(retry_button)
	retry_button.grab_focus()

func restore_world() -> void:
	if is_instance_valid(previous_camera):
		previous_camera.make_current()
	if is_instance_valid(stage):
		stage.queue_free()
	if is_instance_valid(original_visual):
		original_visual.visible = original_visible
	for canvas in hidden_layers:
		if is_instance_valid(canvas):
			canvas.show()
	for mob: Node in stopped_mobs:
		if is_instance_valid(mob):
			mob.process_mode = stopped_mobs[mob]
	queue_free()

