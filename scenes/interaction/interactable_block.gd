@tool
class_name InteractableBlock3D extends Interactable3D

## A versatile invisible interactable volume/block.
## In the editor, displays a translucent colored box for easy positioning and scaling.
## In-game, it is invisible and triggers configurable dialogue, sounds, signals, or methods.

signal triggered(interactor: Node3D)
signal climb_over_started(player: Node3D)
signal climb_over_completed(player: Node3D)

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

@export_category("Inspection")
@export var inspection_view: Node = null

@export_category("Actions")
@export var target_node: Node = null
@export var target_method: StringName = &""
@export var method_argument: Variant = null
@export_file("*.tscn") var next_scene_path: String = "res://scenes/chapters/main/map.tscn"

@export_category("Climb Over Teleport")
## Optional NodePath to the teleport target node (e.g. Marker3D named ClimbOverTeleport).
## If empty, automatically searches the active scene for a node named "ClimbOverTeleport".
@export var climb_over_teleport: NodePath
## Duration in seconds to fade out into black when climbing over.
@export_range(0.1, 5.0, 0.1) var climb_fade_out_duration: float = 0.8
## Duration in seconds to hold in pitch black while the teleportation takes place.
@export_range(0.1, 5.0, 0.1) var climb_black_hold_duration: float = 1.8
## Duration in seconds to fade back out from black to gameplay.
@export_range(0.1, 5.0, 0.1) var climb_fade_in_duration: float = 0.8
## Optional sound effect to play during the blackout (e.g. rustle or footstep).
@export var climb_sound: AudioStream = null
## Whether to trigger a dialogue after teleporting.
@export var trigger_post_teleport_dialogue: bool = true
## Optional dialogue resource to trigger after teleportation completes. Defaults to dialogue_resource.
@export var post_teleport_dialogue_resource: DialogueResource = null
## Optional cue to trigger in post_teleport_dialogue_resource.
@export var post_teleport_dialogue_cue: String = "visitor_center_barrier_post_teleport"
## Fallback single line dialogue if resource/cue is not found.
@export_multiline var post_teleport_single_line_dialogue: String = "Placeholder text."
## Speaker name for the post-teleport single line dialogue.
@export var post_teleport_speaker_name: String = "Thomas"

var custom_callback: Callable
var _editor_mesh_instance: MeshInstance3D = null
var _static_body: StaticBody3D = null
var _collision_shape: CollisionShape3D = null
var _audio_player: AudioStreamPlayer3D = null
var _is_dialogue_active: bool = false
var _is_cooling_down: bool = false
var _is_climbing_over: bool = false
var _last_interactor: Node3D = null
var _climb_canvas: CanvasLayer = null
var _climb_tween: Tween = null


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
	if is_instance_valid(_climb_canvas):
		_climb_canvas.queue_free()
		_climb_canvas = null
	if is_instance_valid(_climb_tween) and _climb_tween.is_valid():
		_climb_tween.kill()


func get_prompt_world_position() -> Vector3:
	return to_global(prompt_offset)


func can_interact(interactor: Node3D) -> bool:
	if not is_enabled or _is_dialogue_active or _is_cooling_down or _is_climbing_over:
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

	_last_interactor = interactor

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

	# Inspection View
	var view := _get_inspection_view()
	if is_instance_valid(view) and view.has_method(&"start_inspection"):
		var player := interactor as FirstPersonPlayer
		if player == null:
			player = get_tree().get_first_node_in_group(&"player") as FirstPersonPlayer
		if is_instance_valid(player):
			view.call(&"start_inspection", player)
			if trigger_once:
				disable()
			return

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


func _get_inspection_view() -> Node:
	if is_instance_valid(inspection_view):
		return inspection_view
	if has_node("InspectableView"):
		return get_node("InspectableView")
	return null


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

	# If this block represents the forest road barrier tree, dynamically route cue based on town map possession
	if cue_to_play in ["visitor_center_barrier", "visitor_center_barrier_nomap", "visitor_center_barrier_map"]:
		var player := interactor as FirstPersonPlayer
		if not is_instance_valid(player):
			player = get_tree().get_first_node_in_group(&"player") as FirstPersonPlayer
		var player_has_map: bool = false
		if is_instance_valid(player) and player.has_method(&"has_item"):
			player_has_map = player.has_item(&"map")
		cue_to_play = "visitor_center_barrier_map" if player_has_map else "visitor_center_barrier_nomap"

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


func has_item(item_id: Variant) -> bool:
	var player := get_tree().get_first_node_in_group(&"player") as FirstPersonPlayer
	if is_instance_valid(player) and player.has_method(&"has_item"):
		return player.has_item(item_id)
	return false


func proceed(interactor: Node3D = null) -> void:
	climb_over_barrier(interactor)


func climb_over(interactor: Node3D = null) -> void:
	climb_over_barrier(interactor)


