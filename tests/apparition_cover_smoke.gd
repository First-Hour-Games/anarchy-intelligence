extends SceneTree

const Controller = preload("res://scenes/atmosphere/forest_apparitions.gd")
const Silhouette = preload("res://scenes/atmosphere/apparition_silhouette.gd")
var failures: int = 0
var world: Node3D
var player: FirstPersonPlayer
var controller: Controller

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ") + message)
	if not value:
		failures += 1

func box(label: String, size: Vector3, point: Vector3) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.7, 0.65, 0.5)
	mesh.material = material
	visual.mesh = mesh
	world.add_child(visual)
	visual.position = point
	return visual

func frame_cover(cover: Node3D) -> bool:
	controller.clear_sighting()
	var focus := cover.global_position
	if cover is MultiMeshInstance3D and not controller._covers.is_empty():
		var bounds: AABB = controller._covers[0]["bounds"]
		focus = bounds.get_center()
	for yaw: float in [-60.0, -45.0, -32.0, -28.0, -24.0, -20.0, -16.0, 16.0, 20.0, 24.0, 28.0, 32.0, 45.0, 60.0]:
		player.camera.look_at(Vector3(focus.x, player.camera.global_position.y, focus.z))
		player.camera.global_basis = Basis(Vector3.UP, deg_to_rad(yaw)) * player.camera.global_basis
		if controller._start_hat_man():
			return true
	return false

func snapshot(filename: String) -> void:
	if not "--preview" in OS.get_cmdline_user_args():
		return
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://") + "../" + filename)

