@tool
class_name StreetlightArray extends Node3D

enum LineAxis {
	POSITIVE_X = 0,
	NEGATIVE_X = 1,
	POSITIVE_Z = 2,
	NEGATIVE_Z = 3,
	CUSTOM = 4
}

const DEFAULT_STREETLIGHT_SCENE: PackedScene = preload("res://models/map/residence/streetlight.tscn")

@export_group("Array Layout")
## Number of streetlights in the line.
@export_range(1, 100, 1) var count: int = 4:
	set(val):
		count = max(1, val)
		_queue_rebuild()

## Distance in meters between consecutive streetlights along the line.
@export_range(0.5, 100.0, 0.5) var spacing: float = 15.0:
	set(val):
		spacing = max(0.1, val)
		_queue_rebuild()

## Axis along which the line extends.
@export var line_axis: LineAxis = LineAxis.POSITIVE_X:
	set(val):
		line_axis = val
		_queue_rebuild()

## Custom direction vector used when line_axis is CUSTOM.
@export var custom_direction: Vector3 = Vector3(1, 0, 0):
	set(val):
		custom_direction = val
		_queue_rebuild()

## Vertical height step added per streetlight (useful for hills and slopes).
@export var height_offset_per_step: float = 0.0:
	set(val):
		height_offset_per_step = val
		_queue_rebuild()

@export_group("Orientation")
## Additional Y rotation applied to every streetlight in degrees.
@export_range(-180.0, 180.0, 1.0) var rotation_offset_degrees: float = 0.0:
	set(val):
		rotation_offset_degrees = val
		_queue_rebuild()

## If true, rotates the lamp arm perpendicular to the line direction.
@export var auto_orient_perpendicular: bool = false:
	set(val):
		auto_orient_perpendicular = val
		_queue_rebuild()

## If true, alternates rotation 180 degrees every other streetlight.
@export var alternate_sides: bool = false:
	set(val):
		alternate_sides = val
		_queue_rebuild()

## Lateral offset distance applied across the line when alternating sides (e.g. road width).
@export var alternate_lateral_offset: float = 0.0:
	set(val):
		alternate_lateral_offset = val
		_queue_rebuild()

@export_group("Streetlight Model & Scale")
## Packed scene for each streetlight. Defaults to the stylized low-poly streetlight.
@export var streetlight_scene: PackedScene = DEFAULT_STREETLIGHT_SCENE:
	set(val):
		streetlight_scene = val
		_queue_rebuild()

## Uniform scale for each streetlight.
@export_range(0.1, 5.0, 0.05) var streetlight_scale: float = 1.0:
	set(val):
		streetlight_scale = max(0.01, val)
		_queue_rebuild()

@export_group("Lighting")
## Toggles the spotlight on all generated streetlights.
@export var enable_lights: bool = true:
	set(val):
		enable_lights = val
		_queue_rebuild()

## Color of the streetlight beam.
@export var light_color: Color = Color(1.0, 0.85, 0.65):
	set(val):
		light_color = val
		_queue_rebuild()

## Energy/intensity of the spotlight.
@export_range(0.0, 20.0, 0.1) var light_energy: float = 3.5:
	set(val):
		light_energy = val
		_queue_rebuild()

## Max distance/range of the spotlight in meters.
@export_range(1.0, 50.0, 0.5) var light_range: float = 14.0:
	set(val):
		light_range = val
		_queue_rebuild()

## Cone angle for the spotlight in degrees.
@export_range(10.0, 85.0, 1.0) var spot_angle: float = 55.0:
	set(val):
		spot_angle = val
		_queue_rebuild()

## Enables shadow casting on the spotlights.
@export var light_shadows: bool = false:
	set(val):
		light_shadows = val
		_queue_rebuild()

@export_group("Physics")
## Enables physical collision on all streetlight poles.
@export var enable_collision: bool = true:
	set(val):
		enable_collision = val
		_update_collision()

@export_group("Actions")
## Check to force a rebuild of the array.
@export var rebuild_array: bool = false:
	set(val):
		if val:
			rebuild()

var _rebuild_pending: bool = false


