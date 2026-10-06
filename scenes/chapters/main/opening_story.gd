extends Node

const DOCUMENT := preload("res://scenes/items/story_document.gd")
const NOTEBOOK_VISUAL := preload("res://scenes/items/carrie_notebook.tscn")
const SAVE_PATH := "user://opening_story_v1.json"
@export var persist_progress: bool = true
@export var progress_save_path: String = SAVE_PATH
const OBJECTIVES: Array[String] = [
	"Search the gas station for someone who can help.",
	"Find Carrie's notebook on the second floor.",
	"Reach the hospital. Carrie believed it was safe.",
	"Search the hospital registration book for Carrie.",
	"Find the evacuation notice in staff records.",
	"Carrie left with the evacuation. Opening chapter complete.",
]
var stage: int = 0
var discovered: Dictionary = {}
var spoken: Dictionary = {}
var journal: Array[String] = []
var player: FirstPersonPlayer
var objective: Control
var subtitle: Label
var reader: PanelContainer
var reader_text: RichTextLabel
var subtitle_queue: Array[String] = []
var subtitle_time: float = 0.0
var checkpoint := Transform3D.IDENTITY
var document_open: bool = false
var target_position := Vector3(158, 0, 38.7)
var _flashlight_seen: bool = false
var _restored: bool = false
var restart_button: Button

func _ready() -> void:
	PauseMenu.has_started_chapter = true
	add_to_group("opening_story")
	player = get_parent().get_node("Player") as FirstPersonPlayer
	_build_hud()
	_build_documents()
	checkpoint = player.global_transform
	player.inventory.inventory_changed.connect(_inventory_changed)
	if is_instance_valid(player) and is_instance_valid(player.inventory) and not player.inventory.has_item(PlayerInventory.MAP_ITEM):
		player.inventory.add_item(PlayerInventory.MAP_ITEM)
	_restore()
	_refresh_objective()
	if not _restored:
		narrate_once("arrival", "The visitor center's map should help. That voice told me to come home... I'll check Carrie's place.")
		narrate_once("barrier", "The road is blocked. I'll have to walk. Maybe someone at the gas station can help.")
	call_deferred("_sync_encounters")
	call_deferred("_refresh_objective")

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 101
	add_child(canvas)
	var safe := AspectRatioContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.ratio = 4.0 / 3.0
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(safe)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(root)
	objective = Control.new()
	objective.set_script(preload("res://scenes/ui/quest_tracker.gd"))
	objective.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	objective.offset_left = -350
	objective.offset_top = 34
	objective.offset_right = -24
	objective.offset_bottom = 140
	root.add_child(objective)
	subtitle = Label.new()
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.offset_left = 48
	subtitle.offset_right = -48
	subtitle.offset_top = -200
	subtitle.offset_bottom = -135
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 21)
	subtitle.add_theme_color_override("font_shadow_color", Color.BLACK)
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(subtitle)
	reader = PanelContainer.new()
	reader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reader.anchor_left = 0.12
	reader.anchor_right = 0.88
	reader.anchor_top = 0.15
	reader.anchor_bottom = 0.8
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.105, 0.10, 0.98)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	reader.add_theme_stylebox_override("panel", style)
	root.add_child(reader)
	var column := VBoxContainer.new()
	reader.add_child(column)
	reader_text = RichTextLabel.new()
	reader_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reader_text.add_theme_font_size_override("normal_font_size", 21)
	column.add_child(reader_text)
	var close := Button.new()
	close.text = "Close / continue"
	close.pressed.connect(close_document)
	column.add_child(close)
	restart_button = Button.new()
	restart_button.text = "Restart opening chapter"
	restart_button.pressed.connect(_restart_chapter)
	column.add_child(restart_button)
	reader.hide()

