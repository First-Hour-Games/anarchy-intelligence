@tool
class_name MapBoundaryZone3D extends Area3D

## A modular 3D boundary and zone system for maps.
## Defines an area where player movement is constrained or monitored.
## Enabled ALLOWED_PLAY_AREA zones combine into one playable area. Leaving all of them triggers a warning dialogue
## reminding the player not to go too far and to return back.
## Supports an eyelid blink transition after the dialogue that teleports the player back
## inside near the boundary edge facing inwards towards the zone center.
## In the Godot editor, it displays a translucent colored box for easy positioning, resizing, and rotation.

signal player_entered_zone(player: Node3D)
signal player_exited_zone(player: Node3D)
signal boundary_warning_triggered(player: Node3D, message: String)
signal player_returned_to_bounds(player: Node3D, new_position: Vector3)

enum ZoneBehavior {
	ALLOWED_PLAY_AREA,  ## Player should stay inside this volume. Leaving it triggers the boundary warning.
	RESTRICTED_AREA,    ## Player should NOT enter this volume. Entering it triggers the boundary warning.
}

@export_category("Zone Behavior")
@export var zone_behavior: ZoneBehavior = ZoneBehavior.ALLOWED_PLAY_AREA
@export var is_enabled: bool = true
@export var trigger_once: bool = false
@export_range(0.0, 15.0, 0.5) var cooldown: float = 3.0

@export_category("Zone Shape")
@export var size: Vector3 = Vector3(20.0, 6.0, 20.0):
	set(value):
		size = value
		_update_collision_shape()
		_update_preview()

@export var zone_color: Color = Color(1.0, 0.55, 0.1, 0.25):
	set(value):
		zone_color = value
		_update_preview()

@export var show_in_editor: bool = true:
	set(value):
		show_in_editor = value
		_update_preview()

## If true, renders the translucent boundary box in-game as well, which is great for testing and level tuning.
@export var show_in_game_debug: bool = false:
	set(value):
		show_in_game_debug = value
		_update_preview()

@export_category("Dialogue")
@export var dialogue_resource: DialogueResource = null
@export var dialogue_cue: String = "start"
@export_multiline var single_line_dialogue: String = "I shouldn't go this far. I should return back."
@export var dialogue_variations: Array[String] = [
	"I shouldn't go this far. I should return back.",
	"I shouldn't go this far. I need to head back.",
	"There is nothing out this far. I should turn back."
]
@export var speaker_name: String = "Thomas"
@export var dialogue_balloon_scene: PackedScene = preload("res://scenes/ui/dialogue_box/bottom_dialogue_balloon.tscn")
@export var freeze_player_during_dialogue: bool = true

@export_category("Blink & Return")
## If enabled, plays an eyelid blink transition after the dialogue and teleports the player back inside near the boundary edge facing inwards.
@export var blink_and_return: bool = true
## Distance in meters inside the boundary edge to teleport the player back to.
@export_range(0.2, 5.0, 0.1) var teleport_inset: float = 1.5
@export var blink_sound: AudioStream = preload("res://sounds/player/blink.mp3")
@export_range(-40.0, 6.0, 0.5) var blink_sound_volume_db: float = 0.0
@export var blink_sound_bus: StringName = &"Master"
@export var blink_close_duration: float = 0.18
@export var blink_hold_duration: float = 0.12
@export var blink_open_duration: float = 0.22

@export_category("Player Reaction")
## If enabled, softly nudges the player back towards the zone center when warning triggers.
@export var push_back_player: bool = false
@export_range(0.5, 20.0, 0.5) var push_back_force: float = 3.5

@export_category("Audio")
@export var warning_sound: AudioStream = null
@export_range(-40.0, 6.0, 0.5) var sound_volume_db: float = 0.0
@export_range(1.0, 50.0, 0.5) var sound_max_distance: float = 20.0
@export var sound_bus: StringName = &"SFX"

var _editor_mesh_instance: MeshInstance3D = null
var _collision_shape: CollisionShape3D = null
var _audio_player: AudioStreamPlayer3D = null

var _blink_canvas: CanvasLayer = null
var _top_eyelid: ColorRect = null
var _bottom_eyelid: ColorRect = null
var _blink_audio_player: AudioStreamPlayer = null

