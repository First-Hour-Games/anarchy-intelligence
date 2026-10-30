class_name SaveSlotScreen
extends CanvasLayer
## The four-file "SAVE PROGRESS" / "LOAD PROGRESS" screen. A SaveGem opens it in SAVE mode and
## the main menu's Load Game opens it in LOAD mode; see SaveGame for the files themselves.
##
## Arrow keys / WASD / d-pad move, accept picks, cancel backs out. Saving over a used file asks
## for a second press. on_choose(slot) does the actual saving or loading and returns true when it
## worked.

signal closed

enum Mode { SAVE, LOAD }

const FONT: Font = preload("res://fonts/EuropeanTeletextNuevo.ttf")
const CRT_SHADER: Shader = preload("res://shaders/crt.gdshader")
const MOVE_SOUND: AudioStream = preload("res://sounds/ui/move.mp3")
const CLICK_SOUND: AudioStream = preload("res://sounds/ui/click.mp3")
const SAVE_LOOP: AudioStream = preload("res://music/saveLoop.ogg")
const SILENT_DB := -80.0
## CRT blue background, white lines and bars, a pale yellow for the selection.
const BLUE := Color(0.03, 0.15, 0.62)
const LINE := Color(0.93, 0.95, 1.0)
const SELECT := Color(1.0, 0.95, 0.66)
const BAR_TEXT := Color(0.02, 0.09, 0.42)
const FADE_TO_BLUE_SECONDS := 0.7
const CONTENT_FADE_SECONDS := 0.3
const BOTTOM := 4

var mode: Mode = Mode.SAVE
var on_choose: Callable
## Pauses the game while open (saving from a gem).
var pause_game: bool = false
## Fades the game out to blue before the files appear (saving from a gem).
var fade_in: bool = false
## saveLoop.ogg fades in to this volume while the screen is open.
var music_volume_db: float = -8.0
var music_fade_in: float = 1.5
var music_fade_out: float = 0.8

var _selected: int = 0
## The file column to go back to when moving up from the bottom bar.
var _last_slot: int = 0
var _confirm_slot: int = -1
var _busy: bool = false
var _input_ready_at: int = 0
var _headers: Array[PanelContainer] = []
var _header_labels: Array[Label] = []
var _cards: Array[PanelContainer] = []
var _card_bodies: Array[VBoxContainer] = []
var _bottom: PanelContainer
var _bottom_label: Label
var _move_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer
var _was_paused: bool = false
var _background_layers: Array[CanvasItem] = []
var _content: Control
var _music_player: AudioStreamPlayer
var _music_tween: Tween
var _closing: bool = false
## Music that was already playing, faded down under the save loop: player -> its volume_db.
var _ducked: Dictionary = {}


## Opens the screen on top of everything. In LOAD mode it starts on the newest file.
static func open(parent: Node, screen_mode: Mode, choose: Callable, pause: bool = false, fade: bool = false) -> SaveSlotScreen:
	var screen := SaveSlotScreen.new()
	screen.mode = screen_mode
	screen.on_choose = choose
	screen.pause_game = pause
	screen.fade_in = fade
	parent.add_child(screen)
	return screen


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_input_ready_at = Time.get_ticks_msec() + 200
	if pause_game:
		_was_paused = get_tree().paused
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_move_player = _sound(MOVE_SOUND)
	_click_player = _sound(CLICK_SOUND)
	_start_music()
	_build()
	_selected = _newest_slot() if mode == Mode.LOAD else _first_empty_slot()
	_refresh()
	if fade_in:
		_play_fade_in()


