extends SceneTree
## The alt route's shed and gate: the key at the gas station is the shed's, and the Wrapper's ambush waits for
## it; the shed's side door stays locked until the key is used, then opens and lets the player in; the shed
## keeps the player inside its walls and holds the shotgun on its bench; no key opens the yard gate, but
## shooting its padlock breaks it and unlocks the gate. The door, and the shotgun's shells, survive a save.

const ALT_FOREST := "res://scenes/chapters/alt_route/starting_forest_alt.tscn"

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func load_forest() -> Node3D:
	var forest: Node3D = load(ALT_FOREST).instantiate()
	forest.auto_start_fade = false
	forest.delay_dialogue_until_fade = false
	forest.get_node("IntroFadeCanvas").free()
	forest.get_node("BottomDialogueBalloon").free()
	root.add_child(forest)
	current_scene = forest
	return forest

func ray(forest: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	return forest.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))

func run() -> void:
	root.get_node("PauseMenu").set_process_unhandled_input(false)
	root.get_node("DebugMenu").set_process_input(false)
	var forest := load_forest()
	for i in 3:
		await physics_frame
	var player := forest.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	player.unfreeze()
	var door := forest.get_node("ShedInterior/ShedDoor") as KeyDoor
	var gate := forest.get_node("GasStation/MetalFenceGate") as RiggedMetalGate
	var padlock := forest.get_node("GatePadlock")
	var key := forest.get_node("FenceKey")

	check(key.get("item_id") == &"shed_key", "the key by the gas station's crates is the shed's")
	check(forest.get_node("WrapperPopoutZone").get("required_key") == &"shed_key", "the Wrapper's ambush waits for the shed key")
	check(gate.required_key == &"" and gate.is_locked, "no key opens the yard gate")

	# The side door: locked without the key, a way in once it is used.
	var doorway_from := Vector3(113.0, 1.2, 24.8)
	var doorway_to := Vector3(109.0, 1.2, 24.8)
	check(door.is_locked and not ray(forest, doorway_from, doorway_to).is_empty(), "the shed's side door is shut and locked")
	door.toggle(player)
	check(door.is_locked and not door.is_moving, "without the key the door only rattles")
	player.inventory.add_item(&"shed_key")
	door.set("_asking_player", player)
	door.open_with_key()
	check(not door.is_locked and not player.inventory.has_item(&"shed_key"), "saying yes to the key uses it up and unlocks the door")
	await create_timer(door.swing_duration + 0.2).timeout
	check(door.is_open and ray(forest, doorway_from, doorway_to).is_empty(), "the door swings in and leaves the doorway clear")
	var leaf_edge := (door.get_node("Hinge") as Node3D).global_transform * Vector3(1.15, 1.2, 0.0)
	check(leaf_edge.x < 111.4, "the door opens into the shed, not onto the porch")

	# Inside, the walls hold and the shotgun waits on the bench under its lamp.
	for direction: Vector3 in [Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		check(not ray(forest, Vector3(103, 1.2, 27.06), Vector3(103, 1.2, 27.06) + direction * 12.0).is_empty(),
			"the shed's walls stop the player from the inside (%s)" % direction)
	var pickup := forest.get_node("ShedInterior/ShotgunPickup") as Node3D
	var bench := forest.get_node("ShedInterior/Workbench") as Node3D
	var across_bench := Vector2(pickup.global_position.x - bench.global_position.x, pickup.global_position.z - bench.global_position.z)
	check(pickup.get("item_id") == &"shotgun" and across_bench.length() < 1.0 and pickup.global_position.y > bench.global_position.y + 0.9,
		"the shotgun lies on the workbench at the far end of the shed")
	var lamp := forest.get_node("ShedInterior/BenchLight") as SpotLight3D
	check(lamp != null and lamp.global_basis.z.y > 0.95 and absf(lamp.global_position.x - bench.global_position.x) < 0.75,
		"a lamp over the bench shines down on it")
	# The pump sign lights the garage from too far off for its shadows to stop at the walls; it leaves the
	# shed's inside out, while the lights inside, and the player's flashlight, still reach it.
	var sign := forest.get_node("GasStation/stationV3/PumpSign3/OmniLight3D") as Light3D
	var inside := forest.get_node("WarehouseBuilding/Inside") as GeometryInstance3D
	var floor := forest.get_node("ShedInterior/Floor") as GeometryInstance3D
	var flashlight := player.get_node("Head/Camera3D/Flashlight/Beam") as Light3D
	check((sign.light_cull_mask & inside.layers) == 0 and (sign.light_cull_mask & floor.layers) == 0
		and (sign.light_cull_mask & 1) != 0, "the pump sign's light leaves out the shed's inside, not the town")
	check((lamp.light_cull_mask & inside.layers) != 0 and (flashlight.light_cull_mask & inside.layers) != 0
		and (flashlight.light_cull_mask & floor.layers) != 0, "the bench lamp and the flashlight light the shed's inside")
	# The lamp's light would come out through the walls too, so it lights only the inside and what is in it.
	var outside := forest.get_node("WarehouseBuilding/Building") as GeometryInstance3D
	var bench_meshes := bench.find_children("*", "GeometryInstance3D", true, false)
	var leaf := door.get_node("Hinge/Leaf") as GeometryInstance3D
	check((lamp.light_cull_mask & outside.layers) == 0 and not bench_meshes.is_empty()
		and bench_meshes.all(func(mesh: Node) -> bool: return (mesh as GeometryInstance3D).layers == inside.layers)
		and (leaf.layers & inside.layers) == 0, "the lamp stays inside the walls with the bench, and the door, seen from outside, is left out")

	# The gate's padlock: a weak hit leaves it, a shotgun blast breaks it and unlocks the gate.
	padlock.take_shot(2.0, Vector3.ZERO)
	check(not padlock.is_broken and gate.is_locked, "a stray pellet does not break the padlock")
	player.inventory.add_item(&"shotgun")
	var shotgun := player.get_node("Head/Camera3D/ShotgunWeapon")
	player.global_position = Vector3(135.3, 0.15, 61.5)
	player.rotation.y = deg_to_rad(90.0)
	var camera := player.get_node("Head/Camera3D") as Camera3D
	await physics_frame
	var aim: Vector3 = (padlock.global_position + Vector3(0.0, -0.05, 0.0)) - camera.global_position
	player.head.rotation.x = atan2(aim.y, Vector2(aim.x, aim.z).length())
	await create_timer(0.6).timeout
	await physics_frame
	check(shotgun.try_fire(), "the shotgun fires at the padlock")
	check(padlock.is_broken and not gate.is_locked, "a shot from the yard breaks the padlock and unlocks the gate")
	await create_timer(padlock.fall_duration + 0.2).timeout
	var lock_model := padlock.get_node("Model/GatePadlock/Padlock") as Node3D
	check(lock_model.global_position.y < 0.6, "the padlock falls to the ground")
	player.global_position = Vector3(134.5, 0.15, 62.4)
	gate.toggle(player)
	check(gate.is_moving, "the unlocked gate swings open")

	# Saving: the door's lock and swing, and the shotgun's shells.
	var door_state: Dictionary = door.get_save_state()
	var gate_state: Dictionary = gate.get_save_state()
	shotgun.restore_shells(1, 3)
	var save_game := root.get_node("SaveGame")
	var player_state: Dictionary = save_game._capture_player(player)
	check(player_state.has("shotgun") and int(player_state.shotgun.loaded) == 1 and int(player_state.shotgun.reserve) == 3,
		"a save keeps the shotgun's shells")
	var section_state: Dictionary = save_game._capture_section(forest)
	check(section_state.saved_states.has("ShedInterior/ShedDoor"), "a save keeps the shed door")
	# Back to how a new game has them: the door and the gate locked, a padlock on the gate, no shotgun.
	door.restore_save_state({"locked": true, "open": false})
	gate.restore_save_state({"locked": true, "angle": 0.0})
	var fresh_lock: Node = (load("res://scenes/chapters/alt_route/gate_padlock.tscn") as PackedScene).instantiate()
	fresh_lock.set("gate_path", NodePath("../GasStation/MetalFenceGate"))
	forest.add_child(fresh_lock)
	(fresh_lock as Node3D).global_transform = padlock.global_transform
	player.inventory.remove_one(&"shotgun")
	await physics_frame
	check(door.is_locked and not door.is_open and gate.is_locked and not fresh_lock.is_broken,
		"a new game's shed door and gate are locked")
	save_game._restore_section(forest, section_state)
	await physics_frame
	await physics_frame
	check(not door.is_locked and door.is_open, "loading puts the shed door back unlocked and open")
	check(not gate.is_locked and fresh_lock.is_broken, "loading an unlocked gate leaves its padlock broken on the ground")
	save_game._restore_player(player, player_state)
	check(player.inventory.has_item(&"shotgun") and int(shotgun.get("loaded")) == 1 and int(shotgun.get("reserve")) == 3,
		"loading gives back the shotgun with the shells it had, not a fresh gun's")
	check(door_state == {"locked": false, "open": true} and not bool(gate_state.locked), "the saved states read as expected")
	print("alt_route_shed_smoke: %d failures" % failures)
	quit(1 if failures else 0)
