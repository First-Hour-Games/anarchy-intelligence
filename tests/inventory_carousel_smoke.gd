extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
	print(("PASS " if value else "FAIL ") + message)

func run() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as FirstPersonPlayer
	root.add_child(player)
	await process_frame
	var inventory := player.inventory as PlayerInventory
	inventory.select_relative(1)
	check(inventory.get_selected_item() == &"", "empty inventory navigation")
	inventory.add_item(&"flashlight")
	inventory.add_item(&"map")
	inventory.add_item(&"notebook")
	inventory.select_relative(1)
	check(inventory.get_selected_item() == &"flashlight", "forward wrap skips empty slots")
	inventory.select_relative(-1)
	check(inventory.get_selected_item() == &"notebook", "backward wrap")
	player.unfreeze()
	inventory.set_open(true, false)
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	inventory._input(wheel)
	await inventory._carousel_tween.finished
	check(inventory.get_selected_item() == &"flashlight", "mouse wheel selects next item")
	check(inventory._cards[0].position.is_equal_approx(Vector2(350, 16)), "selected item settles in center")
	check(not inventory._cards[3].visible, "empty slots hidden")
	check(paused, "inventory pauses gameplay")
	inventory.set_open(false, false)
	check(not paused, "closing restores gameplay")
	player.inventory_enabled = false
	inventory.set_open(true, false)
	check(not inventory.is_open and not paused, "disabled inventory blocks direct opening")
	var tab := InputEventKey.new()
	tab.pressed = true
	tab.keycode = KEY_TAB
	inventory._input(tab)
	check(not inventory.is_open and not paused, "disabled inventory blocks Tab")
	var tutorial := (load("res://scenes/chapters/tutorial/tutorial.tscn") as PackedScene).instantiate()
	check(not (tutorial.get_node("Player") as FirstPersonPlayer).inventory_enabled, "tutorial disables inventory")
	tutorial.free()
	player.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

