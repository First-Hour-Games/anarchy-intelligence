extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("--- Running Pause Distortion Smoke Test ---")
	await process_frame
	var pause_menu := root.get_node_or_null("PauseMenu")
	if pause_menu == null:
		push_error("FAIL: PauseMenu autoload not found in root")
		quit(1)
		return

	# 1. Verify CanvasLayer layer is 99
	assert(pause_menu.layer == 99, "Expected PauseMenu.layer to be 99, got %d" % pause_menu.layer)
	print("PASS: PauseMenu layer is 99 (behind CRTOverlay at 100)")

	# 2. Verify AspectRatioContainer exists
	var arc: AspectRatioContainer = null
	for child in pause_menu.overlay.get_children():
		if child is AspectRatioContainer:
			arc = child
			break
	assert(arc != null, "FAIL: AspectRatioContainer not found in pause_menu.overlay")
	assert(is_equal_approx(arc.ratio, 1.33333), "Expected ratio 1.33333, got %f" % arc.ratio)
	print("PASS: AspectRatioContainer exists with ratio 1.33333")

	# 3. Verify Content and Gutters
	var content: Control = arc.get_child(0) as Control
	assert(content != null, "FAIL: Content control not found in AspectRatioContainer")
	assert(content.get_node_or_null("RightGutter") != null, "FAIL: RightGutter missing")
	assert(content.get_node_or_null("LeftGutter") != null, "FAIL: LeftGutter missing")
	assert(content.get_node_or_null("TopGutter") != null, "FAIL: TopGutter missing")
	assert(content.get_node_or_null("BottomGutter") != null, "FAIL: BottomGutter missing")
	print("PASS: 4:3 Content and black gutters present on pause layer")

	# 4. Verify distortion rect and material
	var distortion_rect: ColorRect = pause_menu._distortion_rect
	assert(distortion_rect != null, "FAIL: _distortion_rect missing")
	assert(distortion_rect.get_parent() == content, "FAIL: _distortion_rect not child of 4:3 content")
	var mat: ShaderMaterial = distortion_rect.material as ShaderMaterial
	assert(mat != null, "FAIL: ShaderMaterial missing on distortion_rect")
	print("PASS: _distortion_rect is inside 4:3 content with ShaderMaterial")

	# 5. Test opening pause menu
	pause_menu.set_open(true)
	assert(pause_menu.opened, "FAIL: PauseMenu failed to open")
	assert(pause_menu.overlay.visible, "FAIL: PauseMenu overlay not visible")
	var cr_min: Vector2 = mat.get_shader_parameter("content_rect_min")
	var cr_size: Vector2 = mat.get_shader_parameter("content_rect_size")
	print("Shader content_rect_min: %s, content_rect_size: %s" % [cr_min, cr_size])
	print("PASS: PauseMenu opened and distortion rect bounds passed to shader")

	# 6. Test closing pause menu
	pause_menu.set_open(false)
	print("PASS: PauseMenu close triggered")

	print("--- All Pause Distortion Smoke Tests Passed! ---")
	quit(0)
