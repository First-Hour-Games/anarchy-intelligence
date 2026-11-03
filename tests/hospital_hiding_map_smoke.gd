extends SceneTree

# Checks the hospital's hiding spots and bottles inside the real map: placement,
# clear exits, navigation reachability, and the Clawman pulling a watched player
# out of a locker and following a thrown bottle using the baked navigation.

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1


func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func run() -> void:
	var map := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate()
	map.get_node("OpeningStory").set("persist_progress", false)
	root.add_child(map)
	current_scene = map
	for frame in 12:
		await physics_frame
	var hospital := map.get_node("Buildings/NeighborhoodHospital") as Node3D
	var player := map.get_node("Player") as FirstPersonPlayer
	var claw := map.get_node("Clawman") as CharacterBody3D
	var health := player.get_node("CombatHealth")

	var spots: Array[HidingSpot] = []
	var bottles := 0
	for child in hospital.get_children():
		if child is HidingSpot:
			spots.append(child)
		elif child is BottlePickup:
			bottles += 1
	var counts := {HidingSpot.Kind.LOCKER: 0, HidingSpot.Kind.CLOSET: 0, HidingSpot.Kind.UNDER_BED: 0}
	for spot in spots:
		counts[spot.kind] += 1
	check(counts[HidingSpot.Kind.LOCKER] == 5 and counts[HidingSpot.Kind.CLOSET] == 1 and counts[HidingSpot.Kind.UNDER_BED] == 2, "Hospital has five lockers, a closet and two ward beds")
	check(bottles == 5, "Hospital has five bottle pickups")

	# Every exit leaves room for the player's capsule.
	var space := hospital.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var blocked_exits: Array[String] = []
	for spot in spots:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, spot.exit_position() + Vector3.UP * 0.96)
		query.exclude = [(spot.get_node("Collision") as StaticBody3D).get_rid()]
		var hits := space.intersect_shape(query, 4)
		if not hits.is_empty():
			blocked_exits.append("%s blocked by %s" % [spot.name, hits[0].collider.get_path()])
	check(blocked_exits.is_empty(), "Every hiding spot has a clear exit" + ("" if blocked_exits.is_empty() else ": " + ", ".join(blocked_exits)))

	# The Clawman can walk to where it pulls a player out of each spot.
	var nav_map := hospital.get_world_3d().navigation_map
	NavigationServer3D.map_force_update(nav_map)
	await create_timer(1.0).timeout
	var unreachable: Array[String] = []
	for spot in spots:
		var goal := spot.hunter_position()
		var route := NavigationServer3D.map_get_path(nav_map, claw.global_position, goal, true)
		var end := route[route.size() - 1] if route.size() > 0 else Vector3.INF
		if route.size() < 2 or flat_distance(end, goal) > 0.45:
			unreachable.append(str(spot.name))
	check(unreachable.is_empty(), "The Clawman can reach every hiding spot" + ("" if unreachable.is_empty() else ": " + ", ".join(unreachable)))

	# Seen hiding: the Clawman walks over on the navmesh and pulls the player out.
	var locker: HidingSpot = null
	for spot in spots:
		if str(spot.name).begins_with("RecordsLocker"):
			locker = spot
			break
	player.global_position = locker.exit_position()
	player.velocity = Vector3.ZERO
	claw.global_position = hospital.to_global(Vector3(10.5, 0.12, -6.3))
	claw.set("enabled", true)
	await physics_frame
	await physics_frame
	locker.enter(player)
	check(claw.get("hunted_spot") == locker, "The Clawman sees the player climb into a records locker")
	var before_health := float(health.get("health"))
	var start := Time.get_ticks_msec()
	while player.is_hidden() and Time.get_ticks_msec() - start < 10000:
		await physics_frame
	check(not player.is_hidden(), "The Clawman walks to the locker and pulls the player out (%.1fs)" % ((Time.get_ticks_msec() - start) / 1000.0))
	check(float(health.get("health")) < before_health, "Being pulled out hurts the player")
	check(flat_distance(claw.global_position, player.global_position) >= 0.75, "The player lands clear of the Clawman's body")

	# Heard but not seen: it walks up to the bed, gives up, and returns to its post.
	claw.set("enabled", false)
	claw.call("reset_enemy")
	health.set("health", float(health.get("max_health")))
	var post: Vector3 = (claw.get("spawn") as Transform3D).origin
	var bed: HidingSpot = null
	for spot in spots:
		if spot.kind == HidingSpot.Kind.UNDER_BED:
			bed = spot
			break
	player.global_position = bed.exit_position()
	player.velocity = Vector3.ZERO
	# In the corridor, behind the ward's front partition: it can hear but not see the player.
	claw.global_position = hospital.to_global(Vector3(6.5, 0.12, -2.6))
	claw.set("enabled", true)
	await physics_frame
	# Enough memory to reach the bed before the trail goes cold.
	claw.set("memory", 6.0)
	claw.set("last_heard", bed.exit_position())
	bed.enter(player)
	check(claw.get("hunted_spot") == null, "Heard through the partition, the Clawman does not know which bed the player chose")
	var closest_to_bed := INF
	start = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 20000:
		await physics_frame
		closest_to_bed = minf(closest_to_bed, flat_distance(claw.global_position, bed.exit_position()))
		if Time.get_ticks_msec() - start > 3000 and flat_distance(claw.global_position, post) < 1.2:
			break
	check(closest_to_bed < 1.5, "It walks up to the bed where it last heard the player (%.1fm)" % closest_to_bed)
	check(flat_distance(claw.global_position, post) < 1.2, "It then returns to its post instead of camping the bed (%.1fs)" % ((Time.get_ticks_msec() - start) / 1000.0))
	var before_exit := float(health.get("health"))
	bed.exit()
	await create_timer(2.0).timeout
	check(float(health.get("health")) == before_exit, "Waiting it out lets the player leave unhurt")

	# A real throw down the corridor draws the Clawman toward the impact.
	claw.set("enabled", false)
	claw.call("reset_enemy")
	health.set("health", float(health.get("max_health")))
	player.global_position = hospital.to_global(Vector3(-8, 0.12, -3))
	player.velocity = Vector3.ZERO
	var aim := hospital.to_global(Vector3(5, 0.12, -3))
	player.look_at(Vector3(aim.x, player.global_position.y, aim.z), Vector3.UP)
	player.head.rotation.x = 0.0
	player.inventory.add_item(PlayerInventory.BOTTLE_ITEM)
	claw.set("enabled", true)
	await physics_frame
	await physics_frame
	check(claw.get("memory") == 0.0, "A distant, still player is not detected")
	check(player.throw_bottle(), "The player throws a bottle down the corridor")
	var thrown := map.get_node_or_null("ThrownBottle") as ThrownBottle
	var impact := {}
	if thrown != null:
		thrown.shattered.connect(func(point: Vector3) -> void: impact["point"] = point)
		for frame in 180:
			if thrown.has_shattered:
				break
			await physics_frame
	check(impact.has("point"), "The bottle shatters inside the hospital")
	check(float(claw.get("memory")) > 0.0, "The Clawman hears the glass break")
	if impact.has("point"):
		var point: Vector3 = impact["point"]
		var distance_before := Vector2(claw.global_position.x - point.x, claw.global_position.z - point.z).length()
		await create_timer(2.5).timeout
		var distance_after := Vector2(claw.global_position.x - point.x, claw.global_position.z - point.z).length()
		check(distance_after < distance_before - 1.0, "The Clawman walks toward the broken glass (%.1fm -> %.1fm)" % [distance_before, distance_after])

	# Thrown from behind the reception desk, outside its 22 m territory, the lure still works.
	claw.set("enabled", false)
	claw.call("reset_enemy")
	player.global_position = hospital.to_global(Vector3(-10.0, 0.12, -4.7))
	player.velocity = Vector3.ZERO
	var far_aim := hospital.to_global(Vector3(5, 0.12, -4.7))
	player.look_at(Vector3(far_aim.x, player.global_position.y, far_aim.z), Vector3.UP)
	player.head.rotation.x = 0.0
	player.inventory.add_item(PlayerInventory.BOTTLE_ITEM)
	claw.set("enabled", true)
	await physics_frame
	check(flat_distance(player.global_position, post) > float(claw.get("territory_radius")), "The thrower stands outside the Clawman's territory")
	player.throw_bottle()
	var far_throw := map.get_node_or_null("ThrownBottle") as ThrownBottle
	var far_impact := {}
	if far_throw != null:
		far_throw.shattered.connect(func(point: Vector3) -> void: far_impact["point"] = point)
		for frame in 180:
			if far_throw.has_shattered:
				break
			await physics_frame
	if far_impact.has("point"):
		var far_point: Vector3 = far_impact["point"]
		var far_before := flat_distance(claw.global_position, far_point)
		await create_timer(3.0).timeout
		var far_after := flat_distance(claw.global_position, far_point)
		check(far_after < far_before - 2.0, "The Clawman leaves its post for glass thrown from outside its territory (%.1fm -> %.1fm)" % [far_before, far_after])
	else:
		check(false, "The bottle thrown from the west end shatters")

	map.queue_free()
	await process_frame
	quit(1 if failures else 0)
