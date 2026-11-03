extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var manager := Engine.get_singleton("DialogueManager")
	var resource = manager.create_resource_from_text("~ start\n[color=blue]Hello?[/color]\n[b][color=blue]Who is this?[/color][/b]\ndo clear_dialogue_text()\nA fresh page.\n=> END")
	var balloon = load("res://scenes/ui/balloon/balloon.tscn").instantiate()
	root.add_child(balloon)
	balloon.start(resource, "start")
	await process_frame
	balloon.dialogue_label.skip_typing()
	await process_frame
	balloon.dialogue_label.set_process(false)
	var parsed := RichTextLabel.new()
	parsed.bbcode_enabled = true
	parsed.text = balloon.accumulated_dialogue_text
	var previous_count := parsed.get_total_character_count()
	balloon.next(balloon.dialogue_line.next_id)
	assert(balloon.dialogue_label.visible_characters == previous_count, "Next line must start after rendered history, excluding color and bold tags.")
	assert(balloon.dialogue_label.get_parsed_text() == "Hello?\n\nWho is this?")
	assert(balloon.dialogue_label.is_typing)
	balloon.dialogue_label.skip_typing()
	await process_frame
	balloon.next(balloon.dialogue_line.next_id)
	await process_frame
	assert(balloon.dialogue_label.get_parsed_text() == "A fresh page.")
	assert(balloon.dialogue_label.visible_characters == 0)
	parsed.free()
	balloon.queue_free()
	await process_frame
	print("PASS: Color and bold tags do not skip or replay cumulative text; explicit clear commands still start a new page.")
	quit()
