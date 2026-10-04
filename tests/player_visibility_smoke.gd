extends SceneTree

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, words: String) -> void:
	print(("PASS: " if value else "FAIL: ") + words)
	if not value:
		failures += 1


func run() -> void:
	print("--- Running Player Automatic Runtime Visibility Smoke Test ---")

	# Test 1: Player instantiated with visible = false (hidden in editor)
	var packed_player := load("res://scenes/player/player.tscn") as PackedScene
	check(packed_player != null, "player.tscn loaded")

	var player := packed_player.instantiate() as FirstPersonPlayer
	player.visible = false # Simulating user hiding player in editor hierarchy
	check(not player.visible, "Player initially hidden before entering tree")

	root.add_child(player)
	await process_frame

	check(player.visible, "Player automatically becomes visible upon entering tree / _ready()")
	check(player.camera.visible, "Player camera is visible")
	if is_instance_valid(player.distance_fog):
		check(player.distance_fog.visible, "DistanceFog quad is visible")

	var vm := player.get_node_or_null("HandViewmodel") as CanvasLayer
	if is_instance_valid(vm):
		check(vm.visible, "HandViewmodel is visible")

	# Test 2: Attempting to hide player during gameplay
	player.visible = false
	await process_frame
	check(player.visible, "Player automatically restores to visible when hidden during gameplay")

	# Test 3: starting_forest.tscn where Player node is defined with visible = false
	var packed_forest := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	check(packed_forest != null, "starting_forest.tscn loaded")

	var forest := packed_forest.instantiate()
	root.add_child(forest)
	await process_frame

	var forest_player := forest.get_node_or_null("Player") as FirstPersonPlayer
	check(is_instance_valid(forest_player), "Forest player found")
	check(forest_player.visible, "Forest player is automatically visible in-game despite being hidden in scene file")
	check(forest_player.camera.visible, "Forest player camera is visible in-game")

	forest.queue_free()
	player.queue_free()

	print("--- Player Automatic Runtime Visibility Checks Complete ---")
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED with %d errors" % failures)
		quit(1)