var _player_inside: bool = false
var _is_dialogue_active: bool = false
var _is_cooling_down: bool = false
var _trigger_count: int = 0
var _cached_player: Node3D = null
var _last_allowed_warning_frame: int = -1


func _enter_tree() -> void:
	add_to_group(&"map_boundary_zones")


func _ready() -> void:
	# Ensure Area3D collision settings
	if collision_mask == 0:
		collision_mask = 1  # Detect default player collision layer

	_update_collision_shape()

	if Engine.is_editor_hint():
		_update_preview()
		return

	# Runtime setup
	if is_instance_valid(_collision_shape) and is_instance_valid(_collision_shape.shape):
		_collision_shape.shape = _collision_shape.shape.duplicate()

	if show_in_game_debug:
		_update_preview()
	else:
		_cleanup_preview()

	_setup_runtime_audio()
	if blink_and_return:
		_setup_blink_ui()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_check_initial_overlap.call_deferred()


func _exit_tree() -> void:
	if Engine.is_editor_hint() and is_instance_valid(_editor_mesh_instance):
		_editor_mesh_instance.queue_free()
		_editor_mesh_instance = null
	if is_instance_valid(_blink_canvas):
		_blink_canvas.queue_free()
		_blink_canvas = null


## Check whether a global 3D point lies inside this zone's oriented bounding box.
func is_point_inside(global_pos: Vector3) -> bool:
	var local_pos := to_local(global_pos)
	var half_size := size * 0.5
	return absf(local_pos.x) <= half_size.x and \
		   absf(local_pos.y) <= half_size.y and \
		   absf(local_pos.z) <= half_size.z


func _check_initial_overlap() -> void:
	if not is_inside_tree():
		return

	await get_tree().physics_frame
	if not is_inside_tree():
		return

	# Check overlapping physics bodies
	for body in get_overlapping_bodies():
		if _is_player(body):
			_player_inside = true
			_cached_player = body
			break

	# Fallback: check player position directly in case physics contact has not ticked yet
	if not _player_inside:
		var p := get_tree().get_first_node_in_group(&"player") as Node3D
		if is_instance_valid(p) and is_point_inside(p.global_position):
			_player_inside = true
			_cached_player = p


func _is_player(body: Node3D) -> bool:
	if not is_instance_valid(body):
		return false
	if body.is_in_group(&"player") or body.is_in_group("player"):
		return true
	if body is FirstPersonPlayer:
		return true
	if body.name == "Player":
		return true
	if body.has_method(&"freeze") and body.has_method(&"unfreeze"):
		return true
	return false


func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return

	_player_inside = true
	_cached_player = body
	player_entered_zone.emit(body)

	if zone_behavior == ZoneBehavior.RESTRICTED_AREA:
		trigger_warning(body)


func _on_body_exited(body: Node3D) -> void:
	if not _is_player(body):
		return

	_player_inside = false
	_cached_player = body
	player_exited_zone.emit(body)

	if zone_behavior == ZoneBehavior.ALLOWED_PLAY_AREA:
		# Physics may emit exits before entries when crossing between overlapping zones.
		# Evaluate geometry after the signal batch rather than relying on overlap flags.
		_check_allowed_area_exit.call_deferred(body)


func _get_enabled_allowed_zones() -> Array[MapBoundaryZone3D]:
	var zones: Array[MapBoundaryZone3D] = []
	if not is_inside_tree():
		return zones
	for candidate in get_tree().get_nodes_in_group(&"map_boundary_zones"):
		if candidate is MapBoundaryZone3D and not candidate.is_queued_for_deletion():
			if candidate.is_enabled and candidate.zone_behavior == ZoneBehavior.ALLOWED_PLAY_AREA:
				zones.append(candidate)
	return zones


func _check_allowed_area_exit(player: Node3D) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(player) or not player.is_inside_tree():
		return
	if not is_enabled or zone_behavior != ZoneBehavior.ALLOWED_PLAY_AREA:
		return
	var zones := _get_enabled_allowed_zones()
	for zone in zones:
		if zone.is_point_inside(player.global_position):
			return
	# A single outside transition may produce exits from several overlapping zones.
	# Share active dialogue/cooldown suppression for this player across allowed zones.
	var frame := Engine.get_physics_frames()
	for zone in zones:
		if zone._cached_player == player and (zone._is_dialogue_active or zone._is_cooling_down or zone._last_allowed_warning_frame == frame):
			return
	var previous_count := _trigger_count
	trigger_warning(player)
	if _trigger_count > previous_count:
		_last_allowed_warning_frame = frame


