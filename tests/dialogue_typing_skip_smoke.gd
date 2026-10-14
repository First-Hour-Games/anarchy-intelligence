extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1

func press(key: Key, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	event.echo = echo
	return event

func run() -> void:
	var manager := Engine.get_singleton("DialogueManager")
	var dialogue: Resource = manager.create_resource_from_text("~ start\nA long first line to verify the typewriter reveal behavior.\nA second line to verify Space also reveals without advancing.\n=> END")
	var packed := load("res://scenes/ui/balloon/balloon.tscn") as PackedScene
	var balloon := packed.instantiate()
	root.add_child(balloon)
	balloon.start(dialogue, "start")
	await process_frame
	var first_id: String = balloon.dialogue_line.id
	check(balloon.dialogue_label.is_typing, "first line is typing")
	balloon._unhandled_input(press(KEY_ENTER, true))
	check(balloon.dialogue_label.is_typing, "held-key repeat does not skip")
	balloon._unhandled_input(press(KEY_ENTER))
	check(not balloon.dialogue_label.is_typing, "Enter reveals complete text")
	check(balloon.dialogue_line.id == first_id, "reveal does not advance the line")
	await process_frame
	await process_frame
	balloon._unhandled_input(press(KEY_SPACE))
	await process_frame
	check(balloon.dialogue_line.id != first_id, "next press advances to second line")
	var second_id: String = balloon.dialogue_line.id
	balloon._unhandled_input(press(KEY_SPACE))
	check(not balloon.dialogue_label.is_typing, "Space reveals complete text")
	check(balloon.dialogue_line.id == second_id, "Space reveal preserves current line")
	check(not balloon.talk_sfx.playing, "typing sound stops on reveal")
	balloon.queue_free()
	await process_frame
	quit(1 if failures else 0)
