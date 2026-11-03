extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_player := load("res://scenes/player/player.tscn") as PackedScene
	var player := packed_player.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame

	var flashlight := player.get_node_or_null("Head/Camera3D/Flashlight")
	var beam := player.get_node_or_null("Head/Camera3D/Flashlight/Beam") as SpotLight3D
	var model_pivot := player.get_node_or_null("Head/Camera3D/Flashlight/ModelPivot") as Node3D
	var inventory := player.get_node_or_null("InventoryHUD") as PlayerInventory
	var toggle_audio := flashlight.get_node("ToggleAudio") as AudioStreamPlayer
	var has_f_binding := false
	for input_event in InputMap.action_get_events("flashlight_toggle"):
		if input_event is InputEventKey and input_event.physical_keycode == KEY_F:
			has_f_binding = true

	var passed := flashlight != null and beam != null and model_pivot != null and inventory != null and has_f_binding
	passed = passed and not flashlight.is_enabled() and not beam.visible and not model_pivot.visible
	passed = passed and not toggle_audio.playing and toggle_audio.bus == &"Effects"

	var toggle_event := InputEventKey.new()
	toggle_event.physical_keycode = KEY_F
	toggle_event.pressed = true
	player._unhandled_input(toggle_event)
	passed = passed and not flashlight.is_enabled() and not beam.visible
	passed = passed and not toggle_audio.playing

	passed = passed and inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM)
	passed = passed and inventory.get_selected_item() == PlayerInventory.FLASHLIGHT_ITEM
	player._unhandled_input(toggle_event)
	passed = passed and flashlight.is_enabled() and beam.visible and not model_pivot.visible
	passed = passed and toggle_audio.playing and toggle_audio.stream.resource_path.ends_with("flashlightTurnOn.ogg")
	passed = passed and toggle_audio.stream is AudioStreamOggVorbis and not toggle_audio.stream.loop

	inventory.select_slot(1)
	# Slot browsing no longer switches the flashlight off; its toggle owns that state.
	passed = passed and flashlight.is_enabled() and beam.visible
	player._unhandled_input(toggle_event)
	flashlight._process(1.0)
	passed = passed and not flashlight.is_enabled() and not beam.visible and not model_pivot.visible
	passed = passed and toggle_audio.playing and toggle_audio.stream.resource_path.ends_with("flashlightTurnOff.ogg")
	passed = passed and toggle_audio.stream is AudioStreamOggVorbis and not toggle_audio.stream.loop
	# Restoring state must not pretend the player pressed the flashlight switch.
	var saves := root.get_node("SaveGame")
	saves._restore_player(player, {"flashlight_on": true})
	passed = passed and flashlight.is_enabled() and not toggle_audio.playing
	saves._restore_player(player, {"flashlight_on": false})
	passed = passed and not flashlight.is_enabled() and not toggle_audio.playing

	print("PASS player flashlight" if passed else "FAIL player flashlight")
	player.queue_free()
	quit(0 if passed else 1)
