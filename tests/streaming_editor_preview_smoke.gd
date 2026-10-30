extends SceneTree

const PREVIEW = preload("res://scenes/zones/streaming_editor_preview.gd")
const STREAMING = preload("res://scenes/shared/world_streaming.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func authored_transform(node: Node3D) -> Transform3D:
	var world := node.transform
	var ancestor := node.get_parent()
	while ancestor is Node3D:
		world = ancestor.transform * world
		ancestor = ancestor.get_parent()
	return world

func run() -> void:
	for path: String in [STREAMING.FOREST, STREAMING.RESIDENCE]:
		var original: Node3D = load(path).instantiate()
		var preview: Node3D = PREVIEW.create(path)
		check(preview != null, "Saved neighbor can be previewed")
		var holder := Node3D.new()
		var marker := Node3D.new()
		marker.position = Vector3(126.8, 3, 69)
		holder.add_child(marker)
		marker.owner = holder
		marker.add_child(preview, false, Node.INTERNAL_MODE_BACK)
		root.add_child(holder)
		var meshes := 0
		for mesh in preview.find_children("*", "MeshInstance3D", true, false):
			var saved: Node3D = original.get_node(preview.get_path_to(mesh))
			check(mesh.global_transform.is_equal_approx(authored_transform(saved)), "Neighbor meshes retain saved world placement: " + String(mesh.name))
			meshes += 1
		for node_name in STREAMING.SHARED_NAMES:
			check(not preview.has_node(NodePath(node_name)), "Preview must not duplicate shared " + node_name)
		for node in preview.find_children("*", "Node", true, false):
			check(node.get_script() == null, "Preview must not run source scripts")
			if node is CollisionObject3D:
				check(node.collision_layer == 0 and node.collision_mask == 0, "Preview must not register gameplay collision")
			if node is CSGShape3D:
				check(not node.use_collision, "Preview roads must not add collision")
		check(preview.owner == null, "Preview root must remain unowned")
		var packed := PackedScene.new()
		check(packed.pack(holder) == OK, "Scene with preview can still be saved")
		var restored := packed.instantiate()
		check(restored.get_child(0).get_child_count(true) == 0, "Editor preview must not be saved or enter runtime")
		restored.free()
		print("Checked preview of ", path.get_file(), ": ", meshes, " meshes retain world placement")
		holder.free()
		original.free()
	print("Streaming editor preview: ", failures, " failures")
	quit(0 if failures == 0 else 1)
