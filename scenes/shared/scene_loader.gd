extends Node

# These scenes were checked with dependency workers. Residence stalls in this mode.
const PARALLEL_LOAD_SCENES := [
	"res://scenes/chapters/intro/intro.tscn",
	"res://scenes/chapters/tutorial/tutorial.tscn",
	"res://scenes/chapters/main/starting_forest.tscn",
]

# Keep only the next scene. Completed obsolete requests are retrieved and released.
var _target := ""
var _packed: PackedScene
var _pending: Dictionary = {}
var _load_error: Error = OK
var _changing := false
var _overlay: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	set_process_input(false)

func _input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()

func prefetch(path: String, use_sub_threads: bool = false) -> Error:
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		return ERR_FILE_NOT_FOUND
	if path == _target and (_packed != null or _pending.has(path)):
		return OK
	_target = path
	_packed = null
	_load_error = OK
	if _pending.has(path):
		return OK
	# Speculative requests use one worker so they compete less with gameplay.
	var error := ResourceLoader.load_threaded_request(path, "PackedScene", use_sub_threads)
	if error != OK:
		_load_error = error
		return error
	_pending[path] = true
	set_process(true)
	return OK

func cancel_prefetch() -> void:
	_target = ""
	_packed = null

func is_ready(path: String) -> bool:
	return path == _target and _packed != null

func is_loading() -> bool:
	return _changing

func _process(_delta: float) -> void:
	for path: String in _pending.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			# Only retrieve completed requests, so this never waits for disk loading.
			var loaded := ResourceLoader.load_threaded_get(path) as PackedScene
			if path == _target:
				_packed = loaded
				if loaded == null:
					_load_error = ERR_INVALID_DATA
		elif path == _target:
			_load_error = ERR_CANT_OPEN
		_pending.erase(path)
	set_process(not _pending.is_empty())

## Run scene-specific setup while the destination is still covered.
func change_to(path: String, before_reveal: Callable = Callable()) -> Error:
	if _changing:
		return ERR_BUSY
	var error := prefetch(path, path in PARALLEL_LOAD_SCENES)
	if error != OK:
		return error
	_changing = true
	var tree := get_tree()
	var was_paused := tree.paused
	tree.paused = true
	_show_loading_screen()
	await _draw_frame()
	while _pending.has(path) and _target == path:
		await tree.process_frame
	if _target != path:
		error = ERR_SKIP
	elif _packed == null:
		error = _load_error if _load_error != OK else ERR_CANT_OPEN
	else:
		var scene := _packed
		cancel_prefetch()
		error = tree.change_scene_to_packed(scene)
		if error == OK:
			await tree.scene_changed
			if before_reveal.is_valid():
				await before_reveal.call(tree.current_scene)
			# Present the restored view before gameplay can move the player or camera.
			_overlay.hide()
			await _draw_frame()
	if not was_paused:
		tree.paused = false
	_overlay.queue_free()
	_overlay = null
	set_process_input(false)
	_changing = false
	if error != OK:
		push_error("Scene transition failed: %s (%s)" % [path, error])
	return error

func _show_loading_screen() -> void:
	var last_frame: Image
	if DisplayServer.get_name() != "headless" and get_tree().get_first_node_in_group("player") != null:
		last_frame = get_viewport().get_texture().get_image()
	_overlay = CanvasLayer.new()
	_overlay.name = "LoadingScreen"
	_overlay.layer = 500
	add_child(_overlay)
	var background := ColorRect.new()
	background.color = Color.BLACK
	_overlay.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if last_frame != null and not last_frame.is_empty():
		var snapshot := TextureRect.new()
		snapshot.texture = ImageTexture.create_from_image(last_frame)
		snapshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		snapshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.add_child(snapshot)
		snapshot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.text = "LOADING..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	background.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process_input(true)

func _draw_frame() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
