@tool
class_name InteractableBlock3D extends Interactable3D

## A versatile invisible interactable volume/block.
## In the editor, displays a translucent colored box for easy positioning and scaling.
## In-game, it is invisible and triggers configurable dialogue, sounds, signals, or methods.

signal triggered(interactor: Node3D)

@export_category("Block Shape")
@export var size: Vector3 = Vector3(1.5, 2.0, 0.8):
	set(value):
		size = value
		_update_shape()
		if is_instance_valid(_collision_shape) and _collision_shape.shape is BoxShape3D:
			(_collision_shape.shape as BoxShape3D).size = size

@export var prompt_offset: Vector3 = Vector3.ZERO:
	set(value):
		prompt_offset = value
		_update_shape()

@export var show_in_editor: bool = true:
	set(value):
		show_in_editor = value
		_update_shape()

@export var editor_color: Color = Color(0.2, 0.75, 1.0, 0.3):
	set(value):
		editor_color = value
		_update_shape()

@export_category("Collision")
@export var has_collision: bool = false:
	set(value):
		has_collision = value
		_update_collision()

@export_flags_3d_physics var collision_layer: int = 1
@export_flags_3d_physics var collision_mask: int = 1

@export_category("State")
@export var is_enabled: bool = true
@export var trigger_once: bool = false
@export_range(0.0, 5.0, 0.1) var cooldown: float = 0.8

@export_category("Dialogue")
@export var dialogue_resource: DialogueResource = null
@export var dialogue_cue: String = ""
@export_multiline var single_line_dialogue: String = ""
@export var speaker_name: String = "Thomas"
@export var dialogue_balloon_scene: PackedScene = preload("res://scenes/ui/dialogue_box/bottom_dialogue_balloon.tscn")
@export var freeze_player_during_dialogue: bool = true

@export_category("Audio")
@export var interaction_sound: AudioStream = null
@export_range(-40.0, 6.0, 0.5) var sound_volume_db: float = 0.0
@export_range(1.0, 50.0, 0.5) var sound_max_distance: float = 15.0
@export var sound_bus: StringName = &"SFX"

@export_category("Actions")
@export var target_node: Node = null
@export var target_method: StringName = &""
@export var method_argument: Variant = null

var custom_callback: Callable
var _editor_mesh_instance: MeshInstance3D = null
var _static_body: StaticBody3D = null
var _collision_shape: CollisionShape3D = null
var _audio_player: AudioStreamPlayer3D = null
var _is_dialogue_active: bool = false
var _is_cooling_down: bool = false


func _ready() -> void:
	# Interactable3D adds to group &"interactable" in its _ready
	super._ready()

	if Engine.is_editor_hint():
		_update_shape()
	else:
		_cleanup_editor_visuals()
		_setup_runtime_audio()
		_setup_runtime_collision()


func _exit_tree() -> void:
	if is_instance_valid(_editor_mesh_instance):
		_editor_mesh_instance.queue_free()
		_editor_mesh_instance = null


func get_prompt_world_position() -> Vector3:
	return to_global(prompt_offset)


func can_interact(interactor: Node3D) -> bool:
	if not is_enabled or _is_dialogue_active or _is_cooling_down:
		return false

	if not is_instance_valid(interactor):
		return false

	# Check distance to the oriented bounding box in local space
	var local_pos := to_local(interactor.global_position)
	var half_size := size * 0.5
	var clamped := Vector3(
		clampf(local_pos.x, -half_size.x, half_size.x),
		clampf(local_pos.y, -half_size.y, half_size.y),
		clampf(local_pos.z, -half_size.z, half_size.z)
	)
	var dist_to_box := local_pos.distance_to(clamped)
	return dist_to_box <= interaction_distance


func interact(interactor: Node3D) -> void:
	if not can_interact(interactor):
		return

	if cooldown > 0.0:
		_is_cooling_down = true
		get_tree().create_timer(cooldown).timeout.connect(func() -> void:
			_is_cooling_down = false
		)

	# Emit standard signals
	interacted.emit(interactor)
	triggered.emit(interactor)
	print(interaction_message)

	# Sound
	_play_sound()

	# Custom invocation
	_invoke_target(interactor)
	if custom_callback.is_valid():
		if custom_callback.get_argument_count() > 0:
			custom_callback.call(interactor)
		else:
			custom_callback.call()

	# Dialogue
	_play_dialogue(interactor)

	# Disable if single-use
	if trigger_once:
		disable()


func disable() -> void:
	is_enabled = false
	remove_from_group(&"interactable")


func enable() -> void:
	is_enabled = true
	if not is_in_group(&"interactable"):
		add_to_group(&"interactable")


func _play_sound() -> void:
	if is_instance_valid(_audio_player) and interaction_sound != null:
		_audio_player.play()


