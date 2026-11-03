extends SceneTree
var failures: int = 0
func _initialize() -> void:
	run.call_deferred()
func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures += 1
func run() -> void:
	check(load("res://shaders/accumulation_blur.glsl") is RDShaderFile, "Blur compute shader imports")
	var map := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate()
	map.get_node("OpeningStory").persist_progress = false
	root.add_child(map)
	current_scene = map
	await create_timer(0.5).timeout
	var player := map.get_node("Player") as FirstPersonPlayer
	var health := player.get_node("CombatHealth")
	var camera := player.get_node("Head/Camera3D") as Camera3D
	var blur: CompositorEffect = health.daze_blur
	check(camera.compositor != null and camera.compositor.compositor_effects.has(blur), "Camera carries the hit blur effect")
	check(blur.get(&"alpha") == 0.0, "Blur is off before any hit")
	health.take_damage(20)
	check(blur.get(&"alpha") > 0.9, "Hit turns strong blur on")
	await create_timer(0.6).timeout
	var mid: float = blur.get(&"alpha")
	check(mid > 0.7 and mid < 0.94, "Blur fades after the hit")
	await create_timer(1.2).timeout
	check(blur.get(&"alpha") > 0.3, "Blur remains noticeable beyond the old duration")
	await create_timer(1.6).timeout
	check(blur.get(&"alpha") == 0.0 and camera.rotation.z == 0.0, "Blur and sway are gone after the daze")
	health.immunity = 0
	health.take_damage(500)
	check(health.is_dead and blur.get(&"alpha") == 0.0, "Fatal hit does not leave the blur on")
	map.queue_free()
	current_scene = null
	for i in 3:
		await process_frame
	quit(1 if failures else 0)
