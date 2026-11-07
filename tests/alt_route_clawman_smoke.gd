extends SceneTree
## The alt route's Clawman (scenes/monsters/the_clawman_alt.tscn, model built by
## tools/blender/build_the_clawman_alt.py): the creator's Clawman half again as big, with five more arms that
## grope on their own, a head that stays shut until it screams and then splits down the face, and a tongue
## that lashes out on its strike. Its strike reaches further than the base Clawman's, whose own scene keeps
## the old reach. map_alt.tscn uses it; map.tscn keeps the base Clawman. Nothing is saved.

const ALT := "res://scenes/monsters/the_clawman_alt.tscn"
const BASE := "res://scenes/monsters/the_clawman.tscn"
const MAP_ALT := "res://scenes/chapters/alt_route/map_alt.tscn"
const MAP := "res://scenes/chapters/main/map.tscn"

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for index in count:
		await process_frame


## Waits this long in game time.
func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


## The rig's poses only last through the frame's drawing (Godot puts the bones back to the animation's pose
## afterwards), so they are read the moment it finishes: the jaw angles, the tongue's slide and the arm's turn.
var posed := {}


## The angle (degrees) a bone's pose is turned from its rest.
func turned(skeleton: Skeleton3D, bone: int) -> float:
	var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	return rad_to_deg(rest.angle_to(skeleton.get_bone_pose_rotation(bone)))


func run() -> void:
	var clawman := (load(ALT) as PackedScene).instantiate() as CharacterBody3D
	root.add_child(clawman)
	await frames(3)
	var visual := clawman.get_node("Visual")
	var skeleton := visual.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var rig := skeleton.get_node_or_null("ClawmanAltRig")
	check(rig != null and rig.call("has_bones"), "the rig is on the skeleton and finds the jaws, tongue and arms")
	check(skeleton.get_bone_count() == 52, "the skeleton has the creator's 26 bones and 26 new ones (%d)" % skeleton.get_bone_count())
	var head := skeleton.find_bone("head")
	var head_height := (skeleton.global_transform * skeleton.get_bone_global_pose(head)).origin.y
	check(head_height > 1.9 and head_height < 2.8, "it stands half again as tall: its head is %.2f m up" % head_height)
	var shape := (clawman.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	check(shape.height <= 2.2, "its body still fits under the hospital's 2.25 m doorways (%.2f m)" % shape.height)
	check(is_equal_approx(clawman.get("strike_reach"), 2.1) and is_equal_approx(clawman.get("hit_reach"), 2.45),
		"its strike reaches further (2.1 m to strike, lands up to 2.45 m)")

	var jaw := skeleton.find_bone("JawL")
	var jaw_r := skeleton.find_bone("JawR")
	var tongue := skeleton.find_bone("Tongue3")
	var arm := skeleton.find_bone("MantisArmL2")
	var tongue_rest := skeleton.get_bone_rest(tongue).origin
	rig.connect("modification_processed", func() -> void:
		posed["jaw"] = turned(skeleton, jaw)
		posed["jaw_r"] = turned(skeleton, jaw_r)
		posed["left_axis"] = (skeleton.get_bone_rest(jaw).basis.get_rotation_quaternion().inverse() * skeleton.get_bone_pose_rotation(jaw)).get_axis()
		posed["right_axis"] = (skeleton.get_bone_rest(jaw_r).basis.get_rotation_quaternion().inverse() * skeleton.get_bone_pose_rotation(jaw_r)).get_axis()
		posed["tongue"] = skeleton.get_bone_pose_position(tongue).distance_to(tongue_rest)
		posed["arm"] = skeleton.get_bone_pose_rotation(arm)
		posed["arm_turn"] = turned(skeleton, arm))
	visual.call("play", "idle")
	await wait(1.0)
	check(posed.has("jaw"), "the rig poses the skeleton every frame")
	check(posed.get("jaw", 99.0) < 3.0, "at rest the head is shut (%.1f deg)" % posed.get("jaw", 99.0))
	check(posed.get("tongue", 1.0) < 0.005, "at rest the tongue is in the throat")
	var arm_before: Quaternion = posed.get("arm", Quaternion.IDENTITY)
	await frames(20)
	check((posed.get("arm", Quaternion.IDENTITY) as Quaternion).angle_to(arm_before) > 0.002, "the extra arms move on their own")
	check(posed.get("arm_turn", 0.0) > 30.0, "the mantis arm is folded over (%.0f deg)" % posed.get("arm_turn", 0.0))

	visual.call("play", "windup")
	await wait(0.8)
	check(posed.get("jaw", 0.0) > 30.0 and posed.get("jaw_r", 0.0) > 30.0,
		"screaming, the head splits open (%.0f and %.0f deg)" % [posed.get("jaw", 0.0), posed.get("jaw_r", 0.0)])
	check((posed.get("left_axis", Vector3.UP) as Vector3).dot(posed.get("right_axis", Vector3.UP)) < -0.9,
		"the halves turn opposite ways about the hinge")

	visual.call("play", "attack")
	var reach := 0.0
	var strike := create_timer(1.2)
	while strike.time_left > 0.0:
		await process_frame
		reach = maxf(reach, posed.get("tongue", 0.0))
	check(reach > 0.04, "striking, the tongue lashes out (%.3f m along one segment)" % reach)
	check(posed.get("jaw", 0.0) > 30.0, "the head is open on the strike")
	visual.call("play", "idle")
	await wait(2.5)
	check(posed.get("jaw", 99.0) < 3.0, "afterwards it shuts again (%.1f deg)" % posed.get("jaw", 99.0))
	check(posed.get("tongue", 1.0) < 0.005, "and the tongue is back in")
	clawman.queue_free()

	var base := (load(BASE) as PackedScene).instantiate()
	check(is_equal_approx(base.get("strike_reach"), 1.65) and is_equal_approx(base.get("hit_reach"), 1.9),
		"the base Clawman keeps its old reach")
	base.free()
	var alt_text := FileAccess.get_file_as_string(MAP_ALT)
	check(alt_text.contains("res://scenes/monsters/the_clawman_alt.tscn") and not alt_text.contains("res://scenes/monsters/the_clawman.tscn\""),
		"the alt map's hospital has the alt Clawman")
	check(FileAccess.get_file_as_string(MAP).contains("res://scenes/monsters/the_clawman.tscn\""), "the main map keeps the base Clawman")
	print("DONE failures=%d" % failures)
	quit(1 if failures else 0)
