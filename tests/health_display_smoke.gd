extends SceneTree
var failures: int = 0
func _initialize() -> void:
	run.call_deferred()
func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures += 1
func run() -> void:
	var map := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate()
	map.get_node("OpeningStory").persist_progress = false
	root.add_child(map)
	current_scene = map
	await create_timer(0.5).timeout
	var player := map.get_node("Player") as FirstPersonPlayer
	var health := player.get_node("CombatHealth")
	var hud := player.get_node("HandViewmodel") as HandViewmodel
	check(hud.hp_face_row == 0, "Full health starts with healthy face")
	health.take_damage(35)
	check(hud.hp_face_row == 1 and hud.hp_face.frame_coords.y == 1, "Enemy damage updates face and portrait frame")
	for key in [KEY_DOWN, KEY_UP, KEY_LEFT, KEY_RIGHT]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		hud._unhandled_input(event)
	check(hud.hp_face_row == 1 and health.health == 65, "Arrow keys cannot fake health condition")
	health.immunity = 0
	health.take_damage(35)
	check(hud.hp_face_row == 3, "Low health selects injured face")
	health.immunity = 0
	health.take_damage(25)
	check(hud.hp_face_row == 4, "Critical health selects most injured living face")
	health.immunity = 0
	health.take_damage(5)
	check(hud.hp_face_row == 5 and health.is_dead, "Zero health selects death face")
	health.respawn()
	check(hud.hp_face_row == 0 and health.health == health.max_health, "Retry restores healthy face")
	health.max_health = 200
	health.health = 100
	health.health_changed.emit(100)
	check(hud.hp_face_row == 2, "Condition uses health percentage rather than a fixed maximum")
	map.queue_free()
	current_scene = null
	for i in 3:
		await process_frame
	quit(1 if failures else 0)
