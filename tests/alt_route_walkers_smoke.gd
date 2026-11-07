extends SceneTree
## The ten walkers, the alt route's rooftop Ridgebacks (models/enemies/the_ridgeback/walkers/, built by
## tools/blender/build_ridgeback_walkers.py). A faller wears its walker's meshes on the original Ridgeback's
## skeletons: the whole body, the legless crawler and the legs it leaves, so every clip plays on it. Each
## walker's skin is bound to the same bones at the same rest as the original's, so it bends exactly as the
## original does. Each has its own eyes, size and voice. (The street's line uses none of them by default.)

const FALLER := preload("res://scenes/monsters/the_ridgeback/ridgeback_faller.tscn")
const ORIGINAL := preload("res://models/enemies/the_ridgeback/THE_RIDGEBACK.glb")
const ORIGINAL_CRAWLER := preload("res://models/enemies/the_ridgeback/THE_RIDGEBACK_crawler.glb")

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func mesh_in(node: Node) -> MeshInstance3D:
	return node.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D


## Each of `skin`'s binds names a bone of `skeleton` and has the bind pose `original` gives that bone.
func binds_like(skin: Skin, original: Skin, skeleton: Skeleton3D) -> bool:
	if skin == null or original == null or skin.get_bind_count() == 0:
		return false
	var poses := {}
	for index in original.get_bind_count():
		poses[original.get_bind_name(index)] = original.get_bind_pose(index)
	for index in skin.get_bind_count():
		var bone := skin.get_bind_name(index)
		if skeleton.find_bone(bone) < 0 or not poses.has(bone):
			return false
		if not (skin.get_bind_pose(index) as Transform3D).is_equal_approx(poses[bone]):
			return false
	return true


func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var looks := RidgebackFallerVisual.walkers()
	var names := RidgebackFallerVisual.walker_names()
	check(names.size() == 10, "ten walkers (%s)" % ", ".join(names))
	var original := ORIGINAL.instantiate()
	var original_skin := mesh_in(original).skin
	var original_crawler := ORIGINAL_CRAWLER.instantiate()
	var original_crawler_skin := mesh_in(original_crawler).skin
	var plain := FALLER.instantiate() as RidgebackFaller
	world.add_child(plain)
	await process_frame
	var plain_shriek := plain.shriek.pitch_scale
	check(plain.visual.walker == &"" and mesh_in(plain.visual.full).mesh == mesh_in(original).mesh,
		"a faller with no walker is the original Ridgeback")
	for name in names:
		var look: Dictionary = looks[String(name)]
		var faller := FALLER.instantiate() as RidgebackFaller
		(faller.get_node("Visual") as RidgebackFallerVisual).walker = name
		world.add_child(faller)
		await process_frame
		var visual := faller.visual
		var source := (load(str(look.model)) as PackedScene).instantiate()
		var whole := mesh_in(visual.full)
		var crawler := mesh_in(visual.crawler)
		var legs := mesh_in(visual.legs)
		var whole_source := source.find_child("Walker", true, false) as MeshInstance3D
		var crawler_source := source.find_child("WalkerCrawler", true, false) as MeshInstance3D
		var legs_source := source.find_child("WalkerLegs", true, false) as MeshInstance3D
		check(whole.mesh == whole_source.mesh and crawler.mesh == crawler_source.mesh and legs.mesh == legs_source.mesh,
			"%s: wears its own body, crawler and legs" % look.title)
		var skeleton := visual.full.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		check(binds_like(whole.skin, original_skin, skeleton) and binds_like(crawler.skin, original_crawler_skin, skeleton),
			"%s: skinned to the original's bones at the original's rest, so every clip plays on it" % look.title)
		var eyes := 0
		for attachment: Node in skeleton.find_children("*", "BoneAttachment3D", false, false):
			eyes += attachment.get_child_count()
		check(eyes == (look.eyes as Array).size() and eyes >= 2, "%s: %d glowing eyes" % [look.title, eyes])
		check(is_equal_approx(visual.scale.x, 1.3 * float(look.scale)), "%s: drawn %.2f times the original's size" % [look.title, float(look.scale)])
		visual.play("splat", true)
		visual.settle()
		visual.lose_legs()
		check(visual.is_crawler and visual.crawler.visible and visual.legs.visible and not visual.full.visible,
			"%s: after the splat it crawls on, its legs left lying" % look.title)
		source.free()
		faller.queue_free()
	var brute := FALLER.instantiate() as RidgebackFaller
	(brute.get_node("Visual") as RidgebackFallerVisual).walker = &"brute"
	world.add_child(brute)
	await process_frame
	check(brute.shriek.pitch_scale < 0.86 and plain_shriek >= 0.9 and (brute.stand_shape.shape as CapsuleShape3D).radius > 0.45
		and (plain.stand_shape.shape as CapsuleShape3D).radius < 0.4, "the Brute's voice is deeper and its body bigger, the others' shapes untouched")
	original.free()
	original_crawler.free()
	print("DONE failures=%d" % failures)
	quit(1 if failures else 0)
