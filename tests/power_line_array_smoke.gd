extends SceneTree

const ARRAY_SCENE = preload("res://models/map/residence/power_lines/power_line_array.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var row = ARRAY_SCENE.instantiate()
	row.pole_count = 12
	row.spacing = 9.0
	root.add_child(row)
	await process_frame
	assert(row.get_child_count() == 12, "Must create the requested count")
	for i in range(12):
		var pole: Node3D = row.get_child(i)
		assert(pole.position.is_equal_approx(Vector3(i * 9.0, 0.0, 0.0)))
		assert(pole.name.ends_with("Variant_%d" % (i % 9 + 1)))
		assert(pole.owner == null, "Preview geometry must not be saved twice")

	# Every extracted variant includes all its materials and has a grounded pivot.
	for scene in row.VARIANTS:
		var pole: Node3D = scene.instantiate()
		root.add_child(pole)
		var bounds := AABB()
		var first := true
		for mesh_node: MeshInstance3D in pole.find_children("*", "MeshInstance3D", true, false):
			var mesh_bounds: AABB = mesh_node.global_transform * mesh_node.mesh.get_aabb()
			bounds = mesh_bounds if first else bounds.merge(mesh_bounds)
			first = false
			for surface in range(mesh_node.mesh.get_surface_count()):
				assert(mesh_node.mesh.surface_get_material(surface) != null)
		assert(not first, "Each pole must contain mesh geometry")
		assert(absf(bounds.position.y) < 0.01, "Pole base must be at Y=0")
		assert(bounds.size.y >= 19.0 and bounds.size.y <= 29.0, "Poles must be upright")
		assert(bounds.size.z < 4.0, "Extracted variant must contain only one pole")
		pole.free()

	# Multiple edits coalesce into a rebuild and leave unrelated children alone.
	var marker := Marker3D.new()
	row.add_child(marker)
	row.pole_count = 3
	row.variant = 7
	row.pole_scale = 0.5
	row.pole_rotation_degrees = 90.0
	await process_frame
	await process_frame
	assert(row.get_child_count() == 4)
	for child in row.get_children():
		if child == marker:
			continue
		assert(child.name.ends_with("Variant_7"))
		assert(child.scale.is_equal_approx(Vector3.ONE * 0.5))
		assert(is_equal_approx(child.rotation_degrees.y, 90.0))
	row.rebuild()
	assert(row.get_child_count() == 4, "Rebuild must replace rather than duplicate poles")

	# Saving and reinstancing keeps the parameters and regenerates exactly one row.
	var saved := PackedScene.new()
	assert(saved.pack(row) == OK)
	var restored = saved.instantiate()
	root.add_child(restored)
	assert(restored.get_child_count() == 3)
	assert(restored.spacing == 9.0 and restored.variant == 7)
	row.pole_count = 0
	await process_frame
	await process_frame
	assert(row.get_child_count() == 1 and row.get_child(0) == marker)
	row.queue_free()
	restored.queue_free()
	await process_frame
	print("PASS: Power-line variants, layout, live edits, rebuild, and save/reload")
	quit(0)
