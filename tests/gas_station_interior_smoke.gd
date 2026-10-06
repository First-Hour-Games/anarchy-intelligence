extends SceneTree

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1

func mesh_bounds(visual: MeshInstance3D, relative_to: Node3D) -> AABB:
	return relative_to.global_transform.affine_inverse() * visual.global_transform * visual.mesh.get_aabb()

func counter_surface(counter: Node3D, point: Vector3, interior: Node3D) -> float:
	var highest := -INF
	var start := interior.to_global(Vector3(point.x, 2, point.z))
	var end := interior.to_global(Vector3(point.x, 0.4, point.z))
	for node: Node in counter.find_children("*", "MeshInstance3D", true, false):
		var visual := node as MeshInstance3D
		var faces := visual.mesh.get_faces()
		for index in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(start, end, visual.to_global(faces[index]), visual.to_global(faces[index + 1]), visual.to_global(faces[index + 2]))
			if hit != null:
				highest = maxf(highest, interior.to_local(hit).y)
	return highest

func run() -> void:
	var forest := (load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene).instantiate() as StartingForest
	root.add_child(forest)
	current_scene = forest
	await process_frame
	forest.finish_fade_immediately()
	if is_instance_valid(forest.opening_balloon):
		forest.opening_balloon._end_dialogue()
	var player := forest.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	player.unfreeze()
	await physics_frame
	var station := forest.get_node("GasStation") as Node3D
	var interior := station.get_node("Interior") as Node3D
	var pickup := interior.get_node("Details/CounterFlashlight") as Node3D
	var powered_lights := 0
	for node: Node in station.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light.visible and light.light_energy > 0:
			powered_lights += 1
			check(pickup.is_ancestor_of(light), "Only the counter flashlight provides station light: " + str(light.name))
	check(powered_lights == 2, "Station power outage leaves only the flashlight beam and spill on")
	var emission_count := 0
	for node: Node in station.find_children("*", "MeshInstance3D", true, false):
		if pickup.is_ancestor_of(node):
			continue
		var visual := node as MeshInstance3D
		for surface in visual.mesh.get_surface_count():
			var material := visual.get_active_material(surface) as BaseMaterial3D
			if material and material.emission_enabled:
				emission_count += 1
	check(emission_count == 0, "Powered fixtures, screens and station signs have no glowing materials")
	check(station.get_node("stationV2/Store_Body").visible and station.get_node("stationV2/Store_Cornice_001").visible, "Reimported room walls and original interior textures remain visible")
	check(station.get_node("stationV2/Store_Roof1").visible and station.get_node("stationV2/Porch_Roof").visible, "Original station roof and porch remain visible")
	var furniture := interior.get_node("Furniture") as Node3D
	check(furniture.get_child_count() == 14, "Checkout, coffee counter, seven shelf bays, three coolers, and ice cabinet are furnished")
	var coffee := furniture.get_node("CoffeeCounter") as Node3D
	for label: String in ["CoffeeMachine", "CoffeeUrn", "PaperCups", "PaperCups2", "CoffeeDripTray"]:
		var visual := interior.get_node("Details/" + label) as MeshInstance3D
		var bounds := mesh_bounds(visual, interior)
		var height := counter_surface(coffee, bounds.get_center(), interior)
		check(absf(bounds.position.y - height) < 0.01, label + " rests on the actual coffee countertop")
	var stock_count := 0
	for node: Node in interior.get_node("Merchandise").get_children():
		var batch := node as MultiMeshInstance3D
		stock_count += batch.multimesh.instance_count
		var buffer := batch.multimesh.buffer
		check(buffer.size() == batch.multimesh.instance_count * 12 and not is_zero_approx(buffer[3]), "Saved " + str(batch.name) + " placements survive a headless scene bake")
	check(stock_count >= 250, "Shelving is stocked with the supplied product models")
	var shape := (player.get_node("CollisionShape3D") as CollisionShape3D).shape
	for point: Vector2 in [Vector2(0, 4.6), Vector2(0, 3.3), Vector2(0, 1.5), Vector2(0, 0), Vector2(0, -2.7), Vector2(2.7, -2.7), Vector2(2.7, 0), Vector2(4.7, 0.5), Vector2(4.7, 2.4), Vector2(-2.5, 1.6), Vector2(-2.5, 2.7), Vector2(-6.95, -1), Vector2(-6.95, 1.6), Vector2(-5, -2.5)]:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, interior.to_global(Vector3(point.x, 0.94, point.y)))
		query.exclude = [player.get_rid()]
		var hits := interior.get_world_3d().direct_space_state.intersect_shape(query)
		check(hits.is_empty(), "Player clearance at entrance/aisle/checkout " + str(point))
	var ray := PhysicsRayQueryParameters3D.create(interior.to_global(Vector3(0, 0.5, 0)), interior.to_global(Vector3(0, -0.3, 0)))
	ray.exclude = [player.get_rid()]
	var floor_hit := interior.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not floor_hit.is_empty() and absf(interior.to_local(floor_hit["position"]).y) < 0.01, "The shop floor has collision at the furniture's ground plane")
	# Walk the real controller from the porch through the doorway and main aisle.
	player.global_position = interior.to_global(Vector3(0.15, 0.05, 7.0))
	player.global_basis = interior.global_basis
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	var forward := InputEventKey.new()
	forward.keycode = KEY_W
	forward.pressed = true
	Input.parse_input_event(forward)
	for frame in 100:
		await physics_frame
	forward.pressed = false
	Input.parse_input_event(forward)
	player.set_physics_process(false)
	var walked_to := interior.to_local(player.global_position)
	check(walked_to.z < 2.8 and walked_to.y > -0.1, "Real player can walk from the porch into the shop without jumping or falling through")
	var flashlight := interior.get_node("Details/CounterFlashlight") as FlashlightPickup
	var beam := flashlight.get_node("Beam") as SpotLight3D
	check(beam.visible and beam.light_energy > 0 and beam.spot_range >= 8 and beam.shadow_enabled, "The supplied flashlight starts on with a real shadowed beam")
	var body := flashlight.get_node("Visual/Model/Flashlight_Body") as MeshInstance3D
	var body_bounds := mesh_bounds(body, interior)
	var counter := furniture.get_node("CheckoutCounter") as Node3D
	var counter_height := counter_surface(counter, body_bounds.get_center(), interior)
	check(body_bounds.position.y >= counter_height and body_bounds.position.y - counter_height < 0.01, "Flashlight rests on the actual checkout counter without floating or clipping")
	player.global_position = interior.get_node("Encounter/PreviewPosition").global_position
	check(flashlight.can_interact(player), "Counter flashlight is reachable from the customer side")
	var inventory := player.get_node("InventoryHUD") as PlayerInventory
	flashlight.interact(player)
	check(inventory.has_item(PlayerInventory.FLASHLIGHT_ITEM) and flashlight.is_queued_for_deletion(), "Collecting the counter flashlight uses the existing inventory pickup")
	check(player.is_frozen, "Counter pickup temporarily locks input for the staged reveal")
	interior.get_node("Encounter").skip_encounter()
	check(not player.is_frozen, "Skipping the reveal returns player control")
	player.flashlight.set_enabled(false)
	var toggle := InputEventKey.new()
	toggle.physical_keycode = KEY_F
	toggle.pressed = true
	player._unhandled_input(toggle)
	check(player.flashlight.is_enabled(), "Collected flashlight can immediately be switched on with F")
	inventory.select_slot(1)
	player.flashlight._process(0.1)
	check(player.flashlight.is_enabled(), "Existing F-anytime behavior keeps the light on while selecting another inventory slot")
	forest.queue_free()
	await process_frame
	quit(1 if failures else 0)
