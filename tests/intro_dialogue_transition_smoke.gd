extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(90.0).timeout.connect(func():
		push_error("INTRO FAIL: watchdog timeout")
		quit(1)
	)
	var translation := load("res://addons/dialogue_manager/l10n/en.po") as Translation
	if translation == null:
		push_error("INTRO FAIL: translation missing from export")
		quit(1)
		return
	print("INTRO PASS: plugin translation included")
	change_scene_to_file("res://scenes/chapters/intro/intro.tscn")
	await scene_changed
	var deadline := Time.get_ticks_msec() + 90000
	var last_line := ""
	while Time.get_ticks_msec() < deadline:
		if not is_instance_valid(current_scene):
			await process_frame
			continue
		if current_scene.scene_file_path == "res://scenes/chapters/tutorial/tutorial.tscn":
			await create_timer(6.0).timeout
			print("INTRO PASS: dialogue, TV cutscene, and background tutorial transition complete")
			quit()
			return
		var balloon_value = current_scene.get("active_balloon")
		if not is_instance_valid(balloon_value):
			await process_frame
			continue
		var balloon := balloon_value as CanvasLayer
		if is_instance_valid(balloon):
			var label = balloon.get("dialogue_label")
			if is_instance_valid(label) and label.is_typing:
				label.skip_typing()
		if is_instance_valid(balloon) and balloon.get("is_waiting_for_input") and not balloon.get("is_advancing"):
			var line = balloon.get("dialogue_line")
			if line != null and line.id != last_line:
				last_line = line.id
				print("INTRO ADVANCE: ", line.text)
				balloon.call("next", line.next_id)
		await process_frame
	push_error("INTRO FAIL: transition timeout")
	quit(1)
