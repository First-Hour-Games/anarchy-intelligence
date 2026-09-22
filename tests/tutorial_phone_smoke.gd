extends SceneTree

var failures := 0

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var tutorial_packed := load("res://scenes/chapters/tutorial/tutorial.tscn") as PackedScene
	check(tutorial_packed != null, "tutorial.tscn loaded")

	var tutorial := tutorial_packed.instantiate()
	root.add_child(tutorial)
	await process_frame

	var phone := tutorial.get_node_or_null("oldPhone") as OldPhone
	check(is_instance_valid(phone), "oldPhone exists in tutorial")

	var player := tutorial.get_node_or_null("Player") as FirstPersonPlayer
	check(is_instance_valid(player), "Player exists in tutorial")

	var pickup_audio := phone.get_node_or_null("PickupAudio") as AudioStreamPlayer
	check(is_instance_valid(pickup_audio), "oldPhone has PickupAudio node")
	if is_instance_valid(pickup_audio):
		check(pickup_audio.stream != null, "PickupAudio has stream")
		check(pickup_audio.stream.resource_path == "res://sounds/chapters/tutorial/phonePickUp.mp3", "PickupAudio stream is phonePickUp.mp3")
		check(pickup_audio.bus == &"Reverb", "PickupAudio bus is Reverb")

	# Simulate ringing first
	phone.start_ringing()
	check(phone.ringing_audio.playing, "Phone starts ringing")

	# Verify player is not frozen initially
	check(not player.is_frozen, "Player is not frozen before interaction")

	# Interact with phone
	var interactable := phone.get_node_or_null("Interactable") as Interactable3D
	check(is_instance_valid(interactable), "Phone has Interactable")
	interactable.interact(player)

	# Verify ringing stopped
	check(not phone.ringing_audio.playing, "Phone ringing stopped after interaction")

	# Verify pickup audio is playing
	check(pickup_audio.playing, "Phone pickup audio is playing")

	# Verify player is frozen
	check(player.is_frozen, "Player is_frozen flag is true")
	check(not player.is_physics_processing(), "Player physics process is disabled")
	check(not player.is_processing_unhandled_input(), "Player unhandled input is disabled")
	check(player.velocity == Vector3.ZERO, "Player velocity is zero")
	check(not player.interaction_detector.is_processing(), "Player interaction detector process is disabled")

	# Verify black screen overlay
	var overlay := root.find_child("PhoneBlackScreenOverlay", true, false) as CanvasLayer
	if not is_instance_valid(overlay):
		overlay = tutorial.find_child("PhoneBlackScreenOverlay", true, false) as CanvasLayer
	check(is_instance_valid(overlay), "PhoneBlackScreenOverlay exists")
	if is_instance_valid(overlay):
		check(overlay.layer >= 100, "Overlay layer is high priority (>= 100)")
		var black_rect := overlay.get_node_or_null("BlackScreen") as ColorRect
		check(is_instance_valid(black_rect), "BlackScreen ColorRect exists")
		if is_instance_valid(black_rect):
			check(black_rect.color == Color.BLACK, "ColorRect color is Color.BLACK")
			check(black_rect.mouse_filter == Control.MOUSE_FILTER_STOP, "ColorRect blocks mouse filter")

	# Check that second interaction does nothing
	var was_playing := pickup_audio.playing
	interactable.interact(player)
	check(pickup_audio.playing == was_playing, "Second interaction is ignored")

	# Wait for dialogue start delay and verify balloon
	await create_timer(0.6).timeout
	check(is_instance_valid(phone.active_balloon), "Dialogue balloon was created")
	if is_instance_valid(phone.active_balloon):
		check(phone.active_balloon.is_inside_tree(), "Dialogue balloon is inside tree")
		if phone.active_balloon is CanvasLayer:
			check((phone.active_balloon as CanvasLayer).layer > 150, "Dialogue balloon layer is on top of black screen")
		check(phone.active_balloon.get("dialogue_line") != null, "Dialogue balloon has active dialogue_line")

	tutorial.queue_free()
	await process_frame

	quit(1 if failures > 0 else 0)
