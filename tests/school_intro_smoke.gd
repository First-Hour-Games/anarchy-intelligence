extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var school = load("res://scenes/flashbacks/school.tscn").instantiate()
	school.fade_duration = 0.1
	root.add_child(school)
	current_scene = school
	var player = school.get_node("Player")
	var fade = school.get_node("IntroFadeCanvas/BlackScreen")
	var dialogue = school.get_node("OpeningDialogue")
	var phone = school.get_node("TeacherDesk/oldPhone")
	assert(not phone.ringing_audio.playing)
	assert(phone.ringing_audio.stream.loop and phone.ringing_audio.bus == &"Reverb")
	var reverb_bus := AudioServer.get_bus_index(&"Reverb")
	assert(reverb_bus >= 0)
	assert(AudioServer.get_bus_effect(reverb_bus, 0) is AudioEffectReverb)
	assert(AudioServer.is_bus_effect_enabled(reverb_bus, 0))
	assert(player.is_frozen and fade.visible and is_equal_approx(fade.modulate.a, 1.0))
	assert(dialogue.dialogue_line == null)
	assert(school.get_node("CRTOverlay").layer == 100)
	assert(school.get_node("CRTOverlay/AspectRatioContainer/Content/Filter").material.shader.resource_path == "res://shaders/crt.gdshader")
	await create_timer(0.4).timeout
	assert(not fade.visible and player.is_frozen)
	assert(dialogue.dialogue_line != null)
	while player.is_frozen:
		assert(not phone.ringing_audio.playing)
		dialogue.dialogue_label.skip_typing()
		dialogue.next(dialogue.dialogue_line.next_id)
		await create_timer(0.3).timeout
	await create_timer(0.5).timeout
	assert(not player.is_frozen)
	assert(phone.ringing_audio.playing)
	phone.stop_ringing()
	assert(not phone.ringing_audio.playing)
	school.queue_free()
	await process_frame
	print("PASS: School fades in before dialogue; phone stays silent until dialogue ends, then loops through an enabled reverb effect and can stop on pickup.")
	quit()
