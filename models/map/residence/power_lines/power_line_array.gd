@tool
extends Node3D
## Instances grounded poles along local +X. Move or rotate this node to place the row.

const VARIANTS: Array[PackedScene] = [
	preload("res://models/map/residence/power_lines/power_line_01.glb"),
	preload("res://models/map/residence/power_lines/power_line_02.glb"),
	preload("res://models/map/residence/power_lines/power_line_03.glb"),
	preload("res://models/map/residence/power_lines/power_line_04.glb"),
	preload("res://models/map/residence/power_lines/power_line_05.glb"),
	preload("res://models/map/residence/power_lines/power_line_06.glb"),
	preload("res://models/map/residence/power_lines/power_line_07.glb"),
	preload("res://models/map/residence/power_lines/power_line_08.glb"),
	preload("res://models/map/residence/power_lines/power_line_09.glb"),
]

@export_range(0, 500, 1) var pole_count: int = 5:
	set(value):
		pole_count = clampi(value, 0, 500)
		_queue_rebuild()

## Distance in local meters between pole bases, independent of pole_scale.
@export_range(0.1, 100.0, 0.1, "or_greater", "suffix:m") var spacing: float = 15.0:
	set(value):
		spacing = maxf(value, 0.1)
		_queue_rebuild()

## The source poles are 20 to 28 units tall. At 0.4 they are 8 to 11.2 meters tall.
@export_range(0.01, 2.0, 0.01, "or_greater") var pole_scale: float = 0.4:
	set(value):
		pole_scale = maxf(value, 0.01)
		_queue_rebuild()

## Cycle uses all nine variants in order. Select a number to repeat just that pole.
@export_enum("Cycle All:0", "Variant 1:1", "Variant 2:2", "Variant 3:3", "Variant 4:4", "Variant 5:5", "Variant 6:6", "Variant 7:7", "Variant 8:8", "Variant 9:9") var variant: int = 0:
	set(value):
		variant = clampi(value, 0, VARIANTS.size())
		_queue_rebuild()

## Rotates each pole around its base without changing the row direction.
@export_range(-180.0, 180.0, 1.0, "degrees") var pole_rotation_degrees: float = 0.0:
	set(value):
		pole_rotation_degrees = value
		_queue_rebuild()

var _rebuild_pending: bool = false


func _ready() -> void:
	rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_pending:
		return
	_rebuild_pending = true
	_rebuild_deferred.call_deferred()


func _rebuild_deferred() -> void:
	_rebuild_pending = false
	if is_inside_tree():
		rebuild()


func rebuild() -> void:
	for child in get_children():
		if child.has_meta(&"power_line_generated"):
			remove_child(child)
			child.queue_free()
	for index in range(pole_count):
		var selected := index % VARIANTS.size() if variant == 0 else variant - 1
		var pole := VARIANTS[selected].instantiate() as Node3D
		pole.name = "Pole_%03d_Variant_%d" % [index + 1, selected + 1]
		pole.set_meta(&"power_line_generated", true)
		pole.position = Vector3(index * spacing, 0.0, 0.0)
		pole.scale = Vector3.ONE * pole_scale
		pole.rotation_degrees.y = pole_rotation_degrees
		# No owner: previews stay out of saved scenes and rebuild on load at runtime.
		add_child(pole)
