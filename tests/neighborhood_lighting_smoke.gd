extends SceneTree

const LOTS := "res://models/buildings/neighborhood_lots"
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func audit_lot(lot: Node3D) -> int:
	var count := 0
	for fixture in lot.find_children("*", "OmniLight3D", true, false):
		count += 1
		var mesh := fixture.get_parent() as MeshInstance3D
		check(mesh != null, "Light must follow its fixture mesh")
		var matched := false
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.mesh.surface_get_material(surface)
			if material == null or material.resource_name != "Lamp_Glow":
				continue
			var arrays := mesh.mesh.surface_get_arrays(surface)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				if fixture.position.distance_to(vertex) < 0.3:
					matched = true
		check(matched, "Light must sit beside an actual bulb: " + String(mesh.name))
		check(fixture.light_color.is_equal_approx(Color(1, 0.91, 0.78)), "Warm color must match existing station lighting")
		check(fixture.shadow_enabled and fixture.light_size > 0, "Fixture needs shadows and a finite source size")
		check(fixture.omni_range <= 8 and fixture.omni_attenuation == 2, "Residential lights need local range and fast falloff")
		check(fixture.distance_fade_enabled and fixture.distance_fade_shadow < fixture.distance_fade_begin, "Shadow work must fade before lighting")
		check(fixture.light_volumetric_fog_energy <= 0.25, "Fog illumination must stay subtle")
	# Every modeled bulb must have exactly one light near it, including detached garages.
	for mesh in lot.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.mesh.surface_get_material(surface)
			if material != null and material.resource_name == "Lamp_Glow":
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
					var nearby := 0
					for child in mesh.get_children():
						if child is OmniLight3D and child.position.distance_to(vertex) < 0.35:
							nearby += 1
					check(nearby == 1, "Every bulb needs exactly one nearby light")
	return count

func run() -> void:
	var full: Node3D = load("res://scenes/chapters/main/hood.Final.glb").instantiate()
	var full_count := audit_lot(full)
	var lot_count := 0
	var total := 0
	for file in DirAccess.get_files_at(LOTS):
		if not file.ends_with(".glb"):
			continue
		var lot: Node3D = load(LOTS + "/" + file).instantiate()
		var count := audit_lot(lot)
		check(count >= 4 and count <= 5, "Expected porch and garage fixtures: " + file)
		if count == 0:
			lot.free()
			continue
		root.add_child(lot)
		var light: OmniLight3D = lot.find_children("*", "OmniLight3D", true, false)[0]
		var local_position: Vector3 = light.global_position
		lot.position = Vector3(20, 1, 50)
		lot.rotation.y = PI * 0.5
		check(light.global_position.is_equal_approx(lot.global_transform * local_position), "Light must follow moved and rotated lot")
		var light_id := light.get_instance_id()
		lot.free()
		check(not is_instance_id_valid(light_id), "Unloading a lot must release its lights")
		total += count
		lot_count += 1
		print("Checked ", file, ": ", count, " fixture lights")
	check(lot_count == 12 and total == full_count and total == 52, "Full neighborhood and separate lots need the same 52 fixtures")
	full.free()
	print("Neighborhood lighting: ", lot_count, " lots, ", total, " lights, ", failures, " failures")
	quit(0 if failures == 0 else 1)