func _build_documents() -> void:
	var house := get_parent().get_node("Buildings/ResidentialLots/WestStubBrickHouse") as Node3D
	_document(house, Vector3(10.5, 1.45, 12.55), &"door_note", "A note at Carrie's door", "My notebook is on the second floor, under something...\n\n- Carrie", Color(0.76, 0.7, 0.53))
	_mount_entrance_note.call_deferred(house)
	# Hide the notebook in the upstairs storage corner.
	_document(house, Vector3(14.0, 3.9952, 7.0), &"carrie", "Carrie's notebook", "They are telling everyone to go to the hospital. They say it is safe there. I can't stay in this house any longer.\n\nIf anyone comes looking for me, that's where I've gone.\n\n— Carrie", Color(0.31, 0.18, 0.12))
	var table := CSGBox3D.new()
	table.name = "AtticNotebookCrate"
	table.position = Vector3(14.0, 3.7712, 7.0)
	table.size = Vector3(0.6, 0.4, 0.5)
	table.use_collision = true
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.24, 0.17, 0.11)
	table.material = wood
	house.add_child(table)
	var hospital := get_parent().get_node("Buildings/NeighborhoodHospital") as Node3D
	_document(hospital, Vector3(-14, 1.3425, -1.9), &"register", "Emergency shelter registration", "TEMPORARY SHELTER — ARRIVALS\n\nCarrie — admitted to the treatment ward. Personal belongings retained.\n\nLater entry: Shelter closed. Remaining residents transferred with the evacuation party. See staff records for departure instructions.", Color(0.73, 0.68, 0.48))
	_document(hospital, Vector3(11, 1.0425, -7.6), &"evacuation", "Evacuation notice", "THE HOSPITAL IS NO LONGER SAFE.\n\nMove residents out before nightfall. The last group, including Carrie, departed with the evacuation party.\n\nDo not follow voices calling from empty rooms.\n\n[The destination has been torn from the page.]", Color(0.76, 0.74, 0.64))
	_document(hospital, Vector3(-12, 1.82, -8.3), &"supply", "Medical stores log", "Most supplies went with the evacuation.\n\nKeep footsteps quiet. Something responds to movement in the corridor. Keep still when it is near and use the partitions for cover.", Color(0.57, 0.65, 0.58))

func _mount_entrance_note(house: Node3D) -> void:
	for i in 3:
		await get_tree().physics_frame
	var note := house.get_node("EntranceNote") as Node3D
	var ray := PhysicsRayQueryParameters3D.create(house.to_global(Vector3(10.5, 1.45, 13)), house.to_global(Vector3(10.5, 1.45, 7)))
	ray.exclude = [player.get_rid()]
	var hit := house.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var normal: Vector3 = hit.normal
		note.global_position = hit.position + normal * 0.012
		note.look_at(note.global_position + normal, Vector3.UP, true)
		note.set_meta("wall_mounted", true)

func _document(parent: Node3D, point: Vector3, id: StringName, title: String, words: String, color: Color) -> void:
	var doc := Node3D.new()
	doc.set_script(DOCUMENT)
	doc.set("document_id", id)
	doc.set("title", title)
	doc.set("body", words)
	doc.set("interaction_distance", 2.6)
	doc.name = "EntranceNote" if id == &"door_note" else str(id).capitalize() + "Document"
	parent.add_child(doc)
	doc.position = point
	var mesh := MeshInstance3D.new()
	var book := BoxMesh.new()
	book.size = Vector3(0.26, 0.34, 0.007) if id == &"door_note" else Vector3(0.32, 0.045, 0.24)
	mesh.mesh = book
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	if id == &"carrie":
		doc.add_child(NOTEBOOK_VISUAL.instantiate())
		mesh.free()
	else:
		doc.add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = Color(0.93, 0.8, 0.55)
	light.light_energy = 0.25
	light.omni_range = 2.3
	light.position.y = 0.35
	doc.add_child(light)
	var label := Label3D.new()
	label.text = title
	label.font_size = 24
	label.pixel_size = 0.002
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 0.22
	if id == &"door_note":
		label.text = "NOTEBOOK ON\nSECOND FLOOR\nUNDER SOMETHING...\n- Carrie"
		label.font_size = 26
		label.pixel_size = 0.0007
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.position = Vector3(0, 0, 0.006)
		label.modulate = Color(0.12, 0.09, 0.06)
		label.outline_size = 0
	doc.add_child(label)

