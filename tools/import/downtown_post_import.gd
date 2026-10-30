@tool
extends EditorScenePostImport

## Finishes models/buildings/downtown/downtown.gltf as Godot imports it, from the markers that
## tools/blender/prepare_downtown.py writes beside it. Everything is saved in the imported scene,
## so nothing is built when the map loads:
## - Collision: one static body (footsteps sound like concrete) with a box per building, step,
##   pole, fence and sidewalk;
## - Occluders: a box inside each building, so the street wall hides what stands behind it;
## - Signs: the lettering as Label3D in the project's condensed face. Neon signs flicker together
##   with their lights (neon_lettering.gd); other lights and lettering stay steady;
## - the window shader on every *_Glass mesh, and a draw distance on every *_Details mesh;
## - SignalBlink, which flashes the traffic signal's lenses (blinking_signal.gd).

const MARKERS := "res://models/buildings/downtown/downtown_markers.json"
const GLASS := "res://models/buildings/downtown/window_glass.tres"
const FONT := "res://fonts/HelveticaNeueCondensed.ttf"
const NEON := "res://scenes/environment/neon_lettering.gd"
const SIGNAL := "res://scenes/environment/blinking_signal.gd"
const DETAIL_RANGE := 90.0
## Painted and carved lettering stops drawing this far away; neon and roof signs show as far as
## the fog allows.
const SIGN_RANGE := 70.0
const FONT_SIZE := 64
## Capital height of the face as a share of its size.
const CAP_HEIGHT := 0.72


func _post_import(scene: Node) -> Object:
	var markers: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MARKERS))
	var glass := load(GLASS) as Material
	for mesh_name: String in markers.objects.glass:
		var mesh := scene.get_node_or_null(mesh_name) as MeshInstance3D
		if mesh != null:
			mesh.material_override = glass
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mesh_name: String in markers.objects.details:
		var mesh := scene.get_node_or_null(mesh_name) as MeshInstance3D
		if mesh != null:
			mesh.visibility_range_end = DETAIL_RANGE
			mesh.visibility_range_end_margin = 10.0
			mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_add_collision(scene, markers.colliders)
	_add_occluders(scene, markers.occluders)
	_add_signs(scene, markers.signs, markers.lights)
	_add_signal(scene, markers.signal)
	return scene


func _own(node: Node, parent: Node, scene: Node) -> void:
	parent.add_child(node, true)
	node.owner = scene


func _add_collision(scene: Node, colliders: Array) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.set_meta("surface", "concrete")
	_own(body, scene, scene)
	for collider: Dictionary in colliders:
		var shape := CollisionShape3D.new()
		shape.name = String(collider.name)
		var box := BoxShape3D.new()
		box.size = _vector(collider.size)
		shape.shape = box
		shape.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(collider.yaw))), _vector(collider.centre))
		_own(shape, body, scene)


func _add_occluders(scene: Node, occluders: Array) -> void:
	var holder := Node3D.new()
	holder.name = "Occluders"
	_own(holder, scene, scene)
	for marker: Dictionary in occluders:
		var occluder := OccluderInstance3D.new()
		occluder.name = String(marker.name)
		var box := BoxOccluder3D.new()
		box.size = _vector(marker.size)
		occluder.occluder = box
		occluder.position = _vector(marker.centre)
		_own(occluder, holder, scene)


func _add_signs(scene: Node, signs: Array, lights: Array) -> void:
	var font := load(FONT) as Font
	var holder := Node3D.new()
	holder.name = "Signs"
	_own(holder, scene, scene)
	var groups := {}
	for sign: Dictionary in signs:
		var group := _group(holder, groups, String(sign.building), String(sign.style) == "neon", scene)
		var dead := int(sign.get("dead_letter", -1))
		var text := String(sign.text)
		if dead >= 0 and dead < text.length():
			_split_label(group, sign, font, text, dead, scene)
		else:
			_own(_label(text, sign, font), group, scene)
	for marker: Dictionary in lights:
		var light := OmniLight3D.new()
		light.name = "Light"
		light.position = _vector(marker.position)
		light.light_color = Color(marker.colour[0], marker.colour[1], marker.colour[2])
		light.light_energy = float(marker.energy)
		light.omni_range = float(marker.range)
		light.shadow_enabled = false
		_own(light, _group(holder, groups, String(marker.building), String(marker.group) == "neon", scene), scene)


