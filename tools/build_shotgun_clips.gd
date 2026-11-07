extends SceneTree
## Turns the shotgun clips exported by tools/blender/build_shotgun_clips.py (a GLB of the arms with the
## clips and two empties, ShotgunMount on the right hand where the gun sits and HandShellsMount on the
## left where the carried shells sit; and a JSON of each clip's per-frame barrels and shells, its shot,
## loading and sound times and looping) into one AnimationLibrary keyed on the arms' own node paths in
## fpsWhite_holding_idle.glb. shotgun_weapon.gd hangs the gun from the right hand as "ShotgunModel" and
## the carried shells from a "Hand_L" bone attachment as "HandShells"; then the barrels' swing on the
## hinge is a rotation track on the gun's Barrels node, the shells in the chambers slide and show on
## their own tracks, and the carried shells show while the left hand has them. The library's "mount" and
## "hand_shells_mount" metadata are the gun's and the carried shells' transforms under their bone
## attachments; a clip's "shot" metadata is when it fires, its "loaded" metadata when the shells are in,
## and its "sounds" metadata when each of the gun's action sounds lands (name to seconds).
## godot --headless --path . --script res://tools/build_shotgun_clips.gd -- <clips.glb> <clips.json> <library.tres>

const ARMS := "res://models/player/fpsWhite_holding_idle.glb"
const GUN := "res://models/props/weapons/shotgun/shotgun.glb"
const HAND := "FPS_Arms/Skeleton3D/Hand_R"
const GUN_NODE := "ShotgunModel"
const HAND_SHELLS := "FPS_Arms/Skeleton3D/Hand_L/HandShells"

