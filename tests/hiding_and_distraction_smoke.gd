extends SceneTree

# Covers the Clawman counterplay tools: bottle pickups and their carry limit,
# throwing and luring, hiding unseen, being pulled out when seen hiding,
# leaving a hiding spot, and dying while hidden.

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1


func wait_physics(frames: int) -> void:
	for frame in frames:
		await physics_frame


func add_box(parent: Node3D, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	parent.add_child(body)
	return body


## Stands in for OpeningStory: the hiding and bottle code only reads document_open
## and calls narrate_once.
func add_fake_story(parent: Node) -> Node:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar document_open: bool = false\nfunc narrate_once(_id: String, _words: String) -> void:\n\tpass\n"
	script.reload()
	var story := Node.new()
	story.set_script(script)
	story.add_to_group("opening_story")
	parent.add_child(story)
	return story


func press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event)


func run() -> void:
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)
	current_scene = world
	add_box(world, Vector3(0, -0.5, 0), Vector3(80, 1, 80))
	# A wall along x = 4 blocks the Clawman's view of the player's start area.
	var wall := add_box(world, Vector3(4, 1.5, 0), Vector3(0.4, 3, 12))
	var story := add_fake_story(world)

	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as FirstPersonPlayer
	var health := Node.new()
	health.name = "CombatHealth"
	health.set_script(load("res://scenes/player/combat_health.gd"))
	player.add_child(health)
	world.add_child(player)
	player.global_position = Vector3(0, 0.05, 0)

	var claw := (load("res://scenes/monsters/the_clawman.tscn") as PackedScene).instantiate() as CharacterBody3D
	world.add_child(claw)
	claw.global_position = Vector3(9, 0.05, 0)
	claw.set("spawn", claw.global_transform)
	claw.set("enabled", true)
	await wait_physics(3)
	player.velocity = Vector3.ZERO

	# --- Bottle pickups and carry limit ---
	player.global_position = Vector3(3.5, 0.05, 0)
	var behind_wall := BottlePickup.new()
	world.add_child(behind_wall)
	behind_wall.global_position = Vector3(4.5, 0, 0)
	await wait_physics(2)
	check(player.global_position.distance_to(behind_wall.get_prompt_world_position()) < behind_wall.interaction_distance and not behind_wall.can_interact(player), "A bottle behind a wall cannot be picked up")
	behind_wall.queue_free()
	player.global_position = Vector3(0, 0.05, 0)
	await wait_physics(2)
	var pickups: Array[BottlePickup] = []
	for index in 4:
		var pickup := BottlePickup.new()
		world.add_child(pickup)
		pickup.global_position = Vector3(0.5 + index * 0.2, 0, -0.5)
		pickups.append(pickup)
	await process_frame
	check(pickups[0].can_interact(player), "Nearby bottle can be picked up")
	for index in 3:
		pickups[index].interact(player)
	check(player.inventory.get_count(PlayerInventory.BOTTLE_ITEM) == 3, "Three bottles stack in one slot")
	check(player.inventory._get_item_display_name(PlayerInventory.BOTTLE_ITEM) == "EMPTY BOTTLE x3", "Bottle card shows the carried count")
	check(not pickups[3].can_interact(player), "With full pockets a bottle offers no prompt, leaving E free for nearby notes")
	pickups[3].interact(player)
	check(player.inventory.get_count(PlayerInventory.BOTTLE_ITEM) == 3 and not pickups[3].is_queued_for_deletion(), "A fourth bottle is refused and stays in the world")
	var bound_to_g := false
	for event in InputMap.action_get_events(&"throw_item"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_G:
			bound_to_g = true
	check(bound_to_g, "Throwing is the remappable throw_item action, bound to G")

	# --- Throwing lures the Clawman to the impact ---
	check(claw.get("memory") == 0.0, "Clawman starts unaware behind the wall")
	player.rotation.y = -PI / 2.0  # face +X toward the wall
	player.head.rotation.x = deg_to_rad(20.0)
	check(player.throw_bottle(), "Throwing consumes a carried bottle")
	check(player.inventory.get_count(PlayerInventory.BOTTLE_ITEM) == 2, "Two bottles remain after one throw")
	var thrown := world.get_node_or_null("ThrownBottle") as ThrownBottle
	check(thrown != null, "A thrown bottle enters the world")
	# Lambdas capture locals by value, so record the impact in a shared dictionary.
	var impact := {}
	if thrown != null:
		thrown.shattered.connect(func(point: Vector3) -> void: impact["point"] = point)
		for frame in 180:
			if thrown.has_shattered:
				break
			await physics_frame
	check(impact.has("point"), "The bottle shatters on impact")
	check(float(claw.get("memory")) > 0.0, "Breaking glass alerts the Clawman")
	check(impact.has("point") and (claw.get("last_heard") as Vector3).distance_to(impact["point"]) < 0.01, "The Clawman heads for the impact point")
	await create_timer(0.9).timeout
	check(is_instance_valid(thrown), "The broken bottle stays until its shards have fallen")
	await create_timer(1.5).timeout
	check(not is_instance_valid(thrown), "The broken bottle is freed afterwards")

	claw.call("reset_enemy")
	claw.set("attack_cooldown", 0.0)
	var spawn_point: Vector3 = (claw.get("spawn") as Transform3D).origin
	claw.call("hear_noise", spawn_point + Vector3(-20, 0, 0), 16.0)
	check(claw.get("memory") == 0.0, "Glass beyond the 16 m hearing radius is ignored")
	claw.global_position = spawn_point + Vector3(-22, 0, 0)
	claw.call("hear_noise", spawn_point + Vector3(-34, 0, 0), 16.0)
	check(claw.get("memory") == 0.0, "Glass far outside the Clawman's territory is ignored")
	claw.call("reset_enemy")
	claw.set("suspended", true)
	claw.call("hear_noise", spawn_point + Vector3(-4, 0, 0), 16.0)
	check(float(claw.get("memory")) > 0.0, "Glass heard while a note is open is remembered")
	claw.set("suspended", false)
	claw.call("reset_enemy")
	player.global_position = spawn_point + Vector3(30, 0, 0)
	claw.call("hear_noise", spawn_point + Vector3(-4, 0, 0), 16.0)
	await wait_physics(3)
	check(claw.get("investigating_noise") and float(claw.get("memory")) > 0.0, "The Clawman investigates glass even when the thrower is outside its territory")
	claw.call("reset_enemy")
	player.global_position = Vector3(0, 0.05, 0)
	await wait_physics(2)

	# --- Hiding while unseen ---
	var locker := HidingSpot.new()
	locker.kind = HidingSpot.Kind.LOCKER
	world.add_child(locker)
	locker.global_position = Vector3(1.5, 0, -3)
	locker.rotation.y = 0.0  # opens toward +Z
	player.global_position = locker.exit_position()
	# Within the 7 m sight range, so only the wall can stop it seeing the player hide.
	claw.global_position = Vector3(6, 0.05, -2.2)
	await wait_physics(2)
	player.stamina = 20.0
	check(locker.can_interact(player), "Locker can be entered from in front")
	locker.interact(player)
	await wait_physics(2)
	check(player.is_hidden() and player.hiding_spot == locker, "Player is hidden in the locker")
	check(player.is_frozen and not player.is_physics_processing(), "Hidden player cannot walk")
	check(player.collision_shape.disabled, "Hidden player's capsule is disabled")
	check(player.camera.global_position.distance_to(locker.eye_position()) < 0.05, "Camera sits at the locker's vent")
	check(not locker.seen_entering and claw.get("hunted_spot") == null, "A Clawman 4.5 m away behind a wall does not see the player hide")
	await create_timer(1.0).timeout
	check(player.stamina > 20.0, "Stamina recovers while hidden")

	var wrapper := (load("res://scenes/monsters/the_wrapper.tscn") as PackedScene).instantiate() as CharacterBody3D
	world.add_child(wrapper)
	wrapper.global_position = locker.exit_position() + Vector3(0, 0, 3)
	await wait_physics(1)
	check(wrapper.call("is_watched_by_player"), "A hidden player holds the Wrapper by watching it through the vents")
	wrapper.global_position = locker.global_position + Vector3(0, 0, -3)
	await wait_physics(1)
	check(not wrapper.call("is_watched_by_player"), "The Wrapper behind the locker is not watched")
	# Unseen, the hidden player is lost to it: it heads back to its post, leaving a way past.
	wrapper.set("enabled", true)
	await wait_physics(2)
	check(Vector3(wrapper.get("last_heard")).is_equal_approx(Transform3D(wrapper.get("spawn")).origin), "A hidden player is lost to the Wrapper, which heads back to its post")
	wrapper.set("enabled", false)
	wrapper.queue_free()

	# Bring the Clawman into plain view of the locker; it must not detect anyone.
	wall.get_child(0).set_deferred("disabled", true)
	claw.global_position = locker.exit_position() + Vector3(0, 0, 2.5)
	player.velocity = Vector3(3, 0, 0)
	await wait_physics(10)
	check(claw.get("memory") == 0.0, "A hidden player is neither seen nor heard")

	player.inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM)
	var light_was_on := player.flashlight.is_enabled()
	press(&"flashlight_toggle")
	check(player.flashlight.is_enabled() != light_was_on and player.is_hidden(), "F toggles the flashlight while hidden")
	var carried := player.inventory.get_count(PlayerInventory.BOTTLE_ITEM)
	press(&"throw_item")
	check(player.inventory.get_count(PlayerInventory.BOTTLE_ITEM) == carried, "G does not throw while hidden")
	var leave := InputEventKey.new()
	leave.keycode = KEY_E
	leave.physical_keycode = KEY_E
	leave.pressed = true
	root.push_input(leave)
	await create_timer(0.7).timeout
	check(not player.is_hidden() and not player.is_frozen, "Pressing E leaves the locker and restores control")
	check(player.is_physics_processing() and not player.collision_shape.disabled, "Leaving restores movement and collision")
	check(Vector2(player.global_position.x - locker.exit_position().x, player.global_position.z - locker.exit_position().z).length() < 0.2, "Player steps out in front of the locker")

	# A note or the journal opened during the door swing keeps the player frozen.
	claw.set("enabled", false)
	locker.interact(player)
	await create_timer(0.5).timeout
	locker.exit()
	story.set("document_open", true)
	player.freeze()
	await create_timer(0.7).timeout
	check(not player.is_hidden() and player.is_frozen, "A note opened while leaving keeps the player frozen")
	story.set("document_open", false)
	player.unfreeze()
	claw.set("enabled", true)

	# --- Hiding while watched ---
	claw.call("reset_enemy")
	claw.set("attack_cooldown", 0.0)
	claw.global_position = locker.exit_position() + Vector3(0, 0, 4)
	await wait_physics(2)
	player.velocity = Vector3.ZERO
	claw.set("memory", 0.0)
	locker.interact(player)
	check(locker.seen_entering and claw.get("hunted_spot") == locker, "A watching Clawman remembers the hiding spot")
	await create_timer(0.5).timeout
	var before_health := float(health.get("health"))
	# Navigation is not baked here, so place the Clawman where its route would end.
	claw.global_position = locker.hunter_position()
	await wait_physics(3)
	check(not player.is_hidden(), "The Clawman pulls the player out of the spot it saw")
	check(float(health.get("health")) < before_health, "The grab itself deals damage at once")
	var separation := Vector2(claw.global_position.x - player.global_position.x, claw.global_position.z - player.global_position.z).length()
	check(separation >= 0.75, "The player is pulled out clear of the Clawman's body (%.2f m)" % separation)
	check(claw.get("hunted_spot") == null, "The Clawman forgets the spot after pulling the player out")
	var after_grab := float(health.get("health"))
	locker.interact(player)
	await create_timer(2.4).timeout
	check(float(health.get("health")) < after_grab, "Climbing straight back in cannot dodge the next grab")
	claw.set("enabled", false)
	if player.is_hidden():
		locker.force_out()
	health.set("health", float(health.get("max_health")))

	# --- Heard but not seen: the Clawman sniffs around, then goes back to its post ---
	await create_timer(0.8).timeout
	wall.get_child(0).set_deferred("disabled", false)
	claw.call("reset_enemy")
	claw.global_position = Vector3(6, 0.05, -2.2)
	claw.set("enabled", true)
	player.global_position = locker.exit_position()
	player.velocity = Vector3.ZERO
	await wait_physics(2)
	claw.set("memory", 1.0)
	claw.set("last_heard", locker.exit_position())
	locker.interact(player)
	check(player.is_hidden() and claw.get("hunted_spot") == null, "A Clawman that only heard the player does not know the hiding spot")
	claw.set("memory", 0.0)
	await wait_physics(3)
	check(claw.get("returning_to_post") and (claw.get("last_heard") as Vector3).distance_to(spawn_point) < 0.01, "With the trail cold it heads back to its post instead of camping the spot")
	claw.set("enabled", false)
	await create_timer(0.5).timeout
	locker.exit()
	await create_timer(0.7).timeout

	# --- Under a bed the body stays on the floor and the head drops to the eye ---
	var bed := HidingSpot.new()
	bed.kind = HidingSpot.Kind.UNDER_BED
	world.add_child(bed)
	bed.global_position = Vector3(-4, 0, 3)
	player.global_position = bed.exit_position()
	await wait_physics(2)
	bed.interact(player)
	await wait_physics(2)
	check(player.hiding_spot == bed and absf(player.global_position.y - bed.global_position.y) < 0.05, "Under a bed the player's body stays on the floor")
	check(player.camera.global_position.distance_to(bed.eye_position()) < 0.05, "Under a bed the camera sits just above the floor")
	await create_timer(0.5).timeout
	bed.exit()
	await create_timer(0.7).timeout
	check(not player.is_hidden() and is_equal_approx(player.head.position.y, player.stand_head_y), "Leaving the bed restores standing head height")

	# --- A point-blank throw at a wall breaks on the near side ---
	player.global_position = Vector3(3.5, 0.05, 0)
	player.global_rotation = Vector3(0, -PI / 2.0, 0)
	player.head.rotation.x = 0.0
	await wait_physics(3)
	player.throw_bottle()
	var close_throw := world.get_node_or_null("ThrownBottle") as ThrownBottle
	check(close_throw != null and close_throw.global_position.x < 3.8, "A bottle thrown into a wall is released on the player's side")
	if close_throw != null:
		var close_impact := {}
		close_throw.shattered.connect(func(point: Vector3) -> void: close_impact["point"] = point)
		for frame in 120:
			if close_throw.has_shattered:
				break
			await physics_frame
		check(close_impact.has("point") and close_impact["point"].x < 3.85, "It shatters against the near face of the wall")
	player.inventory.add_item(PlayerInventory.BOTTLE_ITEM)
	carried = player.inventory.get_count(PlayerInventory.BOTTLE_ITEM)
	press(&"throw_item")
	check(player.inventory.get_count(PlayerInventory.BOTTLE_ITEM) == carried - 1, "Pressing G throws a bottle")

	# --- Dying while hidden ejects the player before respawn ---
	health.set("immunity", 0.0)
	player.global_position = locker.exit_position()
	await wait_physics(2)
	locker.interact(player)
	await wait_physics(2)
	check(player.hiding_spot == locker, "Player is hidden again before the lethal hit")
	health.call("take_damage", 1000.0, null)
	check(bool(health.get("is_dead")) and not player.is_hidden(), "Dying while hidden leaves the hiding spot")
	health.call("respawn")
	await wait_physics(2)
	check(not player.is_frozen and player.is_physics_processing(), "Respawn after a hidden death restores control")

	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
