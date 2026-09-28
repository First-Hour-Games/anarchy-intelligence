extends SceneTree


func _initialize() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(
		"res://models/enemies/watching_yeti/watching_yeti.glb",
		state
	)
	if error != OK:
		push_error("Watching Yeti GLB parse failed: %s" % error_string(error))
		quit(1)
		return
	var scene := document.generate_scene(state)
	if scene == null:
		push_error("Watching Yeti GLB did not generate a scene.")
		quit(1)
		return
	root.add_child(scene)
	var animation_player := _find_animation_player(scene)
	if animation_player == null:
		push_error("Watching Yeti GLB has no AnimationPlayer.")
		quit(1)
		return
	var required := PackedStringArray(["idle", "walk", "run", "windup", "attack", "hit", "death"])
	for clip_name in required:
		if not animation_player.has_animation(clip_name):
			push_error("Watching Yeti GLB is missing animation: %s" % clip_name)
			quit(1)
			return
	print("PASS Watching Yeti GLB: ", animation_player.get_animation_list())
	quit()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
