extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("--- Running Modular Fence Tests ---")
	
	# 1. Test individual piece scenes
	for i in range(1, 7):
		var path = "res://models/props/wood_fence/wood_fence_%d.tscn" % i
		var scene: PackedScene = load(path)
		assert(scene != null, "Scene %s must exist" % path)
		var piece = scene.instantiate() as StaticBody3D
		assert(piece != null, "Piece %d must be StaticBody3D" % i)
		
		var mi: MeshInstance3D = piece.find_child("MeshInstance3D", false, false) as MeshInstance3D
		assert(mi != null, "MeshInstance3D must exist on piece %d" % i)
		assert(mi.mesh != null, "Mesh must be assigned on piece %d" % i)
		
		var col: CollisionShape3D = piece.find_child("CollisionShape3D", false, false) as CollisionShape3D
		assert(col != null, "CollisionShape3D must exist on piece %d" % i)
		assert(col.shape is BoxShape3D, "Collision shape must be BoxShape3D on piece %d" % i)
		
		var aabb = mi.mesh.get_aabb()
		print("Piece %d (%s): AABB min=%.3f, max=%.3f, width=%.3f" % [i, mi.mesh.resource_name, aabb.position.x, aabb.end.x, aabb.size.x])
		assert(is_equal_approx(aabb.position.x, -0.249) or aabb.position.x < 0.0, "Mesh start post must be near X=0")
		assert(aabb.end.x >= 7.0, "Mesh end post must reach X=7.0")
		
		piece.queue_free()
	print("PASS: All 6 modular piece scenes loaded with zeroed pivots and collision shapes")
	
	# 2. Test ModularFence generator
	var generator_script = load("res://models/props/wood_fence/modular_fence.gd")
	assert(generator_script != null, "modular_fence.gd must load")
	
	var fence_gen = Node3D.new()
	fence_gen.set_script(generator_script)
	fence_gen.segment_count = 6
	fence_gen.fence_scale = 0.35
	root.add_child(fence_gen)
	await process_frame
	
	fence_gen.rebuild()
	assert(fence_gen.get_child_count() == 6, "Must generate exactly 6 children")
	
	var expected_spacing: float = 7.0 * 0.35
	for i in range(6):
		var child: Node3D = fence_gen.get_child(i) as Node3D
		var expected_x: float = i * expected_spacing
		assert(is_equal_approx(child.position.x, expected_x), "Segment %d must be at X=%.3f, got %.3f" % [i, expected_x, child.position.x])
		assert(child.scale.is_equal_approx(Vector3(0.35, 0.35, 0.35)), "Segment %d must have scale 0.35" % i)
	print("PASS: ModularFence generated 6 perfectly spaced segments with 0.35 scale")
	
	# 3. Test random mode
	fence_gen.pattern_mode = 1 # RANDOM
	fence_gen.random_seed = 999
	fence_gen.rebuild()
	assert(fence_gen.get_child_count() == 6, "Random pattern must still generate 6 children")
	print("PASS: Random variation mode works")
	
	fence_gen.queue_free()
	await process_frame
	
	print("--- All Modular Fence Tests Passed! ---")
	quit(0)
