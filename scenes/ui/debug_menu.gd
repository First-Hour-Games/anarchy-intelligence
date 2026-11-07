extends CanvasLayer

const SCENES: Array[Dictionary] = [
	{"name": "Main menu", "path": "res://scenes/mainMenu/menu.tscn"},
	{"name": "Intro", "path": "res://scenes/chapters/intro/intro.tscn"},
	{"name": "Tutorial", "path": "res://scenes/chapters/tutorial/tutorial.tscn"},
	{"name": "Starting forest", "path": "res://scenes/chapters/main/starting_forest.tscn"},
]
const FOREST_PATH := "res://scenes/chapters/main/starting_forest.tscn"
const MAP_PATH := "res://scenes/chapters/main/map.tscn"

var opened := false
var _previous_mouse: Input.MouseMode
var _previous_paused := false
var _loading_path := ""
var _overlay: Control
var _scene_label: Label
var _status_label: Label
var _buttons: Array[Button] = []
var _skip_intro_button: Button
var _pending_checkpoint := ""
var _scroll: ScrollContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 300
	if not OS.is_debug_build():
		set_process(false)
		set_process_input(false)
		return
	_build_menu()
	get_viewport().size_changed.connect(_resize_menu)
	get_tree().scene_changed.connect(_on_scene_changed)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_QUOTELEFT or event.keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE:
			if _loading_path.is_empty():
				set_open(not opened)
			get_viewport().set_input_as_handled()
		elif opened and event.keycode == KEY_ESCAPE:
			if _loading_path.is_empty():
				set_open(false)
			get_viewport().set_input_as_handled()


func _build_menu() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.hide()
	add_child(_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.035, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	margin.add_child(_scroll)
	_resize_menu()
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	_scroll.add_child(column)
	var title := Label.new()
	title.text = "DEBUG MENU"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	_scene_label = Label.new()
	column.add_child(_scene_label)
	var help := Label.new()
	help.text = "~ / Esc: close   |   Scene jumps restart that scene."
	help.add_theme_font_size_override("font_size", 14)
	column.add_child(help)
	column.add_child(HSeparator.new())
	_add_button(column, "Open save screen (saves where you stand)", _open_save_screen)
	_add_button(column, "Open load screen", _open_load_screen)
	column.add_child(HSeparator.new())
	for entry in SCENES:
		var path: String = entry["path"]
		_add_button(column, "Go to " + entry["name"], jump_to_scene.bind(path))
	column.add_child(HSeparator.new())
	var checkpoints := Label.new()
	checkpoints.text = "FOREST CHECKPOINTS (fresh start, town map included)"
	checkpoints.add_theme_font_size_override("font_size", 14)
	column.add_child(checkpoints)
	_add_button(column, "Before the log: test the climb", _jump_to_checkpoint.bind("before_log"))
	_add_button(column, "After climbing the log: continue on foot", _jump_to_checkpoint.bind("after_log"))
	_add_button(column, "In front of the gas station", _jump_to_checkpoint.bind("gas_station"))
	var map_checkpoints := Label.new()
	map_checkpoints.text = "MAP CHECKPOINTS (keeps saved progress)"
	map_checkpoints.add_theme_font_size_override("font_size", 14)
	column.add_child(map_checkpoints)
	_add_button(column, "Carrie's house: the Wrapper in the armchair (replay, doesn't save)", _jump_to_map_checkpoint.bind("carrie_house"))
	_add_button(column, "Hospital entrance: Clawman, hiding spots, bottles", _jump_to_map_checkpoint.bind("hospital"))
	column.add_child(HSeparator.new())
	_add_button(column, "Skip to next scene", _skip_next_scene)
	_add_button(column, "Reload current scene", _reload_scene)
	_skip_intro_button = _add_button(column, "Skip forest intro fade", _skip_forest_intro)
	_add_button(column, "Resume", set_open.bind(false))
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size.x = 380
	column.add_child(_status_label)


func _resize_menu() -> void:
	if _scroll != null:
		_scroll.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y - 100.0, 240.0, 600.0)


