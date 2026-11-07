extends CanvasLayer
## The main menu's Credits: the team, then the 3D models and who made them. The model list
## follows CREDITS.md; keep the two in step when a model is added or removed.
##
## Up/Down (W/S, d-pad, mouse wheel) scroll; Esc, Enter, Backspace or a left click go back.

signal closed

const FONT: Font = preload("res://fonts/EuropeanTeletextNuevo.ttf")
const TITLE_SIZE := 24
const HEADING_SIZE := 16
const TEXT_SIZE := 12
const NOTE_SIZE := 10
const TEXT_COLOR := Color(0.85, 0.85, 0.85)
const HEADING_COLOR := Color(1.0, 1.0, 1.0)
const NOTE_COLOR := Color(0.6, 0.6, 0.6)
const SCROLL_SPEED := 360.0
const CONTENT_WIDTH := 560.0

const TEAM: Array[String] = ["Henry Nguyen", "Irvin Soto", "Narciso Gonzales"]
## Each section: a heading, its lines, and an optional licence note under them.
const SECTIONS: Array[Dictionary] = [
	{
		"heading": "3D MODELS",
		"lines": [
			"CyberThreat Urban Props 1-3 by Conor McKenna (CyberThreat/Aphelios), CC BY 4.0",
			"Hospital Assets by Atomic Realm",
			"Fallen Tree N.3 by Danylo Tyupa, CC BY 4.0",
			"PS1 Style Factory Building by Burnedout Visuals, CC BY 4.0",
			"(PSX) - STOP Sign by Kasugay, CC BY 4.0",
			"Low-Poly PSX Style Wooden Interior Doors Pack by vanillao03, CC BY 4.0",
			"Trash Can by Yury Misiyuk, CC BY 4.0",
			"Land Rover Freelander by zairiq zairiq 8, CC BY 4.0",
			"Ceiling_Lamp_LP by Vitor.GomesPT, CC BY 4.0",
			"Coffin by Daniyal Malik, CC BY 4.0",
			"Grandfather Clock by Memorie, CC BY 4.0",
			"Old Telephone by Termi1, CC BY 4.0 (handset split off for the game over)",
			"Stairs by RVECH, CC BY 4.0",
			"Table by yryabchenko, CC BY 4.0",
			"Gem by TomaszObloj, CC BY 4.0 (recoloured)",
			"Prison Bed by Mihai, CC BY-NC 4.0",
		],
		"note": "CC BY 4.0: creativecommons.org/licenses/by/4.0  -  CC BY-NC 4.0: creativecommons.org/licenses/by-nc/4.0",
	},
	{
		"heading": "MONSTERS AND MORE MODELS",
		"lines": [
			"The Wrapper, The Clawman, The Ridgeback by Codyanka",
			"Abandoned House; Characters PSX (the Watching Bear) by Elbolilloduro",
			"Cars Bundle; Ultimate Monsters (the Watching Yeti) by Quaternius",
			"City Kit Roads, Furniture Kit, Graveyard Kit, Nature Kit, Particle Pack by Kenney",
			"PSX Style Modular Hedges by valsekamerplant",
			"PSX Med Pack by Retro Assets Library",
		],
		"note": "Released under CC0 or free game-use licences; credited with thanks.",
	},
	{
		"heading": "MADE WITH",
		"lines": ["Godot Engine", "Dialogue Manager by Nathan Hoad"],
	},
]

var _scroll: ScrollContainer
var _input_ready_at: int = 0


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The key that opened the screen must not close it straight away.
	_input_ready_at = Time.get_ticks_msec() + 200
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		frame.add_theme_constant_override("margin_" + side, 16)
	frame.add_theme_constant_override("margin_top", 28)
	frame.add_theme_constant_override("margin_bottom", 40)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = CONTENT_WIDTH
	column.add_theme_constant_override("separation", 4)
	center.add_child(column)
	_add_label(column, "CREDITS", TITLE_SIZE, HEADING_COLOR)
	_add_gap(column, 10)
	_add_label(column, "TEAM", HEADING_SIZE, HEADING_COLOR)
	for member in TEAM:
		_add_label(column, member, TEXT_SIZE, TEXT_COLOR)
	for section: Dictionary in SECTIONS:
		_add_gap(column, 14)
		_add_label(column, section.heading, HEADING_SIZE, HEADING_COLOR)
		for line: String in section.lines:
			_add_label(column, line, TEXT_SIZE, TEXT_COLOR)
		if section.has("note"):
			_add_gap(column, 2)
			_add_label(column, section.note, NOTE_SIZE, NOTE_COLOR)
	_add_gap(column, 20)
	var hint := Label.new()
	hint.text = "Up / Down: scroll     Esc / Enter: back"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", FONT)
	hint.add_theme_font_size_override("font_size", NOTE_SIZE)
	hint.add_theme_color_override("font_color", NOTE_COLOR)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -28.0
	hint.offset_bottom = -10.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


func _add_label(parent: Node, text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = CONTENT_WIDTH
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _add_gap(parent: Node, height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	parent.add_child(gap)


func _process(delta: float) -> void:
	var direction := 0.0
	if Input.is_action_pressed(&"ui_down") or Input.is_key_pressed(KEY_S):
		direction += 1.0
	if Input.is_action_pressed(&"ui_up") or Input.is_key_pressed(KEY_W):
		direction -= 1.0
	if direction != 0.0:
		_scroll.scroll_vertical += int(direction * SCROLL_SPEED * delta)


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if Time.get_ticks_msec() >= _input_ready_at and _is_back(event):
		close()
	# Keys stay here, not with the menu underneath; the mouse wheel still reaches the scroll.
	if not event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _is_back(event: InputEvent) -> bool:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"ui_accept"):
		return true
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_LEFT
	return event is InputEventKey and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_BACKSPACE, KEY_SPACE]


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()
