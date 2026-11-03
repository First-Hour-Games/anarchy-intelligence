extends CanvasLayer
## The game over: in the dark, the old phone from Thomas's dream rings until he chooses.
## LOAD PROGRESS answers it and opens the load screen over it; MAIN MENU leaves for the menu.
## Before any save file exists the first choice is TRY AGAIN, back to his last checkpoint.
##
## Up/down (or W/S) move, accept picks, the mouse hovers and clicks. Pause is held off while it is
## up. Any accept or click during the opening skips straight to the choices.

## TRY AGAIN: CombatHealth respawns the player, which frees this screen.
signal try_again

const DEATH_SCARE := preload("res://scenes/ui/death_scare.gd")
const FONT: Font = preload("res://fonts/EuropeanTeletextNuevo.ttf")
## The tutorial's telephone with its handset as its own node (tools/blender/build_game_over_phone.py).
const PHONE: PackedScene = preload("res://models/tutorial/old_telephone_split.glb")
const TABLE: Texture2D = preload("res://assets/local_licensed/carrie_house_textures/dark_wooden_planks/dark_wooden_planks_diff_1k.jpg")
const RING_SOUND: AudioStream = preload("res://sounds/chapters/tutorial/oldPhoneRinging.mp3")
const PICK_UP_SOUND: AudioStream = preload("res://sounds/chapters/tutorial/phonePickUp.mp3")
const MOVE_SOUND: AudioStream = preload("res://sounds/ui/move.mp3")
const CLICK_SOUND: AudioStream = preload("res://sounds/ui/click.mp3")
## Where the bell sounds in oldPhoneRinging.mp3 (start, end in seconds): a double ring every 3 s.
const RING_BURSTS := [
	Vector2(0.0, 1.38), Vector2(3.02, 4.26), Vector2(6.04, 7.18), Vector2(9.06, 10.14), Vector2(12.08, 13.22),
	Vector2(15.1, 16.2), Vector2(18.14, 19.24), Vector2(21.16, 22.5), Vector2(24.2, 25.52), Vector2(27.22, 28.4),
]
## Within a burst the bell rings for 0.4 s, rests, rings again 0.6 s in, then dies away.
const RING_LENGTH := 0.4
const SECOND_RING := 0.6
const LINES := ["Hello, Thomas.", "Your destiny is still calling."]
## The main menu's text style (scenes/mainMenu/menu.gd).
const SELECTED_SIZE := 36
const UNSELECTED_SIZE := 24
const SELECTED_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const UNSELECTED_COLOR := Color(0.65, 0.65, 0.65, 0.65)
## The phone's longest side in metres.
const PHONE_SIZE := 0.32
## While the bell rings, the handset rattles in its cradle: it rocks on its corded cup (its origin),
## the free end hopping up to HANDSET_LIFT metres about HOPS_PER_SECOND times a second, and the
## whole handset lifting a little with it. Each hop is a little higher or lower and rolls a little.
const HANDSET_LIFT := 0.006
const HANDSET_HOP := 0.0008
const HANDSET_ROLL := 0.01
const HOPS_PER_SECOND := 12.0
## From the corded cup to the handset's free end, in the model's metres.
const HANDSET_REACH := 0.225
const SPOT_ENERGY := 3.5
## Black and silence after the close-up, before the phone fades in.
const DARK_BEAT := 0.8
const TYPE_SPEED := 26.0
## The receiver lifting, heard before the load screen or the respawn takes over.
const ANSWER_SECONDS := 0.45
const SILENT_DB := -80.0

var ring: AudioStreamPlayer
var phone: Node3D
var handset: Node3D
## The highlighted choice: 0 is LOAD PROGRESS (TRY AGAIN without saves), 1 is MAIN MENU.
var selected: int = 0
var can_load: bool = false
var slot_screen: SaveSlotScreen
var _pick_up: AudioStreamPlayer
var _move: AudioStreamPlayer
var _click: AudioStreamPlayer
var _screen: Control
var _picture: Control
var _spot: SpotLight3D
var _lines: Array[Label] = []
var _choices: Array[Label] = []
var _menu: VBoxContainer
var _intro: Tween
var _phone_rest: Transform3D
var _handset_rest: Transform3D
var _hop: float = 0.0
var _hop_height: float = 1.0
var _hop_roll: float = 0.0
var _shake: float = 0.0
var _jitter := Vector3.ZERO
var _twist := Vector3.ZERO
var _jitter_clock: float = 0.0
var _last_ring: int = -1
var _choosing: bool = false
var _busy: bool = false
var _input_ready_at: int = 0
## Music faded out under the ringing: player -> its volume_db.
var _ducked: Dictionary = {}
## Layers above this one (story text, fades) held hidden while it is up.
var _covered: Array[CanvasLayer] = []