func _add_button(parent: Node, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 34
	button.pressed.connect(action)
	parent.add_child(button)
	_buttons.append(button)
	return button


func set_open(value: bool) -> void:
	if _overlay == null or opened == value or not _loading_path.is_empty():
		return
	if value:
		# Avoid taking pause ownership from the pause menu or another modal UI.
		if get_tree().paused:
			return
		_previous_paused = get_tree().paused
		_previous_mouse = Input.mouse_mode
		opened = true
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_overlay.show()
		_status_label.text = ""
		_refresh_scene_label()
		_scroll.scroll_vertical = 0
		_buttons[0].grab_focus()
	else:
		opened = false
		_overlay.hide()
		get_tree().paused = _previous_paused
		Input.mouse_mode = _previous_mouse


func _refresh_scene_label() -> void:
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene != null else ""
	_scene_label.text = "Current: " + (path.get_file().get_basename() if not path.is_empty() else "No scene")
	_skip_intro_button.disabled = scene == null or not scene.has_method("finish_fade_immediately")


func _skip_next_scene() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for index in range(SCENES.size() - 1):
		if SCENES[index]["path"] == scene.scene_file_path:
			jump_to_scene(SCENES[index + 1]["path"])
			return
	_status_label.text = "No next scene yet. Use a scene button above."


func _reload_scene() -> void:
	var scene := get_tree().current_scene
	if scene != null and not scene.scene_file_path.is_empty():
		jump_to_scene(scene.scene_file_path)


## The gem save screen without a gem: the file restarts the player where they stood.
func _open_save_screen() -> void:
	var player := get_tree().get_first_node_in_group("player") as FirstPersonPlayer
	if player == null or get_tree().current_scene == null:
		_status_label.text = "There's no player in this scene to save."
		return
	set_open(false)
	# The file's picture is the game view, so wait for a frame drawn without this menu.
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	if not is_instance_valid(player):
		return
	var thumbnail := SaveGame.capture_thumbnail()
	player.freeze()
	var save := func(slot: int) -> bool: return SaveGame.save_here(player, slot, thumbnail)
	var screen := SaveSlotScreen.open(get_tree().root, SaveSlotScreen.Mode.SAVE, save, true, true)
	screen.closed.connect(func() -> void:
		if is_instance_valid(player):
			player.unfreeze()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)


func _open_load_screen() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	set_open(false)
	var mouse_mode := Input.mouse_mode
	var screen := SaveSlotScreen.open(scene, SaveSlotScreen.Mode.LOAD, _load_slot, true, true)
	screen.closed.connect(func() -> void: Input.mouse_mode = mouse_mode)


func _load_slot(slot: int) -> bool:
	var error: Error = await SaveGame.load_slot(slot)
	if error != OK:
		return false
	# The old scene takes the load screen with it, so release its pause here.
	get_tree().paused = false
	return true


func _skip_forest_intro() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("finish_fade_immediately"):
		scene.call("finish_fade_immediately")
		set_open(false)


func _jump_to_checkpoint(checkpoint: String) -> void:
	if not _loading_path.is_empty():
		return
	_pending_checkpoint = checkpoint
	jump_to_scene(FOREST_PATH)
	if _loading_path.is_empty():
		_pending_checkpoint = ""


func _jump_to_map_checkpoint(checkpoint: String) -> void:
	if not _loading_path.is_empty():
		return
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == MAP_PATH:
		set_open(false)
		apply_map_checkpoint(scene, checkpoint)
		return
	_pending_checkpoint = checkpoint
	jump_to_scene(MAP_PATH)
	if _loading_path.is_empty():
		_pending_checkpoint = ""


## Hospital: places the player inside the entrance, facing down the corridor. Walking in advances
## the story to the hospital stage as normal play would.
## Carrie's house: places the player on the porch, facing the open front door, with the story set
## back to finding Carrie's notebook so the house plays again. Saving stops for that session.
func apply_map_checkpoint(scene: Node, checkpoint: String) -> void:
	var player := scene.get_node_or_null("Player") as FirstPersonPlayer
	if player == null:
		return
	if player.is_hidden():
		player.hiding_spot.call("force_out")
	var target := Vector3.INF
	match checkpoint:
		"hospital":
			var hospital := scene.get_node_or_null("Buildings/NeighborhoodHospital") as Node3D
			if hospital == null:
				return
			if not player.has_item(PlayerInventory.FLASHLIGHT_ITEM):
				player.inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM)
			player.global_position = hospital.to_global(Vector3(-10.2, 0.2, -2.6))
			target = hospital.to_global(Vector3(5, 0.2, -4.15))
		"carrie_house":
			var house := scene.get_node_or_null("Buildings/ResidentialLots/CarrieHouse") as Node3D
			var story := scene.get_node_or_null("OpeningStory")
			if house == null or story == null:
				return
			story.call("debug_replay_house")
			player.global_position = house.call("point", &"porch") + Vector3.UP * 0.1
			target = house.call("point", &"front_door")
		_:
			return
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(target.x, player.global_position.y, target.z), Vector3.UP)
	player.head.rotation.x = 0.0
	player.snap_to_ground.call_deferred()


func jump_to_scene(path: String) -> void:
	if not OS.is_debug_build() or not _loading_path.is_empty():
		return
	if not ResourceLoader.exists(path, "PackedScene"):
		_status_label.text = "Scene not found: " + path
		return
	_loading_path = path
	for button in _buttons:
		button.disabled = true
	_status_label.text = "Loading " + path.get_file() + "..."
	_jump_with_loading_screen.call_deferred(path)


func _jump_with_loading_screen(path: String) -> void:
	var error := await SceneLoader.change_to(path, _finish_scene_jump)
	if error != OK:
		_pending_checkpoint = ""
		_finish_loading("Scene change failed: " + error_string(error))


func _finish_scene_jump(_scene: Node) -> void:
	_finish_loading("")
	_on_scene_changed()


func _finish_loading(message: String) -> void:
	_loading_path = ""
	for button in _buttons:
		button.disabled = false
	_refresh_scene_label()
	_status_label.text = message


func _on_scene_changed() -> void:
	if not _loading_path.is_empty():
		return
	# Also release pause ownership if another system replaces the scene while open.
	if opened:
		set_open(false)
	_refresh_scene_label()
	if not _pending_checkpoint.is_empty():
		var checkpoint := _pending_checkpoint
		_pending_checkpoint = ""
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path == FOREST_PATH:
			if checkpoint == "gas_station" and scene.has_method("debug_jump_to_gas_station"):
				scene.call("debug_jump_to_gas_station")
			elif scene.has_method("debug_jump_to_log"):
				scene.call("debug_jump_to_log", checkpoint == "after_log")
		elif scene != null and scene.scene_file_path == MAP_PATH:
			# Wait one frame so the story's saved-checkpoint restore has already run.
			apply_map_checkpoint.call_deferred(scene, checkpoint)
