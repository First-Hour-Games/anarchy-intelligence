extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("--- Running Inspection Eye Button Smoke Test ---")
	var btn := InspectionDotButton.new()
	root.add_child(btn)
	await process_frame

	# 1. Texture check
	assert(InspectionDotButton.EYE_TEXTURE != null, "EYE_TEXTURE should not be null")
	assert(InspectionDotButton.EYE_TEXTURE.resource_path == "res://img/player/eyeInteract.png", "EYE_TEXTURE path mismatch")
	print("PASS: eyeInteract.png texture loaded successfully")

	# 2. Initial unhovered state (gray, scale 1.0)
	assert(btn.scale.is_equal_approx(Vector2.ONE), "Default scale should be 1.0")
	assert(btn.modulate.is_equal_approx(InspectionDotButton.COLOR_UNHOVERED), "Default modulate should be gray")
	print("PASS: Unhovered eye icon is gray at 1.0 scale")

	# 3. Simulate mouse hover
	btn.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await create_timer(0.25).timeout
	assert(btn.scale.x > 1.2, "Hovered scale should expand above 1.2, got %s" % btn.scale)
	assert(btn.modulate.is_equal_approx(InspectionDotButton.COLOR_HOVERED), "Hovered modulate should be white, got %s" % btn.modulate)
	print("PASS: Hovered eye icon turns white and scales up")

	# 4. Simulate mouse exit
	btn.notification(Control.NOTIFICATION_MOUSE_EXIT)
	await create_timer(0.25).timeout
	assert(btn.scale.is_equal_approx(Vector2.ONE), "Unhovered scale should return to 1.0, got %s" % btn.scale)
	assert(btn.modulate.is_equal_approx(InspectionDotButton.COLOR_UNHOVERED), "Unhovered modulate should return to gray, got %s" % btn.modulate)
	print("PASS: Unhovered eye icon returns to gray and 1.0 scale")

	# 5. Click signal test
	var click_received := [false]
	btn.clicked.connect(func(): click_received[0] = true)
	var click_ev := InputEventMouseButton.new()
	click_ev.button_index = MOUSE_BUTTON_LEFT
	click_ev.pressed = true
	btn.gui_input.emit(click_ev)
	assert(click_received[0], "clicked signal should be emitted on mouse left click")
	print("PASS: Clicked signal emitted on mouse press")

	btn.queue_free()
	print("--- All Inspection Eye Button Checks Passed! ---")
	quit(0)
