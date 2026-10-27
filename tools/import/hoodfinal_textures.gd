@tool
extends EditorScenePostImport
## Based on the user-supplied hoodfinalTEXTURES.gd.
## Assigned to hood.Final.glb and all twelve exported neighborhood lots.
##
## Set it on the .glb: select the file in the FileSystem dock -> Import tab ->
## Import Script > Path = this file -> Reimport.
##
## What it does to every mesh in the scene:
##   * turns on triplanar mapping (the Blender meshes have no UV maps, triplanar
##     needs none and suits the boxy houses/curbs/roads)
##   * if a texture folder exists for the material (see RULES), loads its
##     albedo / normal / roughness maps and sets the tile size in meters
##   * adds the shared warm exterior light at each modeled Lamp_Glow bulb
##   * adds optimized static boxes for closed buildings, fences, steps and lawn
##
## Textures are optional: without them every surface keeps its Blender color.
## Put CC0 textures (ambientCG.com or polyhaven.com, 1K is plenty) in
##   res://textures/<folder>/  e.g. res://textures/siding/Siding_Color.jpg
## File names are matched loosely: *color* / *albedo* / *diff*  -> albedo,
## *normalgl* / *nor_gl* / *normal* -> normal, *rough* -> roughness.
## After adding textures, reimport the .glb so they get applied.

const TEX_ROOT := "res://textures"
const BOX_COLLISIONS = preload("res://tools/import/neighborhood_box_collisions.gd")
const TRIPLANAR_SHARPNESS := 4.0
const EXTERIOR_LIGHT := preload("res://scenes/environment/house_exterior_light.tscn")

# Prefer res://textures/<folder>/ when supplied. Otherwise reuse project assets.
# No texture files are copied or downloaded by this importer.
const PROJECT_MAPS := {
	"siding": {"albedo": "res://assets/local_licensed/house/Textures/WoodPlanks.jpg"},
	"roof_shingles": {"albedo": "res://assets/local_licensed/house/Textures/RooftilesSlate.jpg"},
	"concrete_aggregate": {
		"albedo": "res://assets/local_licensed/materials/concrete034/Concrete034_Color.jpg",
		"normal": "res://assets/local_licensed/materials/concrete034/Concrete034_NormalGL.jpg",
		"roughness": "res://assets/local_licensed/materials/concrete034/Concrete034_Roughness.jpg",
	},
	"concrete": {
		"albedo": "res://assets/local_licensed/materials/concrete012/Concrete012_Color.jpg",
		"normal": "res://assets/local_licensed/materials/concrete012/Concrete012_NormalGL.jpg",
		"roughness": "res://assets/local_licensed/materials/concrete012/Concrete012_Roughness.jpg",
	},
	"asphalt": {
		"albedo": "res://img/materials/asphalt/Road013A_1K-JPG_Color.jpg",
		"normal": "res://img/materials/asphalt/Road013A_1K-JPG_NormalGL.jpg",
		"roughness": "res://img/materials/asphalt/Road013A_1K-JPG_Roughness.jpg",
	},
	"grass": {"albedo": "res://assets/local_licensed/house/Textures/Grass.jpg"},
	"soil": {
		"albedo": "res://img/materials/dirtRoad/dry_mud_field_001_diff_1k.jpg",
		"normal": "res://img/materials/dirtRoad/dry_mud_field_001_nor_gl_1k.jpg",
		"roughness": "res://img/materials/dirtRoad/dry_mud_field_001_rough_1k.jpg",
	},
	"wood_planks": {"albedo": "res://assets/local_licensed/house/Textures/WoodPlanks_01.jpg"},
	"brick": {"albedo": "res://assets/local_licensed/house/Textures/BrickSmallBrown.jpg"},
	"stone": {"albedo": "res://assets/local_licensed/house/Textures/Rock.jpg"},
}

# [Blender material name prefix, texture folder, meters per texture tile, keep Blender color as tint?]
# First match wins, so more specific prefixes come first.
const RULES := [
	["Siding_", "siding", 1.5, true],                 # use a white / light painted siding texture
	["Roof_Shingle_", "roof_shingles", 2.0, true],
	["Concrete_Driveway", "concrete_aggregate", 3.0, false],
	["Concrete_Joint", "", 1.0, true],                # thin dark lines: keep flat color
	["Concrete_", "concrete", 3.0, false],
	["Foundation_Concrete", "concrete", 3.0, true],
	["Asphalt_", "asphalt", 4.0, false],
	["Lawn_", "grass", 3.0, false],
	["Ground_Soil", "soil", 3.0, false],
	["Cedar_", "wood_planks", 2.0, false],
	["Door_Stained_Wood", "wood_planks", 1.0, true],
	["Brick_", "brick", 1.5, false],
	["Stone_", "stone", 1.5, false],
]

