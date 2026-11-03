extends Node

# Keep only the next scene. Completed obsolete requests are retrieved and released.
var _target := ""
var _packed: PackedScene
var _pending: Dictionary = {}
var _load_error: Error = OK
var _changing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func prefetch(path: String) -> Error:
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		return ERR_FILE_NOT_FOUND
	if path == _target and (_packed != null or _pending.has(path)):
		return OK
	_target = path
	_packed = null
	_load_error = OK
	if _pending.has(path):
		return OK
	# Avoid extra worker threads competing with the currently running scene.
	var error := ResourceLoader.load_threaded_request(path, "PackedScene", false)
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

func change_to(path: String) -> Error:
	if _changing:
		return ERR_BUSY
	_changing = true
	var error := prefetch(path)
	if error == OK:
		while _pending.has(path) and _target == path:
			await get_tree().process_frame
		if _target != path:
			error = ERR_SKIP
		elif _packed == null:
			error = _load_error if _load_error != OK else ERR_CANT_OPEN
		else:
			var scene := _packed
			cancel_prefetch()
			error = get_tree().change_scene_to_packed(scene)
	_changing = false
	if error != OK:
		push_error("Scene transition failed: %s (%s)" % [path, error])
	return error
