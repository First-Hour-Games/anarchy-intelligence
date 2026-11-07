extends Node
## Gem save points for the main path (starting forest and residence area), in four slots.
##
## A SaveGem opens the save screen (scenes/ui/save_slots/save_slot_screen.gd); picking a file
## calls save_at(), which writes the player's state (position, items, abilities, flashlight,
## health), the state of the map section the gem stands in (pickups taken, interactables used,
## one-shot cutscenes played, plus whatever the section's own script reports through
## get_save_state()), the play time and a screenshot. Load Game on the main menu opens the same
## screen to pick a file, then load_slot() loads that section and puts it all back; the section
## can skip its opening by checking is_restoring(). Death returns the player to the last gem used
## (through CombatHealth.spawn, when present).
##
## The map.tscn opening chapter keeps its own save (opening_story.gd).

signal saved(slot: int)

const SLOT_COUNT := 4
const SAVE_DIR := "user://saves"
const VERSION := 1
## The single save written before there were slots; moved into file 01 on first run.
const LEGACY_SAVE := "user://save_game_v1.json"
const THUMBNAIL_SIZE := Vector2i(320, 240)
const PLAYER_PROPERTIES: Array[String] = ["sprint_enabled", "jump_enabled", "crouch_enabled", "inventory_enabled", "stamina"]
const AREA_NAMES: Dictionary = {
	"res://scenes/chapters/main/starting_forest.tscn": "Starting Forest",
	"res://scenes/chapters/main/residence_area.tscn": "Residence",
}
## Scenes where the play-time clock does not run.
const MENU_SCENES: Array[String] = ["res://scenes/mainMenu/menu.tscn", "res://scenes/mainMenu/startup.tscn"]

var save_dir: String = SAVE_DIR
## Total play time of the current playthrough, in seconds. Loading a file restores it.
var play_time: float = 0.0
## The last gem's respawn point this session, for death handling.
var respawn_transform: Transform3D = Transform3D.IDENTITY
var has_respawn: bool = false
## One-time introduction to the first gas-station save point, per playthrough.
var first_save_dialogue_seen: bool = false
var _pending: Dictionary = {}
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_toast()
	_migrate_legacy_save()


func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != null and not get_tree().paused and not MENU_SCENES.has(scene.scene_file_path):
		play_time += delta


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [save_dir, slot + 1]


func thumbnail_path(slot: int) -> String:
	return "%s/slot_%d.png" % [save_dir, slot + 1]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func has_any_save() -> bool:
	for slot in SLOT_COUNT:
		if has_save(slot):
			return true
	return false


func read_slot(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if not data is Dictionary or int(data.get("version", 0)) != VERSION:
		return {}
	if str(data.get("gem", "")) == "GasStationSaveGem" and str(data.get("location", "")) == "Gas Station":
		data["location"] = "Town Entrance"
	return data


func load_thumbnail(slot: int) -> Texture2D:
	var path := thumbnail_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image) if image != null else null


func delete_slot(slot: int) -> Error:
	for path in [slot_path(slot), thumbnail_path(slot)]:
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(path)
			if error != OK:
				return error
	return OK


func delete_all() -> Error:
	has_respawn = false
	for slot in SLOT_COUNT:
		var error := delete_slot(slot)
		if error != OK:
			return error
	return OK


## Called when a new game starts from the menu.
func start_new_game() -> void:
	first_save_dialogue_seen = false
	play_time = 0.0
	has_respawn = false
	_pending = {}


## True while Load Game is loading this scene, so the scene can skip its opening sequence.
func is_restoring(scene_path: String) -> bool:
	return not _pending.is_empty() and str(_pending.get("scene", "")) == scene_path


## The current view, cropped to the game's 4:3 picture and shrunk for a save file thumbnail.
func capture_thumbnail() -> Image:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return null
	var size := image.get_size()
	var crop := Vector2i(mini(size.x, size.y * 4 / 3), mini(size.y, size.x * 3 / 4))
	image = image.get_region(Rect2i((size - crop) / 2, crop))
	image.resize(THUMBNAIL_SIZE.x, THUMBNAIL_SIZE.y, Image.INTERPOLATE_BILINEAR)
	return image


