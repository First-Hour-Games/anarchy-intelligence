extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_test")


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1


func run_test() -> void:
	var tutorial_packed := load("res://scenes/chapters/tutorial/tutorial.tscn") as PackedScene
	check(tutorial_packed != null, "tutorial.tscn loaded successfully")

	var tutorial := tutorial_packed.instantiate()
	root.add_child(tutorial)
	await process_frame
	await process_frame

	var door_viewport := tutorial.get_node_or_null("DoorColorViewport") as SubViewport
	check(is_instance_valid(door_viewport), "DoorColorViewport exists")

	var door_copy := tutorial.get_node_or_null("DoorColorViewport/DoorColorCopy")
	check(is_instance_valid(door_copy), "DoorColorCopy exists in viewport")

	var rooms_occluder := tutorial.get_node_or_null("DoorColorViewport/TutorialRooms_ColorOccluder")
	check(is_instance_valid(rooms_occluder), "TutorialRooms_ColorOccluder exists in DoorColorViewport")

	var overlay_texture := tutorial.get_node_or_null("DoorColorOverlay/DoorTexture") as TextureRect
	check(is_instance_valid(overlay_texture), "DoorTexture exists in DoorColorOverlay")

	var bed_occluder := rooms_occluder.find_child("FloatingBed", true, false) as Node3D
	check(is_instance_valid(bed_occluder), "FloatingBed exists in occluder copy")

	# Verify occluder meshes have depth occluder material applied
	var bed_meshes := bed_occluder.find_children("*", "GeometryInstance3D", true, false)
	check(not bed_meshes.is_empty(), "FloatingBed has geometry instances in occluder copy")
	for m: GeometryInstance3D in bed_meshes:
		check(m.material_override != null, "Mesh %s has occluder material_override" % m.name)
		if m.material_override is ShaderMaterial:
			var mat := m.material_override as ShaderMaterial
			check(mat.render_priority == -1, "Occluder material has render_priority -1")

	# Verify wall and room meshes have occluder material applied
	var wall_mesh := rooms_occluder.find_child("MeshInstance3D", true, false) as GeometryInstance3D
	check(is_instance_valid(wall_mesh) and wall_mesh.material_override is ShaderMaterial, "Wall mesh has occluder ShaderMaterial")

	var baked_wall := rooms_occluder.find_child("CSGBakedMeshInstance3D", true, false) as GeometryInstance3D
	check(is_instance_valid(baked_wall) and baked_wall.material_override is ShaderMaterial, "Doorway wall has occluder ShaderMaterial")

	# Verify door copy surfaces are transparent with render_priority 0
	var door_meshes := door_copy.find_children("*", "MeshInstance3D", true, false)
	check(not door_meshes.is_empty(), "DoorColorCopy has mesh instances")
	for dm: MeshInstance3D in door_meshes:
		for s in range(dm.get_surface_override_material_count()):
			var smat := dm.get_surface_override_material(s)
			if smat is BaseMaterial3D:
				check(smat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Door surface %d is alpha transparent" % s)
				check(smat.render_priority == 0, "Door surface %d has render_priority 0" % s)

	# Verify transform syncing from live FloatingBed to occluder copy
	var live_bed := tutorial.get_node_or_null("TutorialRooms/FloatingBed") as Node3D
	check(is_instance_valid(live_bed), "Live FloatingBed exists")
	live_bed.position.y = 2.5
	tutorial.call("_sync_color_pass")
	check(is_equal_approx(bed_occluder.position.y, 2.5), "FloatingBed occluder position Y syncs with live bed (2.5m)")

	live_bed.position.y = 1.1
	tutorial.call("_sync_color_pass")
	check(is_equal_approx(bed_occluder.position.y, 1.1), "FloatingBed occluder position Y syncs with live bed (1.1m)")

	tutorial.queue_free()
	await process_frame

	quit(1 if failures > 0 else 0)
