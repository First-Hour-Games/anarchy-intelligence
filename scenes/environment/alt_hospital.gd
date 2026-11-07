extends Node3D
## The alt route's hospital (map_alt.tscn): four storeys and a helipad, in place of the old hospital, which the
## main map keeps. The model and its markers come from tools/blender/build_alt_hospital.py (the plan is in
## tools/blender/alt_hospital/plan.py). This makes it playable:
## - collision on everything but its Decor_ meshes, with footstep surfaces: tile inside, concrete on the roof
##   and the path to the door; the Blocker_ boxes (in the heap where stair B fell in) are collision only;
## - each storey is drawn on its own render layer (13 to 16) and its lights light only that layer, so no light
##   shines through a floor or a wall onto the storey above or below, and the town's lights outside are kept
##   off its insides and leave them out of their shadows;
## - each storey's furniture (its Decor_ mesh) has a layer of its own as well (5 to 8), lit by that storey's
##   lights as its walls are, but left out of the moon's shadows: the moon reaches in only through the windows,
##   so this saves drawing the furniture into its four shadow cascades. Inside the building, only the furniture
##   of your own storey and the storeys just above and below it is drawn; from outside, all of it;
## - textures on the plain colours: plaster on the walls (each floor's colour tints it), tiles on the drop
##   ceilings, bare concrete (from tools/make_alt_hospital_textures.gd); stains projected where the markers
##   put them: blood, a handprint, water damage, grime along the corridors' walls;
## - the hiding spots, bottles and lights from the markers, and the rescue helicopter on the helipad;
## - the places the story asks for: document_point() (as the old hospital answers it), point(), storey_at(),
##   clawman_post().

const MARKERS := "res://models/buildings/alt_hospital/alt_hospital_markers.json"
const TEXTURES := "res://img/textures/alt_hospital/"
const PLASTER := TEXTURES + "plaster.png"
const CONCRETE := "res://assets/local_licensed/materials/concrete034/Concrete034_Color.jpg"
## Materials given a texture: its path, the metres one copy of it covers, and how much to brighten the colour
## so the texture's own shading keeps it as light as before.
const SURFACES := {
	"Interior_WallUpper": [PLASTER, 2.4, 1.1],
	"Interior_DadoBlue": [PLASTER, 2.4, 1.1],
	"Interior_DadoGreen": [PLASTER, 2.4, 1.1],
	"Interior_DadoTeal": [PLASTER, 2.4, 1.1],
	"Interior_DadoOchre": [PLASTER, 2.4, 1.1],
	"Interior_ExteriorRender": [PLASTER, 3.5, 1.05],
	"Interior_Ceiling": [TEXTURES + "ceiling_tiles.png", 1.2, 1.15],
	"Interior_CeilingTile": [TEXTURES + "ceiling_tiles.png", 1.2, 1.15],
	"Interior_FloorConcrete": [CONCRETE, 2.5, 1.6],
	"Interior_Concrete": [CONCRETE, 2.0, 1.6],
}
## Each kind of stain: its texture and colour.
const DECALS := {
	"blood_pool": ["res://img/textures/gore/blood_pool.png", Color(0.3, 0.025, 0.018)],
	"blood_smear": ["res://img/textures/gore/blood_smear.png", Color(0.36, 0.03, 0.02)],
	"blood_spatter": ["res://img/textures/gore/blood_spatter.png", Color(0.36, 0.03, 0.02)],
	"handprint": [TEXTURES + "handprint.png", Color(0.34, 0.03, 0.02)],
	"water_stain": [TEXTURES + "water_stain.png", Color(1.0, 1.0, 1.0, 0.85)],
	"grime": [TEXTURES + "grime.png", Color(0.1, 0.085, 0.07, 0.75)],
}
const HOSPITAL_LIGHT := preload("res://scenes/environment/hospital_light.gd")
const LIGHT_MODES := {"steady": 0, "flicker": 1, "strobe": 2, "dying": 3, "noise": 4, "pulse": 5}
const HIDING_KINDS := {"locker": HidingSpot.Kind.LOCKER, "closet": HidingSpot.Kind.CLOSET, "bed": HidingSpot.Kind.UNDER_BED}
## Render layers 13 to 16, one a storey.
const STOREY_LAYERS: Array[int] = [1 << 12, 1 << 13, 1 << 14, 1 << 15]
const ALL_STOREYS := (1 << 12) | (1 << 13) | (1 << 14) | (1 << 15)
## Render layers 5 to 8, one a storey, for its furniture.
const DECOR_LAYERS: Array[int] = [1 << 4, 1 << 5, 1 << 6, 1 << 7]
const ALL_DECOR := (1 << 4) | (1 << 5) | (1 << 6) | (1 << 7)
## How often, in seconds, the furniture shown is matched to the player's storey.
const FURNITURE_CHECK := 0.25
## Floor finishes drawn as tiled vinyl.
const TILED_FLOORS := ["Interior_FloorBeige", "Interior_FloorTerrazzo", "Interior_FloorGreen", "Interior_FloorGreenDark",
	"Interior_FloorLightGrey", "Interior_FloorSafety"]
