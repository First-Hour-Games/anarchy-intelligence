class_name HidingSpot extends Interactable3D

## A locker, closet, or bed the player can hide in. The spot's local +Z is its
## open side: the player looks out along +Z and steps out in front of it.
## Hunters that can see the player at the moment they hide remember the spot
## and pull the player out; otherwise a hidden player cannot be seen or heard.

signal player_entered(player: FirstPersonPlayer)
signal player_exited(player: FirstPersonPlayer)

enum Kind { LOCKER, CLOSET, UNDER_BED }

const LOCKER_MODEL := preload("res://models/props/hospital/staff_locker.glb")
const CLOSET_MODEL := preload("res://models/props/hospital/supply_closet.glb")
const BED_MODEL := preload("res://models/props/hospital/ward_bed.glb")
const LOCKER_SOUNDS: Array[AudioStream] = [
	preload("res://sounds/props/impacts/impactMetal_light_000.ogg"),
	preload("res://sounds/props/impacts/impactMetal_light_001.ogg"),
	preload("res://sounds/props/impacts/impactMetal_light_002.ogg"),
]
const CLOSET_SOUND := preload("res://sounds/chapters/tutorial/doorCreak.mp3")
const MENU_FONT: Font = preload("res://fonts/EuropeanTeletextNuevo.ttf")

@export var kind: Kind = Kind.LOCKER
## Adds the stock locker, closet or ward bed with its collision. Off for spots set into a
## building's own furniture, such as the beds and closets in Carrie's house.
@export var builtin_model: bool = true
@export_range(10.0, 90.0, 1.0) var look_yaw_limit_degrees: float = 45.0
@export_range(5.0, 60.0, 1.0) var look_pitch_limit_degrees: float = 20.0
@export_range(0.05, 1.0, 0.05) var door_swing_seconds: float = 0.22

var occupant: FirstPersonPlayer
## Set by a hunter that watched the player climb in.
var seen_entering: bool = false
var _busy: bool = false
var _doors: Array[Node3D] = []
var _door_signs: Array[float] = []
var _overlay: CanvasLayer
var _audio: AudioStreamPlayer3D
var _base_yaw: float = 0.0
var _yaw: float = 0.0
var _pitch: float = 0.0


func _ready() -> void:
	super._ready()
	interaction_distance = 2.0
	interaction_message = "Hid."
	_audio = AudioStreamPlayer3D.new()
	_audio.bus = &"Reverb"
	_audio.position = Vector3(0, 1.0, 0.3)
	add_child(_audio)
	if not builtin_model:
		return
	match kind:
		Kind.LOCKER:
			_add_model(LOCKER_MODEL)
			_add_collision(Vector3(0.62, 2.0, 0.58), Vector3(0, 1.0, 0))
		Kind.CLOSET:
			_add_model(CLOSET_MODEL)
			_add_collision(Vector3(1.12, 2.06, 0.64), Vector3(0, 1.03, 0))
		Kind.UNDER_BED:
			# Mattress and frame, plus the taller headboard; the bed stays low enough to see over.
			_add_model(BED_MODEL)
			_add_collision(Vector3(2.1, 0.66, 0.94), Vector3(0, 0.33, 0))
			_add_collision(Vector3(0.06, 1.08, 0.94), Vector3(1.02, 0.54, 0))


func _add_model(packed: PackedScene) -> void:
	var model := packed.instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	for door_name: String in ["Door", "DoorLeft", "DoorRight"]:
		var door := model.get_node_or_null(door_name) as Node3D
		if door != null:
			_doors.append(door)
			# Left-hinged doors swing outward with a negative Y rotation.
			_door_signs.append(1.0 if door_name == "DoorRight" else -1.0)


func _add_collision(size: Vector3, center: Vector3) -> void:
	var body := get_node_or_null("Collision") as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = "Collision"
		add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	body.add_child(shape)


func eye_position() -> Vector3:
	match kind:
		Kind.UNDER_BED: return to_global(Vector3(0, 0.26, 0.15))
		# Close behind the gap between the closet doors so the room stays visible.
		Kind.CLOSET: return to_global(Vector3(0, 1.62, 0.22))
		_: return to_global(Vector3(0, 1.62, 0.06))


