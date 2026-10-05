extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		print("FAIL: " + message)
		failures += 1

func _init() -> void:
	print("--- Running Dialogue Fold Animation Smoke Test ---")
	call_deferred("_run")

func _run() -> void:
	var balloon_scene: PackedScene = load("res://scenes/ui/dialogue_box/bottom_dialogue_balloon.tscn")
	check(balloon_scene != null, "bottom_dialogue_balloon.tscn loaded")
	if balloon_scene == null:
		quit(1)
		return

	var balloon: BottomDialogueBalloon = balloon_scene.instantiate() as BottomDialogueBalloon
	root.add_child(balloon)
	await process_frame

	check(is_instance_valid(balloon.balloon), "Balloon Control node found")
	check(is_zero_approx(balloon.balloon.scale.y), "Balloon initially starts with scale.y == 0.0")
	check(not balloon.is_folded_open(), "Balloon is initially not folded open")
	check(balloon.fold_duration > 0.0, "Fold duration is set (> 0.0)")

	# Set fast fold duration for snappy testing
	balloon.fold_duration = 0.08

	var dm := Engine.get_singleton("DialogueManager")
	check(dm != null, "DialogueManager singleton active")

	var script_text := "~ start\nThomas: First dialogue line message.\nThomas: Second line message.\n=> END"
	var res: DialogueResource = dm.create_resource_from_text(script_text)
	check(res != null, "Test DialogueResource created")

	# Start dialogue
	print("--- Test 1: Fold-out on dialogue start ---")
	balloon.start(res, "start")
	await process_frame

	check(balloon.is_opening() or balloon.is_folded_open(), "Opening animation initiated")
	check(balloon.balloon.visible, "Balloon panel is visible during opening")

	# Check that text is hidden / not showing while opening
	if balloon.is_opening():
		check(balloon.dialogue_label.text == "" or not balloon.dialogue_label.visible, "DialogueLabel is hidden/empty during fold-out animation")
		await balloon._fold_tween.finished

	check(balloon.is_folded_open(), "Balloon marked as folded open after opening finishes")
	check(is_equal_approx(balloon.balloon.scale.y, 1.0), "Balloon scale.y reached 1.0 (unfolded)")
	check(balloon.dialogue_label.visible, "DialogueLabel is visible once unfolded")
	check(balloon.dialogue_label.is_typing or balloon.is_waiting_for_input, "Text typing/scrolling started after fold-out")

	# Complete typing of line 1
	if balloon.dialogue_label.is_typing:
		balloon.dialogue_label.skip_typing()
	await process_frame

	check(balloon.dialogue_label.text.contains("First dialogue line message"), "First line text is displayed")

	# Progress to line 2 (should remain unfolded without replaying fold-out animation)
	print("--- Test 2: Subsequent line remains unfolded ---")
	balloon.next(balloon.dialogue_line.next_id)
	await process_frame
	check(balloon.is_folded_open(), "Balloon remains folded open on line 2")
	check(not balloon.is_opening(), "Opening animation does NOT replay on subsequent line")
	check(is_equal_approx(balloon.balloon.scale.y, 1.0), "Balloon scale.y remains 1.0")

	if balloon.dialogue_label.is_typing:
		balloon.dialogue_label.skip_typing()
	await process_frame
	check(balloon.dialogue_label.text.contains("Second line message"), "Second line text is displayed")

	# Test 3: Ending dialogue removes text immediately and folds back shut
	print("--- Test 3: Fold-back on dialogue completion ---")
	balloon.next(balloon.dialogue_line.next_id) # reaches => END
	await process_frame

	check(balloon.is_closing(), "Closing fold-back animation initiated")
	check(balloon.dialogue_label.text == "" and not balloon.dialogue_label.visible, "All text removed immediately before fold-back")
	check(balloon.character_label.text == "" and not balloon.character_label.visible, "Character label removed immediately")

	# Wait for fold-back tween to complete
	await balloon.dialogue_finished

	check(not balloon.is_closing(), "Closing animation finished")
	check(not balloon.is_folded_open(), "Balloon marked as closed")
	check(not balloon.balloon.visible, "Balloon panel is hidden after fold-back finishes")
	check(is_equal_approx(balloon.balloon.scale.y, 0.0), "Balloon scale.y reached 0.0 (folded shut)")

	print("--- Dialogue Fold Animation Smoke Test Complete ---")
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED with %d failures" % failures)
		quit(1)
