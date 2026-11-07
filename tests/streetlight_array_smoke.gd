extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1

func run() -> void:
	print("--- Testing Streetlight Scene ---")
	var light_scene: PackedScene = load("res://models/map/residence/streetlight.tscn")
	check(light_scene != null, "streetlight.tscn loads successfully")
	var single_light := light_scene.instantiate() as Streetlight
	root.add_child(single_light)
	check(single_light != null, "streetlight instantiates as Streetlight (StaticBody3D)")
	check(single_light.has_node("Model"), "streetlight contains imported model")
	check(single_light.has_node("CollisionShape3D"), "streetlight has CollisionShape3D")
	check(single_light.has_node("LampSpotLight"), "streetlight has LampSpotLight (SpotLight3D)")

	var col_shape := single_light.get_node("CollisionShape3D") as CollisionShape3D
	check(col_shape.shape is CylinderShape3D, "pole collision is a cylinder shape")
	check(not col_shape.disabled, "collision is enabled by default")

	var spot := single_light.get_node("LampSpotLight") as SpotLight3D
	check(spot.visible, "spotlight is visible by default")
	check(spot.light_energy > 0.0, "spotlight has positive energy")
	check(spot.position.y > 3.5, "spotlight is positioned at lamp head height")

	single_light.light_enabled = false
	single_light._apply_light_settings()
	check(not spot.visible, "toggling light_enabled hides spotlight")

	single_light.collision_enabled = false
	single_light._apply_collision_settings()
	check(col_shape.disabled, "toggling collision_enabled disables collision")
	single_light.queue_free()

	print("--- Testing StreetlightArray System ---")
	var array_scene: PackedScene = load("res://models/map/residence/streetlight_array.tscn")
	check(array_scene != null, "streetlight_array.tscn loads successfully")
	var arr := array_scene.instantiate() as StreetlightArray
	root.add_child(arr)
	check(arr != null, "streetlight_array instantiates as StreetlightArray (Node3D)")

	# Test default generation
	arr.count = 4
	arr.spacing = 10.0
	arr.rebuild()
	var lights := arr.get_streetlights()
	check(lights.size() == 4, "default array builds 4 streetlights")

	# Check positions along positive X
	check(lights[0].position.is_equal_approx(Vector3(0, 0, 0)), "first streetlight at origin")
	check(lights[1].position.is_equal_approx(Vector3(10, 0, 0)), "second streetlight at X=10")
	check(lights[2].position.is_equal_approx(Vector3(20, 0, 0)), "third streetlight at X=20")
	check(lights[3].position.is_equal_approx(Vector3(30, 0, 0)), "fourth streetlight at X=30")

	# Test adjustable amount
	arr.count = 7
	arr.rebuild()
	lights = arr.get_streetlights()
	check(lights.size() == 7, "adjusting count to 7 creates 7 streetlights")
	check(lights[6].position.is_equal_approx(Vector3(60, 0, 0)), "seventh streetlight at X=60")

	# Test adjustable spacing
	arr.spacing = 25.0
	arr.count = 3
	arr.rebuild()
	lights = arr.get_streetlights()
	check(lights.size() == 3, "count reduced to 3")
	check(lights[1].position.is_equal_approx(Vector3(25, 0, 0)), "spacing adjustment updates spacing to 25m")
	check(lights[2].position.is_equal_approx(Vector3(50, 0, 0)), "third light at 50m")

	# Test Z axis alignment
	arr.line_axis = StreetlightArray.LineAxis.POSITIVE_Z
	arr.spacing = 12.0
	arr.rebuild()
	lights = arr.get_streetlights()
	check(lights[1].position.is_equal_approx(Vector3(0, 0, 12)), "aligning along positive Z places lights along Z")

	# Test height offset step (sloped street / hill)
	arr.height_offset_per_step = 1.5
	arr.rebuild()
	lights = arr.get_streetlights()
	check(is_equal_approx(lights[1].position.y, 1.5), "height step applies Y offset to 2nd light")
	check(is_equal_approx(lights[2].position.y, 3.0), "height step applies Y offset to 3rd light")

	# Test lighting settings propagation
	arr.enable_lights = false
	arr.rebuild()
	lights = arr.get_streetlights()
	var first_spot := lights[0].get_node("LampSpotLight") as SpotLight3D
	check(not first_spot.visible, "enable_lights=false turns off spotlights")

	# Test collision settings propagation
	arr.enable_collision = false
	arr.rebuild()
	lights = arr.get_streetlights()
	var first_col := lights[0].get_node("CollisionShape3D") as CollisionShape3D
	check(first_col.disabled, "enable_collision=false disables collision shapes")

	# Test baking to standalone nodes
	arr.bake_to_standalone_nodes()
	await process_frame
	check(arr.get_script() == null, "baking detaches generator script")
	check(arr.get_child_count() == 3, "baked children are preserved")
	check(not arr.get_child(0).has_meta(&"streetlight_array_item"), "baked children no longer tagged as array metadata")

	arr.queue_free()
	await process_frame

	print("streetlight_array_smoke: %s" % ("OK" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(1 if failures else 0)