## Where the player stands after leaving, and where a hunter goes to reach them.
func exit_position() -> Vector3:
	return to_global(Vector3(0, 0, 1.1 if kind == Kind.UNDER_BED else 0.8))


## Where a hunter stands to pull the player out: far enough beyond the exit that
## the hunter's capsule never overlaps the player placed at exit_position(). Between
## close-set ward beds the standoff shrinks (to no less than 0.8 m) until the point
## lies on the navigation mesh.
func hunter_position() -> Vector3:
	var exit := exit_position()
	var outward := (exit - global_position).normalized()
	var map := get_world_3d().navigation_map
	var standoff := 1.25
	while standoff > 0.85 and NavigationServer3D.map_get_iteration_id(map) > 0:
		var candidate := exit + outward * standoff
		var closest := NavigationServer3D.map_get_closest_point(map, candidate)
		if Vector2(closest.x - candidate.x, closest.z - candidate.z).length() < 0.15:
			return candidate
		standoff -= 0.15
	return exit + outward * standoff


## Collision bodies of this spot, for sight checks that should look through it.
func collision_rids() -> Array[RID]:
	var rids: Array[RID] = []
	var body := get_node_or_null("Collision") as CollisionObject3D
	if body != null:
		rids.append(body.get_rid())
	return rids


func get_prompt_world_position() -> Vector3:
	return to_global(Vector3(0, 0.45, 0.6) if kind == Kind.UNDER_BED else Vector3(0, 1.1, 0.3))


func can_interact(interactor: Node3D) -> bool:
	var player := interactor as FirstPersonPlayer
	return player != null and occupant == null and not _busy and not player.is_hidden() and super.can_interact(interactor)


func interact(interactor: Node3D) -> void:
	var player := interactor as FirstPersonPlayer
	if player == null or not can_interact(player):
		return
	enter(player)
	interacted.emit(interactor)


func enter(player: FirstPersonPlayer) -> void:
	_busy = true
	occupant = player
	seen_entering = false
	# Hunters judge whether they saw the player before the player disappears.
	for mob in get_tree().get_nodes_in_group("story_mob"):
		if mob.has_method(&"notice_player_hiding"):
			mob.notice_player_hiding(self)
	player.freeze()
	player.set_physics_process(false)
	player.collision_shape.set_deferred("disabled", true)
	player.hiding_spot = self
	_play_door_sound()
	_swing_doors(true)
	_base_yaw = global_rotation.y + PI
	_yaw = 0.0
	_pitch = 0.0
	_place_player()
	_show_overlay()
	var story := get_tree().get_first_node_in_group("opening_story")
	if story != null:
		story.narrate_once("hide_first", "If it didn't see me get in here, it shouldn't find me. I need to stay quiet.")
	player_entered.emit(player)
	await get_tree().create_timer(door_swing_seconds + 0.15).timeout
	if occupant == player:
		_swing_doors(false)
	_busy = false


func exit() -> void:
	if occupant == null or _busy:
		return
	_busy = true
	_play_door_sound()
	_swing_doors(true)
	await get_tree().create_timer(door_swing_seconds).timeout
	_release()
	await get_tree().create_timer(0.35).timeout
	if occupant == null:
		_swing_doors(false)
	_busy = false


## Immediately ejects the player, used when a hunter finds them.
func force_out() -> void:
	if occupant == null:
		return
	_play_door_sound()
	_swing_doors(true)
	_release()
	_busy = false


func _release() -> void:
	var player := occupant
	occupant = null
	seen_entering = false
	_hide_overlay()
	if not is_instance_valid(player):
		return
	player.hiding_spot = null
	player.global_position = exit_position()
	player.global_rotation = Vector3(0, _base_yaw, 0)
	player.head.rotation.x = 0.0
	player.head.position.y = player.stand_head_y
	player.collision_shape.set_deferred("disabled", false)
	player.set_physics_process(true)
	# A note or the journal opened during the door swing keeps the player frozen;
	# closing it unfreezes them because they are no longer hidden.
	var story := get_tree().get_first_node_in_group("opening_story")
	if story == null or not bool(story.get("document_open")):
		player.unfreeze()
	player.snap_to_ground.call_deferred()
	player_exited.emit(player)


