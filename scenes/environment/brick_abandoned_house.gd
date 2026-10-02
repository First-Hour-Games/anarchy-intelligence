@tool
extends Node3D

## Keeps the hero brick house while removing the pack's distant showcase scenery.

const HIDDEN_SOURCE_NODES: PackedStringArray = [
	"Vecindario",
	"Cylinder",
	"Cylinder_001",
	"Radio_001",
	"Base",
	"Ban",
]
const OPEN_DOOR_PATH := NodePath("Casa/Puerta")
const STRUCTURE_PATH := NodePath("Casa")
const FLOOR_COLLISION_PATH := NodePath("Colision")
const GENERATED_COLLISION_NAME := "GeneratedStructuralCollision"
const COLLISION_EXCLUDED_NAMES: PackedStringArray = ["Puerta", "Marco_P_014"]
const DOOR_COLLISION_CLEARANCE := AABB(Vector3(11.05, -0.2, 9.25), Vector3(1.4, 2.6, 1.15))


func _ready() -> void:
	var source := get_node_or_null("Source") as Node3D
	if source == null:
		push_warning("Brick abandoned house source model is missing.")
		return
	_prepare_source(source)
	_improve_texture_filtering(source, {})
	if not Engine.is_editor_hint():
		add_to_group("enemy_route_building")
		_build_structural_collision(source)
		var doorway := NavigationLink3D.new()
		doorway.name = "OpenDoorwayRoute"
		doorway.start_position = Vector3(11.75, 0.25, 12.5)
		doorway.end_position = Vector3(11.75, 0.25, 7.5)
		add_child(doorway)
		var stairs := NavigationLink3D.new()
		stairs.name = "MainStairRoute"
		stairs.start_position = Vector3(10.85, 0.1, 1.25)
		stairs.end_position = Vector3(5.4, 3.57, 2.8)
		add_child(stairs)

func contains_route_point(point: Vector3) -> bool:
	var local := to_local(point)
	return local.x > -17 and local.x < 19 and local.z > -10.5 and local.z < 9.65 and local.y > -0.3 and local.y < 7

func route_transitions(from: Vector3, destination: Vector3) -> Array[Dictionary]:
	var gates: Array[Dictionary] = []
	var start := to_local(from)
	var goal := to_local(destination)
	var inside_start := contains_route_point(from)
	var inside_goal := contains_route_point(destination)
	if not inside_start and inside_goal:
		gates.append({"point": to_global(Vector3(11.75, 0.1, 12.5)), "direct": false})
		gates.append({"point": to_global(Vector3(11.75, 0.1, 9.8)), "direct": true})
		gates.append({"point": to_global(Vector3(11.75, 0.1, 7.5)), "direct": true})
	if inside_goal and goal.y > 2.5 and (not inside_start or start.y < 2.5):
		gates.append({"point": to_global(Vector3(10.85, 0.1, 1.25)), "direct": false})
		gates.append({"point": to_global(Vector3(5.65, 3.57, 1.25)), "direct": true})
		gates.append({"point": to_global(Vector3(5.4, 3.57, 1.25)), "direct": true})
		gates.append({"point": to_global(Vector3(5.4, 3.57, 2.8)), "direct": true})
	elif inside_start and start.y > 2.5 and (not inside_goal or goal.y < 2.5):
		gates.append({"point": to_global(Vector3(5.4, 3.57, 2.8)), "direct": false})
		gates.append({"point": to_global(Vector3(5.4, 3.57, 1.25)), "direct": true})
		gates.append({"point": to_global(Vector3(5.65, 3.57, 1.25)), "direct": true})
		gates.append({"point": to_global(Vector3(10.85, 0.1, 1.25)), "direct": true})
	if inside_start and not inside_goal:
		gates.append({"point": to_global(Vector3(11.75, 0.1, 7.5)), "direct": false})
		gates.append({"point": to_global(Vector3(11.75, 0.1, 9.8)), "direct": true})
		gates.append({"point": to_global(Vector3(11.75, 0.1, 12.5)), "direct": true})
	return gates