func _ready() -> void:
	# With the close-up: under the save screen (99) and the CRT (100).
	layer = 98
	process_mode = Node.PROCESS_MODE_ALWAYS
	can_load = SaveGame.has_any_save()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ring = _sound(RING_SOUND, &"Reverb", -5.0)
	_pick_up = _sound(PICK_UP_SOUND, &"Reverb", -2.0)
	_move = _sound(MOVE_SOUND, &"Master", -10.0)
	_click = _sound(CLICK_SOUND, &"Master", -10.0)
	_build()
	_cover_upper_layers()
	_duck_music()
	_play_intro()


func _process(delta: float) -> void:
	var position := ring.get_playback_position() if ring.playing else -1.0
	_shake = move_toward(_shake, ring_strength(position), delta * 14.0)
	_jitter_clock -= delta
	if _jitter_clock <= 0.0:
		# A bell rattles the body about 30 times a second: small shoves and hops, a little twist.
		_jitter_clock = 1.0 / 30.0
		_jitter = Vector3(randf_range(-1.0, 1.0), randf(), randf_range(-1.0, 1.0))
		_twist = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	var offset := Vector3(_jitter.x * 0.0016, _jitter.y * 0.0012, _jitter.z * 0.0016) * _shake
	var twist := Basis.from_euler(Vector3(_twist.x * 0.006, _twist.y * 0.012, _twist.z * 0.006) * _shake)
	phone.transform = Transform3D(twist * _phone_rest.basis, _phone_rest.origin + offset)
	# Each hop is a quick arc up and back down onto the cradle.
	_hop += delta * HOPS_PER_SECOND
	if _hop >= 1.0:
		_hop = fmod(_hop, 1.0)
		_hop_height = randf_range(0.55, 1.0)
		_hop_roll = randf_range(-1.0, 1.0)
	var arc := sin(PI * _hop) * _hop_height * _shake
	var rock := Basis(Vector3.BACK, arc * HANDSET_LIFT / HANDSET_REACH) * Basis(Vector3.RIGHT, arc * _hop_roll * HANDSET_ROLL)
	handset.transform = Transform3D(rock * _handset_rest.basis, _handset_rest.origin + Vector3.UP * arc * HANDSET_HOP)
	var current := ring_index(position)
	if current != -1 and current != _last_ring:
		InputDevice.rumble_pad(0.3, 0.1, RING_LENGTH)
	_last_ring = current


func _input(event: InputEvent) -> void:
	if _is_pause(event):
		# Nothing to pause into; the pause menu waits for the next life.
		get_viewport().set_input_as_handled()
		return
	if _busy or is_instance_valid(slot_screen) or not event.is_pressed() or event.is_echo():
		return
	if not _choosing:
		if _is_accept(event) or event is InputEventMouseButton:
			_intro.custom_step(60.0)
			_input_ready_at = Time.get_ticks_msec() + 150
			get_viewport().set_input_as_handled()
		return
	if Time.get_ticks_msec() < _input_ready_at:
		return
	var key := event as InputEventKey
	var code := key.physical_keycode if key != null else KEY_NONE
	if event.is_action_pressed(&"ui_up") or code == KEY_W:
		_select(posmod(selected - 1, _choices.size()))
	elif event.is_action_pressed(&"ui_down") or code == KEY_S:
		_select(posmod(selected + 1, _choices.size()))
	elif _is_accept(event):
		choose(selected)
	else:
		return
	get_viewport().set_input_as_handled()


## Picks a choice as if it had been clicked.
func choose(index: int) -> void:
	if _busy or is_instance_valid(slot_screen):
		return
	if not _choosing:
		_intro.custom_step(60.0)
	_select(index, false)
	_click.play()
	if index == 1:
		_leave_for_menu()
	elif can_load:
		_answer_for_load()
	else:
		_answer_and_try_again()


## How hard the bell shakes the phone at this point in the ring sound, from 0 to 1.
static func ring_strength(position: float) -> float:
	for burst: Vector2 in RING_BURSTS:
		if position < burst.x or position > burst.y:
			continue
		var into := position - burst.x
		if into < RING_LENGTH or (into >= SECOND_RING and into < SECOND_RING + RING_LENGTH):
			return 1.0
		if into < SECOND_RING:
			return 0.2
		var tail := burst.y - burst.x - SECOND_RING - RING_LENGTH
		return 0.45 * (1.0 - (into - SECOND_RING - RING_LENGTH) / maxf(tail, 0.01))
	return 0.0


