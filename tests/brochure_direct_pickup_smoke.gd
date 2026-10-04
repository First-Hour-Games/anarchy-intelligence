extends SceneTree

const PickupScreen = preload("res://scenes/ui/item_pickup/item_pickup_screen.gd")
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ") + message)
	if not value:
		failures += 1

func run() -> void:
	var forest := load("res://scenes/chapters/main/starting_forest.tscn").instantiate() as Node3D
	root.add_child(forest)
	current_scene = forest
	await process_frame
	forest.finish_fade_immediately()
	if is_instance_valid(forest.opening_balloon):
		forest.opening_balloon._end_dialogue()
	await process_frame
	var player := forest.get_node("Player") as FirstPersonPlayer
	player.unfreeze()
	var pickup := forest.get_node("Interactables/MapInspect/InspectableView/BrochurePickUp/DirectPickup") as Interactable3D
	var inspection := pickup.get_parent().get_parent() as InspectableView3D
	var visual := forest.get_node("welcomeCenterTextured2/mapStand_V3/TownMapBoard/BrochureMap2") as Node3D
	check(pickup.get_prompt_world_position().distance_to(visual.global_position) < 0.01, "Pickup prompt sits on the visible brochures")
	player.global_position = pickup.global_position + inspection.global_basis.z.normalized() * 1.5 - Vector3(0, pickup.global_position.y, 0)
	player.camera.look_at(pickup.global_position)
	player.interaction_detector._process(0.0)
	check(player.interaction_detector.current_interactable == pickup, "Brochures receive the E prompt directly")
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_E
	event.keycode = KEY_E
	player._unhandled_input(event)
	await create_timer(0.4).timeout
	check(player.has_item(&"map"), "E on brochures adds the map without board inspection")
	check(not inspection.is_inspecting, "Direct pickup keeps board inspection closed")
	check(is_instance_valid(PickupScreen.instance) and PickupScreen.instance.is_active, "Direct pickup displays the collected map")
	check(not pickup.can_interact(player), "Collected brochure cannot be picked up twice")
	if is_instance_valid(PickupScreen.instance):
		PickupScreen.instance._unhandled_input(event)
	await create_timer(0.35).timeout
	check(not player.is_frozen, "Confirming pickup restores player movement")
	forest.queue_free()
	await process_frame
	quit(1 if failures else 0)