func _process(delta: float) -> void:
	if document_open or not is_instance_valid(player):
		return
	subtitle_time = maxf(0.0, subtitle_time - delta)
	if subtitle_time <= 0.0:
		subtitle.text = ""
		if not subtitle_queue.is_empty():
			subtitle.text = subtitle_queue.pop_front()
			subtitle_time = maxf(4.0, subtitle.text.length() * 0.055)
	var p := player.global_position
	_near("station", p, Vector3(153, 0, 35), 12, "Nobody here either. A flashlight would help with those dark houses.")
	var house := get_parent().get_node("Buildings/ResidentialLots/WestStubBrickHouse") as Node3D
	_near("house", p, house.to_global(Vector3(11.75, 0, 12)), 9, "Carrie? It's Thomas. What happened here? This place is a mess.")
	_near("notebook_hint", p, house.to_global(Vector3(14, 3.57, 7)), 2.5, "A notebook tucked away up here. That's Carrie's handwriting.")
	_near("hospital", p, Vector3(255.2, 0, 247), 7, "They were sheltering people here. So why is it empty?")
	_near("old_street", p, Vector3(100, 0, 80), 14, "I used to walk this way after school. I've never heard it this quiet.")
	_near("west_road", p, Vector3(30, 0, 125), 16, "Carrie's house is at the end of this road. I hope she stayed inside.")
	if stage >= 2:
		_near("hospital_route", p, Vector3(100, 0, 190), 14, "Everyone went to the hospital. That would explain the empty houses.")
		_near("shelter_approach", p, Vector3(205, 0, 225), 14, "If Carrie got here, there should be a record of her somewhere.")
	if stage < 3 and p.distance_to(Vector3(255.2, 0.5, 246)) < 8:
		stage = 3
		_set_checkpoint(Vector3(255.2, 0.35, 246))
		_refresh_objective()
		_sync_encounters()
		_save()
	var wrapper := get_parent().get_node("Wrapper") as Node3D
	if stage >= 1 and p.distance_to(wrapper.global_position) < 20:
		narrate_once("wrapper_rule", "That thing was farther away a moment ago. It moves when I look away.")
	var ridge := get_parent().get_node("THE_RIDGEBACK") as Node3D
	if ridge.visible and p.distance_to(ridge.global_position) < 17:
		narrate_once("ridge", "Something's watching me. It keeps its distance... but it's following.")
	if float(ridge.get("light_fear")) > 0.0:
		narrate_once("ridge_light", "It's backing away from the light. I should keep the beam on it, or stay near a lamp.")

func _near(id: String, p: Vector3, point: Vector3, radius: float, words: String) -> void:
	if p.distance_to(point) < radius:
		narrate_once(id, words)

func narrate_once(id: String, words: String) -> void:
	if spoken.has(id):
		return
	spoken[id] = true
	subtitle_queue.append("Thomas: " + words)

func _inventory_changed() -> void:
	if _flashlight_seen or not player.inventory.has_item(PlayerInventory.FLASHLIGHT_ITEM):
		return
	_flashlight_seen = true
	stage = maxi(stage, 1)
	narrate_once("flashlight", "This still works. I'll take it. Carrie lives at the corner at the far end of the west road.")
	journal.append("Found a flashlight at the gas station.")
	_set_checkpoint(Vector3(150, 0.35, 39))
	_refresh_objective()
	_sync_encounters()
	_save()

func open_document(id: StringName, title: String, words: String) -> void:
	if document_open:
		return
	var health := player.get_node_or_null("CombatHealth")
	if health != null and bool(health.get("is_dead")):
		return
	document_open = true
	player.freeze()
	get_tree().set_group("story_mob", "suspended", true)
	reader_text.text = title + "\n\n" + words
	restart_button.visible = id == &"journal"
	reader.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if id != &"journal" and not discovered.has(str(id)):
		discovered[str(id)] = true
		journal.append(title + "\n" + words)
		match id:
			&"carrie":
				player.inventory.add_item(PlayerInventory.NOTEBOOK_ITEM)
				stage = maxi(stage, 2)
				narrate_once("carrie_read", "The hospital. She thought it was safe. Maybe she's still there.")
				var house := get_parent().get_node("Buildings/ResidentialLots/WestStubBrickHouse") as Node3D
				_set_checkpoint(house.to_global(Vector3(11.75, 0.35, 12.5)))
			&"register":
				stage = maxi(stage, 4)
				narrate_once("register_read", "She made it here. They evacuated her... the staff records might say where.")
			&"evacuation":
				narrate_once("evac_read", "Carrie got out. But that warning about voices... was it the same voice from my dream?")
			&"supply":
				narrate_once("supply_read", "Quiet footsteps. I should keep still and stay out of sight.")
		if discovered.has("register") and discovered.has("evacuation"):
			stage = 5
		_refresh_objective()
		_save()

