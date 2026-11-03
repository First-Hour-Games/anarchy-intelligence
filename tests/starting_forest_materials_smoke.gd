extends SceneTree

var _checked: Dictionary = {}
var _failures: Array[String] = []


func _initialize() -> void:
	run_checks.call_deferred()


func _check_material(material: Material, usage: String) -> void:
	if material == null or _checked.has(material):
		return
	_checked[material] = true
	if material is BaseMaterial3D:
		# Screen-space fog reads opaque color/depth. Alpha blending (including
		# its depth-prepass mode) can draw solid assets over the completed fog.
		if material.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]:
			_failures.append("%s: blended world material %s" % [usage, material.resource_path])
		if material.disable_fog:
			_failures.append("%s: world material disables fog" % usage)
	# Screen-reading glass and the distance-fog shader have intentional separate
	# passes; this check applies to ordinary lit world materials.
	_check_material(material.next_pass, usage + " next pass")


func _check_node(node: Node) -> void:
	# This translucent editor/debug visualization is deliberately not world art.
	if node.name == &"_ZoneBoxPreview":
		return
	var usage := str(node.get_path())
	if node is GeometryInstance3D:
		_check_material(node.material_override, usage)
		_check_material(node.material_overlay, usage)
	if node is MeshInstance3D and node.mesh:
		for surface in node.mesh.get_surface_count():
			_check_material(node.get_active_material(surface), usage)
	elif node is MultiMeshInstance3D and node.multimesh and node.multimesh.mesh:
		for surface in node.multimesh.mesh.get_surface_count():
			_check_material(node.material_override if node.material_override else node.multimesh.mesh.surface_get_material(surface), usage)
	elif node is CSGPrimitive3D:
		_check_material(node.material, usage)
	for child in node.get_children():
		_check_node(child)


func run_checks() -> void:
	var forest: StartingForest = load("res://scenes/chapters/main/starting_forest.tscn").instantiate()
	forest.auto_start_fade = false
	forest.get_node("BottomDialogueBalloon").auto_start = false
	root.add_child(forest)
	await process_frame
	await process_frame
	_check_node(forest)
	for failure in _failures:
		push_error(failure)
	var failed := not _failures.is_empty()
	if not failed:
		print("PASS: %d forest materials checked; world surfaces support screen-space fog" % _checked.size())
	forest.queue_free()
	await process_frame
	quit(1 if failed else 0)
