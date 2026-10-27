extends SceneTree

const IMPORTER = preload("res://tools/import/hoodfinal_textures.gd")
const SOURCE := "res://scenes/chapters/main/hood.Final.glb"
const LOTS := "res://models/buildings/neighborhood_lots"
var failures := 0
var textured_surfaces := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func audit(path: String, original_materials: Dictionary) -> void:
	var settings := ConfigFile.new()
	check(settings.load(path + ".import") == OK, "Missing import settings: " + path)
	check(settings.get_value("params", "import_script/path", "") == "res://tools/import/hoodfinal_textures.gd", "Importer not assigned: " + path)
	var packed := load(path) as PackedScene
	check(packed != null, "GLB did not import: " + path)
	if packed == null:
		return
	var scene := packed.instantiate()
	var local_textured := 0
	for instance in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in instance.mesh.get_surface_count():
			var material: BaseMaterial3D = instance.mesh.surface_get_material(surface)
			check(material != null and material.uv1_triplanar, "Triplanar mapping missing: " + instance.name)
			for rule in IMPORTER.RULES:
				if not material.resource_name.begins_with(rule[0]):
					continue
				if rule[1] == "":
					check(material.albedo_texture == null, "Concrete joints should stay flat")
					break
				var maps: Dictionary = IMPORTER.PROJECT_MAPS[rule[1]]
				check(material.albedo_texture != null and material.albedo_texture.resource_path == maps["albedo"], "Albedo missing or wrong: " + material.resource_name)
				check(material.uv1_scale.is_equal_approx(Vector3.ONE / float(rule[2])), "Incorrect texture scale: " + material.resource_name)
				if maps.has("normal"):
					check(material.normal_enabled and material.normal_texture != null and material.normal_texture.resource_path == maps["normal"], "Normal map missing: " + material.resource_name)
				if maps.has("roughness"):
					check(material.roughness_texture != null and material.roughness_texture.resource_path == maps["roughness"], "Roughness map missing: " + material.resource_name)
				var original: BaseMaterial3D = original_materials[material.resource_name]
				var tint: Color = original.albedo_color if rule[3] else Color.WHITE
				check(material.albedo_color.is_equal_approx(tint), "Authored tint not preserved: " + material.resource_name)
				local_textured += 1
				break
	check(local_textured > 0, "No textured surfaces in: " + path)
	for collider in scene.find_children("*", "CollisionShape3D", true, false):
		check(collider.shape is BoxShape3D, "Neighborhood collision must use simple boxes")
	textured_surfaces += local_textured
	print("Checked ", path.get_file(), ": ", local_textured, " textured surfaces")
	scene.free()

func run() -> void:
	# Read the original GLB without its Godot post-import settings to check tint preservation.
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	check(document.append_from_file(SOURCE, state) == OK, "Cannot read original GLB")
	var original := document.generate_scene(state)
	var original_materials := {}
	for instance in original.find_children("*", "MeshInstance3D", true, false):
		for surface in instance.mesh.get_surface_count():
			var material: BaseMaterial3D = instance.mesh.surface_get_material(surface)
			original_materials[material.resource_name] = material
	audit(SOURCE, original_materials)
	var count := 0
	for file in DirAccess.get_files_at(LOTS):
		if file.ends_with(".glb"):
			audit(LOTS + "/" + file, original_materials)
			count += 1
	check(count == 12, "Expected twelve lot GLBs")
	original.free()
	print("Neighborhood textures: ", count + 1, " assets, ", textured_surfaces, " textured surfaces, ", failures, " failures")
	quit(0 if failures == 0 else 1)
