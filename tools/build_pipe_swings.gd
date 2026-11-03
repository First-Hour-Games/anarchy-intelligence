extends SceneTree
## Turns the pipe swings exported by tools/blender/build_pipe_swings.py (a GLB of the arms with the
## clips, and a JSON of each clip's impact time and pipe slide) into one AnimationLibrary keyed on the
## arms' own node paths in fpsWhite_holding_idle.glb. The pipe's slide up through the hands while it
## is held in two becomes a position track on the pipe, and each clip's impact time its "impact"
## metadata, which pipe_weapon.gd centres its hit window on. build_pipe_swings.py runs this:
## godot --headless --path . --script res://tools/build_pipe_swings.gd -- <clips.glb> <clips.json> <library.tres>

const ARMS := "res://models/player/fpsWhite_holding_idle.glb"

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
	root.add_child(arms)
	var arms_player := arms.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	arms_player.play(&"Holding_Idle")
	arms_player.seek(0.0, true)
	await process_frame
	await process_frame
	var arms_root := arms_player.get_node(arms_player.root_node)
	var skeleton := arms_root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var skeleton_path := String(arms_root.get_path_to(skeleton))
	var pipe := arms_root.find_child("MetalPipe_Hand_R", true, false) as MeshInstance3D
	# One metre along the pipe toward the end that is on top in the idle pose, in the pipe's parent
	# space: the swings slide the pipe that way through the hands, by world metres.
	var box := pipe.get_aabb()
	var half := Vector3.ZERO
	half[box.get_longest_axis_index()] = box.size[box.get_longest_axis_index()] / 2.0
	var one_end := pipe.global_transform * (box.get_center() + half)
	var other_end := pipe.global_transform * (box.get_center() - half)
	var up_the_pipe := (one_end - other_end).normalized() if one_end.y > other_end.y else (other_end - one_end).normalized()
	var slide_per_metre := (pipe.get_parent() as Node3D).global_basis.inverse() * up_the_pipe
	var grip := pipe.position
	print("pipe slides along ", slide_per_metre, " from ", grip)

	var notes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(args[0], state) != OK:
		fail("Could not read " + args[0])
		return
	# Keep the frames the swings were keyed on rather than resampling them.
	var exported := document.generate_scene(state, float(notes.values()[0]["fps"]))
	var clips_player := exported.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := AnimationLibrary.new()
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
		var slide: Array = notes[clip_name]["slide"]
		var fps := float(notes[clip_name]["fps"])
		var pipe_track := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(pipe_track, arms_root.get_path_to(pipe))
		for index in slide.size():
			animation.position_track_insert_key(pipe_track, index / fps, grip + slide_per_metre * float(slide[index]))
		animation.loop_mode = Animation.LOOP_NONE
		animation.set_meta(&"impact", float(notes[clip_name]["impact"]))
		library.add_animation(clip_name, animation)
		print("%s: %.2f s, hit at %.2f s, %d tracks" % [clip_name, animation.length, animation.get_meta(&"impact"), animation.get_track_count()])
	exported.free()
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
	print("saved ", path, " ", ResourceUID.id_to_text(uid))
	quit(0)
