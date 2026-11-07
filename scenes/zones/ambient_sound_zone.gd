@tool
class_name AmbientSoundZone3D
extends Node3D
## Interior volume with an entrance on its local +Z face. Rotate the zone to
## match the building. Exterior spill is limited to the entrance, not the walls.

@export var is_enabled := true
@export var priority := 0
@export var stream: AudioStream
@export_range(-40.0, 6.0, 0.5) var volume_db := -12.0
@export_category("Interior and Entrance")
@export var size := Vector3(16.8, 5.4, 10.8):
	set(value):
		size = value.max(Vector3.ONE * 0.01)
		_update_preview()
@export_range(0.1, 10.0, 0.1) var interior_fade_distance := 2.5
@export_range(0.0, 1.0, 0.01) var doorway_mix := 0.3
@export var entrance_offset_x := 0.0
@export_range(0.1, 20.0, 0.1) var entrance_width := 2.4
@export_range(0.0, 10.0, 0.1) var exterior_bleed_distance := 2.5
@export_category("Transition")
## Exponential response time in seconds; shorter values follow movement faster.
@export_range(0.05, 5.0, 0.05) var fade_time := 0.65
## A little muffled outdoor sound remains audible through the entrance.
@export_range(0.0, 1.0, 0.01) var outdoor_gain_inside := 0.06
@export_range(100.0, 20000.0, 50.0) var outdoor_cutoff_hz := 1000.0
@export_category("Editor")
@export var show_in_editor := true:
	set(value):
		show_in_editor = value
		_update_preview()

var _preview: MeshInstance3D

func _ready() -> void:
	if Engine.is_editor_hint():
		_update_preview()
	else:
		get_node("/root/AmbienceMixer").register_zone(self)

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		var mixer := get_node_or_null("/root/AmbienceMixer")
		if mixer != null:
			mixer.unregister_zone(self)

func get_weight(world_position: Vector3) -> float:
	if not is_enabled or stream == null:
		return 0.0
	var point := to_local(world_position)
	var half := size * 0.5
	if absf(point.y) > half.y:
		return 0.0
	# Distances use world meters even when a building instance is scaled.
	var scale_z := global_basis.z.length()
	var depth := (half.z - point.z) * scale_z
	if absf(point.x) <= half.x and point.z >= -half.z and depth >= 0.0:
		return lerpf(doorway_mix, 1.0, smoothstep(0.0, interior_fade_distance, depth))
	if depth >= 0.0 or exterior_bleed_distance <= 0.0:
		return 0.0
	var distance_outside := -depth
	var distance_sideways := maxf(0.0, absf(point.x - entrance_offset_x) - entrance_width * 0.5) * global_basis.x.length()
	var distance_to_entrance := Vector2(distance_sideways, distance_outside).length()
	return doorway_mix * (1.0 - smoothstep(0.0, exterior_bleed_distance, distance_to_entrance))

func _update_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if not is_instance_valid(_preview):
		_preview = MeshInstance3D.new()
		_preview.name = "InteriorPreview"
		_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.25, 0.65, 1.0, 0.13)
		_preview.material_override = material
		add_child(_preview)
	var box := BoxMesh.new()
	box.size = size
	_preview.mesh = box
	_preview.visible = show_in_editor
