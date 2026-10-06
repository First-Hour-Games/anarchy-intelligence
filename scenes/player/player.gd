class_name FirstPersonPlayer extends CharacterBody3D

## A small, reusable first-person controller for testing level scale and movement feel.
## One Godot unit is treated as roughly one metre.

signal stamina_changed(current: float, maximum: float)

const WOOD_FOOTSTEPS := [
	preload("res://sounds/footsteps/wood/woodFootsteps1.ogg"),
	preload("res://sounds/footsteps/wood/woodFootsteps2.ogg"),
	preload("res://sounds/footsteps/wood/woodFootsteps3.ogg"),
	preload("res://sounds/footsteps/wood/woodFootsteps4.ogg"),
	preload("res://sounds/footsteps/wood/woodFootsteps5.ogg"),
]
const FOOTSTEP_PHASE_OFFSET := PI * 0.75
const FOOTSTEP_PHASE_INTERVAL := PI
const SURFACES := preload("res://scenes/player/footstep_surfaces.gd")
var current_footstep_surface: StringName = &"dirt"

@export_category("Movement")
@export var walk_speed: float = 3.2
@export var sprint_speed: float = 4.8
@export var ground_acceleration: float = 13.0
@export var ground_deceleration: float = 17.0
@export var air_acceleration: float = 3.0

@export_category("Stamina")
@export_range(1.0, 500.0, 1.0) var max_stamina: float = 200.0
@export_range(1.0, 100.0, 0.1) var sprint_stamina_cost: float = 40.8
@export_range(1.0, 100.0, 1.0) var stamina_regeneration_rate: float = 18.0
@export_range(0.0, 5.0, 0.1) var stamina_regeneration_delay: float = 0.8
@export_range(0.0, 100.0, 1.0) var exhausted_recovery_stamina: float = 20.0

@export_category("Jump")
@export var jump_velocity: float = 3.4

@export_category("Stair Stepping")
@export var max_step_height: float = 0.3

@export_category("Crouch")
@export_range(0.3, 0.9, 0.01) var crouch_height_scale: float = 0.55
@export_range(0.2, 1.0, 0.05) var crouch_speed_multiplier: float = 0.5
@export var crouch_transition_speed: float = 10.0

@export_category("Camera")
@export_range(0.0005, 0.01, 0.0001) var mouse_sensitivity: float = 0.0017
@export_range(45.0, 89.0, 1.0) var vertical_look_limit_degrees: float = 85.0

@export_category("Head Bob")
@export var head_bob_frequency: float = 0.95
@export var head_bob_vertical_amplitude: float = 0.035
@export var head_bob_horizontal_amplitude: float = 0.018
@export var head_bob_smoothing: float = 12.0

@export_category("Footsteps")
@export_range(-40.0, 6.0, 0.5) var footstep_volume_db: float = -13.0
@export_range(0.5, 1.5, 0.01) var footstep_pitch_min: float = 0.96
@export_range(0.5, 1.5, 0.01) var footstep_pitch_max: float = 1.04
@export var default_surface: StringName = &"wood"