## Which ring is sounding, two per burst counted through the file, or -1 between rings.
static func ring_index(position: float) -> int:
	for index in RING_BURSTS.size():
		var into := position - (RING_BURSTS[index] as Vector2).x
		if into >= 0.0 and into < RING_LENGTH:
			return index * 2
		if into >= SECOND_RING and into < SECOND_RING + RING_LENGTH:
			return index * 2 + 1
	return -1


## Black, then the phone fades in ringing, the voice types in, and the choices appear.
func _play_intro() -> void:
	_intro = create_tween()
	_intro.tween_interval(DARK_BEAT)
	_intro.tween_callback(_start_ringing)
	_intro.tween_property(_picture, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro.tween_interval(0.2)
	for line in _lines:
		_intro.tween_property(line, "visible_ratio", 1.0, line.text.length() / TYPE_SPEED)
		_intro.tween_interval(0.25)
	_intro.tween_property(_menu, "modulate:a", 1.0, 0.35)
	_intro.tween_callback(func() -> void: _choosing = true)


func _start_ringing() -> void:
	ring.play()
	# The lamp over the table catches like an old bulb.
	var flicker := create_tween()
	for step: float in [0.2, 0.05, 0.6, 0.15, 1.0]:
		flicker.tween_property(_spot, "light_energy", SPOT_ENERGY * step, 0.05)
		flicker.tween_interval(0.05)


## The ring stops and the receiver lifts; the load screen then opens over the phone.
func _answer_for_load() -> void:
	_busy = true
	_answer()
	await get_tree().create_timer(ANSWER_SECONDS).timeout
	slot_screen = SaveSlotScreen.open(self, SaveSlotScreen.Mode.LOAD, _load_slot, false, true)
	slot_screen.closed.connect(_on_slots_closed)
	_busy = false


## Back from the load screen without loading: the phone starts ringing again.
func _on_slots_closed() -> void:
	slot_screen = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_input_ready_at = Time.get_ticks_msec() + 200
	ring.play()


## Loads a file the way the main menu's Load Game does.
func _load_slot(slot: int) -> bool:
	PauseMenu._save_settings()
	var error: Error = await SaveGame.load_slot(slot)
	return error == OK


## Without a file to load, answering puts Thomas back at his last checkpoint.
func _answer_and_try_again() -> void:
	_busy = true
	_answer()
	var out := create_tween()
	out.tween_interval(ANSWER_SECONDS)
	out.tween_property(_screen, "modulate:a", 0.0, 0.35)
	await out.finished
	for canvas in _covered:
		if is_instance_valid(canvas):
			canvas.show()
	for other in _ducked:
		if is_instance_valid(other):
			(other as AudioStreamPlayer).create_tween().tween_property(other, "volume_db", float(_ducked[other]), 0.8)
	try_again.emit()


## The ring cuts off and the game returns to the main menu, the way the pause menu does it.
func _leave_for_menu() -> void:
	_busy = true
	ring.stop()
	PauseMenu.return_to_main_menu()


func _answer() -> void:
	ring.stop()
	_pick_up.play()


func _select(index: int, sound: bool = true) -> void:
	if index == selected:
		return
	selected = index
	if sound:
		_move.play()
	_refresh()


func _refresh() -> void:
	for index in _choices.size():
		var choice := _choices[index]
		choice.add_theme_font_size_override("font_size", SELECTED_SIZE if index == selected else UNSELECTED_SIZE)
		choice.add_theme_color_override("font_color", SELECTED_COLOR if index == selected else UNSELECTED_COLOR)


func _on_hover(index: int) -> void:
	if _choosing and not _busy and not is_instance_valid(slot_screen):
		_select(index)


func _on_click(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and _choosing:
		choose(index)


func _is_pause(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	var key := event as InputEventKey
	return (event.is_action_pressed(&"pause") or (key != null and key.keycode == KEY_ESCAPE)
		or (event.is_action_pressed(&"ui_cancel") and not (event is InputEventJoypadButton)))


func _is_accept(event: InputEvent) -> bool:
	var key := event as InputEventKey
	return event.is_action_pressed(&"ui_accept") or (key != null and key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E])


func _build() -> void:
	var dark := ColorRect.new()
	dark.color = Color.BLACK
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dark)
	var safe := AspectRatioContainer.new()
	safe.ratio = 4.0 / 3.0
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	_screen = Control.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(_screen)

	_picture = Control.new()
	_picture.anchor_right = 1.0
	_picture.anchor_bottom = 0.62
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.modulate.a = 0.0
	_screen.add_child(_picture)
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.add_child(frame)
	var view := SubViewport.new()
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	frame.add_child(view)
	_build_stage(view)
	var fade := TextureRect.new()
	var gradient := GradientTexture2D.new()
	gradient.fill_to = Vector2(0, 1)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	ramp.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color.BLACK])
	gradient.gradient = ramp
	fade.texture = gradient
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.anchor_right = 1.0
	fade.anchor_bottom = 0.62
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Outside the fading picture, so the table's edge stays black while the phone fades in.
	_screen.add_child(fade)

	var column := VBoxContainer.new()
	column.anchor_right = 1.0
	column.anchor_top = 0.62
	column.anchor_bottom = 1.0
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(column)
	for index in LINES.size():
		var line := _label(LINES[index], 34 if index == 0 else 24, Color.WHITE if index == 0 else Color(0.8, 0.8, 0.8, 0.8))
		line.visible_ratio = 0.0
		column.add_child(line)
		_lines.append(line)
	var gap := Control.new()
	gap.custom_minimum_size.y = 30.0
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.modulate.a = 0.0
	column.add_child(_menu)
	for index in 2:
		var words := "MAIN MENU" if index == 1 else "LOAD PROGRESS" if can_load else "TRY AGAIN"
		var choice := _label(words, SELECTED_SIZE, SELECTED_COLOR)
		choice.mouse_filter = Control.MOUSE_FILTER_STOP
		choice.mouse_entered.connect(_on_hover.bind(index))
		choice.gui_input.connect(_on_click.bind(index))
		_menu.add_child(choice)
		_choices.append(choice)
	_refresh()


