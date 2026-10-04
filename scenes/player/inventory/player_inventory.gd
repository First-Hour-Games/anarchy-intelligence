class_name PlayerInventory
extends CanvasLayer

signal inventory_changed
signal selection_changed(slot_index: int, item_id: StringName)
const SLOT_COUNT: int = 6
const EMPTY_ITEM: StringName = &""
const FLASHLIGHT_ITEM: StringName = &"flashlight"
const MAP_ITEM: StringName = &"map"
const NOTEBOOK_ITEM: StringName = &"notebook"
const INK := Color(0.025, 0.037, 0.038, 0.98)
const TEAL := Color(0.27, 0.46, 0.43)
const GOLD := Color(0.82, 0.66, 0.35)
const PAPER := Color(0.84, 0.85, 0.75)

@export var selected_style: StyleBoxFlat
@export var unselected_style: StyleBoxFlat
var selected_slot_index: int = 0
var _items: Array[StringName] = [EMPTY_ITEM, EMPTY_ITEM, EMPTY_ITEM, EMPTY_ITEM, EMPTY_ITEM, EMPTY_ITEM]
var is_open: bool = false
var _was_paused: bool = false
var _previous_mouse: Input.MouseMode
var _overlay: Control
var _cards: Array[Button] = []
var _description: Label
var _title: Label
var _preview: TextureRect
var _paper_preview: Label
var _use: Button
var _status: Label
var _frame: Control
var _page: Control
@onready var _viewport: SubViewport = $ItemPreview
@onready var _player: FirstPersonPlayer = get_parent() as FirstPersonPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	$InventoryBar.hide()
	_viewport.size = Vector2i(640, 480)
	(_viewport.get_node("Camera") as Camera3D).position = Vector3(0, 0.025, 1.2)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_build_screen()
	_update_hud()

func add_item(item_id: StringName) -> bool:
	if item_id == EMPTY_ITEM or has_item(item_id):
		return false
	for slot in SLOT_COUNT:
		if _items[slot] == EMPTY_ITEM:
			_items[slot] = item_id
			select_slot(slot)
			inventory_changed.emit()
			return true
	return false

func has_item(item_id: StringName) -> bool:
	return _items.has(item_id)

func is_full() -> bool:
	return not _items.has(EMPTY_ITEM)

func get_item(slot: int) -> StringName:
	return _items[slot] if slot >= 0 and slot < SLOT_COUNT else EMPTY_ITEM

func get_selected_item() -> StringName:
	return get_item(selected_slot_index)

func select_slot(slot: int) -> void:
	selected_slot_index = clampi(slot, 0, SLOT_COUNT - 1)
	_update_hud()
	selection_changed.emit(selected_slot_index, get_selected_item())

func select_relative(direction: int) -> void:
	select_slot(posmod(selected_slot_index + direction, SLOT_COUNT))

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	var is_toggle: bool = (
		event.is_action_pressed("inventory_toggle")
		or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB))
	)
	if is_toggle:
		if is_open:
			set_open(false)
			get_viewport().set_input_as_handled()
		else:
			var story := get_tree().get_first_node_in_group("opening_story")
			var health := _player.get_node_or_null("CombatHealth") if is_instance_valid(_player) else null
			var cannot_open: bool = (
				not is_instance_valid(_player)
				or _player.is_frozen
				or get_tree().paused
				or (story != null and bool(story.get("document_open")))
				or (health != null and bool(health.get("is_dead")))
			)
			if not cannot_open:
				set_open(true)
				get_viewport().set_input_as_handled()
	elif is_open:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE)):
			set_open(false)
		elif event.is_action_pressed("ui_left"):
			select_relative(-1)
		elif event.is_action_pressed("ui_right"):
			select_relative(1)
		elif event.is_action_pressed("ui_accept"):
			_use_selected()
		else:
			return
		get_viewport().set_input_as_handled()

func set_open(value: bool) -> void:
	if value == is_open:
		return
	if value:
		var story := get_tree().get_first_node_in_group("opening_story")
		var health := _player.get_node_or_null("CombatHealth")
		if _player.is_frozen or get_tree().paused or (story != null and bool(story.get("document_open"))) or (health != null and bool(health.get("is_dead"))):
			return
		_was_paused = get_tree().paused
		_previous_mouse = Input.mouse_mode
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		get_tree().paused = _was_paused
		Input.mouse_mode = _previous_mouse
	is_open = value
	_overlay.visible = value
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	if value:
		_update_hud()
		_cards[selected_slot_index].grab_focus()

func _exit_tree() -> void:
	if is_open and get_tree() != null:
		get_tree().paused = _was_paused

func _panel(parent: Node, header: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(TEAL.darkened(0.3)))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var title := _label(header, 16, GOLD)
	column.add_child(title)
	return column

func _style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = INK
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	return style

