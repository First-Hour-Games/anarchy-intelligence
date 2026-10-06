extends "res://models/interior/door/interactive_door.gd"

@export var moving_wall_zone_path: NodePath = NodePath("../../MovingWallZone")

var _interaction_unlocked := false


func _ready() -> void:
	super._ready()
	if not is_instance_valid(_interactable):
		return
	_interactable.remove_from_group(&"interactable")
	var zone := get_node(moving_wall_zone_path) as MovingWallZone
	zone.wall_move_started.connect(_on_wall_started)
	zone.wall_move_completed.connect(_on_wall_completed)


func _create_hinge(door_bounds: AABB) -> void:
	super._create_hinge(door_bounds)
	# The imported handle is a sibling of the leaf mesh, so move it with the hinge too.
	var handle := get_node("Wooden Door_006/Door Handle_011") as Node3D
	handle.reparent(_hinge, true)


func toggle(interactor: Node3D = null) -> void:
	if not _interaction_unlocked:
		return
	super.toggle(interactor)


func _on_wall_started(_wall: Node3D, _target_z: float, _duration: float) -> void:
	_interaction_unlocked = false
	_interactable.remove_from_group(&"interactable")


func _on_wall_completed(_wall: Node3D, _final_z: float) -> void:
	_interaction_unlocked = true
	if not is_open and not _is_animating:
		_interactable.add_to_group(&"interactable")