func climb_over_barrier(interactor: Node3D = null) -> void:
	if _is_climbing_over:
		return

	var player := interactor as FirstPersonPlayer
	if not is_instance_valid(player):
		player = _last_interactor as FirstPersonPlayer
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as FirstPersonPlayer

	var teleport_node := get_climb_over_teleport_node()
	var is_barrier_block: bool = (name == "BarrierTree" or dialogue_cue.begins_with("visitor_center_barrier"))

	# If a teleport node is found, or if this block is the forest barrier tree, execute climb-over fade & teleport
	if is_instance_valid(teleport_node) or is_barrier_block:
		_perform_climb_over_teleport(player, teleport_node)
		return

	# Fallback to scene change if configured for scene transition
	var target_scene := next_scene_path if not next_scene_path.is_empty() else "res://scenes/chapters/main/map.tscn"
	if ResourceLoader.exists(target_scene):
		get_tree().change_scene_to_file(target_scene)


func get_climb_over_teleport_node() -> Node3D:
	if not climb_over_teleport.is_empty():
		var explicit_node := get_node_or_null(climb_over_teleport) as Node3D
		if is_instance_valid(explicit_node):
			return explicit_node

	var current := get_tree().current_scene
	if is_instance_valid(current):
		var found := current.find_child("ClimbOverTeleport", true, false) as Node3D
		if is_instance_valid(found):
			return found

	if is_instance_valid(owner):
		var found_owner := owner.find_child("ClimbOverTeleport", true, false) as Node3D
		if is_instance_valid(found_owner):
			return found_owner

	if is_instance_valid(get_tree().root):
		var found_root := get_tree().root.find_child("ClimbOverTeleport", true, false) as Node3D
		if is_instance_valid(found_root):
			return found_root

	return null


func _find_surface_ground(pos: Vector3, upward_offset: float = 2.5, downward_depth: float = 6.0) -> Vector3:
	var world := get_world_3d()
	if not is_instance_valid(world):
		var cur_scene := get_tree().current_scene if (is_inside_tree() and get_tree()) else null
		if is_instance_valid(cur_scene) and cur_scene is Node3D:
			world = (cur_scene as Node3D).get_world_3d()
		elif is_inside_tree() and get_tree() and is_instance_valid(get_tree().root):
			world = get_tree().root.get_world_3d()

	if not is_instance_valid(world):
		return pos

	var space_state := world.direct_space_state
	if not is_instance_valid(space_state):
		return pos

	var start_pos := Vector3(pos.x, pos.y + upward_offset, pos.z)
	var end_pos := Vector3(pos.x, pos.y - downward_depth, pos.z)
	var query := PhysicsRayQueryParameters3D.create(start_pos, end_pos)

	var exclude: Array[RID] = []
	if has_method(&"get_rid"):
		exclude.append(call(&"get_rid"))
	var p := get_tree().get_first_node_in_group(&"player")
	if is_instance_valid(p) and p.has_method(&"get_rid"):
		exclude.append(p.get_rid())
	query.exclude = exclude

	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		var hit_y: float = result["position"].y
		# Position feet slightly above surface (0.005m) to cleanly contact floor without penetration
		return Vector3(pos.x, hit_y + 0.005, pos.z)

	return pos


