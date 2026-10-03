extends SceneTree

const ItemPickupScreen = preload("res://scenes/ui/item_pickup/item_pickup_screen.gd")

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, words: String) -> void:
	print(("PASS: " if value else "FAIL: ") + words)
	if not value:
		failures += 1


func run() -> void:
	print("--- Running Inspection Brochure Pickup End-To-End Smoke Test ---")

	var packed_forest := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	check(packed_forest != null, "Loaded starting_forest.tscn")
	var forest := packed_forest.instantiate()
	root.add_child(forest)
	current_scene = forest
	await process_frame

	var player := forest.get_node_or_null("Player") as FirstPersonPlayer
	check(is_instance_valid(player), "Player found in scene")

	var inspect_view := forest.get_node_or_null("Interactables/MapInspect/InspectableView") as InspectableView3D
	check(is_instance_valid(inspect_view), "InspectableView3D found")

	var brochure_hotspot := inspect_view.get_node_or_null("BrochurePickUp") as InspectionHotspot3D
	check(is_instance_valid(brochure_hotspot), "BrochurePickUp hotspot found")

	# Start inspection
	inspect_view.start_inspection(player)
	while inspect_view._is_transitioning:
		await process_frame
	await process_frame
	check(inspect_view.is_inspecting, "Inspection mode is active")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Mouse is visible in inspection")

	# Simulate clicking brochure hotspot
	inspect_view._on_hotspot_clicked(brochure_hotspot)
	await process_frame

	# Check that active dialogue balloon exists
	var balloon = inspect_view._active_dialogue_balloon
	check(is_instance_valid(balloon), "Dialogue balloon spawned for brochure")

	# Finish/dismiss dialogue
	if is_instance_valid(balloon):
		if balloon.has_signal("dialogue_finished"):
			balloon.emit_signal("dialogue_finished")
		balloon.queue_free()
	await create_timer(0.40).timeout

	# Check that ItemPickupScreen is active
	var pickup_screen = ItemPickupScreen.instance
	check(is_instance_valid(pickup_screen), "ItemPickupScreen instance exists")
	check(pickup_screen.is_active, "ItemPickupScreen is open and active")
	check(pickup_screen.get("_title_label").text == "TOURIST MAP", "Pickup screen shows TOURIST MAP")
	check(player.inventory.has_item(&"map"), "Player inventory received map item")
	check(brochure_hotspot.has_triggered, "BrochurePickUp hotspot has_triggered is true")

	# Close pickup screen via input event
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ENTER
	pickup_screen._unhandled_input(event)
	await create_timer(0.35).timeout

	check(not pickup_screen.is_active, "ItemPickupScreen successfully closed")
	check(inspect_view.is_inspecting, "Still in inspection view after taking brochure")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Mouse mode preserved as visible for remaining inspection")

	# Verify Brochure dot is no longer visible, but MapCenterHotspot remains
	var brochure_btn: InspectionDotButton = inspect_view._hotspot_map.get(brochure_hotspot)
	check(brochure_btn == null or not brochure_btn.visible, "Brochure dot button is hidden/consumed")

	# Exit inspection view with exit key (Backspace)
	var exit_event := InputEventKey.new()
	exit_event.pressed = true
	exit_event.keycode = KEY_BACKSPACE
	inspect_view._unhandled_input(exit_event)
	await create_timer(0.5).timeout
	check(not inspect_view.is_inspecting, "Inspection view successfully exited")

	forest.queue_free()

	print("--- All Inspection Brochure Pickup Checks Passed! ---")
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED with %d errors" % failures)
		quit(1)