func run() -> void:
	root.size = Vector2i(1280, 960)
	world = Node3D.new()
	world.name = "CoverTest"
	root.add_child(world)
	current_scene = world
	var floor := StaticBody3D.new()
	world.add_child(floor)
	var collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(100, 0.2, 100)
	collision.shape = floor_shape
	floor.add_child(collision)
	collision.position.y = -0.1
	box("FloorVisual", floor_shape.size, Vector3(0, -0.1, 0))
	player = load("res://scenes/player/player.tscn").instantiate() as FirstPersonPlayer
	world.add_child(player)
	player.set_physics_process(false)
	player.unfreeze()
	player.global_position = Vector3(0, 0.025, 0)
	controller = Controller.new()
	controller.name = "ForestApparitions"
	controller.automatic_sightings_enabled = false
	world.add_child(controller)
	controller.set_process(false)
	await process_frame
	await physics_frame
	var wall := box("Wall", Vector3(8, 2.8, 0.25), Vector3(0, 1.4, -5))
	controller.cover_paths = [NodePath("../Wall")]
	controller._cache_trees()
	check(controller._trees.is_empty() and controller._covers.size() == 1, "A plain wall is usable cover without any trees")
	check(frame_cover(wall), "Hat man peeks beside a wide wall with no physics collider")
	if controller.active_figure != null:
		controller._process(controller.reveal_seconds)
		check(controller.state == Controller.State.PEEKING, "Wall sighting reveals normally")
		check(controller.active_figure._material.get_shader_parameter("partial_cover"), "General cover uses its actual vertical extent")
		await snapshot("hatman-half-wall.png")
	controller.clear_sighting()
	wall.hide()
	var brick := box("PillarBrickBase", Vector3(1.2, 0.6, 1.2), Vector3(0, 0.3, -5))
	controller.cover_paths = [NodePath("../PillarBrickBase")]
	controller._cache_trees()
	check(not frame_cover(brick), "Waist-low visitor-center brickwork cannot conceal a full-height Hat man")
	brick.hide()
	var hollow := box("BrickAndNarrowPost", Vector3(1.2, 0.6, 1.2), Vector3(0, 0, -5))
	var combined := SurfaceTool.new()
	combined.begin(Mesh.PRIMITIVE_TRIANGLES)
	combined.append_from(hollow.mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)))
	var narrow_post := BoxMesh.new()
	narrow_post.size = Vector3(0.03, 2.8, 0.1)
	combined.append_from(narrow_post, 0, Transform3D(Basis.IDENTITY, Vector3(0, 1.4, 0)))
	hollow.mesh = combined.commit()
	controller.cover_paths = [NodePath("../BrickAndNarrowPost")]
	controller._cache_trees()
	check(not frame_cover(hollow), "A tall bounding box cannot substitute for geometry hiding the concealed half")
	hollow.hide()
	var sign := box("SignPanel", Vector3(0.8, 0.9, 0.12), Vector3(0, 1.55, -2.3))
	controller.cover_paths = [NodePath("../SignPanel")]
	controller._cache_trees()
	check(not frame_cover(sign), "A floating torso-height sign cannot invent cover for his head and legs")
	(sign.mesh as BoxMesh).size = Vector3(0.8, 2.6, 0.12)
	sign.position.y = 1.3
	check(frame_cover(sign), "A full-height sign allows a close sighting without a tree")
	if controller.active_figure != null:
		controller._process(controller.reveal_seconds)
		var figure_position: Vector3 = controller.active_figure.global_position
		var distance := Vector2(figure_position.x - player.global_position.x, figure_position.z - player.global_position.z).length()
		check(distance >= 2.0 and distance < 3.0, "Close sign sighting stays between two and three meters")
		check(controller.state == Controller.State.PEEKING, "A valid close sighting does not immediately retreat on approach")
		var height_range: Vector2 = controller.active_figure._material.get_shader_parameter("conceal_height_range")
		check(is_equal_approx(height_range.x, 0.0) and is_equal_approx(height_range.y, 2.6), "Sign concealment matches the board's full-height geometry")
		check(controller._at_edge(controller._target), "Close sign sighting stays peripheral")
		await snapshot("hatman-half-sign.png")
		sign.hide()
		controller._process(0.11)
		check(controller.state == Controller.State.IDLE, "Losing the actual cover clears the sighting before he floats in the open")
		sign.show()
		var old_transform: Transform3D = controller._covers[0]["transform"]
		sign.position.z -= 2.0
		controller.clear_sighting()
		check(frame_cover(sign) and controller._covers[0]["transform"] != old_transform, "Moving scenery updates the next sighting without rebuilding the scene")
		if controller.active_figure != null:
			controller._process(controller.reveal_seconds)
			var standing_at: Vector3 = controller.active_figure.global_position
			var toward := player.global_position.direction_to(standing_at)
			toward.y = 0.0
			player.global_position = standing_at - toward.normalized() * 1.9
			controller._process(0.01)
			check(controller.state == Controller.State.IDLE, "Approaching within two meters leaves no Hat man to inspect")
			player.global_position = Vector3(0, 0.025, 0)
	controller.clear_sighting()
	sign.position.z = -2.3
	sign.name = "OrdinaryPanel"
	controller.cover_paths = [NodePath("../OrdinaryPanel")]
	controller._cache_trees()
	check(not frame_cover(sign), "Ordinary scenery does not receive the sign's two-meter exception")
	sign.name = "SignPanel"
	sign.position.z = -1.1
	controller.cover_paths = [NodePath("../SignPanel")]
	controller._cache_trees()
	check(not frame_cover(sign), "A sign too close to the player cannot spawn Hat man")
	controller.minimum_distance = 0.1
	controller.small_cover_minimum_distance = 0.1
	check(not controller._hat_man_distance_allowed(Vector3(0, 0, -1.9), true), "Inspector tuning cannot bypass the absolute two-meter limit")
	check(not controller._hat_man_distance_allowed(Vector3(0, 0, -2.9)), "Ordinary cover keeps the three-meter minimum")
	controller.minimum_distance = 3.0
	controller.small_cover_minimum_distance = 2.0
	sign.position.z = -5.0
	sign.rotation.y = 0.55
	check(frame_cover(sign), "Rotated signs remain usable from the current perspective")
	controller.clear_sighting()
	sign.hide()
	check(not frame_cover(sign), "Hidden scenery cannot supply cover")
	var shape := CSGBox3D.new()
	shape.name = "CSGWall"
	shape.size = Vector3(2, 2.8, 0.25)
	world.add_child(shape)
	shape.position = Vector3(0, 1.4, -5)
	await process_frame
	await physics_frame
	controller.cover_paths = [NodePath("../CSGWall")]
	controller._cache_trees()
	check(frame_cover(shape), "CSG scenery can provide cover as well as imported meshes")
	controller.clear_sighting()
	shape.hide()
	var batch := MultiMeshInstance3D.new()
	batch.name = "InstancedPanel"
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(1, 2.6, 0.15)
	instances.mesh = panel_mesh
	instances.instance_count = 1
	# A saved buffer works under both the real and headless rendering servers.
	instances.buffer = PackedFloat32Array([1, 0, 0, 0, 0, 1, 0, 1.3, 0, 0, 1, -5])
	batch.multimesh = instances
	world.add_child(batch)
	await process_frame
	controller.cover_paths = [NodePath("../InstancedPanel")]
	controller._cache_trees()
	check(frame_cover(batch), "An instanced scenery mesh can conceal Hat man")
	controller.clear_sighting()
	batch.hide()
	sign.show()
	sign.rotation = Vector3.ZERO
	sign.position.z = -4.0
	controller.cover_paths = [NodePath("../SignPanel")]
	controller._cache_trees()
	var transparent := StandardMaterial3D.new()
	transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sign.material_override = transparent
	check(not frame_cover(sign), "A transparent prop cannot pretend to conceal a solid silhouette")
	sign.material_override = null
	var board_mesh := QuadMesh.new()
	board_mesh.size = Vector2(1.2, 1.0)
	sign.mesh = board_mesh
	check(not frame_cover(sign), "A short flat board cannot provide full-height concealment")
	board_mesh.size = Vector2(1.2, 2.6)
	check(frame_cover(sign), "A full-height flat sign board works without a collision body or thickness")
	controller.clear_sighting()
	if "--preview" in OS.get_cmdline_user_args():
		sign.hide()
		var reference := Silhouette.new()
		world.add_child(reference)
		reference.position = Vector3(0, 0.025, -4)
		player.camera.look_at(Vector3(0, 1.25, -4))
		await snapshot("hatman-reference-model.png")
		reference.queue_free()
		sign.show()
	var blocker := box("ForegroundBlocker", Vector3(2, 3, 0.3), Vector3(0, 1.5, -2))
	controller._cache_trees()
	check(not controller._cover_line_clear(player.camera.global_position, sign.global_position), "Foreground meshes block a sightline even without physics collision")
	blocker.hide()
	collision.disabled = true
	await physics_frame
	check(not frame_cover(sign), "Sightings require actual ground beside the cover")
	var dog := Silhouette.new()
	dog.shape = Silhouette.Shape.DOG
	world.add_child(dog)
	check(dog._material.shader == Silhouette.VOID_SHADER, "Dog and Hat man share the same void material")
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
