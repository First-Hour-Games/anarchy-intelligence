extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("--- Running Distance Fog Smoke Test ---")
	await process_frame
	
	# 1. Verify distance fog shader resource
	var shader: Shader = load("res://shaders/distance_fog.gdshader")
	assert(shader != null, "distance_fog.gdshader must exist and load")
	assert(shader.code.contains("uniform sampler2D depth_texture"), "Shader must sample depth_texture")
	assert(shader.code.contains("uniform sampler2D screen_texture"), "Shader must sample screen_texture")
	assert(shader.code.contains("fog_distance"), "Shader must have fog_distance parameter")
	assert(shader.code.contains("quantize_color"), "Shader must have color quantization")
	assert(shader.code.contains("dither"), "Shader must have dithering")
	print("PASS: distance_fog.gdshader loaded and contains expected shader functions")
	
	# 2. Verify distance fog material resource
	var mat: ShaderMaterial = load("res://shaders/distance_fog_material.tres")
	assert(mat != null, "distance_fog_material.tres must exist and load")
	assert(mat.shader == shader, "Material must use distance_fog.gdshader")
	assert(mat.get_shader_parameter("enable_fog") == true, "Fog should be enabled by default")
	var fog_dist: float = float(mat.get_shader_parameter("fog_distance"))
	assert(fog_dist > 0.0, "fog_distance must be greater than 0")
	var fade_range: float = float(mat.get_shader_parameter("fog_fade_range"))
	assert(fade_range > 0.0, "fog_fade_range must be greater than 0")
	assert(mat.get_shader_parameter("affect_sky") == false, "affect_sky should be false so sky shader is visible")
	assert(shader.code.contains("affect_sky"), "Shader must support affect_sky toggle")
	assert(shader.code.contains("sky_horizon_blend"), "Shader must support sky_horizon_blend")
	print("PASS: distance_fog_material.tres loaded with fog_distance=%f, fade_range=%f, affect_sky=false" % [fog_dist, fade_range])
	
	# 3. Verify Player scene integration
	var packed_player := load("res://scenes/player/player.tscn") as PackedScene
	assert(packed_player != null, "player.tscn must exist and load")
	var player := packed_player.instantiate() as FirstPersonPlayer
	root.add_child(player)
	await process_frame
	
	var fog_mesh: MeshInstance3D = player.get_node_or_null("Head/Camera3D/DistanceFog")
	assert(fog_mesh != null, "DistanceFog node must exist under Head/Camera3D")
	assert(fog_mesh.mesh is QuadMesh, "DistanceFog mesh must be QuadMesh")
	assert(fog_mesh.extra_cull_margin >= 1000.0, "extra_cull_margin must be large enough to prevent culling")
	assert(fog_mesh.material_override != null, "material_override must be assigned")
	assert(player.get_distance_fog_material() != null, "get_distance_fog_material() helper must return material")
	print("PASS: DistanceFog quad integrated into Player Camera3D")
	
	# 4. Test toggling fog
	player.set_distance_fog_enabled(false)
	assert(not fog_mesh.visible, "Fog should be hidden when disabled")
	player.set_distance_fog_enabled(true)
	assert(fog_mesh.visible, "Fog should be visible when enabled")
	print("PASS: Distance fog enable/disable toggling works")
	
	player.queue_free()
	await process_frame
	
	print("--- All Distance Fog Checks Passed! ---")
	quit(0)