func _physics_process(delta: float) -> void:
	# The player's own physics is off while hidden, so resting here recovers stamina.
	if occupant != null:
		occupant.recover_stamina(delta)


## Keeps the body on the floor below the eye and moves the head to eye height,
## so systems that read the player's position never see it under the floor.
func _place_player() -> void:
	occupant.global_rotation = Vector3(0, _base_yaw + _yaw, 0)
	occupant.head.rotation.x = _pitch
	var eye := eye_position()
	occupant.global_position = Vector3(eye.x, global_position.y, eye.z)
	occupant.head.position.y = eye.y - global_position.y
	var offset := occupant.camera.global_position - eye
	occupant.head.position.y -= offset.y
	occupant.global_position -= Vector3(offset.x, 0, offset.z)


func _unhandled_input(event: InputEvent) -> void:
	if occupant == null or _busy:
		return
	var story := get_tree().get_first_node_in_group("opening_story")
	if story != null and bool(story.get("document_open")):
		return
	var leave: bool = event.is_action_pressed(&"interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E)
	if leave and not event.is_echo():
		get_viewport().set_input_as_handled()
		exit()
	elif event.is_action_pressed(&"flashlight_toggle") and not event.is_echo():
		# The player's own input is frozen while hidden, so the spot forwards the flashlight key.
		if is_instance_valid(occupant.flashlight) and occupant.has_item(PlayerInventory.FLASHLIGHT_ITEM):
			occupant.flashlight.toggle()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var yaw_limit := deg_to_rad(look_yaw_limit_degrees)
		var pitch_limit := deg_to_rad(look_pitch_limit_degrees)
		_yaw = clampf(_yaw - event.relative.x * occupant.mouse_sensitivity, -yaw_limit, yaw_limit)
		_pitch = clampf(_pitch - event.relative.y * occupant.mouse_sensitivity, -pitch_limit, pitch_limit)
		_place_player()
		get_viewport().set_input_as_handled()


func _swing_doors(open: bool) -> void:
	for index in _doors.size():
		var tween := create_tween()
		tween.tween_property(_doors[index], "rotation:y", _door_signs[index] * deg_to_rad(100.0) if open else 0.0, door_swing_seconds)


func _play_door_sound() -> void:
	match kind:
		Kind.LOCKER:
			_audio.stream = LOCKER_SOUNDS.pick_random()
			_audio.volume_db = -8.0
		Kind.CLOSET:
			_audio.stream = CLOSET_SOUND
			_audio.volume_db = -14.0
		_:
			return
	_audio.pitch_scale = randf_range(0.94, 1.06)
	_audio.play()


func _show_overlay() -> void:
	if _overlay == null:
		_overlay = CanvasLayer.new()
		_overlay.name = "HidingOverlay"
		# Above the HUD (20-25), below the town map (50) and story reader (101).
		_overlay.layer = 30
		add_child(_overlay)
		var vignette := TextureRect.new()
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0, 0, 0, 0))
		gradient.set_color(1, Color(0, 0, 0, 0.92))
		gradient.set_offset(0, 0.35)
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		vignette.texture = texture
		vignette.stretch_mode = TextureRect.STRETCH_SCALE
		vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.add_child(vignette)
		var hint := Label.new()
		hint.name = "Hint"
		hint.text = "[E] LEAVE    [F] FLASHLIGHT"
		hint.add_theme_font_override("font", MENU_FONT)
		hint.add_theme_font_size_override("font_size", 18)
		hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 0.8))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		hint.offset_top = -64
		hint.offset_bottom = -36
		hint.offset_left = -240
		hint.offset_right = 240
		_overlay.add_child(hint)
	_overlay.show()


func _hide_overlay() -> void:
	if _overlay != null:
		_overlay.hide()
