extends SceneTree
## Bloody footprint trail: the prints near the gas station stay hidden until the player has the
## flashlight, then fade in glowing red with a glossy wet surface.

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		print("FAIL: " + message)
		failures += 1

func _init() -> void:
	print("--- Running Bloody Footprint Trail Smoke Test ---")
	call_deferred("_run")

func _run() -> void:
	var forest: Node3D = (load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene).instantiate()
	forest.set("auto_start_fade", false)
	root.add_child(forest)
	await process_frame
	await physics_frame

	var trail := forest.get_node_or_null("BloodyFootprintTest") as BloodyFootprintTrail
	var player := forest.get_node_or_null("Player") as FirstPersonPlayer
	check(trail != null, "footprint trail uses BloodyFootprintTrail")
	check(player != null, "player found")
	if trail == null or player == null:
		quit(1)
		return
	var prints: Array[Decal] = []
	for child in trail.get_children():
		if child is Decal:
			prints.append(child as Decal)
	check(prints.size() >= 2, "trail has footprints")
	check(forest.get_node_or_null("FlashlightItem/Pickup") is FlashlightPickup, "gas station flashlight pickup is still there")
	check(not player.inventory.has_item(PlayerInventory.FLASHLIGHT_ITEM), "player starts without the flashlight")
	check(prints.all(func(d: Decal) -> bool: return not d.visible), "footprints are hidden before the flashlight")

	var first := prints[0]
	check(first.texture_emission != null and first.emission_energy > 0.0, "footprints glow")
	check(first.texture_orm != null, "footprints use the wet ORM")

	player.inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM)
	await process_frame
	check(trail.revealed, "picking up the flashlight reveals the trail")
	check(prints.all(func(d: Decal) -> bool: return d.visible), "every footprint is visible")
	var settle := trail.fade_in_time + trail.fade_in_stagger * prints.size() + 0.3
	await create_timer(settle).timeout
	var last := prints[prints.size() - 1]
	check(is_equal_approx(last.modulate.a, 1.0), "last footprint fades in fully")
	check(is_equal_approx(last.emission_energy, last.get("glow_energy")), "last footprint glow fades in to glow_energy")

	forest.queue_free()
	await process_frame
	quit(1 if failures else 0)