## Stains further off than this fade out.
const DECAL_DISTANCE := 28.0

var markers: Dictionary = {}
var helicopter: Node3D
## Each storey's furniture meshes.
var _furniture: Array = [[], [], [], []]
## The storey the furniture is shown for (-1 outside), or -2 before the first check.
var _furniture_for := -2
var _furniture_check := 0.0


func _ready() -> void:
	markers = load_markers()
	_finish_meshes()
	for spot: Dictionary in markers.hiding_spots:
		_hiding_spot(spot)
	for bottle: Dictionary in markers.bottles:
		_bottle(bottle)
	for light: Dictionary in markers.lights:
		_light(light)
	var decals: Array = markers.decals
	for index in decals.size():
		_decal(decals[index], index)
	helicopter = get_node_or_null("Helicopter") as Node3D
	if helicopter != null:
		var heli: Dictionary = markers.helicopter
		helicopter.position = _vector(heli.position)
		helicopter.rotation.y = deg_to_rad(float(heli.yaw))
	_keep_outside_lights_out.call_deferred()
	_keep_furniture_out_of_moon_shadows.call_deferred()
	# Lamps the town builds later (the neighbourhood's street lamps come in a deferred rebuild) are kept out too.
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	_furniture_check -= delta
	if _furniture_check > 0.0:
		return
	_furniture_check = FURNITURE_CHECK
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	show_furniture_for(storey_at(player.global_position) if player != null else -1)


## Draws the furniture of `storey` (0 to 3, 4 the roof) and of the storeys just above and below it, and hides the
## rest: no window, door or stairwell shows further. Outside (-1), all of it shows through the windows.
func show_furniture_for(storey: int) -> void:
	if storey == _furniture_for:
		return
	_furniture_for = storey
	for level in _furniture.size():
		var shown := storey < 0 or absi(level - mini(storey, _furniture.size() - 1)) <= 1
		for mesh: MeshInstance3D in _furniture[level]:
			mesh.visible = shown


static func load_markers() -> Dictionary:
	return (load(MARKERS) as JSON).data


static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


## Storey of a mesh from its name's _L<n> suffix, or -1 for the outside (Exterior, RoofFloor, EntranceWalk).
static func mesh_storey(mesh_name: String) -> int:
	var at := mesh_name.rfind("_L")
	if at < 0:
		return -1
	return int(mesh_name.substr(at + 2))


func _finish_meshes() -> void:
	var finishes: Dictionary = {}
	for node: Node in $Source.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var title := str(mesh.name)
		var storey := mesh_storey(title)
		# Storeys on their own layer, their furniture on its own; the outside on the default one, which the world
		# map's camera draws.
		if storey < 0:
			mesh.layers = 1
		elif title.begins_with("Decor_"):
			mesh.layers = DECOR_LAYERS[storey]
			_furniture[storey].append(mesh)
		else:
			mesh.layers = STOREY_LAYERS[storey]
		for index in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(index) as BaseMaterial3D
			if original == null:
				continue
			var key := original.get_instance_id()
			if not finishes.has(key):
				finishes[key] = _finish(original)
			mesh.set_surface_override_material(index, finishes[key])
		if title.begins_with("Decor_"):
			continue
		mesh.create_trimesh_collision()
		var body := mesh.get_child(mesh.get_child_count() - 1) as StaticBody3D
		if body == null:
			continue
		body.name = title + "_Collision"
		if title.begins_with("GroundFloor_"):
			body.set_meta("surface", "tile")
		elif title == "RoofFloor" or title == "EntranceWalk":
			body.set_meta("surface", "concrete")
		elif title.begins_with("Blocker_"):
			# The heap's rubble is drawn by Decor_; its box only stops you (and, baked, the Clawman).
			mesh.visible = false