func _invoke_target(interactor: Node3D) -> void:
	if not is_instance_valid(target_node) or target_method.is_empty():
		return

	if not target_node.has_method(target_method):
		push_warning("InteractableBlock3D: Target node does not have method '%s'" % target_method)
		return

	if method_argument != null:
		target_node.call(target_method, method_argument)
	else:
		# Check if method accepts an argument
		var method_list := target_node.get_method_list()
		var takes_arg := false
		for m in method_list:
			if m.name == String(target_method):
				takes_arg = (m.args.size() > 0)
				break
		if takes_arg:
			target_node.call(target_method, interactor)
		else:
			target_node.call(target_method)


func _play_dialogue(interactor: Node3D = null) -> void:
	var res_to_play: DialogueResource = dialogue_resource
	var cue_to_play: String = dialogue_cue

	# If no resource provided, but a single line is set, compile on the fly
	if res_to_play == null and not single_line_dialogue.strip_edges().is_empty():
		var dm := Engine.get_singleton("DialogueManager")
		if dm:
			var speaker := speaker_name.strip_edges()
			if speaker.is_empty():
				speaker = "Thomas"
			var script_text := "~ start\n%s: %s\n=> END" % [speaker, single_line_dialogue]
			res_to_play = dm.create_resource_from_text(script_text)
			cue_to_play = "start"

	if res_to_play == null:
		return

	var balloon_scene := dialogue_balloon_scene
	if balloon_scene == null:
		balloon_scene = load("res://scenes/ui/dialogue_box/bottom_dialogue_balloon.tscn") as PackedScene

	if balloon_scene == null:
		return

	var balloon := balloon_scene.instantiate()
	if balloon.get("freeze_player") != null:
		balloon.set("freeze_player", freeze_player_during_dialogue)

	var root_target := get_tree().current_scene if is_instance_valid(get_tree().current_scene) else get_tree().root
	root_target.add_child(balloon)

	_is_dialogue_active = true

	if balloon.has_signal("dialogue_finished"):
		balloon.connect("dialogue_finished", func() -> void:
			_is_dialogue_active = false
		, CONNECT_ONE_SHOT)
	elif Engine.has_singleton("DialogueManager"):
		Engine.get_singleton("DialogueManager").dialogue_ended.connect(func(_res: DialogueResource) -> void:
			_is_dialogue_active = false
		, CONNECT_ONE_SHOT)

	var extra_states: Array = [self]
	if is_instance_valid(interactor):
		extra_states.append(interactor)

	if balloon.has_method(&"start"):
		balloon.start(res_to_play, cue_to_play, extra_states)


func _update_shape() -> void:
	if not Engine.is_editor_hint():
		return

	if not show_in_editor:
		if is_instance_valid(_editor_mesh_instance):
			_editor_mesh_instance.visible = false
		return

	if not is_instance_valid(_editor_mesh_instance):
		_editor_mesh_instance = MeshInstance3D.new()
		_editor_mesh_instance.name = "_EditorBoxPreview"
		_editor_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_editor_mesh_instance)

	var box_mesh: BoxMesh
	if _editor_mesh_instance.mesh is BoxMesh:
		box_mesh = _editor_mesh_instance.mesh as BoxMesh
	else:
		box_mesh = BoxMesh.new()
		_editor_mesh_instance.mesh = box_mesh

	box_mesh.size = size

	var mat: StandardMaterial3D
	if box_mesh.material is StandardMaterial3D:
		mat = box_mesh.material as StandardMaterial3D
	else:
		mat = StandardMaterial3D.new()
		box_mesh.material = mat

	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = editor_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_editor_mesh_instance.visible = true


func _cleanup_editor_visuals() -> void:
	if is_instance_valid(_editor_mesh_instance):
		_editor_mesh_instance.queue_free()
		_editor_mesh_instance = null
	var existing := get_node_or_null("_EditorBoxPreview")
	if is_instance_valid(existing):
		existing.queue_free()


func _setup_runtime_audio() -> void:
	if interaction_sound != null:
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "InteractionAudio"
		_audio_player.stream = interaction_sound
		_audio_player.volume_db = sound_volume_db
		_audio_player.max_distance = sound_max_distance
		_audio_player.bus = sound_bus
		add_child(_audio_player)


func _setup_runtime_collision() -> void:
	if not has_collision:
		return

	_static_body = StaticBody3D.new()
	_static_body.name = "CollisionBody"
	_static_body.collision_layer = collision_layer
	_static_body.collision_mask = collision_mask

	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	_collision_shape.shape = box

	_static_body.add_child(_collision_shape)
	add_child(_static_body)


func _update_collision() -> void:
	if Engine.is_editor_hint():
		return
	if has_collision and not is_instance_valid(_static_body):
		_setup_runtime_collision()
	elif not has_collision and is_instance_valid(_static_body):
		_static_body.queue_free()
		_static_body = null