func _initialize() -> void:
	build.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func build() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		fail("Expected <clips.glb> <clips.json> <library.tres>")
		return
	var arms := (load(ARMS) as PackedScene).instantiate() as Node3D
	var arms_player := arms.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	# Track paths are relative to the AnimationPlayer's root node, the arms scene's root.
	var arms_root := arms_player.get_node(arms_player.root_node)
	var skeleton := arms_root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var skeleton_path := String(arms_root.get_path_to(skeleton))
	if not arms_root.has_node(HAND):
		fail("The arms have no " + HAND)
		return
	var gun := (load(GUN) as PackedScene).instantiate() as Node3D
	var barrels := gun.find_child("Barrels", true, false) as Node3D
	var muzzle := gun.find_child("MuzzleRight", true, false) as Node3D
	var chamber := gun.find_child("ChamberShells", true, false) as Node3D
	if barrels == null or muzzle == null or chamber == null:
		fail("The shotgun model has no Barrels, MuzzleRight or ChamberShells")
		return
	var barrels_path := NodePath("%s/%s/%s" % [HAND, GUN_NODE, gun.get_path_to(barrels)])
	var chamber_path := NodePath("%s/%s/%s" % [HAND, GUN_NODE, gun.get_path_to(chamber)])
	var seated := chamber.position
	if muzzle.position.z >= 0.0:
		fail("The shotgun's barrels should point along -Z")
		return
	var rest := barrels.quaternion

	var notes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(args[0], state) != OK:
		fail("Could not read " + args[0])
		return
	var exported := document.generate_scene(state, float(notes.values()[0]["fps"]))
	var clips_player := exported.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mount_node := exported.find_child("ShotgunMount", true, false) as Node3D
	var shells_mount := exported.find_child("HandShellsMount", true, false) as Node3D
	if mount_node == null or shells_mount == null:
		fail("The GLB has no ShotgunMount or HandShellsMount")
		return
	var library := AnimationLibrary.new()
	library.set_meta(&"mount", mount_node.transform)
	library.set_meta(&"hand_shells_mount", shells_mount.transform)
	library.set_meta(&"barrels_path", barrels_path)
	for clip_name: String in notes:
		if not clips_player.has_animation(clip_name):
			fail("The GLB has no clip " + clip_name)
			return
		var animation := clips_player.get_animation(clip_name).duplicate(true) as Animation
		for track in animation.get_track_count():
			var bone := animation.track_get_path(track).get_concatenated_subnames()
			if skeleton.find_bone(bone) < 0:
				fail("%s track %s is not on a bone of the arms" % [clip_name, animation.track_get_path(track)])
				return
			animation.track_set_path(track, NodePath(skeleton_path + ":" + bone))
		var amounts: Array = notes[clip_name]["open"]
		var fps := float(notes[clip_name]["fps"])
		var angle := deg_to_rad(float(notes[clip_name]["break_angle"]))
		var hinge_track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(hinge_track, barrels_path)
		# Opening swings the barrels down on the hinge pin, round the gun's X axis, muzzles first.
		for index in amounts.size():
			animation.rotation_track_insert_key(hinge_track, index / fps, rest * Quaternion(Vector3.RIGHT, -angle * float(amounts[index])))
		# Shells only move in clips that load: they slide out of the chambers and back in along the
		# barrels, toward +Z in the barrels' frame, and show while they are anywhere to be seen.
		var outs: Array = notes[clip_name]["chamber_shells"]
		var carried: Array = notes[clip_name]["hand_shells"]
		if outs.any(func(out: float) -> bool: return out != 0.0) or carried.any(func(shown: float) -> bool: return shown > 0.5):
			var slide_track := animation.add_track(Animation.TYPE_POSITION_3D)
			animation.track_set_path(slide_track, chamber_path)
			var shown_track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(shown_track, NodePath(String(chamber_path) + ":visible"))
			animation.value_track_set_update_mode(shown_track, Animation.UPDATE_DISCRETE)
			var carried_track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(carried_track, NodePath(HAND_SHELLS + ":visible"))
			animation.value_track_set_update_mode(carried_track, Animation.UPDATE_DISCRETE)
			for index in outs.size():
				var out := float(outs[index])
				animation.position_track_insert_key(slide_track, index / fps, seated + Vector3.BACK * maxf(out, 0.0))
				if index == 0 or (out >= 0.0) != (float(outs[index - 1]) >= 0.0):
					animation.track_insert_key(shown_track, index / fps, out >= 0.0)
				if index == 0 or (float(carried[index]) > 0.5) != (float(carried[index - 1]) > 0.5):
					animation.track_insert_key(carried_track, index / fps, float(carried[index]) > 0.5)
		animation.loop_mode = Animation.LOOP_LINEAR if bool(notes[clip_name]["loop"]) else Animation.LOOP_NONE
		for moment: String in ["shot", "loaded"]:
			if notes[clip_name][moment] != null:
				animation.set_meta(StringName(moment), float(notes[clip_name][moment]))
		var sounds: Dictionary = notes[clip_name].get("sounds", {})
		if not sounds.is_empty():
			animation.set_meta(&"sounds", sounds)
		library.add_animation(clip_name, animation)
		print("%s: %.2f s, %d tracks%s%s" % [clip_name, animation.length, animation.get_track_count(),
			", fires at %.2f s" % animation.get_meta(&"shot") if animation.has_meta(&"shot") else "",
			", loaded at %.2f s" % animation.get_meta(&"loaded") if animation.has_meta(&"loaded") else ""])
	exported.free()
	gun.free()
	arms.free()
	var path := ProjectSettings.localize_path(args[2])
	# A rebuild keeps the library's UID, so nothing that refers to it breaks.
	var uid := ResourceLoader.get_resource_uid(path) if ResourceLoader.exists(path) else ResourceUID.INVALID_ID
	if uid == ResourceUID.INVALID_ID:
		uid = ResourceUID.create_id()
	var error := ResourceSaver.save(library, path)
	if error == OK:
		error = ResourceSaver.set_uid(path, uid)
	if error != OK:
		fail("Could not save %s: %s" % [path, error_string(error)])
		return
	print("saved ", path, " mount ", library.get_meta(&"mount"), " barrels ", barrels_path)
	quit(0)