## Imported materials render both faces; floor finishes become tiled vinyl; walls, ceilings and concrete get
## their textures, laid on in the building's own space so they line up from one mesh to the next.
func _finish(original: BaseMaterial3D) -> Material:
	if original.resource_name in TILED_FLOORS:
		var vinyl := ShaderMaterial.new()
		vinyl.shader = preload("res://shaders/hospital_floor.gdshader")
		vinyl.set_shader_parameter("tint", original.albedo_color)
		return vinyl
	var finish := original.duplicate() as BaseMaterial3D
	finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	if SURFACES.has(original.resource_name):
		var surface: Array = SURFACES[original.resource_name]
		finish.albedo_texture = load(str(surface[0])) as Texture2D
		var tint := original.albedo_color * float(surface[2])
		finish.albedo_color = Color(minf(tint.r, 1.0), minf(tint.g, 1.0), minf(tint.b, 1.0))
		finish.uv1_triplanar = true
		finish.uv1_triplanar_sharpness = 4.0
		finish.uv1_scale = Vector3.ONE / float(surface[1])
	return finish


## A stain from the markers, on its storey's layers only (walls and furniture; never on the player or the
## Clawman). On the floor
## it is projected down, its texture's top along its yaw; on a wall it is projected back into the wall, its
## texture's top up.
func _decal(data: Dictionary, index: int) -> void:
	var kind := str(data.kind)
	var look: Array = DECALS[kind]
	var mark := Decal.new()
	mark.name = "Stain%d_%s" % [index, kind]
	mark.texture_albedo = load(str(look[0])) as Texture2D
	mark.modulate = look[1]
	mark.normal_fade = 0.4
	mark.cull_mask = STOREY_LAYERS[int(data.level)] | DECOR_LAYERS[int(data.level)]
	mark.distance_fade_enabled = true
	mark.distance_fade_begin = DECAL_DISTANCE
	mark.distance_fade_length = 6.0
	var size: Array = data.size
	var at := _vector(data.position)
	if data.facing is String:
		mark.size = Vector3(float(size[0]), 0.6, float(size[1]))
		mark.upper_fade = 0.3
		mark.lower_fade = 0.3
		mark.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(data.yaw))), at)
	else:
		var normal := _vector(data.facing).normalized()
		mark.size = Vector3(float(size[0]), 0.24, float(size[1]))
		mark.transform = Transform3D(Basis(normal.cross(Vector3.DOWN), normal, Vector3.DOWN), at)
	add_child(mark)


func _hiding_spot(data: Dictionary) -> void:
	var spot := HidingSpot.new()
	spot.name = str(data.name)
	spot.kind = HIDING_KINDS[str(data.kind)]
	spot.position = _vector(data.position)
	spot.rotation.y = deg_to_rad(float(data.yaw))
	add_child(spot, true)
	_set_storey_layer(spot, int(data.level))


func _bottle(data: Dictionary) -> void:
	var bottle := BottlePickup.new()
	bottle.name = str(data.name)
	bottle.position = _vector(data.position)
	add_child(bottle, true)
	_set_storey_layer(bottle, int(data.level))


## Spawned things draw on their storey's layer (so its lights reach them) and on the default one.
func _set_storey_layer(root: Node, storey: int) -> void:
	for node: Node in root.find_children("*", "VisualInstance3D", true, false):
		(node as VisualInstance3D).layers = 1 | STOREY_LAYERS[storey]