## Saves at a gem into a slot. Returns false if nothing could be written.
func save_at(gem: Node3D, player: FirstPersonPlayer, slot: int, thumbnail: Image = null) -> bool:
	var section := _section_of(gem)
	if section == null:
		return false
	return _write_save(section, gem.call("get_respawn_transform"), str(gem.get("area_name")), str(gem.get("location_name")),
		str(section.get_path_to(gem)), player, slot, thumbnail)


## Saves where the player stands, without a gem (the debug menu). Loading it puts the player back there.
func save_here(player: FirstPersonPlayer, slot: int, thumbnail: Image = null) -> bool:
	var section := get_tree().current_scene as Node3D
	if section == null or not is_instance_valid(player):
		return false
	return _write_save(section, player.global_transform, "", "Debug save", "", player, slot, thumbnail)


func _write_save(section: Node3D, respawn: Transform3D, area: String, location: String, gem_path: String,
		player: FirstPersonPlayer, slot: int, thumbnail: Image) -> bool:
	if section.scene_file_path.is_empty() or not is_instance_valid(player):
		return false
	if slot < 0 or slot >= SLOT_COUNT:
		return false
	if area.is_empty():
		area = AREA_NAMES.get(section.scene_file_path, section.scene_file_path.get_file().get_basename().capitalize())
	var now := Time.get_datetime_dict_from_system()
	var data := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"saved_label": "%02d/%02d/%02d %02d:%02d" % [now.year % 100, now.month, now.day, now.hour, now.minute],
		"play_time": play_time,
		"first_save_dialogue_seen": first_save_dialogue_seen,
		"area": area,
		"location": location,
		"scene": section.scene_file_path,
		"gem": gem_path,
		"respawn": _transform_to_array(respawn),
		"player": _capture_player(player),
		"section": _capture_section(section),
		"story": {},
	}
	if section.has_method("get_save_state"):
		data["story"] = section.call("get_save_state")
	DirAccess.make_dir_recursive_absolute(save_dir)
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_warning("Could not write the save: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if thumbnail != null:
		thumbnail.save_png(thumbnail_path(slot))
	elif FileAccess.file_exists(thumbnail_path(slot)):
		DirAccess.remove_absolute(thumbnail_path(slot))
	_set_respawn(player, respawn)
	saved.emit(slot)
	return true


## Loads a slot's section and restores it. Returns the scene change result.
func load_slot(slot: int) -> Error:
	if SceneLoader.is_loading():
		return ERR_BUSY
	var data := read_slot(slot)
	if data.is_empty():
		return ERR_FILE_CORRUPT
	var path := str(data.get("scene", ""))
	if not ResourceLoader.exists(path, "PackedScene"):
		return ERR_FILE_NOT_FOUND
	_pending = data
	var error: Error = await SceneLoader.change_to(path, _restore_loaded_scene)
	if error != OK:
		_pending = {}
	return error


static func format_play_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]


func show_message(text: String) -> void:
	_toast.text = text
	if is_instance_valid(_toast_tween) and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.35)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.9)


func _migrate_legacy_save() -> void:
	if not FileAccess.file_exists(LEGACY_SAVE) or has_save(0):
		return
	DirAccess.make_dir_recursive_absolute(save_dir)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_SAVE))
	if data is Dictionary:
		data["saved_label"] = str(data.get("saved_at", "")).replace("T", " ").substr(2, 14).replace("-", "/")
		data["area"] = AREA_NAMES.get(str(data.get("scene", "")), "")
		data["location"] = "Town Entrance" if str(data.get("gem", "")) == "GasStationSaveGem" else ""
		var file := FileAccess.open(slot_path(0), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(data, "\t"))
			file.close()
			DirAccess.remove_absolute(LEGACY_SAVE)