@export_group("Surface Sounds")
@export var wood_footsteps: Array[AudioStream] = [
	preload("res://sounds/footsteps/wood/woodFootsteps1.ogg"),
	preload("res://sounds/footsteps/wood/woodFootsteps2.ogg"),
	preload("res://sounds/footsteps/wood/woodFootsteps3.ogg"),
	preload("res://sounds/footsteps/wood/woodFootsteps4.ogg"),
	preload("res://sounds/footsteps/wood/woodFootsteps5.ogg"),
]
@export var concrete_footsteps: Array[AudioStream] = [
	preload("res://sounds/footsteps/concrete/Concrete footsteps 1.ogg"),
	preload("res://sounds/footsteps/concrete/Concrete footsteps 2.ogg"),
	preload("res://sounds/footsteps/concrete/Concrete footsteps 3.ogg"),
	preload("res://sounds/footsteps/concrete/Concrete footsteps 4.ogg"),
	preload("res://sounds/footsteps/concrete/Concrete footsteps 5.ogg"),
	preload("res://sounds/footsteps/concrete/Concrete footsteps 6.ogg"),
	preload("res://sounds/footsteps/concrete/Concrete footsteps 7.ogg"),
	preload("res://sounds/footsteps/concrete/Concrete footsteps 8.ogg"),
]
@export var gravel_footsteps: Array[AudioStream] = [
	preload("res://sounds/footsteps/gravel/gravelFootstep1.ogg"),
	preload("res://sounds/footsteps/gravel/gravelFootstep2.ogg"),
	preload("res://sounds/footsteps/gravel/gravelFootstep3.ogg"),
	preload("res://sounds/footsteps/gravel/gravelFootstep4.ogg"),
	preload("res://sounds/footsteps/gravel/gravelFootstep5.ogg"),
	preload("res://sounds/footsteps/gravel/gravelFootstep6.ogg"),
	preload("res://sounds/footsteps/gravel/gravelFootstep7.ogg"),
]
@export var dirt_footsteps: Array[AudioStream] = []
@export var grass_footsteps: Array[AudioStream] = [
	preload("res://sounds/footsteps/grass/Grass-footsteps-1.ogg"),
	preload("res://sounds/footsteps/grass/Grass-footsteps-2.ogg"),
	preload("res://sounds/footsteps/grass/Grass-footsteps-3.ogg"),
	preload("res://sounds/footsteps/grass/Grass-footsteps-4.ogg"),
	preload("res://sounds/footsteps/grass/Grass-footsteps-5.ogg"),
	preload("res://sounds/footsteps/grass/Grass-footsteps-6.ogg"),
	preload("res://sounds/footsteps/grass/Grass-footsteps-7.ogg"),
]
@export var snow_footsteps: Array[AudioStream] = []
@export_category("Visibility")
## When true, ensures the player node and essential visuals are automatically shown in game,
## even if hidden in the editor hierarchy for editing convenience.
@export var force_visible_in_game: bool = true

@export var metal_footsteps: Array[AudioStream] = []
@export var custom_surface_sounds: Dictionary = {}

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var ceiling_check: ShapeCast3D = $CeilingCheck
@onready var floor_detector: RayCast3D = $FloorDetector
@onready var interaction_detector: InteractionDetector = $InteractionDetector
@onready var footstep_players: Array[AudioStreamPlayer] = [$FootstepPlayerA, $FootstepPlayerB]
@onready var flashlight: PlayerFlashlight = get_node_or_null("Head/Camera3D/Flashlight") as PlayerFlashlight
@onready var distance_fog: MeshInstance3D = get_node_or_null("Head/Camera3D/DistanceFog") as MeshInstance3D
@onready var inventory: PlayerInventory = (get_node_or_null("InventoryHUD") as PlayerInventory) if has_node("InventoryHUD") else (get_node_or_null("Inventory") as PlayerInventory)

var forced_surface: StringName = &""

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var head_bob_phase: float = 0.0
var camera_rest_position: Vector3
var stamina: float = 100.0
var is_sprinting: bool = false

var capsule_shape: CapsuleShape3D
var stand_capsule_height: float
var stand_collision_y: float
var stand_head_y: float
var crouch_capsule_height: float
var crouch_collision_y: float
var crouch_head_y: float
var is_crouching: bool = false
var _stamina_regeneration_cooldown: float = 0.0
var _sprint_exhausted: bool = false
var _footstep_random := RandomNumberGenerator.new()
var _last_footstep_index: int = -1
var _footstep_player_index: int = 0
var is_frozen: bool = false


func _enter_tree() -> void:
	if not Engine.is_editor_hint() and force_visible_in_game:
		visible = true