func close_document() -> void:
	if not document_open:
		return
	document_open = false
	reader.hide()
	player.unfreeze()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().set_group("story_mob", "suspended", false)
	_sync_encounters()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("story_journal") and not event.is_echo():
		if document_open:
			close_document()
		else:
			open_document(&"journal", "Thomas's journal", OBJECTIVES[stage] + "\n\n" + "\n\n".join(journal))
		get_viewport().set_input_as_handled()
	elif document_open and event.is_action_pressed("ui_cancel"):
		close_document()
		get_viewport().set_input_as_handled()

func _refresh_objective() -> void:
	objective.call("set_objective", stage, OBJECTIVES[stage])
	match stage:
		0: target_position = Vector3(158, 0, 38.7)
		1:
			var house := get_parent().get_node("Buildings/ResidentialLots/WestStubBrickHouse") as Node3D
			target_position = house.to_global(Vector3(11.75, 0, 10.25))
		2, 3: target_position = Vector3(255.2, 0, 249)
		4: target_position = Vector3(234, 0, 258.6)
		5: target_position = Vector3.ZERO

func _sync_encounters() -> void:
	get_parent().get_node("Wrapper").set("enabled", stage >= 1)
	get_parent().get_node("Clawman").set("enabled", stage >= 3)
	var ridge := get_parent().get_node("THE_RIDGEBACK") as Node3D
	ridge.set("activation_enabled", _flashlight_seen)
	ridge.visible = _flashlight_seen
	(ridge.get_node("CollisionShape3D") as CollisionShape3D).set_deferred("disabled", not _flashlight_seen)
	for light: Node in get_parent().find_children("*", "OmniLight3D", true, false):
		if not player.is_ancestor_of(light):
			light.add_to_group("ridgeback_repellent")
	var prototype := get_parent().get_node_or_null("RobotKid") as Node3D
	if prototype != null:
		prototype.hide()
		prototype.set_process(false)
		prototype.set_physics_process(false)
		prototype.remove_from_group("corrupted_friend")
		var prototype_collider := prototype.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if prototype_collider != null:
			prototype_collider.set_deferred("disabled", true)
	for name: String in ["THE_RIDGEBACK2", "THE_RIDGEBACK3"]:
		var extra := get_parent().get_node_or_null(name) as Node3D
		if extra != null:
			extra.hide()
			extra.set_physics_process(false)
			extra.remove_from_group("corrupted_friend")
			var collider := extra.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if collider != null:
				collider.set_deferred("disabled", true)

func _set_checkpoint(point: Vector3) -> void:
	checkpoint = player.global_transform
	checkpoint.origin = point
	var health := player.get_node_or_null("CombatHealth")
	if health != null:
		health.set("spawn", checkpoint)

func _save() -> void:
	if not persist_progress:
		return
	var file := FileAccess.open(progress_save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"stage": stage, "discovered": discovered, "spoken": spoken, "journal": journal, "flashlight": _flashlight_seen, "checkpoint": [checkpoint.origin.x, checkpoint.origin.y, checkpoint.origin.z]}))

func _restore() -> void:
	if not persist_progress:
		return
	if not FileAccess.file_exists(progress_save_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(progress_save_path))
	if not data is Dictionary:
		return
	stage = clampi(int(data.get("stage", 0)), 0, 5)
	discovered = data.get("discovered", {})
	spoken = data.get("spoken", {})
	for entry: Variant in data.get("journal", []):
		journal.append(str(entry))
	_flashlight_seen = bool(data.get("flashlight", false))
	if discovered.has("carrie"):
		player.inventory.add_item(PlayerInventory.NOTEBOOK_ITEM)
	if _flashlight_seen:
		player.inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM)
		var pickup := get_parent().get_node_or_null("AtmosphereProps/DroppedFlashlight")
		if pickup != null:
			pickup.queue_free()
	var point: Array = data.get("checkpoint", [])
	if point.size() == 3:
		_set_checkpoint(Vector3(float(point[0]), float(point[1]), float(point[2])))
		player.global_transform = checkpoint
	_restored = true

func _restart_chapter() -> void:
	if FileAccess.file_exists(progress_save_path):
		DirAccess.remove_absolute(progress_save_path)
	get_tree().reload_current_scene()