func _label(words: String, size: int = 18, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _build_screen() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.009, 0.009, 0.95)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var safe := AspectRatioContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.ratio = 4.0 / 3.0
	_overlay.add_child(safe)
	_frame = Control.new()
	safe.add_child(_frame)
	_page = Control.new()
	_page.size = Vector2(1024, 768)
	_frame.add_child(_page)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page.add_child(margin)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	_frame.resized.connect(_layout_screen)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	margin.add_child(page)
	var heading := HBoxContainer.new()
	page.add_child(heading)
	var name := _label("THOMAS / FIELD INVENTORY", 26, GOLD)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(name)
	var town := _label("CICELY TOWN", 16, TEAL.lightened(0.4))
	town.autowrap_mode = TextServer.AUTOWRAP_OFF
	town.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	town.custom_minimum_size.x = 160
	heading.add_child(town)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	page.add_child(row)
	for slot in SLOT_COUNT:
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 86)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_font_size_override("font_size", 14)
		card.add_theme_stylebox_override("normal", _style(TEAL))
		card.add_theme_stylebox_override("focus", _style(GOLD))
		card.pressed.connect(select_slot.bind(slot))
		row.add_child(card)
		_cards.append(card)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var status_column := _panel(body, "PERSONAL STATUS")
	status_column.get_parent().size_flags_stretch_ratio = 0.7
	var portrait := TextureRect.new()
	var faces := load("res://img/player/hpFaces.png") as Texture2D
	var atlas := AtlasTexture.new()
	atlas.atlas = faces
	atlas.region = Rect2(0, 0, faces.get_width() / 2.0, faces.get_height() / 6.0)
	portrait.texture = atlas
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size.y = 140
	status_column.add_child(portrait)
	status_column.add_child(_label("THOMAS", 22, GOLD))
	_status = _label("", 16)
	status_column.add_child(_status)
	status_column.add_child(_label("Find Carrie.\nFollow what she left behind.", 15, TEAL.lightened(0.4)))
	var preview_column := _panel(body, "EXAMINE ITEM")
	preview_column.get_parent().size_flags_stretch_ratio = 1.7
	_preview = TextureRect.new()
	_preview.texture = _viewport.get_texture()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_column.add_child(_preview)
	_paper_preview = _label("", 30, PAPER)
	_paper_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_paper_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paper_preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_column.add_child(_paper_preview)
	var details := _panel(body, "ITEM INFORMATION")
	details.get_parent().size_flags_stretch_ratio = 1.1
	_title = _label("", 24, GOLD)
	details.add_child(_title)
	_description = _label("", 17)
	_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(_description)
	_use = Button.new()
	_use.custom_minimum_size.y = 44
	_use.add_theme_stylebox_override("normal", _style(GOLD))
	_use.pressed.connect(_use_selected)
	details.add_child(_use)
	var close := Button.new()
	close.text = "RETURN TO TOWN"
	close.pressed.connect(set_open.bind(false))
	details.add_child(close)
	page.add_child(_label("E / ESC  CLOSE     ← / →  SELECT     ENTER  USE     F  FLASHLIGHT IN THE WORLD", 14, TEAL.lightened(0.45)))
	_overlay.hide()
	call_deferred("_layout_screen")

func _layout_screen() -> void:
	if _frame == null or _page == null:
		return
	var factor := minf(_frame.size.x / 1024.0, _frame.size.y / 768.0)
	_page.scale = Vector2.ONE * factor
	_page.position = (_frame.size - Vector2(1024, 768) * factor) * 0.5

func _update_hud() -> void:
	if _cards.is_empty():
		return
	for slot in SLOT_COUNT:
		_cards[slot].text = "%02d\n%s" % [slot + 1, _get_item_display_name(_items[slot])]
		_cards[slot].add_theme_stylebox_override("normal", _style(GOLD if slot == selected_slot_index else TEAL.darkened(0.25)))
	var item := get_selected_item()
	_title.text = _get_item_display_name(item)
	_preview.visible = item == FLASHLIGHT_ITEM
	_paper_preview.visible = item != FLASHLIGHT_ITEM
	_paper_preview.text = "CICELY TOWN\nTOURIST MAP" if item == MAP_ITEM else "CARRIE\nPERSONAL NOTES" if item == NOTEBOOK_ITEM else "—"
	if item == EMPTY_ITEM:
		_description.text = "Nothing stored here."
		_use.text = "EMPTY"
	elif ItemDatabase.has_item(item):
		var item_data := ItemDatabase.get_item(item)
		_description.text = item_data.description
		_use.text = item_data.use_action_text
	else:
		_description.text = "A working flashlight found at the abandoned gas station. Its beam makes the Ridgeback retreat. Press F anytime while exploring." if item == FLASHLIGHT_ITEM else "Collected at the welcome center. Thomas has marked places connected to Carrie's trail." if item == MAP_ITEM else "Carrie's handwriting. She left for the hospital because people said it was safe. Read this with the other clues in your journal." if item == NOTEBOOK_ITEM else "Nothing stored here."
		_use.text = "TOGGLE FLASHLIGHT" if item == FLASHLIGHT_ITEM else "OPEN MAP" if item == MAP_ITEM else "READ NOTES" if item == NOTEBOOK_ITEM else "EMPTY"
	_use.disabled = item == EMPTY_ITEM
	var health := _player.get_node_or_null("CombatHealth")
	_status.text = "CONDITION / %d%%\n\nLIGHT / %s" % [int(health.get("health")) if health != null else 100, "CARRIED" if has_item(FLASHLIGHT_ITEM) else "NOT FOUND"]

func _use_selected() -> void:
	var item := get_selected_item()
	if item == EMPTY_ITEM:
		return
	set_open(false)
	match item:
		FLASHLIGHT_ITEM:
			_player.flashlight.toggle()
		MAP_ITEM:
			var maps := get_tree().get_nodes_in_group("world_map")
			if not maps.is_empty():
				maps[0].set_map_open(true)
		NOTEBOOK_ITEM:
			var story := get_tree().get_first_node_in_group("opening_story")
			if story != null:
				story.open_document(&"journal", "Thomas's journal", "\n\n".join(story.journal))

func _get_item_display_name(item: StringName) -> String:
	match item:
		FLASHLIGHT_ITEM: return "FLASHLIGHT"
		MAP_ITEM: return "TOWN MAP"
		NOTEBOOK_ITEM: return "CARRIE'S NOTES"
		_: return "EMPTY" if item == EMPTY_ITEM else str(item).to_upper()