func _prepare_source(source: Node3D) -> void:
	for child_name: String in HIDDEN_SOURCE_NODES:
		var child := source.get_node_or_null(NodePath(child_name)) as Node3D
		if child != null:
			child.visible = false
	for child: Node in source.get_children():
		if child is Node3D and str(child.name).begins_with("Reseptor"):
			(child as Node3D).visible = false

	var front_door := source.get_node_or_null(OPEN_DOOR_PATH) as Node3D
	if front_door != null:
		front_door.visible = false
	else:
		push_warning("Brick abandoned house entrance door mesh was not found.")


func _improve_texture_filtering(node: Node, material_cache: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in mesh_instance.mesh.get_surface_count():
				var source_material := mesh_instance.get_active_material(surface_index) as BaseMaterial3D
				if source_material == null:
					continue
				var material_id := source_material.get_instance_id()
				var improved_material := material_cache.get(material_id) as BaseMaterial3D
				if improved_material == null:
					improved_material = source_material.duplicate() as BaseMaterial3D
					improved_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					material_cache[material_id] = improved_material
				mesh_instance.set_surface_override_material(surface_index, improved_material)
	for child: Node in node.get_children():
		_improve_texture_filtering(child, material_cache)


func _build_structural_collision(source: Node3D) -> void:
	var previous := get_node_or_null(GENERATED_COLLISION_NAME)
	if previous != null:
		previous.queue_free()

	var collision_body := StaticBody3D.new()
	collision_body.name = GENERATED_COLLISION_NAME
	add_child(collision_body)

	var collision_index := 0
	var structure := source.get_node_or_null(STRUCTURE_PATH)
	if structure != null:
		collision_index = _append_mesh_collisions(
			structure,
			source.transform,
			collision_body,
			collision_index,
			str(structure.name)
		)
	var floor_collision := source.get_node_or_null(FLOOR_COLLISION_PATH)
	if floor_collision != null:
		collision_index = _append_mesh_collisions(
			floor_collision,
			source.transform,
			collision_body,
			collision_index,
			str(floor_collision.name)
		)
	if collision_index == 0:
		push_warning("Brick abandoned house generated no structural collision shapes.")


func _append_mesh_collisions(
	node: Node,
	parent_transform: Transform3D,
	collision_body: StaticBody3D,
	collision_index: int,
	source_path: String
) -> int:
	var current_transform := parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform

	if node is MeshInstance3D and str(node.name) not in COLLISION_EXCLUDED_NAMES:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var shape: Shape3D
			var shape_transform := current_transform
			if str(node.name) == "Casa":
				shape = _create_doorway_structure_shape(mesh_instance.mesh, current_transform)
				shape_transform = Transform3D.IDENTITY
			else:
				shape = mesh_instance.mesh.create_trimesh_shape()
			if shape != null:
				var collision_shape := CollisionShape3D.new()
				collision_shape.name = "StructureCollision_%03d" % collision_index
				collision_shape.shape = shape
				collision_shape.transform = shape_transform
				collision_shape.set_meta("source_mesh_path", source_path)
				collision_body.add_child(collision_shape)
				collision_index += 1

	for child: Node in node.get_children():
		collision_index = _append_mesh_collisions(
			child,
			current_transform,
			collision_body,
			collision_index,
			source_path + "/" + str(child.name)
		)
	return collision_index


func _create_doorway_structure_shape(mesh: Mesh, mesh_transform: Transform3D) -> ConcavePolygonShape3D:
	var source_faces := mesh.get_faces()
	var filtered_faces := PackedVector3Array()
	for face_index in range(0, source_faces.size(), 3):
		var first: Vector3 = mesh_transform * source_faces[face_index]
		var second: Vector3 = mesh_transform * source_faces[face_index + 1]
		var third: Vector3 = mesh_transform * source_faces[face_index + 2]
		var triangle_bounds := AABB(first, Vector3.ZERO).expand(second).expand(third)
		if triangle_bounds.intersects(DOOR_COLLISION_CLEARANCE):
			continue
		filtered_faces.append(first)
		filtered_faces.append(second)
		filtered_faces.append(third)

	if filtered_faces.is_empty():
		return null
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(filtered_faces)
	shape.backface_collision = true
	return shape
