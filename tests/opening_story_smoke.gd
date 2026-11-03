extends SceneTree

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, title: String) -> void:
	print(("PASS " if condition else "FAIL ") + title)
	if not condition:
		failures += 1

func run() -> void:
	var packed := load("res://scenes/chapters/main/map.tscn") as PackedScene
	check(packed != null, "Opening map loads")
	if packed == null:
		quit(1)
		return
	var map := packed.instantiate()
	var story := map.get_node("OpeningStory")
	story.set("persist_progress", false)
	root.add_child(map)
	current_scene = map
	for i in 12:
		await physics_frame
	check(story.stage == 0, "New chapter starts at the welcome center")
	check(map.get_node("Player").global_position.distance_to(Vector3(69.4, 0, -2.17)) < 2, "Player starts on the welcome-center path")
	check(map.get_node("Buildings/NeighborhoodHospital/Source") != null, "User hospital replaces clinic")
	check(not map.get_node("Wrapper").enabled and not map.get_node("Clawman").enabled, "Later encounters wait for progression")
	var player := map.get_node("Player") as FirstPersonPlayer
	var house := map.get_node("Buildings/ResidentialLots/CarrieHouse") as Node3D
	var doc := house.get_node("CarrieDocument") as Node3D
	var door_note := house.get_node("EntranceNote") as Node3D
	check(door_note != null and str(door_note.get("body")) == "My notebook is upstairs, on my desk.\n\n- Carrie", "Entrance note directs player to notebook inside")
	check(bool(door_note.get_meta("wall_mounted", false)) and not house.has_node("EntranceNotePost") and "upstairs" in str(door_note.get("body")), "Entrance note is wall mounted and directs player upstairs")
	var on_desk: Vector3 = house.call("local_point", &"notebook")
	var desk := house.get_node("Source/CarrieDesk") as Node3D
	check(doc.position.distance_to(on_desk) < 0.01 and doc.position.y > 4.3 and doc.global_position.distance_to(desk.global_position) < 1.0, "Notebook lies on the desk in Carrie's room")
	check("isn't me" in str(doc.get("body")), "The notebook's last page warns about the voice")
	check(doc.has_node("CarrieNotebook/Pages") and doc.has_node("CarrieNotebook/Bookmark"), "Notebook has a distinct reusable 3D asset")
	var wrapper := map.get_node("Wrapper") as CharacterBody3D
	check(wrapper.seated and wrapper.global_position.distance_to(house.call("point", &"wrapper_post")) < 0.05, "The Wrapper sits in Carrie's living-room armchair")
	var porch: Vector3 = house.call("point", &"porch")
	player.global_position = door_note.global_position + door_note.global_basis.z * 1.4
	player.global_position.y = porch.y + 0.1
	player.velocity = Vector3.ZERO
	await physics_frame
	check(door_note.can_interact(player), "Entrance note can be read from outside the house")
	door_note.interact(player)
	check(story.stage == 0 and not player.inventory.has_item(PlayerInventory.NOTEBOOK_ITEM), "Entrance note does not skip finding the notebook")
	story.close_document()
	player.inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM)
	check(story.stage == 1 and not wrapper.enabled, "Flashlight advances objective; the Wrapper waits in Carrie's house")
	# The story reacts once a frame, not once a physics step.
	player.global_position = house.call("point", &"hall") + Vector3.UP * 0.05
	player.camera.look_at(house.call("point", &"stairs_bottom") + Vector3.UP * 1.5)
	for i in 2:
		await process_frame
	check(not wrapper.enabled and story.checkpoint.origin.distance_to(porch + Vector3.UP * 0.35) < 0.01, "Walking in sets a porch checkpoint; the Wrapper sits still until Thomas has seen it")
	player.camera.look_at(wrapper.global_position + Vector3.UP)
	for i in 2:
		await process_frame
	check(wrapper.enabled and story.spoken.has("wrapper_seen"), "Seeing the Wrapper in its chair wakes it")
	player.global_position = house.call("point", &"stairs_top") + Vector3.UP * 0.05
	for i in 2:
		await process_frame
	check(story.spoken.has("carrie_voice"), "Upstairs, Carrie's voice calls from her room")
	story.open_document(&"carrie", "Carrie's notebook", "Hospital is safe.")
	check(story.stage == 2 and player.is_frozen and wrapper.suspended, "Notebook advances story and reading protects player")
	check(wrapper.global_position.distance_to(house.call("point", &"stairs_bottom")) < 0.05 and not wrapper.seated, "Reading the notebook sends the Wrapper to the foot of the main stair")
	story.close_document()
	check(not player.is_frozen and not wrapper.suspended and wrapper.enabled, "Closing document resumes exploration")
	story.open_document(&"evacuation", "Evacuation notice", "Carrie escaped.")
	story.close_document()
	check(story.stage == 2, "Finding evacuation early does not skip registration")
	story.open_document(&"register", "Registration book", "Carrie arrived.")
	story.close_document()
	check(story.stage == 5, "Both hospital clues complete chapter in either order")
	check(map.get_node("Clawman").enabled, "Clawman remains active while exploring the hospital")
	var health := player.get_node("CombatHealth")
	check(health.spawn.origin.distance_to(porch + Vector3.UP * 0.35) < 0.01, "Notebook establishes retry checkpoint")
	story.open_document(&"journal", "Journal", "Collected clues")
	story.close_document()
	check(not story.discovered.has("journal"), "Journal rereading does not create a duplicate clue")
	var hospital := map.get_node("Buildings/NeighborhoodHospital") as Node3D
	var space := hospital.get_world_3d().direct_space_state
	var entry := PhysicsRayQueryParameters3D.create(hospital.to_global(Vector3(-10.2, 1.5, 2)), hospital.to_global(Vector3(-10.2, 1.5, -3)))
	var entry_hit := space.intersect_ray(entry)
	if not entry_hit.is_empty():
		print("Entrance obstruction: ", entry_hit.collider.get_path(), " at ", entry_hit.position)
	check(entry_hit.is_empty(), "Hospital entrance has clear player-height passage")
	var nav_map := hospital.get_world_3d().navigation_map
	NavigationServer3D.map_force_update(nav_map)
	await create_timer(1.0).timeout
	var route := NavigationServer3D.map_get_path(nav_map, hospital.to_global(Vector3(-10.2, 0.2, -3)), hospital.to_global(Vector3(11, 0.2, -6.5)), true)
	check(route.size() > 1 and route[route.size() - 1].distance_to(hospital.to_global(Vector3(11, 0.2, -6.5))) < 2, "Hospital staff room is reachable on the navigation mesh")
	# Standing in front of the desk chair.
	player.global_position = house.to_global(Vector3(on_desk.x, float(house.markers.floors.UPPER), on_desk.z - 1.1))
	player.velocity = Vector3.ZERO
	await physics_frame
	check(doc.can_interact(player), "Notebook can be read at Carrie's desk")
	var blocked := PhysicsRayQueryParameters3D.create(hospital.to_global(Vector3(-5, 1.5, -3)), hospital.to_global(Vector3(-5, 1.5, -7)))
	check(not space.intersect_ray(blocked).is_empty(), "Hospital partitions provide real cover")
	player.freeze()
	wrapper.enabled = true
	wrapper.attack_cooldown = 100.0
	# Watched from the hall, the Wrapper waiting at the foot of the main stair keeps still.
	wrapper.call("place", Transform3D(Basis.IDENTITY, house.call("point", &"stairs_bottom")))
	player.global_position = house.call("point", &"hall") + Vector3.UP * 0.05
	player.camera.look_at(wrapper.global_position + Vector3.UP)
	var before := wrapper.global_position
	for i in 20:
		await physics_frame
	check(Vector2(wrapper.global_position.x - before.x, wrapper.global_position.z - before.z).length() < 0.1, "Watching the Wrapper stops its advance")
	player.camera.rotate_y(PI)
	for i in 60:
		await physics_frame
	check(Vector2(wrapper.global_position.x - before.x, wrapper.global_position.z - before.z).length() > 0.2, "Wrapper advances while unseen")
	wrapper.enabled = false
	var claw := map.get_node("Clawman") as CharacterBody3D
	claw.enabled = true
	player.global_position = claw.global_position + Vector3(9, 0.2, 0)
	player.velocity = Vector3(2, 0, 0)
	player.is_crouching = true
	for i in 5:
		await physics_frame
	check(claw.memory == 0.0, "Quiet crouched movement does not alert distant Clawman")
	player.is_crouching = false
	for i in 5:
		await physics_frame
	check(claw.memory > 0.0, "Loud movement alerts Clawman")
	var claw_before := claw.global_position
	for i in 100:
		await physics_frame
	check(Vector2(claw.global_position.x - claw_before.x, claw.global_position.z - claw_before.z).length() > 0.2, "Clawman pursues after its alert animation")
	story.progress_save_path = "user://opening_story_smoke_only.json"
	story.persist_progress = true
	story._save()
	check(FileAccess.file_exists(story.progress_save_path), "Chapter progress saves to an isolated test file")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(story.progress_save_path))
	check(int(saved.stage) == 5 and saved.flashlight and saved.discovered.has("carrie"), "Save retains chapter stage, flashlight and clues")
	DirAccess.remove_absolute(story.progress_save_path)
	story.persist_progress = false
	# The debug jump replays Carrie's house from the porch without saving.
	root.get_node("DebugMenu").call("apply_map_checkpoint", map, "carrie_house")
	for i in 2:
		await process_frame
	check(story.stage == 1 and not story.persist_progress and wrapper.seated and not wrapper.enabled
			and not story.discovered.has("carrie") and not story.spoken.has("carrie_voice")
			and player.global_position.distance_to(porch) < 0.5, "Debug jump replays Carrie's house from the porch without saving")
	print("Opening story failures: ", failures)
	map.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