## The game fades to the blue screen first, then the files appear.
func _play_fade_in() -> void:
	_busy = true
	for layer_item in _background_layers:
		layer_item.modulate.a = 0.0
	_content.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	for layer_item in _background_layers:
		tween.tween_property(layer_item, "modulate:a", 1.0, FADE_TO_BLUE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_property(_content, "modulate:a", 1.0, CONTENT_FADE_SECONDS)
	await tween.finished
	_busy = false


func close() -> void:
	if _closing:
		return
	_closing = true
	_busy = true
	visible = false
	if pause_game:
		get_tree().paused = _was_paused
	closed.emit()
	await _fade_music_out().finished
	queue_free()


## The save loop fades in over the game's music, which dips out underneath it.
func _start_music() -> void:
	for node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		var other := node as AudioStreamPlayer
		if other.playing and other.bus == &"Music":
			_ducked[other] = other.volume_db
	var stream := SAVE_LOOP.duplicate() as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music_player = _sound(stream)
	_music_player.bus = &"Music"
	_music_player.volume_db = SILENT_DB
	_fade_music_in()


func _fade_music_in() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	if not _music_player.playing:
		_music_player.play()
	_music_tween = create_tween().set_parallel()
	_music_tween.tween_property(_music_player, "volume_db", music_volume_db, music_fade_in) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for other in _ducked:
		if is_instance_valid(other):
			_music_tween.tween_property(other, "volume_db", SILENT_DB, music_fade_in) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Fades the save loop out and brings the ducked music back to where it was.
func _fade_music_out(restore: bool = true) -> Tween:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel()
	_music_tween.tween_property(_music_player, "volume_db", SILENT_DB, music_fade_out) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if restore:
		for other in _ducked:
			if is_instance_valid(other):
				_music_tween.tween_property(other, "volume_db", float(_ducked[other]), music_fade_out) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_music_tween.chain().tween_callback(_music_player.stop)
	return _music_tween


func _input(event: InputEvent) -> void:
	if _closing:
		return
	if _busy or Time.get_ticks_msec() < _input_ready_at:
		get_viewport().set_input_as_handled()
		return
	if not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	var code := key.physical_keycode if key != null else KEY_NONE
	if event.is_action_pressed(&"ui_left") or code == KEY_A:
		if _selected < BOTTOM:
			_select(posmod(_selected - 1, SaveGame.SLOT_COUNT))
	elif event.is_action_pressed(&"ui_right") or code == KEY_D:
		if _selected < BOTTOM:
			_select(posmod(_selected + 1, SaveGame.SLOT_COUNT))
	elif event.is_action_pressed(&"ui_down") or code == KEY_S:
		_select(BOTTOM)
	elif event.is_action_pressed(&"ui_up") or code == KEY_W:
		if _selected == BOTTOM:
			_select(_last_slot)
	elif event.is_action_pressed(&"ui_cancel") or code == KEY_ESCAPE:
		_play(_click_player)
		close()
	elif event.is_action_pressed(&"ui_accept") or code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]:
		_activate()
	else:
		return
	get_viewport().set_input_as_handled()


func _select(index: int) -> void:
	if index == _selected:
		return
	if _selected < BOTTOM:
		_last_slot = _selected
	_selected = index
	_confirm_slot = -1
	_play(_move_player)
	_refresh()


func _activate() -> void:
	_play(_click_player)
	if _selected == BOTTOM:
		close()
		return
	var slot := _selected
	if mode == Mode.LOAD:
		if not SaveGame.has_save(slot):
			return
		_busy = true
		_header_labels[slot].text = "LOADING"
		# The loaded section brings its own music; don't bring the menu's back.
		_fade_music_out(false)
		if not await _choose(slot):
			_busy = false
			_header_labels[slot].text = "LOAD FAILED"
			_fade_music_in()
		return
	if SaveGame.has_save(slot) and _confirm_slot != slot:
		_confirm_slot = slot
		_refresh()
		return
	_busy = true
	if await _choose(slot):
		_confirm_slot = -1
		_refresh()
		_header_labels[slot].text = "SAVED"
		await get_tree().create_timer(0.9, true, false, true).timeout
		close()
	else:
		_busy = false
		_header_labels[slot].text = "SAVE FAILED"


