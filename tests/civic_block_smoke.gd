extends SceneTree

## Run with --headless --script res://tests/civic_block_smoke.gd.
## Omit --headless and append -- --capture to save daytime/nighttime reviews.
var failures: int = 0

func _initialize() -> void:
	call_deferred("run_test")

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1

func run_test() -> void:
	var map := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate() as Node3D
	# Focused geometry test; full-map startup is tested separately with nav enabled.
	map.get_node("MapNavigation").free()
	root.add_child(map)
	await process_frame
	await physics_frame
	await physics_frame
	var finishing := map.get_node("Buildings/CivicFinishing")
	var streetlights := map.find_children("StreetlightGlow_*", "OmniLight3D", true, false)
	check(streetlights.size() == 31, "31 working neighborhood streetlights")
	for light: OmniLight3D in streetlights:
		check(light.light_energy > 0.0, "Streetlight powered " + light.name)
	var streets := map.get_node("RemainingStreetConnections")
	check(streets.crossings.size() == 22, "22 remaining residential lots connected")
	var clinic := map.get_node("Buildings/NeighborhoodClinic/Interior")
	check(clinic.has_node("Roof") and clinic.get_node("Roof").get_child_count() >= 7, "Clinic pitched roof built completely")
	check(finishing.get_child_count() > 40, "Urban dressing instantiated")
	var missing_texture := false
	for node in finishing.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.material_override != null:
			continue
		for i in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(i) as StandardMaterial3D
			missing_texture = missing_texture or material == null or material.albedo_texture == null
	check(not missing_texture, "Imported urban meshes retain textures")
	var space := map.get_world_3d().direct_space_state
	var entrance_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(150.8, 1.2, 32), Vector3(150.8, 1.2, 37)))
	check(entrance_hit.is_empty(), "Gas station doorway open")
	for center: Vector3 in [Vector3(-129, 0, 125), Vector3(-50, 0, 225)]:
		var road_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(center + Vector3(0, 1, 0), center + Vector3(0, -0.1, 0)))
		check(not road_hit.is_empty() and absf(road_hit.position.y - 0.1) < 0.015, "Turnaround road height " + str(center))
	var curb_hits := 0
	for crossing: Vector3 in streets.crossings:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(crossing + Vector3(0, 0.17, 0), crossing + Vector3(0, 0.13, 0)))
		if not hit.is_empty():
			curb_hits += 1
	check(curb_hits == 0, "No raised curb across new driveway mouths")
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	for segment: Array in [[Vector3(114, 1.05, 233), Vector3(253, 1.05, 233)], [Vector3(245, 1.05, 233), Vector3(245, 1.05, 254.85)], [Vector3(245, 1.05, 254.85), Vector3(248, 1.05, 254.85)], [Vector3(245, 1.05, 254.85), Vector3(242, 1.05, 254.85)], [Vector3(139, 1.05, 234), Vector3(139, 1.05, 270)], [Vector3(169, 1.05, 234), Vector3(169, 1.05, 270)], [Vector3(201, 1.05, 234), Vector3(201, 1.05, 270)], [Vector3(109, 1.05, 270), Vector3(237, 1.05, 270)]]:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, segment[0])
		query.motion = segment[1] - segment[0]
		var travel := space.cast_motion(query)
		check(travel[0] > 0.99, "Walk clearance " + str(segment[0]) + " to " + str(segment[1]))
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(240, 1.5, 242), Vector3(240, 1.5, 247)))
	check(not wall.is_empty(), "Clinic front window blocks movement")
	var mounts := map.get_node("Buildings/CivicBlock").find_children("MountedBusinessSign", "Node3D", true, false)
	check(mounts.size() == 4, "Four building-mounted business signs")
	for mount in mounts:
		check(mount.get_parent() is MeshInstance3D, "Sign follows building transform")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		for canvas in map.find_children("*", "CanvasLayer", true, false):
			canvas.visible = false
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.current = true
		var world := map.get_node("WorldEnvironment") as WorldEnvironment
		var night := world.environment
		var day := Environment.new()
		day.background_mode = Environment.BG_COLOR
		day.background_color = Color(0.3, 0.35, 0.4)
		day.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		day.ambient_light_color = Color.WHITE
		day.ambient_light_energy = 0.7
		world.environment = day
		map.get_node("MapMakingLight").visible = true
		camera.position = Vector3(251, 2.1, 231)
		camera.look_at(Vector3(242, 1.8, 244))
		await capture("clinic-finished-day")
		camera.position = Vector3(232, 2.1, 231.8)
		camera.look_at(Vector3(172, 2, 235))
		await capture("civic-finished-day")
		camera.position = Vector3(111, 20, 93)
		camera.look_at(Vector3(90, 0, 72))
		await capture("remaining-streets-review")
		camera.position = Vector3(184, 23, 1)
		camera.look_at(Vector3(148, 0, 25))
		await capture("gas-station-review")
		camera.position = Vector3(150.8, 1.8, 35)
		camera.look_at(Vector3(158, 1.4, 40))
		await capture("gas-station-interior-review")
		camera.position = Vector3(-105, 27, 146)
		camera.look_at(Vector3(-130, 0, 125))
		await capture("upper-turnaround-review")
		camera.position = Vector3(-23, 27, 249)
		camera.look_at(Vector3(-51, 0, 225))
		await capture("lower-turnaround-review")
		camera.position = Vector3(245, 1.8, 245)
		camera.look_at(Vector3(248, 1.5, 250))
		await capture("clinic-reception-review")
		camera.position = Vector3(243, 1.8, 254.8)
		camera.look_at(Vector3(239, 1.1, 255.5))
		await capture("clinic-exam-review")
		camera.position = Vector3(232, 2.1, 231.8)
		camera.look_at(Vector3(172, 2, 235))
		world.environment = night
		map.get_node("MapMakingLight").visible = false
		await capture("civic-finished-night")
		camera.position = Vector3(50, 2.1, 125)
		camera.look_at(Vector3(-100, 2, 125))
		await capture("neighborhood-lighting-night")
		camera.position = Vector3(100, 12, -23)
		camera.look_at(Vector3(15, 0, 0))
		await capture("main-strip-lighting-night")
	quit(1 if failures > 0 else 0)

func capture(label: String) -> void:
	await create_timer(1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../" + label + ".png")
