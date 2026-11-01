extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func run() -> void:
	var forest: Node3D = load("res://scenes/chapters/main/starting_forest.tscn").instantiate()
	var placed := forest.get_node("Sketchfab_Scene4") as InventoryPickup
	check(placed != null and placed.item_id == &"metal_pipe", "authored pipe is a real inventory pickup")
	var authored_transform := placed.transform
	forest.remove_child(placed)
	forest.free()
	var section := Node3D.new()
	root.add_child(section)
	section.add_child(placed)
	check(placed.transform == authored_transform, "pickup preserves the pipe's authored placement")
	var mesh := placed.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var material := mesh.material_override as StandardMaterial3D
	check(material != null and material.albedo_texture.resource_path.ends_with("pipeWeapon_0.png"), "placed pipe uses its correct rusted-metal atlas")
	check(material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "pipe uses lit pixel-texture filtering")
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as FirstPersonPlayer
	root.add_child(player)
	player.set_physics_process(false)
	player.unfreeze()
	await process_frame
	var weapon: Node3D = player.get_node("Head/Camera3D/PipeWeapon")
	check(not weapon.get("equipped") and not weapon.get_node("ModelPivot").visible, "pipe cannot be held before pickup")
	var focus := placed.get_prompt_world_position()
	player.global_position = focus + Vector3(0, -1.0, 1.2)
	player.camera.look_at(focus)
	var detector := player.get_node("InteractionDetector") as InteractionDetector
	detector._process(0.0)
	check(detector.current_interactable == placed and detector.try_interact(), "real interaction detector picks up the authored pipe")
	check(player.inventory.has_item(&"metal_pipe") and bool(weapon.get("equipped")), "pickup adds the pipe and automatically equips it")
	var pickup_screen := root.get_node_or_null("ItemPickupScreen")
	check(pickup_screen != null and player.is_frozen, "pipe pickup opens its inspection screen")
	if pickup_screen != null:
		pickup_screen.close()
	await create_timer(0.8).timeout
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.camera.rotation = Vector3.ZERO
	check(not player.is_frozen and weapon.get_node("ModelPivot").visible, "closing pickup returns control and shows the held pipe")
	var wrapper := (load("res://scenes/monsters/the_wrapper.tscn") as PackedScene).instantiate() as CharacterBody3D
	section.add_child(wrapper)
	wrapper.set("enabled", true)
	wrapper.set_physics_process(false)
	wrapper.global_position = player.global_position + Vector3(0, 0, -1.15)
	wrapper.set("strike_time", 0.7)
	await physics_frame
	await process_frame
	check(weapon.try_swing(), "equipped pipe can swing")
	check(not weapon.try_swing(), "cooldown prevents repeated swings")
	await create_timer(0.25).timeout
	check(float(wrapper.get("melee_stagger_time")) > 0.0 and is_zero_approx(float(wrapper.get("strike_time"))), "pipe hits a real enemy and interrupts its attack")
	check(wrapper.get("_melee_push").z < 0.0, "pipe pushes the enemy away from the player")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	check(mouse.is_action_pressed(&"weapon_attack"), "left click is bound to the weapon swing")
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	check(trigger.is_action_pressed(&"weapon_attack"), "controller right trigger is bound to the weapon swing")
	await create_timer(0.6).timeout
	player.freeze()
	check(not weapon.try_swing(), "dialogue and pickup freeze block attacks")
	player.unfreeze()
	player.set_physics_process(false)
	player.camera.top_level = true
	check(not weapon.try_swing(), "inspection camera blocks attacks")
	player.camera.top_level = false
	player.camera.transform = Transform3D.IDENTITY
	# A wall must intercept the swing before an enemy behind it.
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 0.15)
	collision.shape = box
	wall.add_child(collision)
	section.add_child(wall)
	wall.global_position = player.global_position + Vector3(0, 1, -0.55)
	wrapper.set("melee_stagger_time", 0.0)
	await physics_frame
	await process_frame
	check(weapon.try_swing(), "a new swing is available after cooldown")
	await create_timer(0.25).timeout
	check(is_zero_approx(float(wrapper.get("melee_stagger_time"))), "pipe cannot hit an enemy through a wall")
	var slot := 0
	for i in PlayerInventory.SLOT_COUNT:
		if player.inventory.get_item(i) == &"metal_pipe":
			slot = i
	player.inventory.select_slot(slot)
	player.inventory.set_open(true, false)
	check(not weapon.try_swing(), "inventory blocks attacks")
	player.inventory._use_selected()
	check(not bool(weapon.get("equipped")) and not player.inventory.is_open, "inventory action holsters the pipe")
	var saves := root.get_node("SaveGame")
	var state: Dictionary = saves._capture_player(player)
	check(state.items.has("metal_pipe") and not state.pipe_equipped, "save records pipe ownership and holstered state")
	weapon.set_equipped(true)
	saves._restore_player(player, state)
	check(player.inventory.has_item(&"metal_pipe") and not bool(weapon.get("equipped")), "load restores the pipe and its equipment state")
	var section_state: Dictionary = saves._capture_section(section)
	check(section_state.inventory_pickups_present.is_empty(), "collected pipe is absent from saved world pickups")
	var restored := (load("res://scenes/items/metal_pipe_pickup.tscn") as PackedScene).instantiate()
	restored.name = "Sketchfab_Scene4"
	section.add_child(restored)
	saves._restore_section(section, section_state)
	check(restored.is_queued_for_deletion(), "restoring a section cannot respawn the collected pipe")
	var legacy_pipe := (load("res://scenes/items/metal_pipe_pickup.tscn") as PackedScene).instantiate()
	section.add_child(legacy_pipe)
	saves._restore_section(section, {"inventory_pickups_present": []})
	check(not legacy_pipe.is_queued_for_deletion(), "older saves still allow picking up the newly added weapon")
	player.queue_free()
	section.queue_free()
	await process_frame
	print("metal_pipe_weapon_smoke: %d failures" % failures)
	quit(1 if failures else 0)
