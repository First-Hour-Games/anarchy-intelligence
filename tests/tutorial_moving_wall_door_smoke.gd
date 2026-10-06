extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_test")


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1


func run_test() -> void:
	var tutorial := (load("res://scenes/chapters/tutorial/tutorial.tscn") as PackedScene).instantiate()
	root.add_child(tutorial)
	await process_frame
	var zone := tutorial.get_node("TutorialRooms/MovingWallZone") as MovingWallZone
	var door := tutorial.get_node("TutorialRooms/BakedMovingWall/WhiteDoor") as InteractiveDoor
	var first_door := tutorial.get_node("Door3") as InteractiveDoor
	var interactable := door.get_node("Interactable") as Interactable3D
	var hinge := door.get_node("HingePivot") as AnimatableBody3D
	var handle := hinge.get_node("Door Handle_011") as Node3D
	var player := tutorial.get_node("Player") as Node3D
	check(not player.sprint_enabled, "tutorial sprint starts locked")
	var leaf_bounds := door._get_mesh_bounds_in_door_space(door._door_leaf)
	check(is_equal_approx(hinge.position.x, leaf_bounds.end.x), "white door hinges on the left when approached from the hallway")
	check(door.to_local(handle.global_position).x < door._door_center_local.x, "handle is opposite the hinge")
	check(not interactable.is_in_group(&"interactable"), "white door has no prompt before wall movement")
	door.toggle(player)
	check(not door._is_animating, "white door rejects interaction before movement completes")
	check(door.open_duration == first_door.open_duration and door.open_angle_degrees == first_door.open_angle_degrees, "white door matches first door opening settings")
	zone.trigger()
	await create_timer(0.2).timeout
	check(not interactable.is_in_group(&"interactable"), "white door stays locked during movement")
	check(not player.sprint_enabled, "sprint stays locked while the wall drags")
	await zone._active_tween.finished
	check(player.sprint_enabled, "wall completion unlocks sprint")
	check(interactable.is_in_group(&"interactable"), "white door unlocks when wall tween finishes")
	var center := interactable.get_prompt_world_position()
	player.set_process(false)
	player.set_physics_process(false)
	player.global_position = center + Vector3(0.0, 0.0, 1.5)
	check(interactable.can_interact(player), "player can interact within normal door range")
	var handle_transform := handle.transform
	var closed_angle := hinge.rotation.y
	var closed_center := door.to_global(door._door_center_local)
	interactable.interact(player)
	check(door.get_node("OpeningSound").playing, "white door plays the opening creak")
	check(not interactable.is_in_group(&"interactable"), "one-way white door removes its prompt after use")
	await door._motion_tween.finished
	await physics_frame
	check(door.is_open and absf(hinge.rotation.y - closed_angle) > 1.0, "white door opens around its hinge")
	check(handle.transform.is_equal_approx(handle_transform), "handle remains attached to the moving hinge")
	var open_center := door._door_leaf.global_transform * door._door_leaf.get_aabb().get_center()
	check(open_center.z < closed_center.z, "white door swings away from the hallway player")
	check(door._door_collision.disabled, "open door collision is disabled")
	var ray := PhysicsRayQueryParameters3D.create(center + Vector3(0.0, 0.0, 1.0), center - Vector3(0.0, 0.0, 1.0))
	var hit: Dictionary = tutorial.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		print("Doorway blocker: ", hit.collider.get_path())
	check(hit.is_empty(), "opened white doorway is clear of wall collision")
	tutorial.queue_free()
	await process_frame
	quit(1 if failures else 0)