func _choose(slot: int) -> bool:
	if not on_choose.is_valid():
		return false
	var result: Variant = await on_choose.call(slot)
	return bool(result)


func _refresh() -> void:
	for slot in SaveGame.SLOT_COUNT:
		var selected := slot == _selected
		var data := SaveGame.read_slot(slot)
		_style_bar(_headers[slot], selected)
		_header_labels[slot].text = "OVERWRITE?" if _confirm_slot == slot else "FILE %02d" % (slot + 1)
		_style_frame(_cards[slot], selected)
		_fill_card(slot, data, selected)
	_style_frame(_bottom, _selected == BOTTOM, 2)
	_bottom_label.add_theme_color_override("font_color", SELECT if _selected == BOTTOM else LINE)


func _fill_card(slot: int, data: Dictionary, selected: bool) -> void:
	var body := _card_bodies[slot]
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var color := SELECT if selected else LINE
	if data.is_empty():
		body.add_child(_spacer(1.0))
		body.add_child(_label("NO DATA", 24, color))
		body.add_child(_spacer(1.0))
		var cross := CrossBox.new()
		cross.color = color
		body.add_child(_thumbnail_frame(cross, selected))
		return
	body.add_child(_spacer(0.25))
	body.add_child(_label(str(data.get("saved_label", "")), 24, color))
	body.add_child(_label(SaveGame.format_play_time(float(data.get("play_time", 0.0))), 24, color))
	var area := str(data.get("area", "")).to_upper()
	body.add_child(_label("« %s »" % area if not area.is_empty() else "", 24, color))
	body.add_child(_label(str(data.get("location", "")).to_upper(), 24, color))
	body.add_child(_spacer(1.0))
	var texture := SaveGame.load_thumbnail(slot)
	if texture != null:
		var picture := TextureRect.new()
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.modulate = Color.WHITE if selected else Color(0.5, 0.56, 0.72)
		body.add_child(_thumbnail_frame(picture, selected))
	else:
		var cross := CrossBox.new()
		cross.color = color
		body.add_child(_thumbnail_frame(cross, selected))


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var background := ColorRect.new()
	background.color = BLUE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	_background_layers.append(background)

	var vignette := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.set_color(1, Color(0, 0, 0, 0.5))
	var vignette_texture := GradientTexture2D.new()
	vignette_texture.gradient = gradient
	vignette_texture.fill = GradientTexture2D.FILL_RADIAL
	vignette_texture.fill_from = Vector2(0.5, 0.5)
	vignette_texture.fill_to = Vector2(1.1, 1.1)
	vignette.texture = vignette_texture
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vignette)
	_background_layers.append(vignette)

	var marks := PlusGrid.new()
	marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(marks)
	_background_layers.append(marks)

	var content := VBoxContainer.new()
	content.anchor_left = 0.095
	content.anchor_right = 0.905
	content.anchor_top = 0.2
	content.anchor_bottom = 0.82
	content.add_theme_constant_override("separation", 20)
	root.add_child(content)
	_content = content

	var title := PanelContainer.new()
	_style_bar(title, false)
	title.add_child(_label("SAVE PROGRESS" if mode == Mode.SAVE else "LOAD PROGRESS", 30, BAR_TEXT))
	content.add_child(title)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 40)
	content.add_child(row)
	for slot in SaveGame.SLOT_COUNT:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 12)
		column.mouse_filter = Control.MOUSE_FILTER_STOP
		column.mouse_entered.connect(_on_hover.bind(slot))
		column.gui_input.connect(_on_click.bind(slot))
		row.add_child(column)
		var header := PanelContainer.new()
		header.mouse_filter = Control.MOUSE_FILTER_PASS
		var header_label := _label("FILE %02d" % (slot + 1), 30, BAR_TEXT)
		header.add_child(header_label)
		column.add_child(header)
		var card := PanelContainer.new()
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		column.add_child(card)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 10)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(body)
		_headers.append(header)
		_header_labels.append(header_label)
		_cards.append(card)
		_card_bodies.append(body)

	_bottom = PanelContainer.new()
	_bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	_bottom.mouse_entered.connect(_on_hover.bind(BOTTOM))
	_bottom.gui_input.connect(_on_click.bind(BOTTOM))
	_bottom_label = _label("CANCEL SAVING" if mode == Mode.SAVE else "BACK", 26, LINE)
	_bottom.add_child(_bottom_label)
	content.add_child(_bottom)

	var crt := ColorRect.new()
	var crt_material := ShaderMaterial.new()
	crt_material.shader = CRT_SHADER
	crt_material.set_shader_parameter("crt_curve", 0.0)
	crt_material.set_shader_parameter("crt_scan_line_color", 0.25)
	crt_material.set_shader_parameter("aperture_grille_rate", 0.25)
	crt.material = crt_material
	crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crt)


