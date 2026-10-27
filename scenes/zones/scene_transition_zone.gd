extends Area3D
## Road exit that survives scene replacement until the destination fades in.
@export_file("*.tscn") var destination_scene: String
@export var destination_spawn: NodePath = NodePath("ForestEntranceSpawn")
## Use matching scene coordinates when both map sections share the same layout.
@export var preserve_relative_position := false
@export_range(0.1, 5.0) var fade_out_seconds := 0.8
@export_range(0.1, 5.0) var fade_in_seconds := 1.0
var transitioning := false
var _shade: ColorRect


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if transitioning or not body is FirstPersonPlayer or get_tree().paused:
		return
	if body.is_frozen:
		return
	transitioning = true
	_transition.call_deferred(body)


func _transition(player: FirstPersonPlayer) -> void:
	var source_scene := get_tree().current_scene as Node3D
	var arrival_transform := player.global_transform
	if source_scene != null:
		arrival_transform = source_scene.global_transform.affine_inverse() * player.global_transform
	var head_rotation := player.head.rotation
	var error := ResourceLoader.load_threaded_request(destination_scene, "PackedScene")
	if error != OK:
		push_warning("Cannot load transition destination: " + error_string(error))
		transitioning = false
		return
	var items: Array[StringName] = []
	for slot in PlayerInventory.SLOT_COUNT:
		items.append(player.inventory.get_item(slot))
	var selected := player.inventory.selected_slot_index
	var flashlight_on := player.flashlight.is_enabled()
	var state := {}
	for property in ["sprint_enabled", "jump_enabled", "crouch_enabled", "inventory_enabled", "stamina"]:
		state[property] = player.get(property)
	var old_health := player.get_node_or_null("CombatHealth")
	var health: float = old_health.health if old_health != null else 100.0
	# Keep the overlay alive when the old scene is freed.
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	monitoring = false
	get_tree().paused = true
	var canvas := CanvasLayer.new()
	canvas.layer = 500
	add_child(canvas)
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(_shade)
	await _fade(1.0, fade_out_seconds)
	while ResourceLoader.load_threaded_get_status(destination_scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(destination_scene) != ResourceLoader.THREAD_LOAD_LOADED:
		await _recover("Transition destination failed to load.")
		return
	var packed := ResourceLoader.load_threaded_get(destination_scene) as PackedScene
	error = get_tree().change_scene_to_packed(packed)
	if error != OK:
		await _recover("Scene transition failed: " + error_string(error))
		return
	await get_tree().scene_changed
	var scene := get_tree().current_scene
	var next_player := scene.get_node_or_null("Player") as FirstPersonPlayer
	if next_player != null:
		var spawn := scene.get_node_or_null(destination_spawn) as Node3D
		if preserve_relative_position and scene is Node3D:
			next_player.global_transform = scene.global_transform * arrival_transform
			next_player.head.rotation = head_rotation
		elif spawn != null:
			next_player.global_transform = spawn.global_transform
		for item in items:
			next_player.inventory.add_item(item)
		next_player.inventory.select_slot(selected)
		for property in state:
			next_player.set(property, state[property])
		next_player.stamina_changed.emit(next_player.stamina, next_player.max_stamina)
		next_player.flashlight.set_enabled(flashlight_on)
		var next_health := next_player.get_node_or_null("CombatHealth")
		if next_health != null:
			next_health.health = minf(health, next_health.max_health)
			next_health.health_changed.emit(next_health.health)
			next_health.call("_refresh")
	# Draw the destination behind black before revealing it.
	await get_tree().process_frame
	await _fade(0.0, fade_in_seconds)
	get_tree().paused = false
	queue_free()


func _fade(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_shade, "color:a", alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _recover(message: String) -> void:
	push_warning(message)
	await _fade(0.0, fade_in_seconds)
	get_tree().paused = false
	queue_free()
