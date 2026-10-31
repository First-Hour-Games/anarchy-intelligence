extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1

func passage_clear(gate: Node3D) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, gate.to_global(Vector3(0.6, 1.0, 2.0)))
	query.motion = gate.global_basis * Vector3(0, 0, -4.0)
	query.collision_mask = 1
	var fractions := gate.get_world_3d().direct_space_state.cast_motion(query)
	if gate.is_open and fractions[0] < 0.99:
		query.transform.origin += query.motion * minf(1.0, fractions[1] + 0.01)
		for hit in gate.get_world_3d().direct_space_state.intersect_shape(query):
			print("PASSAGE BLOCKER ", hit.collider.get_path(), " fraction ", fractions)
	return fractions[0] > 0.99

func run() -> void:
	# Test the instance and placement actually authored in Starting Forest.
	var forest := (load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene).instantiate()
	var station := forest.get_node("GasStation") as Node3D
	var gate: Variant = station.get_node("MetalFenceGate")
	var placement: Transform3D = forest.transform * station.transform
	var reference := station.get_node("Fence1") as MeshInstance3D
	var fence_height := (reference.transform * reference.get_aabb()).size.y
	forest.remove_child(station)
	station.owner = null
	root.add_child(station)
	station.global_transform = placement
	forest.free()
	check(absf(gate.get_node("GatePostCollision/CollisionShape3D").shape.size.y - fence_height) < 0.02, "gate height matches existing metal fences")
	check(gate._skeleton != null and gate._bone >= 0, "gate uses imported armature and leaf bone")
	check(not gate.is_open and not gate.is_moving, "gate starts closed")
	check(not station.get_node("Fence2").visible and station.get_node("Fence2/StaticBody3D/CollisionShape3D").disabled, "old fence panel and collider are replaced only in Starting Forest")
	check(not gate.leaf_body.sync_to_physics, "moving collision avoids inherited-scale synchronization")
	gate.swing_duration = 0.3
	gate.interactable.cooldown = 0.0
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as FirstPersonPlayer
	root.add_child(player)
	player.collision_layer = 0
	player.set_physics_process(false)
	player.global_position = gate.to_global(Vector3(0.7, 0, 1.8))
	player.look_at(Vector3(gate.interactable.global_position.x, player.global_position.y, gate.interactable.global_position.z))
	var detector := player.get_node("InteractionDetector") as InteractionDetector
	await physics_frame
	await physics_frame
	check(not passage_clear(gate), "closed gate blocks player-sized capsule")
	check(gate.is_locked, "gate starts locked")
	detector._process(0.0)
	check(detector.try_interact() and gate.is_locked and not gate.is_moving, "interaction without key keeps gate locked")
	await process_frame
	var balloon: Node = null
	for candidate in root.get_children():
		if candidate is BottomDialogueBalloon:
			balloon = candidate
	check(balloon != null and balloon.dialogue_line != null and "lock" in balloon.dialogue_line.text, "locked gate shows Thomas's lock dialogue")
	if balloon != null:
		balloon._end_dialogue()
		await create_timer(0.4).timeout
	player.set_physics_process(false)
	var key_scene: PackedScene = load("res://scenes/items/fence_key_pickup.tscn")
	var key: Node3D = key_scene.instantiate()
	key.name = "TestFenceKey"
	station.add_child(key)
	key.global_position = gate.to_global(Vector3(0.7, 1.0, 1.4))
	var saves := root.get_node("SaveGame")
	var streaming := root.get_node("WorldStreaming")
	streaming._remember_pickups(station)
	var before: Dictionary = saves._capture_section(station)
	check(before.inventory_pickups_present.has("TestFenceKey"), "save state records placed key pickup")
	for i in PlayerInventory.SLOT_COUNT:
		player.inventory.add_item(StringName("test_item_%d" % i))
	key.interact(player)
	check(not key.is_queued_for_deletion() and key.visible and not player.has_item(PlayerInventory.FENCE_KEY_ITEM), "full inventory leaves key in the world")
	for i in PlayerInventory.SLOT_COUNT:
		player.inventory.remove_one(StringName("test_item_%d" % i))
	key.interact(player)
	check(player.has_item(PlayerInventory.FENCE_KEY_ITEM), "placeable key adds fence key to inventory")
	var pickup_screen: Variant = load("res://scenes/ui/item_pickup/item_pickup_screen.gd").instance
	check(pickup_screen != null and pickup_screen.is_active and pickup_screen._current_item.id == &"fence_key", "key uses existing pickup screen and item metadata")
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	pickup_screen.close()
	await create_timer(0.4).timeout
	check(not player.is_frozen and not station.has_node("TestFenceKey"), "confirming key pickup removes prop and restores control")
	player.set_physics_process(false)
	player.global_position = gate.to_global(Vector3(0.7, 0, 1.8))
	detector._process(0.0)
	check(detector.current_interactable == gate.interactable and detector.try_interact(), "real player interaction opens gate")
	check(not gate.is_locked and not player.has_item(PlayerInventory.FENCE_KEY_ITEM), "unlocking consumes exactly one key")
	check(gate.is_moving and not gate.interactable.is_enabled, "swing blocks repeated activation")
	await gate._motion.finished
	await physics_frame
	check(gate.is_open and not gate.is_moving, "opening tween completes")
	check(gate._skeleton.get_bone_pose_rotation(gate._bone).angle_to(gate._closed_bone_rotation) > deg_to_rad(90), "imported armature opens more than 90 degrees")
	check(absf(gate.leaf_body.global_basis.z.dot(gate.global_basis.z)) < 0.15, "collision rotates with the rigged leaf")
	check(not gate.leaf_body.get_node("CollisionShape3D").disabled, "open gate keeps physical collision on swung leaf")
	check(passage_clear(gate), "opened gate clears player-sized passage")
	# Approach the moved gate's prompt to close it.
	player.global_position = gate.interactable.global_position + gate.global_basis * Vector3(0, -1.4, 1.8)
	player.look_at(Vector3(gate.interactable.global_position.x, player.global_position.y, gate.interactable.global_position.z))
	detector._process(0.0)
	check(detector.current_interactable == gate.interactable and detector.try_interact(), "real player can close the opened gate")
	await gate._motion.finished
	await physics_frame
	check(not gate.is_open and passage_clear(gate) == false, "closed gate restores blocked passage")
	check(gate.leaf_body.transform.is_equal_approx(Transform3D.IDENTITY), "closing returns collision to its original transform")
	player.global_position = gate.to_global(Vector3(0.7, 0, -1.8))
	gate.interactable.interact(player)
	await gate._motion.finished
	await physics_frame
	check(gate.is_open and gate._angle < 0.0 and passage_clear(gate), "gate opens away from a player on the other side")
	gate.toggle(player)
	await gate._motion.finished
	check(not gate.is_locked, "closing gate does not relock or require another key")
	var state: Dictionary = saves._capture_section(station)
	check(state.inventory_pickups_present.is_empty() and not state.metal_gates.MetalFenceGate.locked, "save captures consumed key and permanently unlocked gate")
	streaming._save_state(station)
	var fresh_forest := (load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene).instantiate()
	var restored_station := fresh_forest.get_node("GasStation") as Node3D
	fresh_forest.remove_child(restored_station)
	restored_station.owner = null
	var restored_key := key_scene.instantiate()
	restored_key.name = "TestFenceKey"
	restored_station.add_child(restored_key)
	streaming._restore_state(restored_station)
	root.add_child(restored_station)
	check(not restored_station.has_node("TestFenceKey") and not restored_station.get_node("MetalFenceGate").is_locked, "streamed return before ready keeps key collected and gate unlocked")
	var restored_gate: Node = restored_station.get_node("MetalFenceGate")
	restored_gate.is_locked = true
	saves._restore_section(restored_station, state)
	check(not restored_gate.is_locked, "save-game restore keeps gate unlocked after key consumption")
	var compatibility_key := key_scene.instantiate()
	compatibility_key.name = "NewKeyInOldSave"
	restored_station.add_child(compatibility_key)
	saves._restore_section(restored_station, {"pickups_present": []})
	check(not compatibility_key.is_queued_for_deletion(), "older saves do not erase newly placed key props")
	restored_station.queue_free()
	fresh_forest.free()
	if pickup_screen != null:
		pickup_screen.queue_free()
	station.queue_free()
	player.queue_free()
	await process_frame
	print("metal_gate_smoke: %s" % ("OK" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(1 if failures else 0)