## The phone on a dark table under one warm lamp, in its own world.
func _build_stage(view: SubViewport) -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.1, 0.1, 0.12)
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	view.add_child(world)
	phone = PHONE.instantiate() as Node3D
	view.add_child(phone)
	handset = phone.find_child("Handset", true, false) as Node3D
	_handset_rest = handset.transform
	var box := _bounds(phone)
	phone.scale = Vector3.ONE * (PHONE_SIZE / maxf(box.size.x, box.size.z))
	box = _bounds(phone)
	_phone_rest = phone.transform
	var centre := box.get_center()
	var radius := box.size.length() * 0.5
	var table := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 14.0
	table.mesh = plane
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = TABLE
	wood.albedo_color = Color(0.55, 0.45, 0.4)
	wood.uv1_scale = Vector3(3, 3, 3)
	wood.roughness = 0.8
	table.material_override = wood
	view.add_child(table)
	table.position = Vector3(centre.x, box.position.y, centre.z)
	var camera := Camera3D.new()
	camera.fov = 28.0
	view.add_child(camera)
	camera.position = centre + Vector3(0.75, 0.55, 1.0).normalized() * radius * 4.2
	camera.look_at(centre + Vector3(0, -radius * 0.1, 0))
	_spot = SpotLight3D.new()
	view.add_child(_spot)
	_spot.position = centre + Vector3(-0.3, 1.0, 0.25) * radius * 5.0
	_spot.look_at(centre)
	_spot.spot_angle = 18.0
	_spot.spot_range = radius * 12.0
	_spot.light_energy = 0.0
	_spot.light_color = Color(1.0, 0.82, 0.62)
	_spot.shadow_enabled = true
	var fill := OmniLight3D.new()
	view.add_child(fill)
	fill.position = camera.position + Vector3(0, radius, 0)
	fill.omni_range = radius * 12.0
	fill.light_energy = 0.5
	fill.light_color = Color(0.6, 0.7, 0.9)


func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var box := mesh.global_transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## Story text, fades and the like above this layer wait hidden under it; the CRT stays.
func _cover_upper_layers() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for node: Node in scene.find_children("*", "CanvasLayer", true, false):
		var canvas := node as CanvasLayer
		if canvas.visible and canvas.layer > layer and not DEATH_SCARE.holds_crt(canvas) and not is_ancestor_of(canvas):
			_covered.append(canvas)
			canvas.hide()


## The scene's music fades out under the phone, as it does under the save screen.
func _duck_music() -> void:
	for node: Node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		var other := node as AudioStreamPlayer
		if other.playing and other.bus == &"Music":
			_ducked[other] = other.volume_db
	if _ducked.is_empty():
		return
	var quiet := create_tween().set_parallel()
	for other in _ducked:
		quiet.tween_property(other, "volume_db", SILENT_DB, 0.6)


func _sound(stream: AudioStream, bus: StringName, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _label(words: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = words
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label
