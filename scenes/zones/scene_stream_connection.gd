@tool
extends Node3D
## Both outdoor scenes use this marker at the same world-space road crossing.
@export_range(30.0, 300.0, 5.0) var preload_distance := 140.0
## Radial distance to release the neighbor; runtime keeps this beyond the preload radius.
@export_range(20.0, 400.0, 5.0) var unload_distance := 180.0
@export_range(1.0, 15.0, 0.5) var crossing_hysteresis := 3.0
## Reject trees whose transformed mesh bounds overlap another loaded tree.
@export var avoid_tree_canopy_overlap := true
## Keep editor-authored density within each section; reconcile spacing only across sections.
@export var preserve_authored_tree_spacing := true

@export_group("Editor preview")
## Shows the saved neighbor so house placements can be checked against its buildings.
@export var show_neighbor_in_editor := false:
	set(value):
		show_neighbor_in_editor = value
		_queue_editor_preview()
@export_file("*.tscn") var editor_neighbor_scene := "":
	set(value):
		editor_neighbor_scene = value
		_queue_editor_preview()

var _editor_preview: Node3D
var _preview_pending := false
var _preview_poll := 0.0
var _neighbor_modified := 0

func _ready() -> void:
	if Engine.is_editor_hint():
		_queue_editor_preview()
		return
	set_process(false)
	WorldStreaming.register_section.call_deferred(get_parent(), self)

func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or editor_neighbor_scene.is_empty() or not show_neighbor_in_editor:
		return
	_preview_poll += delta
	if _preview_poll < 1.0:
		return
	_preview_poll = 0.0
	if FileAccess.get_modified_time(editor_neighbor_scene) != _neighbor_modified:
		_queue_editor_preview()

func _queue_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() or _preview_pending:
		return
	_preview_pending = true
	_refresh_editor_preview.call_deferred()

func _refresh_editor_preview() -> void:
	_preview_pending = false
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if is_instance_valid(_editor_preview):
		_editor_preview.free()
	if not show_neighbor_in_editor or editor_neighbor_scene.is_empty():
		return
	_neighbor_modified = FileAccess.get_modified_time(editor_neighbor_scene)
	_editor_preview = preload("res://scenes/zones/streaming_editor_preview.gd").create(editor_neighbor_scene)
	if _editor_preview != null:
		# Internal and unowned: visible in 3D, excluded from packing the scene.
		add_child(_editor_preview, false, Node.INTERNAL_MODE_BACK)
