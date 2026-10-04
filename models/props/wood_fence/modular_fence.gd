@tool
class_name ModularFence extends Node3D

enum PatternMode {
	SEQUENTIAL = 0,
	RANDOM = 1,
	SINGLE_PIECE = 2,
	CUSTOM_SEQUENCE = 3
}

const FENCE_LENGTH: float = 7.0

const FENCE_SCENES: Array[PackedScene] = [
	preload("res://models/props/wood_fence/wood_fence_1.tscn"),
	preload("res://models/props/wood_fence/wood_fence_2.tscn"),
	preload("res://models/props/wood_fence/wood_fence_3.tscn"),
	preload("res://models/props/wood_fence/wood_fence_4.tscn"),
	preload("res://models/props/wood_fence/wood_fence_5.tscn"),
	preload("res://models/props/wood_fence/wood_fence_6.tscn")
]

@export_group("Layout")
@export_range(1, 100, 1) var segment_count: int = 5:
	set(val):
		segment_count = max(1, val)
		_queue_rebuild()

@export_range(0.05, 2.0, 0.01) var fence_scale: float = 0.35:
	set(val):
		fence_scale = max(0.01, val)
		_queue_rebuild()

## Custom spacing along X. Set to 0.0 to automatically match fence length * fence_scale (e.g. 2.45m at 0.35 scale).
@export var spacing: float = 0.0:
	set(val):
		spacing = val
		_queue_rebuild()

## Curvature / turn angle added to each consecutive segment in degrees.
@export_range(-45.0, 45.0, 0.5) var angle_per_segment_deg: float = 0.0:
	set(val):
		angle_per_segment_deg = val
		_queue_rebuild()

@export_group("Variations")
@export var pattern_mode: PatternMode = PatternMode.SEQUENTIAL:
	set(val):
		pattern_mode = val
		_queue_rebuild()

## Used when pattern_mode is SINGLE_PIECE (1 to 6).
@export_range(1, 6, 1) var single_piece_variant: int = 1:
	set(val):
		single_piece_variant = clampi(val, 1, 6)
		_queue_rebuild()

## Sequence of piece IDs (1 to 6) used when pattern_mode is CUSTOM_SEQUENCE.
@export var custom_sequence: Array[int] = [1, 2, 3, 4, 5, 6]:
	set(val):
		custom_sequence = val
		_queue_rebuild()

## Seed used for random pattern mode.
@export var random_seed: int = 12345:
	set(val):
		random_seed = val
		_queue_rebuild()

@export_group("Physics")
@export var enable_collision: bool = true:
	set(val):
		enable_collision = val
		_update_collision()

@export_group("Actions")
## Click in inspector to force a rebuild.
@export var rebuild_fence: bool = false:
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
	_rebuild_pending = false
	rebuild()


func get_effective_spacing() -> float:
	if is_zero_approx(spacing):
		return FENCE_LENGTH * fence_scale
	return spacing


func rebuild() -> void:
	# Clear previous generated fence children immediately
	for child in get_children():
		if child.has_meta(&"modular_fence_segment"):
			remove_child(child)
			child.queue_free()
	
	var eff_spacing := get_effective_spacing()
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	
	var current_pos := Vector3.ZERO
	var current_rot_deg: float = 0.0
	
	for i in range(segment_count):
		var piece_idx := _pick_piece_index(i, rng)
		var piece_scene := FENCE_SCENES[piece_idx]
		var piece := piece_scene.instantiate() as StaticBody3D
		piece.name = "Segment_%02d_Var%d" % [i + 1, piece_idx + 1]
		piece.set_meta(&"modular_fence_segment", true)
		
		# Apply transform
		piece.position = current_pos
		piece.rotation_degrees = Vector3(0, current_rot_deg, 0)
		piece.scale = Vector3(fence_scale, fence_scale, fence_scale)
		
		if not enable_collision:
			for col in piece.find_children("", "CollisionShape3D", false):
				(col as CollisionShape3D).disabled = true
		
		add_child(piece)
		if Engine.is_editor_hint():
			piece.owner = get_tree().edited_scene_root
		
		# Advance position for next segment in local direction
		var forward_step := Vector3(eff_spacing, 0, 0).rotated(Vector3.UP, deg_to_rad(current_rot_deg))
		current_pos += forward_step
		current_rot_deg += angle_per_segment_deg


func _pick_piece_index(index: int, rng: RandomNumberGenerator) -> int:
	match pattern_mode:
		PatternMode.SEQUENTIAL:
			return index % FENCE_SCENES.size()
		PatternMode.RANDOM:
			return rng.randi_range(0, FENCE_SCENES.size() - 1)
		PatternMode.SINGLE_PIECE:
			return clampi(single_piece_variant - 1, 0, FENCE_SCENES.size() - 1)
		PatternMode.CUSTOM_SEQUENCE:
			if custom_sequence.is_empty():
				return 0
			var val := custom_sequence[index % custom_sequence.size()]
			return clampi(val - 1, 0, FENCE_SCENES.size() - 1)
	return 0


func _update_collision() -> void:
	for child in get_children():
		if child.has_meta(&"modular_fence_segment") and child is StaticBody3D:
			for col in child.find_children("", "CollisionShape3D", false):
				(col as CollisionShape3D).disabled = not enable_collision


## Converts generated segments into independent persistent nodes and detaches this generator script.
func bake_to_standalone_nodes() -> void:
	for child in get_children():
		if child.has_meta(&"modular_fence_segment"):
			child.remove_meta(&"modular_fence_segment")
			if Engine.is_editor_hint() and get_tree().edited_scene_root:
				child.owner = get_tree().edited_scene_root
	set_script(null)
