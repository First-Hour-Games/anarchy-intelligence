extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1200, 900)
	var map := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate()
	map.get_node("OpeningStory").set("persist_progress", false)
	root.add_child(map)
	current_scene = map
	for i in 15:
		await process_frame
	var player := map.get_node("Player") as FirstPersonPlayer
	player.freeze()
	map.get_node("OpeningStory").set_process(false)
	map.get_node("CRTOverlay").hide()
	map.get_node("WorldEnvironment").set_runtime_overhead_preview_active(true)
	var camera := Camera3D.new()
	map.add_child(camera)
	camera.current = true
	var views: Array[Dictionary] = [
		{"name": "welcome-center", "position": Vector3(85, 9, 7), "target": Vector3(73, 2, -18)},
		{"name": "hospital-exterior", "position": Vector3(290, 15, 224), "target": Vector3(247, 5, 255)},
		{"name": "hospital-interior", "position": Vector3(255.2, 1.9, 251.5), "target": Vector3(248, 1.2, 255)},
		{"name": "hospital-supplies", "position": Vector3(260, 1.8, 257.5), "target": Vector3(258, 1, 259.2)},
		{"name": "civic-ground-props", "position": Vector3(185, 2.5, 229), "target": Vector3(182, 0.9, 235.8)},
		{"name": "carrie-notebook", "position": Vector3(-154, 1.7, 113.25), "target": Vector3(-157.4, 1, 113.25)},
	]
	for view: Dictionary in views:
		camera.global_position = view.position
		camera.look_at(view.target)
		for i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../story-" + view.name + ".png")
		print("Captured ", view.name)
	player.unfreeze()
	player.inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM)
	player.inventory.set_open(true)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../story-inventory.png")
	root.size = Vector2i(1152, 648)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../story-inventory-wide.png")
	player.inventory.set_open(false)
	var pause_menu := root.get_node("PauseMenu")
	pause_menu.set_open(true)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../story-pause-menu.png")
	pause_menu.set_open(false)
	quit()