func _restore_loaded_scene(scene: Node) -> void:
	var data := _pending
	_pending = {}
	play_time = float(data.get("play_time", 0.0))
	await _restore(scene, data)


func _restore(scene: Node, data: Dictionary) -> void:
	# Existing saves already passed the first opportunity to introduce saving.
	first_save_dialogue_seen = bool(data.get("first_save_dialogue_seen", true))
	var player := scene.get_node_or_null("Player") as FirstPersonPlayer
	if scene.has_method("restore_save_state"):
		# Untyped, so a restore that waits on frames is awaited properly.
		var section: Variant = scene
		await section.restore_save_state(data.get("story", {}))
	if not is_instance_valid(scene) or not is_instance_valid(player):
		return
	_restore_section(scene, data.get("section", {}))
	_restore_player(player, data.get("player", {}))
	var respawn := _array_to_transform(data.get("respawn", []))
	player.global_transform = respawn
	player.velocity = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.snap_to_ground()
	_set_respawn(player, respawn)
	player.unfreeze()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _capture_player(player: FirstPersonPlayer) -> Dictionary:
	var items: Array[String] = []
	for slot in PlayerInventory.SLOT_COUNT:
		items.append(str(player.inventory.get_item(slot)))
	var state := {
		"items": items,
		"selected_slot": player.inventory.selected_slot_index,
		"flashlight_on": is_instance_valid(player.flashlight) and player.flashlight.is_enabled(),
	}
	for property in PLAYER_PROPERTIES:
		state[property] = player.get(property)
	var health := player.get_node_or_null("CombatHealth")
	var weapon := player.get_node_or_null("Head/Camera3D/PipeWeapon")
	if weapon != null:
		state["pipe_equipped"] = bool(weapon.get("equipped"))
	if health != null:
		state["health"] = health.get("health")
	return state


func _restore_player(player: FirstPersonPlayer, state: Dictionary) -> void:
	var wanted: Dictionary = {}
	for item: Variant in state.get("items", []):
		var id := StringName(str(item))
		if id != PlayerInventory.EMPTY_ITEM:
			wanted[id] = int(wanted.get(id, 0)) + 1
	for id: StringName in wanted:
		while player.inventory.get_count(id) < int(wanted[id]):
			if not player.inventory.add_item(id):
				break
	player.inventory.select_slot(int(state.get("selected_slot", 0)))
	var weapon := player.get_node_or_null("Head/Camera3D/PipeWeapon")
	if weapon != null:
		weapon.set_equipped(bool(state.get("pipe_equipped", player.inventory.has_item(&"metal_pipe"))))
	for property in PLAYER_PROPERTIES:
		if state.has(property):
			player.set(property, state[property])
	player.stamina_changed.emit(player.stamina, player.max_stamina)
	if is_instance_valid(player.flashlight):
		player.flashlight.set_enabled(bool(state.get("flashlight_on", false)), false)
	var health := player.get_node_or_null("CombatHealth")
	if health != null and state.has("health"):
		health.set("health", minf(float(state.health), float(health.get("max_health"))))
		health.emit_signal("health_changed", health.get("health"))
		health.call("_refresh")


## The same section state WorldStreaming keeps when a section unloads, as plain paths.
func _capture_section(section: Node) -> Dictionary:
	var state := {"pickups_present": [], "inventory_pickups_present": [], "metal_gates": {}, "interactables": {}, "one_shot_cutscenes": {}}
	state["inventory_pickups_version"] = 2
	for node in section.find_children("*", "FlashlightPickup", true, false):
		state.pickups_present.append(str(section.get_path_to(node)))
	for node in section.find_children("*", "InventoryPickup", true, false):
		if not node.is_queued_for_deletion():
			state.inventory_pickups_present.append(str(section.get_path_to(node)))
	for gate in section.find_children("*", "RiggedMetalGate", true, false):
		state.metal_gates[str(section.get_path_to(gate))] = gate.get_save_state()
	for node in section.find_children("*", "InteractableBlock3D", true, false):
		state.interactables[str(section.get_path_to(node))] = node.get("is_enabled")
	for cutscene in get_tree().get_nodes_in_group("streaming_one_shot"):
		if section.is_ancestor_of(cutscene):
			state.one_shot_cutscenes[str(section.get_path_to(cutscene))] = cutscene.get("has_played")
	state["dead_story_mobs"] = {}
	for mob in get_tree().get_nodes_in_group("story_mob"):
		if section.is_ancestor_of(mob) and bool(mob.get("dead")):
			state.dead_story_mobs[str(section.get_path_to(mob))] = _transform_to_array(mob.global_transform)
	return state


