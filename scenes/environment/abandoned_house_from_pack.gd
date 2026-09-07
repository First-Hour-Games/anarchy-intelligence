@tool
extends Node3D

## Lightweight, single-house wrapper around the Abandoned House environment pack.
## The source FBX contains a complete showcase neighborhood. This wrapper reuses
## one house mesh so map designers can place homes as individual road-side lots.

const SOURCE_SCENE_PATH := "res://assets/local_licensed/house/Models/House.fbx"
const SOURCE_MESH_NAME := "House"
const GENERATED_ROOT_NAME := "GeneratedHouse"

static var _cached_mesh: Mesh
static var _cached_transform := Transform3D.IDENTITY
static var _cached_ground_center := Vector3.ZERO
static var _cached_size := Vector3.ZERO

@export var collision_enabled: bool = true


func _ready() -> void:
	_build_house()


func _build_house() -> void:
	var existing := get_node_or_null(GENERATED_ROOT_NAME)
	if existing:
		existing.free()

	if not _ensure_source_cache():
		return

	var generated_root := Node3D.new()
	generated_root.name = GENERATED_ROOT_NAME
	add_child(generated_root)

	var house_mesh := MeshInstance3D.new()
	house_mesh.name = "HouseMesh"
	house_mesh.mesh = _cached_mesh
	house_mesh.transform = _cached_transform
	house_mesh.position -= _cached_ground_center
	generated_root.add_child(house_mesh)

	if collision_enabled:
		_add_collision(generated_root, _cached_size)


func _ensure_source_cache() -> bool:
	if _cached_mesh != null:
		return true

	var packed_scene := load(SOURCE_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Unable to load abandoned-house pack: %s" % SOURCE_SCENE_PATH)
		return false

	var source_root: Node = packed_scene.instantiate()
	var source_mesh := source_root.get_node_or_null(NodePath(SOURCE_MESH_NAME)) as MeshInstance3D
	if source_mesh == null or source_mesh.mesh == null:
		push_error("Unable to find the '%s' mesh in the abandoned-house pack." % SOURCE_MESH_NAME)
		source_root.free()
		return false

	var source_bounds: AABB = source_mesh.transform * source_mesh.get_aabb()
	_cached_mesh = source_mesh.mesh
	_cached_transform = source_mesh.transform
	_cached_ground_center = Vector3(
		source_bounds.get_center().x,
		source_bounds.position.y,
		source_bounds.get_center().z
	)
	_cached_size = source_bounds.size
	source_root.free()
	return true


func _add_collision(parent: Node3D, house_size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "HouseCollision"
	parent.add_child(body)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(house_size.x * 0.92, house_size.y, house_size.z * 0.92)
	collision.shape = shape
	collision.position.y = house_size.y * 0.5
	body.add_child(collision)
