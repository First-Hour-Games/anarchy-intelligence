extends SceneTree

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1


func run() -> void:
	var packed: PackedScene = load("res://scenes/chapters/main/starting_forest.tscn")
	check(packed != null, "starting_forest.tscn loads successfully")

	var forest: Variant = packed.instantiate()
	forest.auto_start_fade = false
	if forest.has_node("BottomDialogueBalloon"):
		forest.get_node("BottomDialogueBalloon").auto_start = false
	root.add_child(forest)
	await process_frame
	await physics_frame

	var world_flashlight := forest.get_node_or_null("FlashlightItem") as Node3D
	check(is_instance_valid(world_flashlight), "FlashlightItem exists in starting forest")

	var audio := world_flashlight.get_node_or_null("FlickerAudio") as AudioStreamPlayer3D
	check(is_instance_valid(audio), "FlashlightItem has FlickerAudio AudioStreamPlayer3D")

	if is_instance_valid(audio):
		check(audio.stream != null, "FlickerAudio has an audio stream assigned")
		check(audio.stream.resource_path == "res://sounds/chapters/main/electric_light_hum_flickers_01_wav.ogg", "Audio stream is electric_light_hum_flickers_01_wav.ogg")
		check(audio.stream is AudioStreamOggVorbis and (audio.stream as AudioStreamOggVorbis).loop, "Stream is AudioStreamOggVorbis configured to loop")
		check(audio.bus == &"Reverb", "Audio bus is set to Reverb for ambient realism")
		check(audio.unit_size >= 2.0 and audio.unit_size <= 5.0, "Audio unit_size (%.1f) provides realistic near-field attenuation" % audio.unit_size)
		check(audio.max_distance >= 20.0 and audio.max_distance <= 40.0, "Audio max_distance (%.1f) lets loop be heard when nearing the gas station" % audio.max_distance)
		check(audio.playing, "Flicker audio starts playing and looping for uncollected flashlight")

	var player: FirstPersonPlayer = forest.player
	var pickup := world_flashlight.get_node_or_null("Pickup") as FlashlightPickup
	check(is_instance_valid(pickup), "FlashlightPickup exists on FlashlightItem")

	if is_instance_valid(pickup) and is_instance_valid(player):
		pickup.interact(player)
		await physics_frame
		await physics_frame

		check(not world_flashlight.visible, "FlashlightItem hides on pickup")
		if is_instance_valid(audio):
			check(not audio.playing, "Flicker audio loop stops immediately once picked up")

		for _i in 10:
			await physics_frame

		if is_instance_valid(audio):
			check(not audio.playing, "Flicker audio remains stopped after pickup")

	forest.queue_free()
	await process_frame

	# Verify fresh forest instance with flashlight restored/hidden doesn't play
	var forest2: Variant = packed.instantiate()
	forest2.auto_start_fade = false
	if forest2.has_node("BottomDialogueBalloon"):
		forest2.get_node("BottomDialogueBalloon").auto_start = false
	var fl2 := forest2.get_node("FlashlightItem") as Node3D
	fl2.visible = false
	root.add_child(forest2)
	await process_frame
	await physics_frame

	var audio2 := fl2.get_node_or_null("FlickerAudio") as AudioStreamPlayer3D
	check(is_instance_valid(audio2) and not audio2.playing, "Hidden/already-collected flashlight does not play audio on scene load")

	forest2.queue_free()
	await process_frame

	print("--- Gas Station Flashlight Audio Smoke Test Finished ---")
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED with %d errors" % failures)
		quit(1)
