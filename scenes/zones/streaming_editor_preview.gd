@tool
extends RefCounted
## Visual copy of the saved neighbor, excluded from scene saving and runtime.

const SHARED_NAMES = preload("res://scenes/shared/world_streaming.gd").SHARED_NAMES

static func create(path: String) -> Node3D:
	var packed := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		return null
	var preview := packed.instantiate() as Node3D
	if preview == null:
		return null
	# Remove scripts before entering the tree, preventing recursive previews and
	# procedural layout scripts from running inside this visual copy.
	strip_behavior(preview)
	for node_name in SHARED_NAMES:
		var duplicate := preview.get_node_or_null(NodePath(node_name))
		if duplicate != null:
			duplicate.free()
	preview.name = "StreamingNeighborPreview"
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	# Connection markers are offset, but both sections use shared world coordinates.
	preview.top_level = true
	return preview

static func strip_behavior(node: Node) -> void:
	node.set_script(null)
	node.set_meta("_edit_lock_", true)
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is CollisionShape3D:
		node.disabled = true
	if node is CSGShape3D:
		node.use_collision = false
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.autoplay = false
	if node is Camera3D:
		node.current = false
	for child in node.get_children():
		strip_behavior(child)
