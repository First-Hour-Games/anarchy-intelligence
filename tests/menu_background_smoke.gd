extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("--- Running Menu Background Smoke Test ---")
	var menu_scene: PackedScene = load("res://scenes/mainMenu/menu.tscn")
	assert(menu_scene != null, "menu.tscn should load successfully")
	var menu: CanvasLayer = menu_scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	
	var bg = menu.get_node_or_null("MenuBackground") as ColorRect
	assert(bg != null, "MenuBackground ColorRect must exist")
	assert(bg.material != null, "MenuBackground must have a material")
	assert(bg.material is ShaderMaterial, "MenuBackground material must be a ShaderMaterial")
	
	var mat := bg.material as ShaderMaterial
	assert(mat.shader != null, "ShaderMaterial must have an assigned shader")
	assert(mat.shader.resource_path == "res://shaders/menu_background.gdshader", "Shader must be menu_background.gdshader")
	
	var patterns = mat.get_shader_parameter("patterns")
	assert(patterns is Array, "patterns uniform must be an Array")
	assert((patterns as Array).size() == 5, "patterns uniform must contain 5 textures")
	
	var directions = mat.get_shader_parameter("directions")
	assert(directions != null, "directions uniform must not be null")
	
	var velocities = mat.get_shader_parameter("velocities")
	assert(velocities != null, "velocities uniform must not be null")
	
	for f in 10:
		await process_frame
	
	print("PASS: Menu background shader initialized and rendered frames successfully")
	menu.queue_free()
	print("--- All Menu Background Smoke Tests Passed! ---")
	quit(0)