func _ready() -> void:
	if not Engine.is_editor_hint() and force_visible_in_game:
		_ensure_runtime_visibility()
		visibility_changed.connect(func() -> void:
			if not visible and force_visible_in_game and not Engine.is_editor_hint():
				visible = true
		)

	if is_instance_valid(floor_detector):
		floor_detector.add_exception(self)
	_footstep_random.randomize()
	stamina = max_stamina
	stamina_changed.emit(stamina, max_stamina)
	camera_rest_position = camera.position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	capsule_shape = collision_shape.shape.duplicate()
	collision_shape.shape = capsule_shape
	stand_capsule_height = capsule_shape.height
	stand_collision_y = collision_shape.position.y
	stand_head_y = head.position.y

	var height_diff := stand_capsule_height * (1.0 - crouch_height_scale)
	crouch_capsule_height = stand_capsule_height - height_diff
	crouch_collision_y = stand_collision_y - height_diff * 0.5
	if is_instance_valid(inventory):
		inventory.selection_changed.connect(_on_inventory_selection_changed)

	# Ensure the player's feet are already contacting the floor on initial spawn
	if not Engine.is_editor_hint():
		snap_to_ground.call_deferred()


## Snaps the player downwards to the nearest floor surface within max_distance.
## Positions the feet directly on the ground and registers floor contact.
func snap_to_ground(max_distance: float = 4.0) -> bool:
	var world := get_world_3d()
	if not is_instance_valid(world):
		return false
	var space_state := world.direct_space_state
	if not is_instance_valid(space_state):
		return false

	var start_pos := Vector3(global_position.x, global_position.y + 0.5, global_position.z)
	var end_pos := Vector3(global_position.x, global_position.y - max_distance, global_position.z)
	var query := PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.exclude = [get_rid()]

	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		var ground_y: float = float(result["position"].y)
		global_position.y = ground_y + 0.001
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.1
		move_and_slide()
		return true
	return false


func freeze() -> void:
	is_frozen = true
	velocity.x = 0.0
	velocity.z = 0.0
	set_process_unhandled_input(false)
	for footstep_player in footstep_players:
		if is_instance_valid(footstep_player) and footstep_player.playing:
			footstep_player.stop()
	if is_instance_valid(interaction_detector):
		interaction_detector.set_process(false)
		var viewmodel: HandViewmodel = get_node_or_null("HandViewmodel") as HandViewmodel
		if is_instance_valid(viewmodel):
			viewmodel.set_interaction_prompt(false)

	# Ensure player is solidly positioned on the floor when frozen
	if is_inside_tree() and not is_on_floor():
		snap_to_ground()


func unfreeze() -> void:
	is_frozen = false
	set_process_unhandled_input(true)
	if is_instance_valid(interaction_detector):
		interaction_detector.set_process(true)


func has_item(item_id: Variant) -> bool:
	if is_instance_valid(inventory):
		return inventory.has_item(StringName(item_id))
	return false


func proceed() -> void:
	var barrier := get_tree().current_scene.find_child("BarrierTree", true, false)
	if is_instance_valid(barrier) and barrier.has_method(&"proceed"):
		barrier.call(&"proceed", self)
		return
	elif is_instance_valid(barrier) and barrier.has_method(&"climb_over_barrier"):
		barrier.call(&"climb_over_barrier", self)
		return


