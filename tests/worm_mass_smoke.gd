extends SceneTree
## The worm mass (scenes/monsters/worm_mass): its body is clumps of MultiMesh strands on anchor
## points, sharing one mesh and one shader, casting no shadows except through its one hidden proxy;
## density shares out without rebuilding; scouts slither free; the walk, the wall climb and the
## lunge run their course and come back to rest.

const WORM_SCENE := "res://scenes/monsters/worm_mass/worm_mass.tscn"

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func run() -> void:
	var worm: Node3D = (load(WORM_SCENE) as PackedScene).instantiate()
	root.add_child(worm)
	for i in 3:
		await physics_frame

	# The body: fifteen clumps on their anchors, one mesh and one material between them.
	var clumps: Array[Node] = worm.find_children("Clump", "MultiMeshInstance3D", true, false)
	check(clumps.size() == 15, "every anchor hangs a clump of strands (%d of 15)" % clumps.size())
	var first := clumps[0] as MultiMeshInstance3D
	var mesh := first.multimesh.mesh as ArrayMesh
	check(mesh != null and clumps.all(func(c: Node) -> bool: return (c as MultiMeshInstance3D).multimesh.mesh == mesh),
		"all clumps share the one strand mesh")
	var vertex_count: int = (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	check(vertex_count == 80, "the strand stays low poly (%d vertices)" % vertex_count)
	var material := mesh.surface_get_material(0) as ShaderMaterial
	check(material != null and material.shader != null, "the strand's writhe shader is on the mesh")
	# Per-instance values cannot be read back under the headless dummy renderer, so only the
	# format flag is checked here; the writhe variation is judged by eye in the captures.
	check(clumps.all(func(c: Node) -> bool: return (c as MultiMeshInstance3D).multimesh.use_custom_data),
		"every clump carries per-strand custom data")

	# Shadows: never the strands, always the one proxy.
	check(clumps.all(func(c: Node) -> bool: return (c as MultiMeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),
		"no clump casts shadows")
	var proxy := worm.find_children("ShadowProxy", "MeshInstance3D", true, false)
	check(proxy.size() == 1 and (proxy[0] as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,
		"one hidden capsule casts the body's shadow")

	# Density: shared out close to what was asked, within the buffers, without rebuilding.
	for wanted in [600, 300, 900]:
		worm.call("set_density", wanted)
		var shown := int(worm.call("strands_shown"))
		check(absi(shown - wanted) <= 12, "density %d shows %d strands" % [wanted, shown])
	var capacity_ok := true
	for clump: Node in clumps:
		var multimesh := (clump as MultiMeshInstance3D).multimesh
		if multimesh.visible_instance_count > multimesh.instance_count:
			capacity_ok = false
	check(capacity_ok, "no clump shows more strands than its buffer holds")

	# The scouts: free tendrils on the ground, casting nothing.
	var scouts: Array[Node] = []
	for child in worm.get_children():
		if String(child.name).begins_with("Scout"):
			scouts.append(child)
	check(scouts.size() == int(worm.get("scout_count")), "the scouts are out (%d)" % scouts.size())
	check(scouts.all(func(s: Node) -> bool:
		var strand := (s as Node3D).get_node_or_null("Strand") as MeshInstance3D
		return strand != null and strand.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),
		"each scout is one shadowless strand")
	var squirm := worm.get_node_or_null("Body/Squirm") as AudioStreamPlayer3D
	check(squirm != null and squirm.stream != null, "the wet squirm bed is loaded")

	# It moves: the walk reaches its mark, the climb ends on the far side, the lunge lands.
	worm.call("walk_to", Vector3(0.0, 0.0, 2.0))
	check(int(worm.get("state")) == WormMass.State.WALK, "walk_to sets it walking")
	var waited := 0.0
	while int(worm.get("state")) != WormMass.State.IDLE and waited < 4.0:
		await create_timer(0.1).timeout
		waited += 0.1
	var at: Vector3 = (worm as Node3D).global_position
	check(int(worm.get("state")) == WormMass.State.IDLE and at.distance_to(Vector3(0, 0, 2)) < 0.7,
		"the walk arrives and stands down (%.2f m off)" % at.distance_to(Vector3(0, 0, 2)))
	worm.call("climb_over", Vector3(0.0, 2.7, 4.0), Vector3(0.0, 0.0, 5.8))
	check(int(worm.get("state")) == WormMass.State.CLIMB, "climb_over starts the climb")
	await create_timer(5.5).timeout
	at = (worm as Node3D).global_position
	check(int(worm.get("state")) == WormMass.State.IDLE and at.distance_to(Vector3(0.0, 0.0, 5.8)) < 0.3,
		"the climb comes down on the far side (%.2f m off)" % at.distance_to(Vector3(0.0, 0.0, 5.8)))
	worm.call("lunge_at", Vector3(2.5, 0.0, 5.8))
	await create_timer(1.4).timeout
	at = (worm as Node3D).global_position
	check(int(worm.get("state")) == WormMass.State.IDLE and at.distance_to(Vector3(2.5, 0.0, 5.8)) < 0.3,
		"the lunge lands on its mark and settles")

	print("worm_mass_smoke: %d failures" % failures)
	quit(1 if failures else 0)
