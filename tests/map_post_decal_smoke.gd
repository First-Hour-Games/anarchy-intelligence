extends SceneTree

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, words: String) -> void:
	print(("PASS: " if value else "FAIL: ") + words)
	if not value:
		failures += 1

func run() -> void:
	print("--- Running Map Post Decal Smoke Test ---")
	
	var packed_forest := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	check(packed_forest != null, "Loaded starting_forest.tscn")
	
	var forest := packed_forest.instantiate()
	root.add_child(forest)
	await process_frame
	
	var map_stand := forest.find_child("mapStand_V3", true, false) as Node3D
	check(is_instance_valid(map_stand), "mapStand_V3 found in starting_forest")
	
	var decal := map_stand.find_child("MapPostDecal", true, false) as Decal
	check(is_instance_valid(decal), "MapPostDecal node found under mapStand_V3")
	
	if is_instance_valid(decal):
		check(decal.texture_albedo != null, "Decal has texture_albedo assigned")
		if decal.texture_albedo:
			check(decal.texture_albedo.resource_path == "res://img/textures/mapPost.png", "Decal texture is mapPost.png")
		
		check(is_equal_approx(decal.size.x, 3.16), "Decal size.x is ~3.16 (covers canvas width)")
		check(is_equal_approx(decal.size.z, 1.4), "Decal size.z is ~1.4 (covers canvas height)")
		check(is_equal_approx(decal.position.y, 2.23), "Decal is centered vertically on canvas (y = 2.23)")
		print("Actual decal rotation_degrees: ", decal.rotation_degrees)
		check(is_equal_approx(decal.rotation_degrees.x, 90.0) or is_equal_approx(abs(decal.rotation_degrees.x), 90.0), "Decal is rotated 90 degrees around X to project onto canvas")
		
		# Check that decal is in front of inspection camera anchor
		var inspect_view := forest.find_child("InspectableView", true, false) as InspectableView3D
		check(is_instance_valid(inspect_view), "InspectableView found")
		if is_instance_valid(inspect_view):
			var cam_anchor := inspect_view.find_child("CameraAnchor", true, false) as Marker3D
			check(is_instance_valid(cam_anchor), "CameraAnchor found")
			if is_instance_valid(cam_anchor):
				var dist: float = cam_anchor.global_position.distance_to(decal.global_position)
				check(dist < 2.5, "Decal is framed in front of inspection camera (distance %.2fm)" % dist)
	
	forest.queue_free()
	
	print("--- Map Post Decal Smoke Test Complete ---")
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED with %d errors" % failures)
		quit(1)
