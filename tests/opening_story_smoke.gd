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
	var house := map.get_node("Buildings/ResidentialLots/WestStubBrickHouse") as Node3D
	var doc := house.get_node("CarrieDocument") as Node3D
	var door_note := house.get_node("EntranceNote") as Node3D
	check(door_note != null and str(door_note.get("body")) == "My notebook is on the second floor, under something...\n\n- Carrie", "Entrance note directs player to notebook inside")
	check(bool(door_note.get_meta("wall_mounted", false)) and not house.has_node("EntranceNotePost") and "second floor" in str(door_note.get("body")), "Entrance note is wall mounted and directs player upstairs")
	check(doc.position.y > 3.9 and house.has_node("AtticNotebookCrate"), "Notebook is hidden on an attic crate")
	check(doc.has_node("CarrieNotebook/Pages") and doc.has_node("CarrieNotebook/Bookmark"), "Notebook has a distinct reusable 3D asset")
	player.global_position = door_note.global_position + door_note.global_basis.z * 1.4
	player.global_position.y = house.global_position.y + 0.1
	player.velocity = Vector3.ZERO
	await physics_frame
	check(door_note.can_interact(player), "Entrance note can be read from outside the house")
	door_note.interact(player)
	check(story.stage == 0 and not player.inventory.has_item(PlayerInventory.NOTEBOOK_ITEM), "Entrance note does not skip finding the notebook")
	story.close_document()
	player.inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM)
	check(story.stage == 1 and map.get_node("Wrapper").enabled, "Flashlight advances objective and activates Wrapper")
	story.open_document(&"carrie", "Carrie's notebook", "Hospital is safe.")
	check(story.stage == 2 and player.is_frozen and map.get_node("Wrapper").suspended, "Notebook advances story and reading protects player")
	story.close_document()
	check(not player.is_frozen and not map.get_node("Wrapper").suspended, "Closing document resumes exploration")
	story.open_document(&"evacuation", "Evacuation notice", "Carrie escaped.")
	story.close_document()
	check(story.stage == 2, "Finding evacuation early does not skip registration")
	story.open_document(&"register", "Registration book", "Carrie arrived.")
	story.close_document()
	check(story.stage == 5, "Both hospital clues complete chapter in either order")
	check(map.get_node("Clawman").enabled, "Clawman remains active while exploring the hospital")
	var health := player.get_node("CombatHealth")
	check(health.spawn.origin.distance_to(house.to_global(Vector3(11.75, 0.35, 12.5))) < 0.01, "Notebook establishes retry checkpoint")
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
	player.global_position = house.to_global(Vector3(13, 3.65, 7))
	player.velocity = Vector3.ZERO
	await physics_frame
	check(doc.can_interact(player), "Notebook can be read in its upstairs hiding place")
	var blocked := PhysicsRayQueryParameters3D.create(hospital.to_global(Vector3(-5, 1.5, -3)), hospital.to_global(Vector3(-5, 1.5, -7)))
	check(not space.intersect_ray(blocked).is_empty(), "Hospital partitions provide real cover")
	player.freeze()
	var wrapper := map.get_node("Wrapper") as CharacterBody3D
	wrapper.enabled = true
	player.global_position = wrapper.global_position + Vector3(0, 0.2, 6)
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
	print("Opening story failures: ", failures)
	map.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
