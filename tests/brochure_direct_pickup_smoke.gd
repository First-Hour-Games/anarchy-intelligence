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

	# 1. Verify no direct pickup exists outside inspection
	var direct_pickup := forest.get_node_or_null("Interactables/MapInspect/InspectableView/BrochurePickUp/DirectPickup")
	check(direct_pickup == null, "Direct pickup does not exist outside inspection")

	var board := forest.get_node("Interactables/MapInspect") as InteractableBlock3D
	var inspection := forest.get_node("Interactables/MapInspect/InspectableView") as InspectableView3D
	var brochure_hotspot := inspection.get_node("BrochurePickUp") as InspectionHotspot3D
	var visual := forest.get_node("welcomeCenterTextured2/mapStand_V3/TownMapBoard/BrochureMap2") as Node3D

	# 2. Verify BrochurePickUp hotspot sits on the visible brochure mesh
	check(brochure_hotspot.global_position.distance_to(visual.global_position) < 0.05, "BrochurePickUp hotspot sits on the visible brochures")

	# 3. Looking at the board from outside targets the MapInspect board
	player.global_position = board.global_position + Vector3(0, 0, 1.2)
	player.camera.look_at(board.global_position)
	player.interaction_detector._process(0.0)
	check(player.interaction_detector.current_interactable == board, "Looking at board targets MapInspect")

	# 4. Press E to enter inspection mode
	board.interact(player)
	while inspection._is_transitioning:
		await process_frame
	await process_frame
	check(inspection.is_inspecting, "Interacting with board enters inspection mode")

	# 5. In inspection, BrochurePickUp eye icon button exists and can be clicked
	var brochure_btn: InspectionDotButton = inspection._hotspot_map.get(brochure_hotspot)
	check(is_instance_valid(brochure_btn) and brochure_btn.visible, "BrochurePickUp eye icon is visible in inspection")

	# 6. Click BrochurePickUp eye icon to trigger dialogue and pickup
	brochure_btn.clicked.emit()
	await process_frame

	var balloon = inspection._active_dialogue_balloon
	check(is_instance_valid(balloon), "Dialogue balloon spawned for brochure click")
	if is_instance_valid(balloon):
		if balloon.has_signal("dialogue_finished"):
			balloon.emit_signal("dialogue_finished")
		balloon.queue_free()
	await create_timer(0.40).timeout

	# 7. ItemPickupScreen displays the map
	check(is_instance_valid(PickupScreen.instance) and PickupScreen.instance.is_active, "PickupScreen opened after brochure interaction")
	check(player.has_item(&"map"), "Player received map item in inventory")

	# Confirm pickup with E
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_E
	event.keycode = KEY_E
	if is_instance_valid(PickupScreen.instance):
		PickupScreen.instance._unhandled_input(event)
	await create_timer(0.35).timeout

	check(not PickupScreen.instance.is_active, "PickupScreen closed after confirm")
	check(inspection.is_inspecting, "Player remains in inspection mode after taking brochure")
	check(not brochure_btn.visible, "BrochurePickUp eye icon is hidden after being picked up")

	# 8. Exit inspection mode
	var exit_event := InputEventKey.new()
	exit_event.pressed = true
	exit_event.keycode = KEY_ESCAPE
	inspection._unhandled_input(exit_event)
	await create_timer(0.5).timeout
	check(not inspection.is_inspecting, "Inspection mode exited successfully")

	forest.queue_free()
	await process_frame
	quit(1 if failures else 0)