func _light(data: Dictionary) -> void:
	var light := OmniLight3D.new()
	light.name = str(data.name)
	light.omni_range = float(data.range)
	light.set_script(HOSPITAL_LIGHT)
	light.set("mode", LIGHT_MODES[str(data.mode)])
	var color: Array = data.color
	light.light_color = Color(float(color[0]), float(color[1]), float(color[2]))
	light.light_energy = float(data.energy)
	# Only its own storey and its furniture, and whatever moves about in it (the default layer).
	light.light_cull_mask = STOREY_LAYERS[int(data.level)] | DECOR_LAYERS[int(data.level)] | 1
	light.add_to_group("ridgeback_repellent")
	add_child(light)
	light.position = _vector(data.position)


## The town's lamps outside are kept off the building's insides: its storeys' and furniture's layers are left out
## of what they light and out of their shadows. Near the building most have no shadows to stop them at its walls;
## from further off they reach in only faintly through the windows, while drawing the storeys into a lamp's
## shadow costs as much as drawing them (a parked car's lamps 45 m from it drew the storeys into theirs).
func _keep_outside_lights_out() -> void:
	var map := _map()
	if map == null:
		return
	for node: Node in map.find_children("*", "Light3D", true, false):
		_keep_light_out(node as Light3D)


func _on_node_added(node: Node) -> void:
	if node is Light3D:
		# After the lamp's own scene has set it up.
		_keep_light_out_id.call_deferred(node.get_instance_id())


func _keep_light_out_id(id: int) -> void:
	if is_instance_id_valid(id):
		_keep_light_out(instance_from_id(id) as Light3D)


## One lamp of the map kept off the insides, unless it is the building's own, the moon or the player's flashlight.
func _keep_light_out(light: Light3D) -> void:
	if light == null or light is DirectionalLight3D or not is_inside_tree() or not light.is_inside_tree() or is_ancestor_of(light):
		return
	var map := _map()
	var player := get_tree().get_first_node_in_group("player") as Node
	if map == null or not map.is_ancestor_of(light) or (player != null and player.is_ancestor_of(light)):
		return
	light.light_cull_mask &= ~(ALL_STOREYS | ALL_DECOR)
	light.shadow_caster_mask &= ~(ALL_STOREYS | ALL_DECOR)


## The map this building stands in: the scene under the tree's root.
func _map() -> Node:
	var map := get_parent()
	while map != null and map.get_parent() != get_tree().root:
		map = map.get_parent()
	return map


## The moon leaves the furniture out of its shadows (see the top of this file). Its walls and floors still cast
## them, so no moonlight comes in anywhere but through the windows.
func _keep_furniture_out_of_moon_shadows() -> void:
	var map := get_parent()
	while map != null and map.get_parent() != get_tree().root:
		map = map.get_parent()
	if map == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node
	for node: Node in map.find_children("*", "DirectionalLight3D", true, false):
		if player == null or not player.is_ancestor_of(node):
			(node as DirectionalLight3D).shadow_caster_mask &= ~ALL_DECOR


## Building-local resting point of a story document (register, evacuation, supply, flight).
func document_point(id: StringName) -> Vector3:
	return _vector(markers.documents[str(id)])


## A named place, building-local: entrance, lobby, roof_door, helipad, landing_A0..landing_B3.
func local_point(id: StringName) -> Vector3:
	return _vector(markers.points[str(id)])


func point(id: StringName) -> Vector3:
	return to_global(local_point(id))


## The storey a world position is on: 0 to 3 inside, 4 on the roof, -1 outside the building.
func storey_at(world: Vector3) -> int:
	var local := to_local(world)
	var footprint: Array = markers.footprint
	if local.x < float(footprint[0]) or local.x > float(footprint[1]) or local.z < float(footprint[2]) or local.z > float(footprint[3]):
		return -1
	if local.y >= float(markers.roof_y) - 0.5:
		return 4
	var levels: Array = markers.levels
	var storey := 0
	for index in levels.size():
		if local.y >= float(levels[index]) - 0.6:
			storey = index
	return storey


## Where the Clawman waits on a storey, facing along the corridor toward where you come in.
func clawman_post(storey: int) -> Transform3D:
	var posts: Dictionary = markers.clawman_posts
	var local := _vector(posts[str(storey)])
	var facing := Vector3(signf(-local.x), 0.0, 0.0)
	return global_transform * Transform3D(Basis.looking_at(facing), local)