var _done := {}
var _maps_cache := {}
var _scene_root: Node


func _post_import(scene: Node) -> Object:
	_done.clear()
	_maps_cache.clear()
	_scene_root = scene
	_walk(scene)
	_done.clear()
	_scene_root = null
	return scene


func _walk(n: Node) -> void:
	if n is MeshInstance3D and n.mesh != null:
		var mesh: Mesh = n.mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m is BaseMaterial3D and not _done.has(m):
				_done[m] = true
				_setup_material(m)
		_add_fixture_lights(n)
		BOX_COLLISIONS.add_to_mesh(n, _scene_root)
	for c in n.get_children():
		if c is StaticBody3D:
			continue
		_walk(c)


func _add_fixture_lights(instance: MeshInstance3D) -> void:
	# Lamp_Glow combines several separate bulbs into one surface. Place one light
	# at each connected bulb rather than at the center of the whole garage mesh.
	for surface in instance.mesh.get_surface_count():
		var material := instance.mesh.surface_get_material(surface)
		if material == null or material.resource_name != "Lamp_Glow":
			continue
		var arrays := instance.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var fixtures := _fixture_bounds(vertices)
		for index in fixtures.size():
			var light_name := "ExteriorLight%d" % (index + 1)
			if instance.has_node(NodePath(light_name)):
				continue
			var bounds: AABB = fixtures[index]
			var center := bounds.get_center()
			# Move just beyond the bulb's thin face so the opaque bulb geometry
			# does not shadow its own light. Choose the face away from the building.
			var axis := bounds.size.min_axis_index()
			var direction := 1.0 if center[axis] >= instance.mesh.get_aabb().get_center()[axis] else -1.0
			center[axis] += direction * (bounds.size[axis] * 0.5 + 0.12)
			var light := EXTERIOR_LIGHT.instantiate() as OmniLight3D
			light.name = light_name
			light.position = center
			instance.add_child(light)
			light.owner = _scene_root


func _fixture_bounds(vertices: PackedVector3Array) -> Array[AABB]:
	var result: Array[AABB] = []
	var remaining := Array(vertices)
	while not remaining.is_empty():
		var seed: Vector3 = remaining.pop_back()
		var bounds := AABB(seed, Vector3.ZERO)
		var pending: Array[Vector3] = [seed]
		while not pending.is_empty():
			var point: Vector3 = pending.pop_back()
			for index in range(remaining.size() - 1, -1, -1):
				var candidate: Vector3 = remaining[index]
				if point.distance_squared_to(candidate) <= 0.09:
					bounds = bounds.expand(candidate)
					pending.append(candidate)
					remaining.remove_at(index)
		result.append(bounds)
	return result


func _setup_material(m: BaseMaterial3D) -> void:
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = TRIPLANAR_SHARPNESS
	var mat_name := m.resource_name
	for r in RULES:
		if not mat_name.begins_with(r[0]):
			continue
		if r[1] == "":
			return
		var folder := String(r[1])
		if not _maps_cache.has(folder):
			var custom := _find_maps(TEX_ROOT + "/" + folder)
			# Keep custom sets together; do not mix their normals with fallback maps.
			_maps_cache[folder] = custom if not custom.is_empty() else PROJECT_MAPS.get(folder, {})
		var maps: Dictionary = _maps_cache[folder]
		if maps.has("albedo"):
			m.albedo_texture = load(maps["albedo"])
			if not r[3]:
				m.albedo_color = Color.WHITE  # the texture already has the color
		if maps.has("normal"):
			m.normal_enabled = true
			m.normal_texture = load(maps["normal"])
		if maps.has("roughness"):
			m.roughness_texture = load(maps["roughness"])
			m.roughness = 1.0
		m.uv1_scale = Vector3.ONE / float(r[2])
		return


func _find_maps(dir: String) -> Dictionary:
	var out := {}
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		var low := f.to_lower()
		if low.ends_with(".import"):
			continue
		if not (low.ends_with(".png") or low.ends_with(".jpg") or low.ends_with(".jpeg") or low.ends_with(".webp")):
			continue
		var path := dir + "/" + f
		if "normaldx" in low or "nor_dx" in low:
			continue                          # Godot wants OpenGL-style (GL) normal maps
		if not out.has("albedo") and ("color" in low or "albedo" in low or "diff" in low):
			out["albedo"] = path
		elif not out.has("normal") and ("normal" in low or "nor_gl" in low):
			out["normal"] = path
		elif not out.has("roughness") and "rough" in low:
			out["roughness"] = path
	return out