func _restore_section(section: Node, state: Dictionary) -> void:
	if state.has("pickups_present"):
		var present: Array = state.pickups_present
		for node in section.find_children("*", "FlashlightPickup", true, false):
			if present.has(str(section.get_path_to(node))):
				continue
			var visual := node.get_node_or_null(node.get("visual_target_path")) as Node3D
			if visual != null and visual != section:
				visual.hide()
			node.queue_free()
	if state.has("inventory_pickups_present"):
		var present: Array = state.inventory_pickups_present
		for node in section.find_children("*", "InventoryPickup", true, false):
			# Saves made before the pipe became a pickup must leave it available.
			if node.get("item_id") == &"metal_pipe" and int(state.get("inventory_pickups_version", 1)) < 2:
				continue
			if not present.has(str(section.get_path_to(node))):
				node.hide()
				node.queue_free()
	var interactables: Dictionary = state.get("interactables", {})
	for path: String in interactables:
		var node := section.get_node_or_null(NodePath(path))
		if node != null:
			node.set("is_enabled", interactables[path])
	var cutscenes: Dictionary = state.get("one_shot_cutscenes", {})
	for path: String in cutscenes:
		var node := section.get_node_or_null(NodePath(path))
		if node != null:
			node.set("has_played", cutscenes[path])
	for path: String in state.get("metal_gates", {}):
		var gate := section.get_node_or_null(NodePath(path))
		if gate != null:
			gate.restore_save_state(state.metal_gates[path])
	var dead_mobs: Dictionary = state.get("dead_story_mobs", {})
	for path: String in dead_mobs:
		var mob := section.get_node_or_null(NodePath(path))
		var at: Array = dead_mobs[path]
		if mob != null and mob.has_method("restore_dead") and at.size() >= 4:
			mob.restore_dead(Vector3(float(at[0]), float(at[1]), float(at[2])), float(at[3]))


func _set_respawn(player: FirstPersonPlayer, respawn: Transform3D) -> void:
	respawn_transform = respawn
	has_respawn = true
	var health := player.get_node_or_null("CombatHealth")
	if health != null:
		health.set("spawn", respawn)


## The map section (current scene or streamed section) that a node belongs to.
func _section_of(node: Node) -> Node3D:
	var root := get_tree().root
	while node != null and node.get_parent() != root:
		node = node.get_parent()
	return node as Node3D


func _transform_to_array(t: Transform3D) -> Array:
	return [t.origin.x, t.origin.y, t.origin.z, t.basis.get_euler().y]


func _array_to_transform(values: Array) -> Transform3D:
	if values.size() < 4:
		return Transform3D.IDENTITY
	return Transform3D(Basis(Vector3.UP, float(values[3])), Vector3(float(values[0]), float(values[1]), float(values[2])))


func _build_toast() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 120
	add_child(canvas)
	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_left = -260
	_toast.offset_right = 260
	_toast.offset_top = -120
	_toast.offset_bottom = -80
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	_toast.add_theme_color_override("font_shadow_color", Color.BLACK)
	_toast.add_theme_constant_override("shadow_offset_x", 2)
	_toast.add_theme_constant_override("shadow_offset_y", 2)
	var font := load("res://fonts/JainiPurva.ttf") as Font
	if font != null:
		_toast.add_theme_font_override("font", font)
	_toast.modulate.a = 0.0
	canvas.add_child(_toast)
