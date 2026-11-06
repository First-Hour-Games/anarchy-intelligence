extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var school = load("res://scenes/flashbacks/school.tscn").instantiate()
	school.auto_start_intro = false
	root.add_child(school)
	current_scene = school
	var phone = school.get_node("TeacherDesk/oldPhone")
	var logo = school.get_node("EndingLogo")
	assert(not logo.visible and not phone.transition_after_dialogue)
	phone.dialogue_start_delay = 0.0
	phone._on_phone_interacted(school.get_node("Player"))
	await process_frame
	var balloon = phone.active_balloon
	var dialogue_layer: int = balloon.layer
	while not logo.visible:
		balloon.dialogue_label.skip_typing()
		balloon.next(balloon.dialogue_line.next_id)
		await process_frame
	assert(logo.layer > phone._black_screen_overlay.layer and logo.layer > dialogue_layer)
	assert(logo.get_node("Logo").texture.resource_path == "res://img/menu/title.png")
	assert(school.get_node("Player").is_frozen)
	assert(not phone.ringing_audio.playing)
	await create_timer(1.2).timeout
	assert(current_scene == school and logo.visible)
	var tutorial_phone = load("res://scenes/chapters/tutorial/old_phone.gd").new()
	assert(tutorial_phone.transition_after_dialogue)
	tutorial_phone.free()
	school.queue_free()
	await process_frame
	print("PASS: Completing the school phone dialogue shows the title logo on black, keeps the player frozen, and stays in school; tutorial transitions remain enabled by default.")
	quit()
