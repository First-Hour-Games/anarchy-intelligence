class_name PlayerInventory
extends CanvasLayer

signal inventory_changed
signal selection_changed(slot_index: int, item_id: StringName)
const SLOT_COUNT: int = 6
const EMPTY_ITEM: StringName = &""
const FLASHLIGHT_ITEM: StringName = &"flashlight"
const MAP_ITEM: StringName = &"map"
const NOTEBOOK_ITEM: StringName = &"notebook"
const INK := Color(0.015, 0.015, 0.015, 0.80)
const MUTED := Color(0.50, 0.50, 0.50)
const WHITE := Color(1.0, 1.0, 1.0)
const PAPER := Color(0.78, 0.78, 0.78)
const MENU_FONT: Font = preload("res://fonts/EuropeanTeletextNuevo.ttf")

@export var selected_style: StyleBoxFlat
@export var unselected_style: StyleBoxFlat
var selected_slot_index: int = 0
var _items: Array[StringName] = [EMPTY_ITEM, EMPTY_ITEM, EMPTY_ITEM, EMPTY_ITEM, EMPTY_ITEM, EMPTY_ITEM]
var is_open: bool = false
var _was_paused: bool = false
var _previous_mouse: Input.MouseMode
var _overlay: Control
var _cards: Array[Button] = []
var _carousel: Control
var _carousel_tween: Tween
var _portrait_atlas: AtlasTexture
var _counter: Label
var _title: Label
var _use: Button
var _frame: Control
var _page: Control
var _fade_rect: ColorRect
var _fade_tween: Tween
@onready var _viewport: SubViewport = $ItemPreview
@onready var _player: FirstPersonPlayer = get_parent() as FirstPersonPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 96
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

func remove_item(item_id: StringName) -> bool:
	var slot := _items.find(item_id)
	if item_id == EMPTY_ITEM or slot < 0:
		return false
	_items[slot] = EMPTY_ITEM
	_update_hud()
	selection_changed.emit(selected_slot_index, get_selected_item())
	inventory_changed.emit()
	return true

func is_full() -> bool:
	return not _items.has(EMPTY_ITEM)

func get_item(slot: int) -> StringName:
	return _items[slot] if slot >= 0 and slot < SLOT_COUNT else EMPTY_ITEM

func get_selected_item() -> StringName:
	return get_item(selected_slot_index)

func select_slot(slot: int) -> void:
	selected_slot_index = clampi(slot, 0, SLOT_COUNT - 1)
	_update_hud()
	if is_open and not _cards.is_empty():
		_use.grab_focus()
	selection_changed.emit(selected_slot_index, get_selected_item())