func _on_hover(index: int) -> void:
	if not _busy:
		_select(index)


func _on_click(event: InputEvent, index: int) -> void:
	if _busy or Time.get_ticks_msec() < _input_ready_at:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select(index)
		_activate()


func _thumbnail_frame(inner: Control, selected: bool) -> Control:
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 4.0 / 3.0
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	aspect.size_flags_stretch_ratio = 2.2
	aspect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.0)
	style.border_color = SELECT if selected else LINE
	style.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", style)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(inner)
	aspect.add_child(frame)
	return aspect


func _style_bar(panel: PanelContainer, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = SELECT if selected else LINE
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)


func _style_frame(panel: PanelContainer, selected: bool, width: int = 3) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.95, 0.66, 0.06) if selected else Color(0, 0, 0, 0)
	style.border_color = SELECT if selected else LINE
	style.set_border_width_all(width)
	style.set_content_margin_all(18)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _spacer(ratio: float) -> Control:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = ratio
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _sound(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _play(player: AudioStreamPlayer) -> void:
	if is_instance_valid(player):
		player.play()


func _newest_slot() -> int:
	var newest := 0
	var newest_time := ""
	for slot in SaveGame.SLOT_COUNT:
		var stamp := str(SaveGame.read_slot(slot).get("saved_at", ""))
		if not stamp.is_empty() and stamp > newest_time:
			newest_time = stamp
			newest = slot
	return newest


func _first_empty_slot() -> int:
	for slot in SaveGame.SLOT_COUNT:
		if not SaveGame.has_save(slot):
			return slot
	return _newest_slot()


## Faint "+" registration marks across the background.
class PlusGrid extends Control:
	func _draw() -> void:
		var mark := Color(1, 1, 1, 0.12)
		for column in 5:
			for row in 3:
				var center := Vector2(size.x * (0.1 + column * 0.2), size.y * (0.13 + row * 0.35))
				draw_line(center - Vector2(8, 0), center + Vector2(8, 0), mark, 2.0)
				draw_line(center - Vector2(0, 8), center + Vector2(0, 8), mark, 2.0)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


## The empty-file picture: a crossed-out box with folded corners.
class CrossBox extends Control:
	var color: Color = Color.WHITE

	func _draw() -> void:
		var inset := 16.0
		draw_line(Vector2(inset * 2, size.y), Vector2(size.x - inset * 2, 0), color, 2.0)
		draw_line(Vector2(inset * 2, 0), Vector2(size.x - inset * 2, size.y), color, 2.0)
		var corner := 14.0
		draw_colored_polygon(PackedVector2Array([Vector2(size.x - corner, 0), Vector2(size.x, 0), Vector2(size.x, corner)]), color)
		draw_colored_polygon(PackedVector2Array([Vector2(0, size.y - corner), Vector2(0, size.y), Vector2(corner, size.y)]), color)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
