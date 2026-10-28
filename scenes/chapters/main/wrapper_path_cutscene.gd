extends Node3D
## One-shot ambient appearance. The player keeps control while the Wrapper walks.

signal cutscene_started
signal cutscene_finished

@export_node_path("Node3D") var wrapper_path: NodePath
@export_node_path("Area3D") var activation_zone_path: NodePath = NodePath("ActivationZone")
## Leave empty to follow direct Marker3D children in scene-tree order.
@export var path_markers: Array[NodePath] = []
@export_range(0.1, 10.0, 0.1) var walk_speed: float = 1.5
@export var walk_animation: StringName = &"MonsterPSX_Rig|Walk_Nervous"
## Matches Node3D.look_at's model-front convention for imported models facing +Z.
@export var model_faces_positive_z := false

@export_group("View Requirement")
## The front windows the player should be looking toward before the walk begins.
## If empty, uses the middle of the marked route at torso height.
@export_node_path("Node3D") var view_target_path: NodePath
@export_range(5.0, 80.0, 1.0) var view_angle_degrees := 30.0

## Stored by WorldStreaming so unloading and returning cannot replay the appearance.
var has_played := false
var is_playing := false
var _wrapper: Node3D
var _zone: Area3D
var _animation_player: AnimationPlayer
var _route: PackedVector3Array
var _next_marker := 1
var _waiting_player: FirstPersonPlayer


func _ready() -> void:
	add_to_group("streaming_one_shot")
	_wrapper = get_node_or_null(wrapper_path) as Node3D
	_zone = get_node_or_null(activation_zone_path) as Area3D
	set_physics_process(false)
	if _wrapper == null or _zone == null:
		push_warning("Wrapper cutscene needs a Wrapper instance and an activation Area3D.")
		return
	_wrapper.hide()
	# This instance is a staged appearance, independent of the story monster's AI.
	_wrapper.set_physics_process(false)
	_wrapper.set_process(false)
	if _wrapper is CollisionObject3D:
		_wrapper.collision_layer = 0
		_wrapper.collision_mask = 0
	var animations := _wrapper.find_children("*", "AnimationPlayer", true, false)
	if not animations.is_empty():
		_animation_player = animations[0] as AnimationPlayer
	_zone.body_entered.connect(_on_body_entered)
	_zone.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if has_played or not body is FirstPersonPlayer or body.is_frozen:
		return
	if not body.has_item(PlayerInventory.FLASHLIGHT_ITEM):
		return
	_waiting_player = body
	set_physics_process(true)
	_try_start()


func _on_body_exited(body: Node3D) -> void:
	if body == _waiting_player:
		_waiting_player = null
		if not is_playing:
			set_physics_process(false)


func _try_start() -> void:
	if not is_instance_valid(_waiting_player) or _waiting_player.is_frozen:
		return
	if not _waiting_player.has_item(PlayerInventory.FLASHLIGHT_ITEM):
		return
	_route = _marker_positions()
	if _route.size() < 2 or not is_instance_valid(_wrapper):
		push_warning("Wrapper cutscene needs at least two path markers.")
		set_physics_process(false)
		return
	var view_target := get_node_or_null(view_target_path) as Node3D if not view_target_path.is_empty() else null
	var focus: Vector3 = view_target.global_position if view_target != null else (_route[0] + _route[-1]) * 0.5 + Vector3.UP * 1.2
	var to_focus := focus - _waiting_player.camera.global_position
	if to_focus.length_squared() < 0.001:
		return
	var camera_forward := -_waiting_player.camera.global_basis.z.normalized()
	if camera_forward.dot(to_focus.normalized()) < cos(deg_to_rad(view_angle_degrees)):
		return
	has_played = true
	is_playing = true
	_next_marker = 1
	_wrapper.global_position = _route[0]
	_face_toward(_route[1])
	_play_walk_animation()
	_wrapper.show()
	set_physics_process(true)
	cutscene_started.emit()


func _marker_positions() -> PackedVector3Array:
	var points := PackedVector3Array()
	if path_markers.is_empty():
		for child in get_children():
			if child is Marker3D:
				points.append(child.global_position)
	else:
		for path in path_markers:
			var marker := get_node_or_null(path) as Node3D
			if marker == null:
				return PackedVector3Array()
			points.append(marker.global_position)
	return points


func _physics_process(delta: float) -> void:
	if not is_playing:
		_try_start()
		return
	if not is_instance_valid(_wrapper):
		_finish()
		return
	var remaining_distance := walk_speed * delta
	while _next_marker < _route.size():
		var destination := _route[_next_marker]
		var distance := _wrapper.global_position.distance_to(destination)
		_face_toward(destination)
		if distance > remaining_distance:
			_wrapper.global_position = _wrapper.global_position.move_toward(destination, remaining_distance)
			return
		_wrapper.global_position = destination
		remaining_distance -= distance
		_next_marker += 1
	_finish()


func _face_toward(destination: Vector3) -> void:
	var direction := destination - _wrapper.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.000001:
		_wrapper.look_at(_wrapper.global_position + direction, Vector3.UP, model_faces_positive_z)


func _play_walk_animation() -> void:
	if _animation_player == null or not _animation_player.has_animation(walk_animation):
		return
	# Loop a private copy so this appearance cannot change the shared story asset.
	var animation := _animation_player.get_animation(walk_animation).duplicate() as Animation
	animation.loop_mode = Animation.LOOP_LINEAR
	var library := AnimationLibrary.new()
	library.add_animation(&"walk", animation)
	_animation_player.add_animation_library(&"cutscene", library)
	_animation_player.play(&"cutscene/walk")
	_animation_player.advance(0.0)


func _finish() -> void:
	set_physics_process(false)
	is_playing = false
	if is_instance_valid(_wrapper):
		_wrapper.hide()
	if is_instance_valid(_animation_player):
		_animation_player.stop()
	cutscene_finished.emit()