func _unhandled_input(event: InputEvent) -> void:
	if is_frozen:
		return

	if event.is_action_pressed(&"flashlight_toggle") and not event.is_echo():
		if is_instance_valid(inventory) and is_instance_valid(flashlight) and inventory.has_item(PlayerInventory.FLASHLIGHT_ITEM):
			flashlight.toggle()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed(&"map_toggle") and not event.is_echo():
		if is_instance_valid(inventory) and inventory.has_item(PlayerInventory.MAP_ITEM):
			var maps := get_tree().get_nodes_in_group("world_map")
			if not maps.is_empty():
				var map_overlay = maps[0]
				if map_overlay.has_method(&"set_map_open") and map_overlay.has_method(&"is_map_open"):
					map_overlay.set_map_open(not map_overlay.is_map_open())
					get_viewport().set_input_as_handled()
					return

	var is_interact_pressed: bool = event.is_action_pressed(&"interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E)
	if is_interact_pressed and not event.is_echo():
		if interaction_detector.try_interact():
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if is_instance_valid(flashlight):
			flashlight.add_look_impulse(event.relative)
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		var look_limit: float = deg_to_rad(vertical_look_limit_degrees)
		head.rotation.x = clamp(head.rotation.x, -look_limit, look_limit)


func _on_inventory_selection_changed(_slot_index: int, _item_id: StringName) -> void:
	pass


func _physics_process(delta: float) -> void:
	if is_frozen:
		_update_stamina(delta, false)
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		return

	_update_crouch(delta)

	if is_on_floor():
		velocity.y = 0.0
		if Input.is_key_pressed(KEY_SPACE) and not is_crouching:
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta

	var input_vector: Vector2 = _get_movement_input()
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var world_direction := (global_transform.basis * local_direction).normalized()
	var wants_to_sprint := Input.is_key_pressed(KEY_SHIFT) and input_vector.y < 0.0 and not is_crouching
	_update_stamina(delta, wants_to_sprint)
	var target_speed := sprint_speed if is_sprinting else walk_speed
	if is_crouching:
		target_speed = walk_speed * crouch_speed_multiplier
	var target_velocity := world_direction * target_speed

	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	if world_direction.is_zero_approx() and is_on_floor():
		acceleration = ground_deceleration

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	StairStepping.apply(self, delta, max_step_height)
	move_and_slide()
	_update_head_bob(delta)


func _update_stamina(delta: float, wants_to_sprint: bool) -> void:
	var previous_stamina := stamina

	if _sprint_exhausted and stamina >= minf(exhausted_recovery_stamina, max_stamina):
		_sprint_exhausted = false

	is_sprinting = wants_to_sprint and not _sprint_exhausted and stamina > 0.0
	if is_sprinting:
		stamina = maxf(0.0, stamina - sprint_stamina_cost * delta)
		_stamina_regeneration_cooldown = stamina_regeneration_delay
		if stamina <= 0.0:
			_sprint_exhausted = true
			is_sprinting = false
	else:
		var regeneration_time := maxf(0.0, delta - _stamina_regeneration_cooldown)
		_stamina_regeneration_cooldown = maxf(0.0, _stamina_regeneration_cooldown - delta)
		if regeneration_time > 0.0:
			stamina = minf(max_stamina, stamina + stamina_regeneration_rate * regeneration_time)

	if not is_equal_approx(previous_stamina, stamina):
		stamina_changed.emit(stamina, max_stamina)


func _update_crouch(delta: float) -> void:
	var wants_crouch := Input.is_key_pressed(KEY_CTRL)
	if is_crouching and not wants_crouch and ceiling_check.is_colliding():
		wants_crouch = true
	is_crouching = wants_crouch

	var target_capsule_height := crouch_capsule_height if is_crouching else stand_capsule_height
	var target_collision_y := crouch_collision_y if is_crouching else stand_collision_y
	var target_head_y := crouch_head_y if is_crouching else stand_head_y

	var blend_weight := 1.0 - exp(-crouch_transition_speed * delta)
	capsule_shape.height = lerp(capsule_shape.height, target_capsule_height, blend_weight)
	collision_shape.position.y = lerp(collision_shape.position.y, target_collision_y, blend_weight)
	head.position.y = lerp(head.position.y, target_head_y, blend_weight)


func _get_movement_input() -> Vector2:
	var input_vector := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	return input_vector.limit_length(1.0)


func _update_head_bob(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var is_moving_on_floor := is_on_floor() and horizontal_speed > 0.1
	var target_offset := Vector3.ZERO

	if is_moving_on_floor:
		var speed_ratio := horizontal_speed / walk_speed
		var previous_bob_phase := head_bob_phase
		head_bob_phase += delta * head_bob_frequency * TAU * speed_ratio
		_play_footstep_for_phase_crossing(previous_bob_phase, head_bob_phase)
		var amplitude_scale: float = clampf(speed_ratio, 0.65, 1.5)
		target_offset.x = cos(head_bob_phase) * head_bob_horizontal_amplitude * amplitude_scale
		target_offset.y = sin(head_bob_phase * 2.0) * head_bob_vertical_amplitude * amplitude_scale
	else:
		head_bob_phase = 0.0

	var target_position := camera_rest_position + target_offset
	var blend_weight := 1.0 - exp(-head_bob_smoothing * delta)
	camera.position = camera.position.lerp(target_position, blend_weight)


func _play_footstep_for_phase_crossing(previous_phase: float, current_phase: float) -> void:
	var previous_step := floori((previous_phase - FOOTSTEP_PHASE_OFFSET) / FOOTSTEP_PHASE_INTERVAL)
	var current_step := floori((current_phase - FOOTSTEP_PHASE_OFFSET) / FOOTSTEP_PHASE_INTERVAL)
	if current_step > previous_step:
		_play_footstep_sound()


func _detect_ground_surface() -> StringName:
	if not forced_surface.is_empty():
		return forced_surface

	var collider: Object = null
	if is_instance_valid(floor_detector):
		floor_detector.force_raycast_update()
		if floor_detector.is_colliding():
			collider = floor_detector.get_collider()

	if not is_instance_valid(collider) and get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var collision := get_slide_collision(i)
			if collision != null and collision.get_normal().y > 0.5:
				collider = collision.get_collider()
				break

	if not is_instance_valid(collider) and is_on_floor():
		var last_collision := get_last_slide_collision()
		if last_collision != null:
			collider = last_collision.get_collider()

	if not is_instance_valid(collider):
		return default_surface

	# 1. Check collider itself
	var surface := _check_node_surface(collider as Node)
	if not surface.is_empty():
		return surface

	# 2. Check collision shape children and specific hit shape
	if collider is CollisionObject3D:
		var col_obj := collider as CollisionObject3D
		if is_instance_valid(floor_detector) and floor_detector.is_colliding() and floor_detector.get_collider() == collider:
			var shape_idx := floor_detector.get_collider_shape()
			if shape_idx >= 0:
				var owner_id := col_obj.shape_find_owner(shape_idx)
				var shape_node := col_obj.shape_owner_get_owner(owner_id)
				surface = _check_node_surface(shape_node)
				if not surface.is_empty():
					return surface

		for child in col_obj.get_children():
			surface = _check_node_surface(child)
			if not surface.is_empty():
				return surface

	# 3. Check siblings (e.g. GroundPlane MeshInstance3D next to StaticBody3D)
	var parent := (collider as Node).get_parent()
	if is_instance_valid(parent):
		for sibling in parent.get_children():
			if sibling != collider and (sibling is MeshInstance3D or sibling.name.to_lower().contains("ground") or sibling.name.to_lower().contains("floor")):
				surface = _check_node_surface(sibling)
				if not surface.is_empty():
					return surface

	# 4. Check ancestors up the tree
	var ancestor := parent
	var depth := 0
	while is_instance_valid(ancestor) and depth < 3:
		surface = _check_node_surface(ancestor)
		if not surface.is_empty():
			return surface
		ancestor = ancestor.get_parent()
		depth += 1

	if is_instance_valid(collider) and collider is Node:
		var classified := SURFACES.classify(collider as Node)
		if not classified.is_empty() and classified != &"dirt":
			return classified

	return default_surface


func _check_node_surface(node: Node) -> StringName:
	if not is_instance_valid(node):
		return &""
	if node.has_meta("surface"):
		return StringName(str(node.get_meta("surface")).to_lower())
	if node.has_meta("surface_type"):
		return StringName(str(node.get_meta("surface_type")).to_lower())
	if node.has_meta("footstep"):
		return StringName(str(node.get_meta("footstep")).to_lower())
	if node.has_meta("footstep_surface"):
		return StringName(str(node.get_meta("footstep_surface")).to_lower())

	var surface_prop = node.get("surface_type")
	if surface_prop != null and not str(surface_prop).is_empty():
		return StringName(str(surface_prop).to_lower())

	for group in node.get_groups():
		var g_str := str(group).to_lower()
		if g_str.begins_with("surface_"):
			return StringName(g_str.substr(8))
		if g_str in [&"wood", &"concrete", &"asphalt", &"stone", &"road", &"dirt", &"mud", &"ground", &"grass", &"snow", &"ice", &"metal", &"carpet", &"water", &"gravel"]:
			return StringName(g_str)

	return &""


func _get_sounds_for_surface(surface: StringName) -> Array[AudioStream]:
	match surface:
		&"wood":
			return wood_footsteps
		&"concrete", &"asphalt", &"stone":
			return concrete_footsteps
		&"gravel", &"road":
			return gravel_footsteps
		&"dirt", &"mud", &"ground":
			return dirt_footsteps
		&"grass", &"foliage":
			return grass_footsteps
		&"snow", &"ice":
			return snow_footsteps
		&"metal":
			return metal_footsteps
		_:
			if custom_surface_sounds.has(surface):
				var custom_list = custom_surface_sounds[surface]
				if custom_list is Array:
					var cast_array: Array[AudioStream] = []
					for item in custom_list:
						if item is AudioStream:
							cast_array.append(item)
					return cast_array
			return []


func get_footstep_surface() -> StringName:
	return _detect_ground_surface()


func _play_surface_footstep() -> void:
	_play_footstep_sound()


func _play_random_wood_footstep() -> void:
	_play_footstep_sound()


func _play_footstep_sound() -> void:
	if footstep_players.is_empty():
		return

	var surface := _detect_ground_surface()
	current_footstep_surface = surface
	var sound_list := _get_sounds_for_surface(surface)

	if sound_list.is_empty() and surface != default_surface:
		sound_list = _get_sounds_for_surface(default_surface)
	if sound_list.is_empty():
		sound_list = wood_footsteps
	if sound_list.is_empty():
		return

	var sound_index := _footstep_random.randi_range(0, sound_list.size() - 1)
	if sound_list.size() > 1 and sound_index == _last_footstep_index:
		sound_index = (sound_index + _footstep_random.randi_range(1, sound_list.size() - 1)) % sound_list.size()
	_last_footstep_index = sound_index

	var footstep_player := footstep_players[_footstep_player_index]
	_footstep_player_index = (_footstep_player_index + 1) % footstep_players.size()
	footstep_player.stream = sound_list[sound_index]
	footstep_player.volume_db = footstep_volume_db
	footstep_player.pitch_scale = _footstep_random.randf_range(
		minf(footstep_pitch_min, footstep_pitch_max),
		maxf(footstep_pitch_min, footstep_pitch_max)
	)
	footstep_player.play()


func get_distance_fog_material() -> ShaderMaterial:
	if is_instance_valid(distance_fog):
		return distance_fog.material_override as ShaderMaterial
	return null


func set_distance_fog_enabled(enabled: bool) -> void:
	if is_instance_valid(distance_fog):
		distance_fog.visible = enabled


func _ensure_runtime_visibility() -> void:
	visible = true
	var head_node := get_node_or_null("Head") as Node3D
	if is_instance_valid(head_node):
		head_node.visible = true
	var cam_node := get_node_or_null("Head/Camera3D") as Camera3D
	if is_instance_valid(cam_node):
		cam_node.visible = true
	if is_instance_valid(distance_fog):
		distance_fog.visible = true
	var vm := get_node_or_null("HandViewmodel") as CanvasLayer
	if is_instance_valid(vm):
		vm.visible = true