## Manually trigger or execute the boundary warning logic.
func trigger_warning(interactor: Node3D = null) -> void:
	if not is_enabled:
		return
	if trigger_once and _trigger_count > 0:
		return
	if _is_cooling_down or _is_dialogue_active:
		return

	_trigger_count += 1

	if cooldown > 0.0:
		_is_cooling_down = true
		get_tree().create_timer(cooldown).timeout.connect(func() -> void:
			_is_cooling_down = false
		)

	var text := _get_dialogue_text()
	boundary_warning_triggered.emit(interactor, text)

	_play_sound()

	if push_back_player and is_instance_valid(interactor) and interactor is CharacterBody3D:
		_apply_pushback(interactor as CharacterBody3D)

	_play_dialogue(interactor, text)


func _apply_pushback(player: CharacterBody3D) -> void:
	var dir := (global_position - player.global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		dir = dir.normalized()
		player.velocity += dir * push_back_force


func _get_dialogue_text() -> String:
	if not dialogue_variations.is_empty():
		var idx := randi() % dialogue_variations.size()
		return dialogue_variations[idx]
	return single_line_dialogue


func _play_sound() -> void:
	if is_instance_valid(_audio_player):
		_audio_player.play()


func _play_dialogue(interactor: Node3D = null, custom_text: String = "") -> void:
	if not is_inside_tree():
		return

	var res_to_play: DialogueResource = dialogue_resource
	var cue_to_play: String = dialogue_cue

	var dm: Object = null
	if Engine.has_singleton("DialogueManager"):
		dm = Engine.get_singleton("DialogueManager")
	elif is_instance_valid(get_tree()) and is_instance_valid(get_tree().root) and get_tree().root.has_node("DialogueManager"):
		dm = get_tree().root.get_node("DialogueManager")

	# Compile single line or variation on the fly if no pre-compiled DialogueResource provided
	if res_to_play == null:
		var text_to_use := custom_text if not custom_text.strip_edges().is_empty() else _get_dialogue_text()
		if text_to_use.strip_edges().is_empty():
			return

		if dm and dm.has_method(&"create_resource_from_text"):
			var speaker := speaker_name.strip_edges()
			if speaker.is_empty():
				speaker = "Thomas"
			var script_text := "~ start\n%s: %s\n=> END" % [speaker, text_to_use]
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

	var root_target: Node = get_tree().current_scene if is_instance_valid(get_tree().current_scene) else get_tree().root
	if not is_instance_valid(root_target):
		return

	_is_dialogue_active = true

	var extra_states: Array = [self]
	if is_instance_valid(interactor):
		extra_states.append(interactor)

	root_target.add_child.call_deferred(balloon)
	balloon.ready.connect(func() -> void:
		var target_player := interactor
		if not is_instance_valid(target_player):
			target_player = _cached_player
		if not is_instance_valid(target_player) and is_inside_tree():
			target_player = get_tree().get_first_node_in_group(&"player")

		var on_dialogue_finished := func() -> void:
			if blink_and_return and is_instance_valid(target_player):
				_play_blink_and_teleport(target_player)
			else:
				_is_dialogue_active = false

		if balloon.has_signal("dialogue_finished"):
			balloon.connect("dialogue_finished", on_dialogue_finished, CONNECT_ONE_SHOT)
		elif dm and dm.has_signal("dialogue_ended"):
			dm.dialogue_ended.connect(func(_res: DialogueResource) -> void:
				on_dialogue_finished.call()
			, CONNECT_ONE_SHOT)

		if balloon.has_method(&"start"):
			balloon.start(res_to_play, cue_to_play, extra_states)
	, CONNECT_ONE_SHOT)


func _setup_blink_ui() -> void:
	if is_instance_valid(_blink_canvas):
		return

	_blink_canvas = CanvasLayer.new()
	_blink_canvas.name = "ZoneBlinkCanvas"
	_blink_canvas.layer = 60
	add_child(_blink_canvas)

	var blink_container := Control.new()
	blink_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blink_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blink_canvas.add_child(blink_container)

	_top_eyelid = ColorRect.new()
	_top_eyelid.name = "TopEyelid"
	_top_eyelid.color = Color.BLACK
	_top_eyelid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blink_container.add_child(_top_eyelid)

	_bottom_eyelid = ColorRect.new()
	_bottom_eyelid.name = "BottomEyelid"
	_bottom_eyelid.color = Color.BLACK
	_bottom_eyelid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blink_container.add_child(_bottom_eyelid)

	_reset_eyelids()
	_blink_canvas.visible = false


func _reset_eyelids() -> void:
	if is_instance_valid(_top_eyelid):
		_top_eyelid.anchor_left = 0.0
		_top_eyelid.anchor_right = 1.0
		_top_eyelid.anchor_top = 0.0
		_top_eyelid.anchor_bottom = 0.0
		_top_eyelid.offset_left = 0.0
		_top_eyelid.offset_right = 0.0
		_top_eyelid.offset_top = 0.0
		_top_eyelid.offset_bottom = 0.0
	if is_instance_valid(_bottom_eyelid):
		_bottom_eyelid.anchor_left = 0.0
		_bottom_eyelid.anchor_right = 1.0
		_bottom_eyelid.anchor_top = 1.0
		_bottom_eyelid.anchor_bottom = 1.0
		_bottom_eyelid.offset_left = 0.0
		_bottom_eyelid.offset_right = 0.0
		_bottom_eyelid.offset_top = 0.0
		_bottom_eyelid.offset_bottom = 0.0


func _play_blink_sound() -> void:
	var sound: AudioStream = blink_sound
	if sound == null:
		sound = preload("res://sounds/player/blink.mp3")
	if sound == null:
		return

	if not is_instance_valid(_blink_audio_player):
		_blink_audio_player = AudioStreamPlayer.new()
		_blink_audio_player.name = "BlinkAudioPlayer"
		_blink_audio_player.bus = blink_sound_bus
		add_child(_blink_audio_player)

	_blink_audio_player.stream = sound
	_blink_audio_player.volume_db = blink_sound_volume_db
	_blink_audio_player.bus = blink_sound_bus
	_blink_audio_player.play()


## Performs the eyelid blink animation, and while blacked out teleports the player inside near the boundary edge facing inwards.
func _play_blink_and_teleport(player: Node3D) -> void:
	if not is_inside_tree():
		return

	if not is_instance_valid(player):
		_is_dialogue_active = false
		return

	# Freeze player during the blink transition
	if player.has_method(&"freeze"):
		player.freeze()

	_play_blink_sound()

	if not is_instance_valid(_blink_canvas):
		_setup_blink_ui()

	if not is_instance_valid(_blink_canvas) or not is_instance_valid(_top_eyelid) or not is_instance_valid(_bottom_eyelid):
		# Fallback if UI creation failed
		_teleport_player_inwards(player)
		if player.has_method(&"unfreeze"):
			player.unfreeze()
		_is_dialogue_active = false
		return

	_reset_eyelids()
	_blink_canvas.visible = true

	# 1. Close eyelids
	var close_tween := create_tween()
	close_tween.set_parallel(true)
	close_tween.tween_property(_top_eyelid, "anchor_bottom", 0.505, blink_close_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	close_tween.tween_property(_bottom_eyelid, "anchor_top", 0.495, blink_close_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await close_tween.finished

	if not is_inside_tree():
		return

	# 2. Hold on black for brief moment
	if blink_hold_duration > 0.0:
		await get_tree().create_timer(blink_hold_duration, false).timeout
		if not is_inside_tree():
			return

	# 3. Teleport and face inwards while fully blacked out!
	_teleport_player_inwards(player)

	# 4. Open eyelids
	var open_tween := create_tween()
	open_tween.set_parallel(true)
	open_tween.tween_property(_top_eyelid, "anchor_bottom", 0.0, blink_open_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	open_tween.tween_property(_bottom_eyelid, "anchor_top", 1.0, blink_open_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await open_tween.finished

	if not is_inside_tree():
		return

	# 5. Finish and cleanup
	_reset_eyelids()
	if is_instance_valid(_blink_canvas):
		_blink_canvas.visible = false

	if player.has_method(&"unfreeze"):
		player.unfreeze()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_is_dialogue_active = false


## Teleports the player back within near the boundary edge they exited from, but inside, and facing inwards towards the zone center.
func _teleport_player_inwards(player: Node3D) -> void:
	if not is_instance_valid(player):
		return

	var half_size := size * 0.5
	var local_pos := to_local(player.global_position)

	var max_inner_x := maxf(0.0, half_size.x - teleport_inset)
	var max_inner_z := maxf(0.0, half_size.z - teleport_inset)
	var max_inner_y := maxf(0.0, half_size.y - 0.2)

	# Clamp to be inside the boundary near the edge
	local_pos.x = clampf(local_pos.x, -max_inner_x, max_inner_x)
	local_pos.z = clampf(local_pos.z, -max_inner_z, max_inner_z)
	local_pos.y = clampf(local_pos.y, -max_inner_y, max_inner_y)

	var target_pos := to_global(local_pos)

	# Calculate inward direction towards the center of the zone
	var center_global := to_global(Vector3(0.0, local_pos.y, 0.0))
	var inward_dir := center_global - target_pos
	inward_dir.y = 0.0

	var target_yaw: float = player.rotation.y
	if inward_dir.length_squared() > 0.0001:
		inward_dir = inward_dir.normalized()
		target_yaw = atan2(-inward_dir.x, -inward_dir.z)

	player.global_position = target_pos
	player.rotation.y = target_yaw

	# Level camera view horizontally
	if player.get("head") != null and player.head is Node3D:
		player.head.rotation.x = 0.0
	elif player.get_node_or_null("Head") != null:
		(player.get_node_or_null("Head") as Node3D).rotation.x = 0.0

	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO

	_player_inside = true
	player_returned_to_bounds.emit(player, target_pos)


func _update_collision_shape() -> void:
	if not is_instance_valid(_collision_shape):
		_collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
		if not is_instance_valid(_collision_shape):
			for child in get_children():
				if child is CollisionShape3D:
					_collision_shape = child
					break
		if not is_instance_valid(_collision_shape):
			_collision_shape = CollisionShape3D.new()
			_collision_shape.name = "CollisionShape3D"
			add_child(_collision_shape)
			if Engine.is_editor_hint() and is_inside_tree() and is_instance_valid(get_tree().edited_scene_root):
				_collision_shape.owner = get_tree().edited_scene_root

	var box_shape: BoxShape3D
	if _collision_shape.shape is BoxShape3D:
		box_shape = _collision_shape.shape as BoxShape3D
	else:
		box_shape = BoxShape3D.new()
		_collision_shape.shape = box_shape

	box_shape.size = size


func _update_preview() -> void:
	var should_show: bool = (Engine.is_editor_hint() and show_in_editor) or (not Engine.is_editor_hint() and show_in_game_debug)

	if not should_show:
		if is_instance_valid(_editor_mesh_instance):
			_editor_mesh_instance.visible = false
		return

	if not is_instance_valid(_editor_mesh_instance):
		_editor_mesh_instance = get_node_or_null("_ZoneBoxPreview") as MeshInstance3D
		if not is_instance_valid(_editor_mesh_instance):
			_editor_mesh_instance = MeshInstance3D.new()
			_editor_mesh_instance.name = "_ZoneBoxPreview"
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
	mat.albedo_color = zone_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_editor_mesh_instance.visible = true


func _cleanup_preview() -> void:
	if is_instance_valid(_editor_mesh_instance):
		_editor_mesh_instance.queue_free()
		_editor_mesh_instance = null
	var existing := get_node_or_null("_ZoneBoxPreview")
	if is_instance_valid(existing):
		existing.queue_free()


func _setup_runtime_audio() -> void:
	if warning_sound != null:
		_audio_player = AudioStreamPlayer3D.new()
		_audio_player.name = "WarningAudio"
		_audio_player.stream = warning_sound
		_audio_player.volume_db = sound_volume_db
		_audio_player.max_distance = sound_max_distance
		_audio_player.bus = sound_bus
		add_child(_audio_player)