func _ready() -> void:
	if get_child_count() == 0:
		rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree():
		return
	if _rebuild_pending:
		return
	_rebuild_pending = true
	call_deferred(&"_do_rebuild")


func _do_rebuild() -> void:
	if not _rebuild_pending:
		return
	_rebuild_pending = false
	rebuild()


func get_line_direction() -> Vector3:
	var dir := Vector3.RIGHT
	match line_axis:
		LineAxis.POSITIVE_X:
			dir = Vector3.RIGHT
		LineAxis.NEGATIVE_X:
			dir = Vector3.LEFT
		LineAxis.POSITIVE_Z:
			dir = Vector3.BACK
		LineAxis.NEGATIVE_Z:
			dir = Vector3.FORWARD
		LineAxis.CUSTOM:
			dir = custom_direction
	if dir.is_zero_approx():
		return Vector3.RIGHT
	return dir.normalized()


func get_perpendicular_direction() -> Vector3:
	var dir := get_line_direction()
	return Vector3(-dir.z, 0.0, dir.x).normalized()


func rebuild() -> void:
	# Clear previously generated streetlight children
	for child in get_children():
		if child.has_meta(&"streetlight_array_item"):
			remove_child(child)
			child.queue_free()

	if streetlight_scene == null:
		return

	var dir := get_line_direction()
	var perp := get_perpendicular_direction()

	for i in range(count):
		var inst := streetlight_scene.instantiate() as Node3D
		if inst == null:
			continue
		inst.name = "Streetlight_%02d" % (i + 1)
		inst.set_meta(&"streetlight_array_item", true)

		# Position along line
		var pos := dir * (i * spacing)
		pos.y += i * height_offset_per_step

		var rot_y: float = rotation_offset_degrees
		if auto_orient_perpendicular:
			rot_y += rad_to_deg(atan2(perp.x, perp.z))

		if alternate_sides and (i % 2 == 1):
			pos += perp * alternate_lateral_offset
			rot_y += 180.0

		inst.position = pos
		inst.rotation_degrees = Vector3(0.0, rot_y, 0.0)
		inst.scale = Vector3.ONE * streetlight_scale

		# Apply light and collision settings
		if inst is Streetlight:
			var light_post := inst as Streetlight
			light_post.light_enabled = enable_lights
			light_post.light_color = light_color
			light_post.light_energy = light_energy
			light_post.light_range = light_range
			light_post.spot_angle = spot_angle
			light_post.shadow_enabled = light_shadows
			light_post.collision_enabled = enable_collision
		else:
			for light in inst.find_children("", "SpotLight3D", true, false):
				var sl := light as SpotLight3D
				sl.visible = enable_lights
				sl.light_color = light_color
				sl.light_energy = light_energy
				sl.spot_range = light_range
				sl.spot_angle = spot_angle
				sl.shadow_enabled = light_shadows
			if not enable_collision:
				for col in inst.find_children("", "CollisionShape3D", true, false):
					(col as CollisionShape3D).disabled = true

		add_child(inst)
		if Engine.is_editor_hint():
			inst.owner = get_tree().edited_scene_root


func _update_collision() -> void:
	for child in get_children():
		if child.has_meta(&"streetlight_array_item"):
			if child is Streetlight:
				(child as Streetlight).collision_enabled = enable_collision
			else:
				for col in child.find_children("", "CollisionShape3D", true, false):
					(col as CollisionShape3D).disabled = not enable_collision


## Returns all currently generated streetlight nodes in the array.
func get_streetlights() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in get_children():
		if child.has_meta(&"streetlight_array_item") and child is Node3D:
			result.append(child as Node3D)
	return result


## Converts generated streetlights into independent persistent scene nodes and detaches this generator script.
func bake_to_standalone_nodes() -> void:
	_rebuild_pending = false
	for child in get_children():
		if child.has_meta(&"streetlight_array_item"):
			child.remove_meta(&"streetlight_array_item")
			if Engine.is_editor_hint() and get_tree().edited_scene_root:
				child.owner = get_tree().edited_scene_root
	set_script.call_deferred(null)
