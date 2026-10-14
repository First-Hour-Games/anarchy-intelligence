extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var flashlight := load("res://scenes/player/flashlight/player_flashlight.tscn").instantiate() as PlayerFlashlight
	root.add_child(flashlight)
	await process_frame
	var model := flashlight.get_node("ModelPivot/Model") as Node3D
	assert(model.scene_file_path == "res://models/props/flashlightItem.tscn")
	var lens := model.get_node("Flashlight_Body/Flashlight_Lens") as MeshInstance3D
	assert((lens.material_override as StandardMaterial3D).emission_enabled)
	for mesh in model.find_children("*", "GeometryInstance3D", true, false):
		assert(mesh.layers == 2)
		assert(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var body := model.get_node("Flashlight_Body") as MeshInstance3D
	var held_bounds := body.transform * body.get_aabb()
	held_bounds = model.transform * held_bounds
	assert(held_bounds.size.z > 0.25 and held_bounds.size.z < 0.35)
	assert(held_bounds.size.y < 0.1)
	flashlight.set_enabled(true)
	flashlight._process(1.0)
	assert(flashlight.model_pivot.visible and flashlight.beam.visible)
	flashlight.set_enabled(false)
	flashlight._process(1.0)
	assert(not flashlight.model_pivot.visible and not flashlight.beam.visible)
	print("PASS: Held flashlight uses gas station model, correct scale/orientation, and working toggle")
	flashlight.queue_free()
	await process_frame
	quit()
