extends SceneTree

var failures := 0
var capture := false

func _initialize() -> void:
	capture = "--capture-portal" in OS.get_cmdline_user_args()
	call_deferred("run_test")

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1

func position_player(player: Node3D, camera: Camera3D, portal: Node, center: Vector3, position: Vector3) -> void:
	player.global_position = position - Vector3.UP * portal.crossing_height
	camera.global_position = position + Vector3(0.0, 0.5, 0.0)
	camera.look_at(center + Vector3(0.0, 0.5, 0.0))
	portal._process(0.0)

func run_test() -> void:
	var tutorial := (load("res://scenes/chapters/tutorial/tutorial.tscn") as PackedScene).instantiate()
	root.add_child(tutorial)
	await process_frame
	var portal := tutorial.get_node("LedgePortal")
	var back_collision := tutorial.get_node("Ledge/StaticBody3D/LedgeBackCollision") as CollisionShape3D
	check(back_collision.disabled, "ledge back collision starts disabled inside hallway")
	var zone := tutorial.get_node("TutorialRooms/MovingWallZone") as MovingWallZone
	var door := tutorial.get_node("TutorialRooms/BakedMovingWall/WhiteDoor") as InteractiveDoor
	var player := tutorial.get_node("Player") as Node3D
	var camera := tutorial.get_node("Player/Head/Camera3D") as Camera3D
	var floor_mesh := tutorial.get_node("TutorialRooms/Floor2") as GeometryInstance3D
	var floor_body := tutorial.get_node("TutorialRooms/CollisionGeometry") as CollisionObject3D
	var original_collision_layer := floor_body.collision_layer
	var phone := tutorial.get_node("Phone and Table/oldPhone/Interactable") as Interactable3D
	var light_settings: Dictionary = {}
	for light in tutorial.get_node("HallwayBulbs").find_children("*", "Light3D", true, false):
		light_settings[light] = [light.light_cull_mask, light.shadow_caster_mask, light.shadow_enabled]
	check(not portal.has_node("LedgeLight"), "portal adds no directional light to the scene")
	tutorial.set_process(false)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	for node in tutorial.get_children():
		if node is CanvasLayer:
			node.visible = false
	check(camera.get_cull_mask_value(20), "hallway is visible normally before crossing")
	check(floor_mesh.layers == portal.INTERIOR_LAYER, "hallway geometry uses the interior render layer")
	check(not tutorial.get_node("Ledge").find_children("*", "CollisionShape3D", true, false).is_empty(), "updated ledge retains walkable collision")
	zone.moving_wall.position.z = zone.target_z
	zone.wall_move_completed.emit(zone.moving_wall, zone.target_z)
	door.is_open = true
	door._hinge.rotation.y = deg_to_rad(-door.open_angle_degrees)
	door._door_collision.disabled = true
	for bulb in tutorial.get_node("HallwayBulbs")._bulbs:
		tutorial.get_node("HallwayBulbs")._set_bulb_on(bulb, true)
	var center := door.to_global(door._door_center_local)
	var normal := door.global_basis.z.normalized()
	await physics_frame
	await physics_frame
	var passage_query := PhysicsShapeQueryParameters3D.new()
	passage_query.shape = player.get_node("CollisionShape3D").shape
	passage_query.exclude = [player.get_rid()]
	var passage_clear := true
	for distance in [-0.5, -0.2, 0.0, 0.2, 0.5, 1.0, 2.0]:
		passage_query.transform = Transform3D(Basis.IDENTITY, center + normal * distance)
		var hits: Array = tutorial.get_world_3d().direct_space_state.intersect_shape(passage_query)
		passage_clear = passage_clear and hits.is_empty()
	check(passage_clear, "player capsule fits through first doorway crossing without hitting ledge barriers")
	position_player(player, camera, portal, center, center - normal * 2.0)
	tutorial.call("_sync_color_pass")
	await save_view("inside")
	position_player(player, camera, portal, center, center + normal * 0.05)
	await process_frame
	check(portal._outside_body and back_collision.disabled, "crossing doorway keeps back barrier disabled until player clears it")
	position_player(player, camera, portal, center, center + normal * 3.0)
	tutorial.call("_sync_color_pass")
	check(portal._outside_body, "walking through the opening enters the ledge space")
	await process_frame
	check(not back_collision.disabled, "ledge back collision enables after portal exit")
	check(not camera.get_cull_mask_value(20), "hallway is hidden outside the doorway window")
	check(portal._portal_surface.visible, "doorway window shows the hallway from the ledge")
	check(portal._portal_camera.cull_mask == portal.INTERIOR_LAYER, "portal camera renders the hallway")
	check(portal._portal_camera.global_transform.is_equal_approx(camera.global_transform), "portal camera matches the player for parallax")
	check(tutorial.get_node("DoorColorViewport/DoorCamera").cull_mask == camera.cull_mask, "first door overlay cannot leak outside the portal")
	check(floor_body.collision_layer == 0 and floor_body.collision_mask == 0, "hallway collision does not block ledge movement")
	check(door._hinge.collision_layer == 1, "white door retains its own physics")
	var original_lighting := true
	for light in light_settings:
		original_lighting = original_lighting and light_settings[light] == [light.light_cull_mask, light.shadow_caster_mask, light.shadow_enabled]
	check(original_lighting, "original hallway lighting and shadows stay unchanged outside")
	check(phone.is_in_group(&"interactable"), "phone remains interactable on the ledge")
	var table_visible := true
	for mesh in tutorial.get_node("Phone and Table").find_children("*", "MeshInstance3D", true, false):
		table_visible = table_visible and (mesh.layers & camera.cull_mask) != 0
	check(table_visible, "phone and table stay visible after exiting")
	await save_view("outside")
	position_player(player, camera, portal, center, center + normal * 3.0 + Vector3.RIGHT * 3.0)
	await save_view("outside_angle")
	position_player(player, camera, portal, center, center - normal * 2.0 + Vector3.RIGHT * 3.0)
	check(portal._outside_body and not camera.get_cull_mask_value(20), "walking behind the frame keeps the player in ledge space")
	check(not portal._portal_surface.visible, "back of portal does not reveal the hallway")
	check(floor_body.collision_layer == 0, "walking behind the frame does not restore hallway collision")
	await save_view("behind_frame")
	position_player(player, camera, portal, center, center + normal * 3.0 + Vector3.RIGHT * 3.0)
	position_player(player, camera, portal, center, center + normal * 2.0)
	position_player(player, camera, portal, center, center - normal * 2.0)
	check(not portal._outside_body and camera.get_cull_mask_value(20), "returning through the actual opening restores the hallway")
	await process_frame
	check(back_collision.disabled, "ledge back collision disables on return through portal")
	check(floor_body.collision_layer == original_collision_layer, "returning through opening restores hallway physics")
	check(not portal._portal_surface.visible, "portal surface is hidden while inside")
	check(phone.is_in_group(&"interactable"), "phone interaction persists on both sides")
	tutorial.queue_free()
	await process_frame
	quit(1 if failures else 0)

func save_view(view_name: String) -> void:
	if not capture:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/portal_preview")
	root.get_texture().get_image().save_png("res://.godot/portal_preview/%s.png" % view_name)
