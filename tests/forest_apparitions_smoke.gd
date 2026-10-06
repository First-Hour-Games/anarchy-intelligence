extends SceneTree

const Controller = preload("res://scenes/atmosphere/forest_apparitions.gd")
const Silhouette = preload("res://scenes/atmosphere/apparition_silhouette.gd")
const TreeAnchor = preload("res://scenes/atmosphere/apparition_tree_anchor.gd")
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ") + message)
	if not value:
		failures += 1

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	root.size = Vector2i(1280, 960)
	var forest := load("res://scenes/chapters/main/starting_forest.tscn").instantiate() as Node3D
	root.add_child(forest)
	current_scene = forest
	await process_frame
	forest.finish_fade_immediately()
	if is_instance_valid(forest.opening_balloon):
		forest.opening_balloon._end_dialogue()
	await process_frame
	await physics_frame
	var player := forest.get_node("Player") as FirstPersonPlayer
	player.unfreeze()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var controller := forest.get_node("ForestApparitions") as Controller
	controller.set_process(false)
	player.set_physics_process(false)
	check(controller._trees.size() > 2, "Existing forest trees are available for sightings")
	check(controller.state == Controller.State.IDLE, "No sighting before the first automatic interval")
	check(controller.automatic_sightings_enabled and is_equal_approx(controller.hat_man_interval_seconds, 30.0) and is_equal_approx(controller.dog_interval_seconds, 100.0), "Forest enables independent 30-second hat-man and 100-second dog timers")
	controller.automatic_sightings_enabled = false
	var gameplay := controller._gameplay_rect()
	var border_point := player.camera.project_position(gameplay.position + gameplay.size * Vector2(0.06, 0.5), 12.0)
	var peripheral_point := player.camera.project_position(gameplay.position + gameplay.size * Vector2(0.18, 0.5), 12.0)
	var center_point := player.camera.project_position(gameplay.position + gameplay.size * Vector2(0.5, 0.5), 12.0)
	check(not controller._at_edge(border_point), "Hat man is kept clear of the curved TV border")
	check(controller._at_edge(peripheral_point), "Readable peripheral area is accepted inside the TV border")
	check(not controller._at_edge(center_point), "Hat man cannot spawn directly in the middle of the view")
	var shortcut := InputEventKey.new()
	shortcut.pressed = true
	shortcut.keycode = KEY_EQUAL
	check(not shortcut.is_action_pressed(&"debug_apparition"), "The plus/equals key alone cannot trigger a developer sighting")
	shortcut.alt_pressed = true
	check(shortcut.is_action_pressed(&"debug_apparition"), "Alt + the plus/equals key triggers without needing Shift")
	var sprint_shortcut := shortcut.duplicate() as InputEventKey
	sprint_shortcut.shift_pressed = true
	check(sprint_shortcut.is_action_pressed(&"debug_apparition"), "Alt + plus still works while Shift is held for sprinting")
	var alternate := InputEventKey.new()
	alternate.pressed = true
	alternate.keycode = KEY_PLUS
	check(not alternate.is_action_pressed(&"debug_apparition"), "Plus alone cannot trigger a developer sighting")
	alternate.alt_pressed = true
	check(alternate.is_action_pressed(&"debug_apparition"), "Alt + a dedicated plus key triggers the developer action")
	alternate.keycode = KEY_KP_ADD
	check(alternate.is_action_pressed(&"debug_apparition"), "Alt + numpad plus triggers the developer action")
	alternate.alt_pressed = false
	check(not alternate.is_action_pressed(&"debug_apparition"), "Numpad plus alone cannot trigger a developer sighting")
	alternate.keycode = KEY_F8
	alternate.alt_pressed = true
	check(not alternate.is_action_pressed(&"debug_apparition"), "The previous Alt + F8 shortcut is removed")
	var offset_trunk := CylinderMesh.new()
	offset_trunk.height = 3.0
	offset_trunk.top_radius = 0.12
	offset_trunk.bottom_radius = 0.12
	var trunk_transform := Transform3D(Basis.IDENTITY, Vector3(2.0, 1.5, 0.0))
	var parts: Array[Dictionary] = [{"faces": TreeAnchor.bark_faces(offset_trunk), "transform": trunk_transform}]
	var measured := TreeAnchor.sections(parts, 0.0)
	check(measured.size() == 4 and measured[1][0].x > 1.8, "Trunk placement follows an offset mesh instead of guessing from the tree root")
	var foliage := QuadMesh.new()
	var foliage_material := StandardMaterial3D.new()
	foliage_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	foliage.material = foliage_material
	check(TreeAnchor.bark_faces(foliage).is_empty(), "Transparent foliage cannot inflate the measured trunk width")
	# Isolate a real tree for repeatable grounding and retreat checks.
	var tree := forest.get_node("dead_tree_rt_155") as Node3D
	controller.tree_paths = [NodePath("../dead_tree_rt_155")]
	controller._cache_trees()
	player.global_position = tree.global_position + Vector3(0, 0.25, 12)
	player.camera.look_at(tree.global_position + Vector3.UP * 1.96)
	await physics_frame
	# Find an unobstructed approach to the tree, rather than looking through the welcome-center props.
	for angle_index in 8:
		var angle := angle_index * TAU / 8.0
		player.global_position = tree.global_position + Vector3(sin(angle) * 12, 0.25, cos(angle) * 12)
		for yaw: float in [-32.0, -30.0, -28.0, -25.0, 25.0, 28.0, 30.0, 32.0]:
			player.camera.look_at(tree.global_position + Vector3.UP * 2.14)
			player.camera.global_basis = Basis(Vector3.UP, deg_to_rad(yaw)) * player.camera.global_basis
			controller._unhandled_input(shortcut)
			if controller.active_figure != null:
				break
		if controller.active_figure != null:
			break
	check(controller.state == Controller.State.REVEALING, "Alt + plus starts a gradual hat-man reveal")
	var hat_player_transform := player.global_transform
	var hat_camera_transform := player.camera.transform
	if controller.active_figure != null:
		check(controller.active_figure.shape == Silhouette.Shape.HAT_MAN, "First silhouette is hat man")
		check(controller._at_edge(controller._target), "Hat man stays peripheral with clearance from the TV border")
		var edges: PackedVector3Array = controller.active_figure._material.get_shader_parameter("conceal_edges")
		check(edges.size() == 4, "Concealment follows measured bark at coat, shoulder, and hat heights")
		check(is_zero_approx(controller.active_figure.rotation.z), "Figure starts upright behind the trunk")
		check(is_zero_approx(float(controller.active_figure._material.get_shader_parameter("reveal_amount"))), "Figure starts fully concealed instead of popping into view")
		controller._process(controller.reveal_seconds * 0.5)
		check(is_zero_approx(controller.active_figure.rotation.z) and controller._peek_amount > 0.0 and controller._peek_amount < 1.0, "Figure gradually slides out while staying upright")
		controller._process(controller.reveal_seconds * 0.6)
		check(controller.state == Controller.State.PEEKING and is_zero_approx(controller.active_figure.rotation.z), "Full peek keeps the hat man's body straight")
		var coat_side := controller.active_figure.to_global(Vector3(-controller._peek_side * 0.30, 1.20, 0))
		var view_origin := player.camera.global_position
		var outward := controller._peek_direction
		var forward: Vector3 = controller.active_figure._material.get_shader_parameter("conceal_forward")
		var coat_offset := coat_side - view_origin
		var edge_offset := edges[1] - view_origin
		check(coat_offset.dot(outward) / coat_offset.dot(forward) > edge_offset.dot(outward) / edge_offset.dot(forward), "Upper coat extends past the actual trunk edge, below the former shoulder cutoff")
		var center_offset := controller.active_figure.global_position + Vector3.UP * 1.20 - view_origin
		var center_error := absf(center_offset.dot(outward) / center_offset.dot(forward) - edge_offset.dot(outward) / edge_offset.dot(forward)) * center_offset.dot(forward)
		check(center_error < 0.03, "Measured bark edge divides the upright body approximately in half")
		player.global_position += player.camera.global_basis.x * 0.25
		controller._process(0.01)
		var mask_view: Vector3 = controller.active_figure._material.get_shader_parameter("conceal_view_origin")
		check(mask_view.is_equal_approx(player.camera.global_position), "Bark concealment stays aligned when the player moves")
		check(controller.active_figure.find_children("*", "CollisionObject3D", true, false).is_empty(), "Apparitions have no physical body")
		var valid_visuals := true
		for child: Node in controller.active_figure.get_children():
			valid_visuals = valid_visuals and (child as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and (child as MeshInstance3D).layers == Silhouette.VIEW_LAYER
		check(valid_visuals, "All silhouette parts are shadowless and on the player view layer")
		var original := controller.active_figure
		controller._unhandled_input(shortcut)
		check(controller.active_figure == original, "Repeated shortcut presses do not create overlapping figures")
		player.camera.look_at(controller._target)
		controller._process(0.02)
		check(controller.state == Controller.State.RETREATING and is_zero_approx(controller.active_figure.rotation.z), "Looking directly makes the upright figure slide back")
		controller._process(0.6)
		check(controller.state == Controller.State.IDLE and controller.active_figure == null, "Retreat cleans up the figure")
		check(not (controller._trees[0]["sections"] as Array).is_empty(), "Retreat preserves the cached trunk for later sightings")
	player.camera.rotation.x = 0.0
	controller._trees.clear()
	controller._unhandled_input(shortcut)
	check(controller.state == Controller.State.DOG_PASS and controller.active_figure != null and controller.active_figure.shape == Silhouette.Shape.DOG, "Dog makes a close pass without needing a tree")
	if controller.active_figure != null:
		controller._process(controller.dog_pass_seconds * 0.3)
		var ears := controller.active_figure.to_global(Vector3(-0.59, 1.475, 0))
		check(controller._screen_position(ears).y > 0.83, "Only the top of the dog enters the bottom of the view")
		controller._process(controller.dog_pass_seconds)
		check(controller.state == Controller.State.IDLE, "Dog vanishes in less than half a second")
	# Use real sprint input, physics movement, and head bob on an open road.
	player.global_position = Vector3(-280.0, 0.025, 10.5346913)
	player.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	player.head.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.camera.position = player.camera_rest_position
	player.velocity = Vector3.ZERO
	key(KEY_W, true)
	key(KEY_SHIFT, true)
	player.set_physics_process(true)
	for frame in 30:
		await physics_frame
	check(player.is_sprinting and Vector2(player.velocity.x, player.velocity.z).length() > player.walk_speed, "Sprint regression uses actual forward movement and Shift input")
	var sprint_start := player.global_position
	controller.next_shape = Silhouette.Shape.DOG
	controller._unhandled_input(sprint_shortcut)
	check(controller.state == Controller.State.DOG_PASS, "Alt + plus triggers the dog while sprinting with Shift held")
	var sprint_visible_frames := 0
	var dog_stayed_ahead := true
	for frame in 25:
		await physics_frame
		controller._process(1.0 / 60.0)
		if controller.active_figure == null:
			continue
		var ears := controller.active_figure.to_global(Vector3(-0.59, 1.475, 0))
		var screen := controller._screen_position(ears)
		if screen.x > 0.0 and screen.x < 1.0 and screen.y > 0.78 and screen.y < 1.0:
			sprint_visible_frames += 1
		dog_stayed_ahead = dog_stayed_ahead and not player.camera.is_position_behind(ears)
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.camera.position = player.camera_rest_position
	check(player.global_position.distance_to(sprint_start) > 1.0, "Player moves more than a meter during the sprint glimpse")
	check(sprint_visible_frames >= 3 and dog_stayed_ahead, "Dog remains briefly visible at the bottom instead of being overtaken while sprinting")
	check(controller.state == Controller.State.IDLE, "Sprinting dog still disappears within the short glimpse")
	controller.next_shape = Silhouette.Shape.DOG
	controller.trigger_sighting()
	if controller.active_figure != null:
		player.camera.rotation.x -= deg_to_rad(12.0)
		controller._process(0.01)
		check(controller.state == Controller.State.IDLE, "Looking down quickly leaves no dog to inspect")
	player.camera.rotation.x = 0.0
	controller.next_shape = Silhouette.Shape.DOG
	controller.trigger_sighting()
	player.freeze()
	controller._process(0.01)
	check(controller.state == Controller.State.IDLE, "Dialogue or inspection clears an active sighting")
	controller._unhandled_input(shortcut)
	check(controller.state == Controller.State.IDLE, "Developer trigger is blocked while player is frozen")
	paused = true
	controller._unhandled_input(shortcut)
	check(controller.state == Controller.State.IDLE, "Pause and inventory suppress the developer trigger")
	paused = false
	player.unfreeze()
	controller.developer_trigger_enabled = false
	controller._unhandled_input(shortcut)
	check(controller.state == Controller.State.IDLE, "Developer trigger can be disabled in the inspector")
	check(not player.has_item(&"map"), "Sightings do not grant items or alter inventory")
	# Advance gameplay time directly to verify long intervals without a long wait.
	player.global_transform = hat_player_transform
	player.camera.transform = hat_camera_transform
	controller._cache_trees()
	controller.automatic_sightings_enabled = true
	var manual_next := controller.next_shape
	controller._process(29.0)
	check(controller.state == Controller.State.IDLE, "Automatic hat man waits the full 30 seconds")
	controller._process(1.0)
	check(controller.state == Controller.State.REVEALING and controller.active_figure != null and controller.active_figure.shape == Silhouette.Shape.HAT_MAN, "Hat man starts automatically at 30 seconds with developer input disabled")
	check(controller.next_shape == manual_next, "Automatic sightings preserve the manual shortcut sequence")
	controller.clear_sighting()
	controller._trees.clear()
	player.global_position = Vector3(-280.0, 0.025, 10.5346913)
	player.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	player.camera.rotation = Vector3.ZERO
	controller._process(69.0)
	check(controller.state == Controller.State.IDLE, "Dog's independent timer has not fired at 99 seconds")
	controller._process(1.0)
	check(controller.state == Controller.State.DOG_PASS and controller.active_figure != null and controller.active_figure.shape == Silhouette.Shape.DOG, "Dog starts automatically at 100 seconds even without a suitable tree")
	controller.clear_sighting()
	controller._hat_man_clock = 5.0
	controller._dog_clock = 7.0
	paused = true
	controller._process(200.0)
	paused = false
	player.freeze()
	controller._process(200.0)
	player.unfreeze()
	check(is_equal_approx(controller._hat_man_clock, 5.0) and is_equal_approx(controller._dog_clock, 7.0) and controller.state == Controller.State.IDLE, "Pause and dialogue stop both automatic clocks without queuing a burst")
	player.global_transform = hat_player_transform
	player.camera.transform = hat_camera_transform
	controller._hat_man_clock = 30.0
	controller._hat_man_retry = 0.0
	controller._process(0.0)
	check(controller.state == Controller.State.IDLE and is_equal_approx(controller._hat_man_clock, 30.0), "A missing peripheral tree keeps one hat-man sighting pending")
	controller._cache_trees()
	controller._process(0.25)
	check(controller.state == Controller.State.IDLE, "Pending hat man waits between retries")
	controller._process(0.75)
	check(controller.state == Controller.State.REVEALING, "Pending hat man appears when a suitable peripheral tree becomes available")
	controller.clear_sighting()
	controller._hat_man_clock = 30.0
	controller._dog_clock = 100.0
	controller._dog_retry = 0.0
	player.global_position = Vector3(-280.0, 0.025, 10.5346913)
	player.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	player.camera.rotation = Vector3.ZERO
	controller._process(0.0)
	check(controller.state == Controller.State.DOG_PASS, "Dog gets priority when both automatic timers are due")
	var due_dog := controller.active_figure
	controller._process(0.1)
	check(controller.active_figure == due_dog, "Due hat man cannot overlap the automatic dog")
	controller._process(0.4)
	player.global_transform = hat_player_transform
	player.camera.transform = hat_camera_transform
	controller._process(0.0)
	check(controller.state == Controller.State.REVEALING, "Due hat man appears after the automatic dog finishes")
	controller.clear_sighting()
	controller.automatic_sightings_enabled = false
	controller._process(200.0)
	check(controller.state == Controller.State.IDLE, "Automatic sightings can be switched off in the inspector")
	root.size = Vector2i(1920, 1080)
	await process_frame
	var safe := controller._gameplay_rect()
	var visible_size := root.get_visible_rect().size
	check(is_equal_approx(safe.size.x / safe.size.y, 4.0 / 3.0) and safe.position.is_equal_approx((visible_size - safe.size) * 0.5), "Peripheral framing uses the centered 4:3 area after viewport scaling")
	forest.queue_free()
	await process_frame
	quit(1 if failures else 0)