## The node a building's signs and lights go under; neon ones get their own, which flickers.
func _group(holder: Node3D, groups: Dictionary, building: String, neon: bool, scene: Node) -> Node3D:
	var key := building + ("Neon" if neon else "")
	if not groups.has(key):
		var group := Node3D.new()
		group.name = key
		if neon:
			group.set_script(load(NEON))
		_own(group, holder, scene)
		groups[key] = group
	return groups[key]


func _label(text: String, sign: Dictionary, font: Font) -> Label3D:
	var label := Label3D.new()
	label.name = "Lettering"
	label.text = text
	label.font = font
	label.font_size = FONT_SIZE
	label.pixel_size = float(sign.height) / (CAP_HEIGHT * FONT_SIZE)
	var lines := text.split("\n")
	if lines.size() > 1:
		# Stacked letters (a blade sign): close the lines up to the pitch the sign was drawn with.
		label.line_spacing = float(sign.get("pitch", float(sign.height) * 1.3)) / label.pixel_size - font.get_height(FONT_SIZE)
	var widest := 0.0
	for line in lines:
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	if widest * label.pixel_size > float(sign.width):
		label.pixel_size *= float(sign.width) / (widest * label.pixel_size)
	var colour := Color(sign.colour[0], sign.colour[1], sign.colour[2])
	label.modulate = colour
	label.double_sided = false
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	match String(sign.style):
		"neon":
			label.shaded = false
			label.modulate = Color(colour.r * 1.5, colour.g * 1.5, colour.b * 1.5)
			label.outline_size = 10
			label.outline_modulate = Color(colour.r * 0.35, colour.g * 0.35, colour.b * 0.35)
		"marquee":
			label.shaded = false
			label.visibility_range_end = SIGN_RANGE + 20.0
		"ghost":
			label.shaded = true
			label.alpha_cut = Label3D.ALPHA_CUT_DISABLED
			label.modulate = Color(colour.r, colour.g, colour.b, 0.38)
		_:
			label.shaded = true
			label.visibility_range_end = SIGN_RANGE
	var facing := _vector(sign.facing)
	label.transform = Transform3D(Basis.looking_at(-facing, Vector3.UP), _vector(sign.position))
	return label


## A sign with one dead letter: the letters before and after it lit, the dead one dark, laid out
## as the whole word would be.
func _split_label(group: Node3D, sign: Dictionary, font: Font, text: String, dead: int, scene: Node) -> void:
	var whole := _label(text, sign, font)
	var size := whole.pixel_size
	var basis := whole.transform.basis
	var origin := whole.transform.origin
	whole.free()
	var parts := [text.substr(0, dead), text.substr(dead, 1), text.substr(dead + 1)]
	var total := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x * size
	var x := -total / 2.0
	for i in parts.size():
		if parts[i].is_empty():
			continue
		var label := _label(parts[i], sign, font)
		label.pixel_size = size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.transform = Transform3D(basis, origin + basis * Vector3(x, 0.0, 0.0))
		if i == 1:
			label.name = "DeadLetter"
			label.shaded = true
			label.outline_size = 0
			label.modulate = Color(0.22, 0.2, 0.17)
		_own(label, group, scene)
		x += font.get_string_size(parts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x * size


func _add_signal(scene: Node, marker: Dictionary) -> void:
	var blink := Node3D.new()
	blink.name = "SignalBlink"
	blink.set_script(load(SIGNAL))
	_own(blink, scene, scene)
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.position = _vector(marker.head)
	glow.light_color = Color(1.0, 0.62, 0.12)
	glow.omni_range = 9.0
	glow.shadow_enabled = false
	_own(glow, blink, scene)
	var lenses: Array[NodePath] = [NodePath("../" + String(marker.amber)), NodePath("../" + String(marker.red))]
	blink.set("lenses", lenses)
	blink.set("glow", NodePath("Glow"))


static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