func _perform_climb_over_teleport(player: FirstPersonPlayer, teleport_node: Node3D) -> void:
	_is_climbing_over = true
	climb_over_started.emit(player)

	if is_instance_valid(player):
		player.set_meta(&"is_climbing_over", true)
		if player.has_method(&"freeze"):
			player.freeze()

	var target_pos: Vector3
	var target_yaw: float = 0.0
	var has_target_yaw: bool = false
	var is_barrier_block: bool = (name == "BarrierTree" or dialogue_cue.begins_with("visitor_center_barrier"))

	if is_instance_valid(teleport_node):
		target_pos = teleport_node.global_position
		if not teleport_node.global_rotation.is_zero_approx():
			target_yaw = teleport_node.global_rotation.y
			has_target_yaw = true
		elif is_barrier_block:
			target_yaw = -PI * 0.5
			has_target_yaw = true
	else:
		# Fallback: On the other side of the barrier tree log along the road (+X direction)
		target_pos = Vector3(-245.5, 0.105, 10.2)
		target_yaw = -PI * 0.5
		has_target_yaw = true

	target_pos = _find_surface_ground(target_pos)

	if is_instance_valid(_climb_canvas):
		_climb_canvas.queue_free()

	_climb_canvas = CanvasLayer.new()
	_climb_canvas.name = "ClimbOverFadeCanvas"
	_climb_canvas.layer = 115

	var black_rect := ColorRect.new()
	black_rect.name = "BlackFadeRect"
	black_rect.color = Color(0, 0, 0, 0)
	black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_climb_canvas.add_child(black_rect)

	var root_target := get_tree().current_scene if is_instance_valid(get_tree().current_scene) else get_tree().root
	root_target.add_child(_climb_canvas)

	if is_instance_valid(_climb_tween) and _climb_tween.is_valid():
		_climb_tween.kill()
	_climb_tween = create_tween()

	# 1. Smooth fade to black
	_climb_tween.tween_property(
		black_rect,
		"color:a",
		1.0,
		climb_fade_out_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 2. Hold in pitch black for a few seconds and teleport player
	var hold_before := climb_black_hold_duration * 0.4
	var hold_after := climb_black_hold_duration * 0.6

	if hold_before > 0.0:
		_climb_tween.tween_interval(hold_before)

	_climb_tween.tween_callback(func() -> void:
		if is_instance_valid(player):
			var final_ground_pos := _find_surface_ground(target_pos)
			player.global_position = final_ground_pos
			player.velocity = Vector3.ZERO
			if has_target_yaw:
				player.global_rotation.y = target_yaw
			var head := player.get_node_or_null("Head") as Node3D
			if is_instance_valid(head):
				head.rotation.x = 0.0
			if player.has_method(&"apply_floor_snap"):
				player.apply_floor_snap()

		if climb_sound != null and is_instance_valid(_climb_canvas):
			var ap := AudioStreamPlayer.new()
			ap.stream = climb_sound
			ap.bus = &"SFX"
			_climb_canvas.add_child(ap)
			ap.play()
	)

	if hold_after > 0.0:
		_climb_tween.tween_interval(hold_after)

	# 3. Smooth fade back out from black
	_climb_tween.tween_property(
		black_rect,
		"color:a",
		0.0,
		climb_fade_in_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 4. Clean up and restore player control
	_climb_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(_climb_canvas):
			_climb_canvas.queue_free()
			_climb_canvas = null

		if is_instance_valid(player):
			var final_ground_pos := _find_surface_ground(player.global_position)
			player.global_position = final_ground_pos
			player.velocity = Vector3.ZERO
			player.remove_meta(&"is_climbing_over")
			if player.has_method(&"unfreeze"):
				player.unfreeze()
			if player.has_method(&"apply_floor_snap"):
				player.apply_floor_snap()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		_is_climbing_over = false
		climb_over_completed.emit(player)

		if trigger_post_teleport_dialogue:
			_play_post_teleport_dialogue(player)
	)


func finish_climb_over_immediately() -> void:
	if not _is_climbing_over:
		return
	if is_instance_valid(_climb_tween) and _climb_tween.is_valid():
		_climb_tween.kill()

	var player := _last_interactor as FirstPersonPlayer
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as FirstPersonPlayer

	var teleport_node := get_climb_over_teleport_node()
	var raw_pos := teleport_node.global_position if is_instance_valid(teleport_node) else Vector3(-245.5, 0.105, 10.2)
	var target_pos := _find_surface_ground(raw_pos)

	if is_instance_valid(player):
		player.global_position = target_pos
		player.velocity = Vector3.ZERO
		if is_instance_valid(teleport_node) and not teleport_node.global_rotation.is_zero_approx():
			player.global_rotation.y = teleport_node.global_rotation.y
		else:
			player.global_rotation.y = -PI * 0.5
		var head := player.get_node_or_null("Head") as Node3D
		if is_instance_valid(head):
			head.rotation.x = 0.0
		player.remove_meta(&"is_climbing_over")
		if player.has_method(&"unfreeze"):
			player.unfreeze()
		if player.has_method(&"apply_floor_snap"):
			player.apply_floor_snap()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if is_instance_valid(_climb_canvas):
		_climb_canvas.queue_free()
		_climb_canvas = null

	_is_climbing_over = false
	climb_over_completed.emit(player)

	if trigger_post_teleport_dialogue:
		_play_post_teleport_dialogue(player)


func play_post_teleport_dialogue(player: FirstPersonPlayer = null) -> void:
	_play_post_teleport_dialogue(player)


func _play_post_teleport_dialogue(interactor: Node3D = null) -> void:
	if not trigger_post_teleport_dialogue:
		return

	var player := interactor as FirstPersonPlayer
	if not is_instance_valid(player):
		player = _last_interactor as FirstPersonPlayer
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as FirstPersonPlayer

	var res_to_play: DialogueResource = post_teleport_dialogue_resource
	if res_to_play == null:
		res_to_play = dialogue_resource

	var cue_to_play: String = post_teleport_dialogue_cue
	if cue_to_play.is_empty():
		if name == "BarrierTree" or dialogue_cue.begins_with("visitor_center_barrier"):
			cue_to_play = "visitor_center_barrier_post_teleport"
		else:
			cue_to_play = "start"

	var cue_exists: bool = false
	if is_instance_valid(res_to_play):
		cue_exists = res_to_play.get_cues().has(cue_to_play)

	if not cue_exists:
		var dm := Engine.get_singleton("DialogueManager")
		if dm:
			var speaker := post_teleport_speaker_name.strip_edges()
			if speaker.is_empty():
				speaker = "Thomas"
			var text_line := post_teleport_single_line_dialogue.strip_edges()
			if text_line.is_empty():
				text_line = "Placeholder text."
			var script_text := "~ start\n%s: %s\n=> END" % [speaker, text_line]
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
	if is_instance_valid(player):
		extra_states.append(player)

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
