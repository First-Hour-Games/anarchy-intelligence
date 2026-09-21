extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_test")


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1


func run_test() -> void:
	var door := (load("res://models/interior/door/door_2.tscn") as PackedScene).instantiate() as InteractiveDoor
	root.add_child(door)
	await process_frame

	var hinge := door.get_node_or_null("HingePivot") as AnimatableBody3D
	var interactable := door.get_node_or_null("Interactable") as Interactable3D
	check(is_instance_valid(hinge), "door creates a hinge pivot")
	check(door.has_node("HingePivot/CollisionShape3D"), "door creates moving collision")
	check(is_instance_valid(interactable) and interactable.is_in_group("interactable"), "door registers one interactable")
	check(interactable.get_prompt_world_position().distance_to(door.global_position) > 0.1, "prompt tracks the door leaf")

	var closed_angle := hinge.rotation.y
	interactable.interact(door)
	check((door.get_node("OpeningSound") as AudioStreamPlayer3D).playing, "opening interaction plays the door creak")
	await create_timer(door.open_duration + 0.1).timeout
	check(door.is_open, "interaction opens the door")
	check(absf(hinge.rotation.y - closed_angle) > 1.0, "door leaf rotates around its hinge")
	check(hinge.scale.is_equal_approx(Vector3.ONE), "door hinge scale stays stable while open")

	interactable.interact(door)
	await create_timer(door.open_duration + 0.1).timeout
	check(not door.is_open, "second interaction closes the door")
	check(is_equal_approx(hinge.rotation.y, closed_angle), "door returns to its closed angle")
	check(hinge.scale.is_equal_approx(Vector3.ONE), "door hinge scale stays stable after closing")

	door.queue_free()
	await process_frame

	var tutorial := (load("res://scenes/chapters/tutorial/tutorial.tscn") as PackedScene).instantiate()
	root.add_child(tutorial)
	await process_frame
	var baked_wall := tutorial.get_node_or_null("TutorialRooms/CSGBakedMeshInstance3D") as MeshInstance3D
	var doorway_collision := tutorial.get_node_or_null("TutorialRooms/CollisionGeometry/CollisionShape3D3") as CollisionShape3D
	check(is_instance_valid(baked_wall), "rear tutorial CSG wall is baked to a mesh")
	check(doorway_collision != null and doorway_collision.shape is ConcavePolygonShape3D, "baked wall uses its cutout collision")
	check(tutorial.has_node("Door3/HingePivot"), "tutorial uses the interactive inherited door")
	check(not tutorial.has_node("DoorInteractable"), "tutorial has no duplicate door interactable")
	var color_copy := tutorial.get_node_or_null("DoorColorViewport/DoorColorCopy")
	check(is_instance_valid(color_copy), "tutorial creates the full-color door copy")
	check(color_copy != null and color_copy.get_script() == null, "color copy has no gameplay script")
	check(color_copy != null and color_copy.has_node("HingePivot"), "color copy retains the animated hinge")

	var tutorial_door := tutorial.get_node("Door3") as InteractiveDoor
	check(not tutorial_door.can_close, "tutorial door is configured as one-way")
	var source_hinge := tutorial_door.get_node("HingePivot") as Node3D
	var copy_hinge := color_copy.get_node("HingePivot") as Node3D
	var closed_doorway_center := (tutorial_door.get_node("Interactable") as Interactable3D).get_prompt_world_position()
	tutorial_door.toggle(tutorial.get_node("Player"))
	check(not (tutorial_door.get_node("Interactable") as Interactable3D).is_in_group("interactable"), "one-way door stops prompting after use")
	await create_timer(tutorial_door.open_duration * 0.5).timeout
	tutorial.call("_sync_color_pass")
	check(absf(source_hinge.rotation.y) > 0.1, "tutorial door starts opening")
	check(is_equal_approx(copy_hinge.rotation.y, source_hinge.rotation.y), "full-color door copy follows the hinge")
	await create_timer(tutorial_door.open_duration * 0.6).timeout
	await physics_frame
	var doorway_ray := PhysicsRayQueryParameters3D.create(
		Vector3(closed_doorway_center.x, closed_doorway_center.y, -2.0),
		Vector3(closed_doorway_center.x, closed_doorway_center.y, -5.0)
	)
	var doorway_hit: Dictionary = tutorial.get_world_3d().direct_space_state.intersect_ray(doorway_ray)
	if not doorway_hit.is_empty():
		print("Doorway blocker: ", (doorway_hit.collider as Node).get_path(), " at ", doorway_hit.position)
	check(doorway_hit.is_empty(), "opened door leaves the doorway collision clear")
	var player_capsule := CapsuleShape3D.new()
	player_capsule.radius = 0.35
	player_capsule.height = 1.8
	var passage_query := PhysicsShapeQueryParameters3D.new()
	passage_query.shape = player_capsule
	passage_query.transform = Transform3D(Basis.IDENTITY, Vector3(closed_doorway_center.x, 0.41, -2.0))
	passage_query.motion = Vector3(0.0, 0.0, -3.0)
	var passage_motion: PackedFloat32Array = tutorial.get_world_3d().direct_space_state.cast_motion(passage_query)
	if passage_motion[0] <= 0.99:
		print("Player passage safe fraction: ", passage_motion[0])
		for sample_z in [-2.0, -3.0, -3.5, -4.0, -5.0]:
			passage_query.transform.origin.z = sample_z
			var overlaps: Array[Dictionary] = tutorial.get_world_3d().direct_space_state.intersect_shape(passage_query, 16)
			for overlap in overlaps:
				print("Capsule overlap z=", sample_z, ": ", (overlap.collider as Node).get_path())
	check(passage_motion[0] > 0.99, "player capsule fits through the opened doorway")

	quit(1 if failures > 0 else 0)