func select_relative(direction: int) -> void:
	for step in range(1, SLOT_COUNT + 1):
		var slot := posmod(selected_slot_index + step * direction, SLOT_COUNT)
		if _items[slot] != EMPTY_ITEM:
			select_slot(slot)
			return

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
				or not _player.inventory_enabled
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
		elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			select_relative(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		elif event.is_action_pressed("ui_left"):
			select_relative(-1)
		elif event.is_action_pressed("ui_right"):
			select_relative(1)
		elif event.is_action_pressed("ui_accept"):
			_use_selected()
		else:
			return
		get_viewport().set_input_as_handled()

func set_open(value: bool, animate: bool = true) -> void:
	if value == is_open:
		return
	if value:
		if not is_instance_valid(_player) or not _player.inventory_enabled:
			return
		var story := get_tree().get_first_node_in_group("opening_story")
		var health := _player.get_node_or_null("CombatHealth")
		if _player.is_frozen or get_tree().paused or (story != null and bool(story.get("document_open"))) or (health != null and bool(health.get("is_dead"))):
			return
		_was_paused = get_tree().paused
		_previous_mouse = Input.mouse_mode
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		is_open = true
		_overlay.visible = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_update_hud()
		if not _cards.is_empty():
			_use.grab_focus()

		# Quick transition: fade to black, then fade to inventory content
		if _fade_tween != null and _fade_tween.is_valid():
			_fade_tween.kill()

		if animate and is_instance_valid(_fade_rect) and is_instance_valid(_frame):
			_frame.modulate.a = 0.0
			_fade_rect.visible = true
			_fade_rect.color = Color(0, 0, 0, 0.0)
			_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			_fade_tween.tween_property(_fade_rect, "color:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_fade_tween.tween_callback(func():
				if is_instance_valid(_frame):
					_frame.modulate.a = 1.0
				if not _cards.is_empty():
					_use.grab_focus()
			)
			_fade_tween.tween_property(_fade_rect, "color:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_fade_tween.tween_callback(func():
				if is_instance_valid(_fade_rect):
					_fade_rect.visible = false
			)
		else:
			if is_instance_valid(_frame):
				_frame.modulate.a = 1.0
			if is_instance_valid(_fade_rect):
				_fade_rect.visible = false
	else:
		is_open = false
		get_tree().paused = _was_paused
		Input.mouse_mode = _previous_mouse
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

		if _fade_tween != null and _fade_tween.is_valid():
			_fade_tween.kill()

		if animate and is_instance_valid(_fade_rect) and is_instance_valid(_overlay) and _overlay.visible:
			_fade_rect.visible = true
			_fade_rect.color = Color(0, 0, 0, 0.0)
			_fade_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			_fade_tween.tween_property(_fade_rect, "color:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_fade_tween.tween_callback(func():
				if is_instance_valid(_overlay):
					_overlay.visible = false
				if is_instance_valid(_frame):
					_frame.modulate.a = 1.0
			)
			_fade_tween.tween_property(_fade_rect, "color:a", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_fade_tween.tween_callback(func():
				if is_instance_valid(_fade_rect):
					_fade_rect.visible = false
			)
		else:
			if is_instance_valid(_fade_rect):
				_fade_rect.visible = false
			if is_instance_valid(_frame):
				_frame.modulate.a = 1.0
			if is_instance_valid(_overlay):
				_overlay.visible = false

func finish_transition_immediately() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if is_instance_valid(_fade_rect):
		_fade_rect.visible = false
	if is_instance_valid(_frame):
		_frame.modulate.a = 1.0
	if not is_open:
		if is_instance_valid(_overlay):
			_overlay.visible = false
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		get_tree().paused = _was_paused
		Input.mouse_mode = _previous_mouse
	elif not _cards.is_empty():
		_use.grab_focus()

func _exit_tree() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if is_open and get_tree() != null:
		get_tree().paused = _was_paused

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
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _style_button(button: Button) -> void:
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_focus_color", WHITE)
	button.add_theme_color_override("font_pressed_color", WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.25))
	button.add_theme_stylebox_override("normal", _style(MUTED.darkened(0.5)))
	button.add_theme_stylebox_override("hover", _style(WHITE))
	button.add_theme_stylebox_override("focus", _style(WHITE))
	button.add_theme_stylebox_override("pressed", _style(WHITE))
	button.add_theme_stylebox_override("disabled", _style(MUTED.darkened(0.7)))

func _build_screen() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	var backing := ColorRect.new()
	backing.color = Color.BLACK
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(backing)

	var safe := AspectRatioContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.ratio = 4.0 / 3.0
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(safe)

	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(_frame)

	_create_black_gutters(_frame)

	var dim := ColorRect.new()
	dim.material = preload("res://shaders/menu_background_material.tres")
	dim.color = Color(0.005, 0.005, 0.005, 1.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(dim)

	_page = Control.new()
	_page.size = Vector2(1024, 768)
	_frame.add_child(_page)
	_frame.resized.connect(_layout_screen)
	var status_heading := _label("STATUS", 18, MUTED)
	status_heading.name = "StatusHeading"
	status_heading.position = Vector2(64, 56)
	status_heading.size = Vector2(164, 28)
	status_heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	_page.add_child(status_heading)
	var portrait := TextureRect.new()
	var faces := preload("res://img/player/hpFaces.png")
	_portrait_atlas = AtlasTexture.new()
	_portrait_atlas.atlas = faces
	_portrait_atlas.region = Rect2(0, 0, faces.get_width() / 2.0, faces.get_height() / 6.0)
	portrait.texture = _portrait_atlas
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(64, 92)
	portrait.size = Vector2(164, 178)
	_page.add_child(portrait)
	var equipment_heading := _label("INVENTORY", 18, MUTED)
	equipment_heading.name = "InventoryHeading"
	equipment_heading.position = Vector2(390, 56)
	equipment_heading.size = Vector2(244, 28)
	equipment_heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	equipment_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(equipment_heading)
	_carousel = Control.new()
	_carousel.position = Vector2(42, 290)
	_carousel.size = Vector2(940, 300)
	_carousel.clip_contents = true
	_page.add_child(_carousel)
	for slot in SLOT_COUNT:
		var card := Button.new()
		card.size = Vector2(240, 260)
		card.focus_mode = Control.FOCUS_NONE
		_style_button(card)
		card.pressed.connect(select_slot.bind(slot))
		_carousel.add_child(card)
		_cards.append(card)
		var image := TextureRect.new()
		image.name = "Image"
		image.position = Vector2(20, 20)
		image.size = Vector2(200, 220)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(image)
		var fallback := _label("", 22, PAPER)
		fallback.name = "Fallback"
		fallback.position = Vector2(20, 20)
		fallback.size = Vector2(200, 220)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(fallback)
	for direction in [-1, 1]:
		var arrow := Button.new()
		arrow.text = "<" if direction < 0 else ">"
		arrow.position = Vector2(278 if direction < 0 else 706, 600)
		arrow.size = Vector2(40, 40)
		_style_button(arrow)
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.pressed.connect(select_relative.bind(direction))
		_page.add_child(arrow)
	_title = _label("", 26, WHITE)
	_title.position = Vector2(320, 600)
	_title.size = Vector2(384, 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(_title)
	_counter = _label("", 14, MUTED)
	_counter.position = Vector2(390, 650)
	_counter.size = Vector2(244, 24)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(_counter)
	_use = Button.new()
	_use.position = Vector2(728, 110)
	_use.size = Vector2(232, 48)
	_style_button(_use)
	_use.focus_mode = Control.FOCUS_ALL
	_use.pressed.connect(_use_selected)
	_page.add_child(_use)
	var close := Button.new()
	close.text = "EXIT"
	close.position = Vector2(804, 698)
	close.size = Vector2(156, 40)
	_style_button(close)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(set_open.bind(false))
	_page.add_child(close)

	# Fullscreen fade rect on top of overlay
	_fade_rect = ColorRect.new()
	_fade_rect.name = "InventoryFadeRect"
	_fade_rect.color = Color.BLACK
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.visible = false
	add_child(_fade_rect)

	_overlay.hide()
	call_deferred("_layout_screen")

func _create_black_gutters(content: Control) -> void:
	var right_gutter := ColorRect.new()
	right_gutter.name = "RightGutter"
	right_gutter.color = Color(0, 0, 0, 1)
	right_gutter.mouse_filter = Control.MOUSE_FILTER_STOP
	right_gutter.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right_gutter.offset_left = 0.0
	right_gutter.offset_right = 4000.0
	right_gutter.offset_top = -2000.0
	right_gutter.offset_bottom = 2000.0
	content.add_child(right_gutter)

	var left_gutter := ColorRect.new()
	left_gutter.name = "LeftGutter"
	left_gutter.color = Color(0, 0, 0, 1)
	left_gutter.mouse_filter = Control.MOUSE_FILTER_STOP
	left_gutter.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_gutter.offset_left = -4000.0
	left_gutter.offset_right = 0.0
	left_gutter.offset_top = -2000.0
	left_gutter.offset_bottom = 2000.0
	content.add_child(left_gutter)

	var top_gutter := ColorRect.new()
	top_gutter.name = "TopGutter"
	top_gutter.color = Color(0, 0, 0, 1)
	top_gutter.mouse_filter = Control.MOUSE_FILTER_STOP
	top_gutter.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_gutter.offset_left = -4000.0
	top_gutter.offset_right = 4000.0
	top_gutter.offset_top = -4000.0
	top_gutter.offset_bottom = 0.0
	content.add_child(top_gutter)

	var bottom_gutter := ColorRect.new()
	bottom_gutter.name = "BottomGutter"
	bottom_gutter.color = Color(0, 0, 0, 1)
	bottom_gutter.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom_gutter.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_gutter.offset_left = -4000.0
	bottom_gutter.offset_right = 4000.0
	bottom_gutter.offset_top = 0.0
	bottom_gutter.offset_bottom = 4000.0
	content.add_child(bottom_gutter)

func _layout_screen() -> void:
	if _frame == null or _page == null:
		return
	var factor := minf(_frame.size.x / 1024.0, _frame.size.y / 768.0)
	_page.scale = Vector2.ONE * factor
	_page.position = (_frame.size - Vector2(1024, 768) * factor) * 0.5

func _update_hud() -> void:
	if _cards.is_empty():
		return
	var occupied: Array[int] = []
	for slot in SLOT_COUNT:
		if _items[slot] != EMPTY_ITEM:
			occupied.append(slot)
	if not occupied.is_empty() and _items[selected_slot_index] == EMPTY_ITEM:
		selected_slot_index = occupied[0]
	var selected := occupied.find(selected_slot_index)
	if _carousel_tween != null and _carousel_tween.is_valid():
		_carousel_tween.kill()
	_carousel_tween = null
	if is_open and not occupied.is_empty():
		_carousel_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	for slot in SLOT_COUNT:
		var card := _cards[slot]
		var index := occupied.find(slot)
		card.visible = index >= 0
		if index < 0:
			continue
		var offset := index - selected
		if offset > occupied.size() / 2.0:
			offset -= occupied.size()
		elif offset < -occupied.size() / 2.0:
			offset += occupied.size()
		var active := slot == selected_slot_index
		var target := Vector2(350 + offset * 270, 16 if active else 42)
		var scale_target := Vector2.ONE if active else Vector2.ONE * 0.8
		card.pivot_offset = card.size * 0.5
		if is_open:
			_carousel_tween.tween_property(card, "position", target, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_carousel_tween.tween_property(card, "scale", scale_target, 0.18)
		else:
			card.position = target
			card.scale = scale_target
		card.modulate = WHITE if active else Color(0.5, 0.5, 0.5, 1)
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.border_color = Color(0.65, 0.62, 0.78) if active else Color.TRANSPARENT
		style.set_border_width_all(2 if active else 0)
		card.add_theme_stylebox_override("normal", style)
		card.add_theme_stylebox_override("hover", style)
		card.add_theme_stylebox_override("pressed", style)
		var item := _items[slot]
		var data := ItemDatabase.get_item(item)
		var image := card.get_node("Image") as TextureRect
		image.texture = _viewport.get_texture() if item == FLASHLIGHT_ITEM else data.image
		image.visible = image.texture != null
		var fallback := card.get_node("Fallback") as Label
		fallback.visible = not image.visible
		fallback.text = "CARRIE'S\nNOTES" if item == NOTEBOOK_ITEM else data.name
	var item := get_selected_item()
	_title.text = "EMPTY" if occupied.is_empty() else _get_item_display_name(item)
	_counter.text = "" if occupied.is_empty() else "%02d / %02d" % [selected + 1, occupied.size()]
	_use.text = "USE" if item == EMPTY_ITEM else ItemDatabase.get_item(item).use_action_text
	_use.disabled = item == EMPTY_ITEM
	var health := _player.get_node_or_null("CombatHealth")
	var ratio := clampf(float(health.get("health")) / maxf(float(health.get("max_health")), 0.01), 0.0, 1.0) if health != null else 1.0
	var row := 5 if ratio <= 0.0 else 0 if ratio >= 0.8 else 1 if ratio >= 0.6 else 2 if ratio >= 0.4 else 3 if ratio >= 0.2 else 4
	var faces := _portrait_atlas.atlas
	_portrait_atlas.region = Rect2(0, row * faces.get_height() / 6.0, faces.get_width() / 2.0, faces.get_height() / 6.0)

func _use_selected() -> void:
	var item := get_selected_item()
	if item == EMPTY_ITEM:
		return
	match item:
		FLASHLIGHT_ITEM:
			set_open(false)
			_player.flashlight.toggle()
		MAP_ITEM:
			set_open(false, false)
			var maps := get_tree().get_nodes_in_group("world_map")
			if not maps.is_empty():
				maps[0].set_map_open(true)
		NOTEBOOK_ITEM:
			set_open(false, false)
			var story := get_tree().get_first_node_in_group("opening_story")
			if story != null:
				story.open_document(&"journal", "Thomas's journal", "\n\n".join(story.journal))

func _get_item_display_name(item: StringName) -> String:
	match item:
		FLASHLIGHT_ITEM: return "FLASHLIGHT"
		MAP_ITEM: return "TOWN MAP"
		NOTEBOOK_ITEM: return "CARRIE'S NOTES"
		_: return "EMPTY" if item == EMPTY_ITEM else str(item).to_upper()
