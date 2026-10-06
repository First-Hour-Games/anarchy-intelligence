class_name BottomDialogueBalloon extends CanvasLayer

signal dialogue_started
signal dialogue_finished

@export var dialogue_resource: DialogueResource
@export var start_from_cue: String = "start"
@export var auto_start: bool = false
@export var will_block_other_input: bool = true
@export var freeze_player: bool = true
@export var next_action: StringName = &"ui_accept"
@export var skip_action: StringName = &"ui_cancel"

@export_category("Animation")
## Duration in seconds for the fold-out (opening) and fold-in (closing) animations.
@export_range(0.05, 1.0, 0.01) var fold_duration: float = 0.18

@onready var balloon: Control = %Balloon
@onready var character_label: RichTextLabel = %CharacterLabel
@onready var dialogue_label: Control = %DialogueLabel
@onready var responses_menu: Control = %ResponsesMenu
@onready var progress_indicator: Label = %ProgressIndicator
@onready var move_sfx: AudioStreamPlayer = %MoveSfx
@onready var click_sfx: AudioStreamPlayer = %ClickSfx
@onready var talk_sfx: AudioStreamPlayer = %TalkSfx

var temporary_game_states: Array = []
var is_waiting_for_input: bool = false
var is_post_typing_delay: bool = false
var will_hide_balloon: bool = false
var locals: Dictionary = {}
var accumulated_dialogue_text: String = ""
var _cached_player: FirstPersonPlayer = null
var _is_folded_open: bool = false
var _is_opening: bool = false
var _is_closing: bool = false
var _fold_tween: Tween = null

var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			_end_dialogue()
	get:
		return dialogue_line


func _ready() -> void:
	balloon.hide()
	_update_pivot()
	balloon.scale.y = 0.0
	if not balloon.resized.is_connected(_update_pivot):
		balloon.resized.connect(_update_pivot)
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	if responses_menu:
		if responses_menu.next_action.is_empty():
			responses_menu.next_action = next_action
		if not responses_menu.response_selected.is_connected(_on_responses_menu_response_selected):
			responses_menu.response_selected.connect(_on_responses_menu_response_selected)
		if not responses_menu.response_focused.is_connected(_on_responses_menu_response_focused):
			responses_menu.response_focused.connect(_on_responses_menu_response_focused)

	if talk_sfx:
		talk_sfx.finished.connect(_on_talk_sfx_finished)

	if auto_start and dialogue_resource:
		call_deferred(&"start", dialogue_resource, start_from_cue)


func _play_talk_sfx() -> void:
	if talk_sfx:
		talk_sfx.pitch_scale = randf_range(0.92, 1.08)
		talk_sfx.play()


func _on_talk_sfx_finished() -> void:
	if is_instance_valid(dialogue_label) and dialogue_label.is_typing and talk_sfx:
		_play_talk_sfx()


func _process(_delta: float) -> void:
	if is_instance_valid(dialogue_line) and dialogue_label:
		var should_show: bool = not dialogue_label.is_typing and dialogue_line.responses.size() == 0 and is_waiting_for_input
		if should_show:
			var blink_on: bool = (int(Time.get_ticks_msec() / 350) % 2) == 0
			if progress_indicator:
				progress_indicator.visible = blink_on
		else:
			if progress_indicator:
				progress_indicator.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not balloon.visible:
		return

	# Never intercept or block pause input (Escape / ui_cancel) so the pause menu can always open
	if event.is_action_pressed(&"ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
		return

	if _is_closing:
		if will_block_other_input and is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()
		return

	if _is_opening:
		if event.is_pressed() and not event.is_echo():
			finish_opening_animation()
		if will_block_other_input and is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()
		return

	if not is_instance_valid(dialogue_line):
		if will_block_other_input and is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()
		return

	if event.is_pressed() and not event.is_echo():
		# 1. When dialogue options / responses are active:
		if dialogue_line.responses.size() > 0 and responses_menu.visible:
			var items: Array = responses_menu.get_menu_items()
			if not items.is_empty():
				# Navigation Up: Up arrow or W
				if event.is_action_pressed(&"ui_up") or (event is InputEventKey and (event.keycode == KEY_UP or event.keycode == KEY_W)):
					_navigate_responses(-1)
					if get_viewport():
						get_viewport().set_input_as_handled()
					return

				# Navigation Down: Down arrow or S
				if event.is_action_pressed(&"ui_down") or (event is InputEventKey and (event.keycode == KEY_DOWN or event.keycode == KEY_S)):
					_navigate_responses(1)
					if get_viewport():
						get_viewport().set_input_as_handled()
					return

				# Selection / Confirmation: E (interact), ui_accept (Enter / Space)
				if event.is_action_pressed(&"interact") or event.is_action_pressed(next_action) or (event is InputEventKey and (event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE)):
					var focused := get_viewport().gui_get_focus_owner()
					var target_item: Control = focused if focused in items else items[0]
					if is_instance_valid(target_item):
						var resp = target_item.get_meta("response", null)
						if resp != null:
							if get_viewport():
								get_viewport().set_input_as_handled()
							_on_responses_menu_response_selected(resp)
							return

				# Cancel / Escape: select 'No' if present
				if event.is_action_pressed(skip_action) or event.is_action_pressed(&"ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
					for itm in items:
						var resp = itm.get_meta("response", null)
						if resp != null and resp.text.to_lower() == "no":
							if get_viewport():
								get_viewport().set_input_as_handled()
							_on_responses_menu_response_selected(resp)
							return

			if will_block_other_input and is_inside_tree() and get_viewport():
				get_viewport().set_input_as_handled()
			return

		# 2. When regular dialogue line (no responses active yet):
		var is_click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
		var is_advance_key: bool = event.is_action_pressed(next_action) or event.is_action_pressed(&"interact") or (event is InputEventKey and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_E))

		if is_click or is_advance_key:
			if dialogue_label.is_typing:
				dialogue_label.skip_typing()
				if get_viewport():
					get_viewport().set_input_as_handled()
				return
			elif is_waiting_for_input and dialogue_line.responses.size() == 0:
				if click_sfx:
					click_sfx.play()
				if get_viewport():
					get_viewport().set_input_as_handled()
				next(dialogue_line.next_id)
				return

	if will_block_other_input:
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()


func _navigate_responses(dir: int) -> void:
	if not responses_menu:
		return
	var items: Array = responses_menu.get_menu_items()
	if items.is_empty():
		return
	var current_focus := get_viewport().gui_get_focus_owner()
	var current_idx := items.find(current_focus)
	if current_idx == -1:
		current_idx = 0
	else:
		current_idx = posmod(current_idx + dir, items.size())
	items[current_idx].grab_focus()
	if move_sfx:
		move_sfx.pitch_scale = randf_range(0.96, 1.04)
		move_sfx.play()


func start(with_dialogue_resource: DialogueResource = null, cue: String = "", extra_game_states: Array = []) -> void:
	accumulated_dialogue_text = ""
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	is_post_typing_delay = false
	_is_folded_open = false
	_is_opening = false
	_is_closing = false

	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not cue.is_empty():
		start_from_cue = cue

	if freeze_player:
		_freeze_player()

	dialogue_started.emit()
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_cue, temporary_game_states)
	show()


func apply_dialogue_line() -> void:
	if progress_indicator:
		progress_indicator.hide()
	is_waiting_for_input = false
	is_post_typing_delay = false

	# 1. Fold-out animation on first dialogue line: start at 0 height y, tween to original size y
	if not _is_folded_open:
		_is_opening = true
		if character_label:
			character_label.hide()
		if dialogue_label:
			dialogue_label.hide()
		if responses_menu:
			responses_menu.hide()
		if progress_indicator:
			progress_indicator.hide()

		_update_pivot()
		balloon.scale.y = 0.0
		balloon.show()
		show()

		if _fold_tween != null and _fold_tween.is_valid():
			_fold_tween.kill()

		if fold_duration > 0.0:
			_fold_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			_fold_tween.tween_property(balloon, "scale:y", 1.0, fold_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			await _fold_tween.finished

		if is_instance_valid(balloon):
			balloon.scale.y = 1.0
		_is_opening = false
		_is_folded_open = true

	# 2. Text display and typing/scrolling begins after folding out
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	# Character name (hidden for Thomas or when empty)
	var char_name := dialogue_line.character.strip_edges()
	var is_thomas: bool = char_name.to_lower() == "thomas"
	character_label.visible = not char_name.is_empty() and not is_thomas
	if character_label.visible:
		character_label.text = tr(char_name, "dialogue").to_upper()

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	balloon.show()
	will_hide_balloon = false

	if dialogue_line.responses.size() > 0:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		_play_talk_sfx()
		dialogue_label.type_out()
		await dialogue_label.finished_typing
		if talk_sfx:
			talk_sfx.stop()

	if dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var items: Array = responses_menu.get_menu_items()
		if not items.is_empty():
			items[0].grab_focus()
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


func next(next_id: String) -> void:
	if talk_sfx:
		talk_sfx.stop()
	is_waiting_for_input = false
	is_post_typing_delay = false
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


func _end_dialogue(animate: bool = true) -> void:
	if _is_closing:
		return
	_is_closing = true

	if talk_sfx:
		talk_sfx.stop()

	# 1. Immediately remove all text
	if character_label:
		character_label.text = ""
		character_label.hide()
	if dialogue_label:
		dialogue_label.dialogue_line = null
		dialogue_label.text = ""
		dialogue_label.hide()
	if responses_menu:
		responses_menu.hide()
	if progress_indicator:
		progress_indicator.hide()

	balloon.focus_mode = Control.FOCUS_NONE
	is_waiting_for_input = false
	is_post_typing_delay = false

	# 2. Folding back tween animation: reduce scale y to 0 like folding back
	if animate and fold_duration > 0.0 and is_instance_valid(balloon) and balloon.visible and _is_folded_open:
		if _fold_tween != null and _fold_tween.is_valid():
			_fold_tween.kill()

		_update_pivot()
		_fold_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_fold_tween.tween_property(balloon, "scale:y", 0.0, fold_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await _fold_tween.finished

	if is_instance_valid(balloon):
		balloon.hide()
		balloon.scale.y = 0.0

	_is_folded_open = false
	_is_closing = false

	if click_sfx and click_sfx.playing:
		await click_sfx.finished

	if freeze_player:
		_unfreeze_player()

	dialogue_finished.emit()

	if owner == null:
		queue_free()
	else:
		hide()


func _update_pivot() -> void:
	if is_instance_valid(balloon):
		var w := balloon.size.x if balloon.size.x > 0.0 else (balloon.offset_right - balloon.offset_left)
		var h := balloon.size.y if balloon.size.y > 0.0 else (balloon.offset_bottom - balloon.offset_top)
		balloon.pivot_offset = Vector2(w * 0.5, h * 0.5)


func is_animating() -> bool:
	return _is_opening or _is_closing


func is_opening() -> bool:
	return _is_opening


func is_closing() -> bool:
	return _is_closing


func is_folded_open() -> bool:
	return _is_folded_open


func finish_opening_animation() -> void:
	if not _is_opening:
		return
	if _fold_tween != null and _fold_tween.is_valid():
		_fold_tween.custom_step(999.0)
	elif is_instance_valid(balloon):
		balloon.scale.y = 1.0
		_is_opening = false
		_is_folded_open = true


func finish_closing_animation() -> void:
	if not _is_closing:
		return
	if _fold_tween != null and _fold_tween.is_valid():
		_fold_tween.custom_step(999.0)
	elif is_instance_valid(balloon):
		balloon.scale.y = 0.0


func finish_animation_immediately() -> void:
	if _is_opening:
		finish_opening_animation()
	elif _is_closing:
		finish_closing_animation()


func _freeze_player() -> void:
	_cached_player = get_tree().get_first_node_in_group(&"player") as FirstPersonPlayer
	if is_instance_valid(_cached_player) and _cached_player.has_method(&"freeze"):
		_cached_player.freeze()


func _unfreeze_player() -> void:
	var p := _cached_player
	if not is_instance_valid(p) and is_inside_tree() and get_tree():
		p = get_tree().get_first_node_in_group(&"player") as FirstPersonPlayer

	if is_instance_valid(p):
		if p.get_meta(&"is_climbing_over", false):
			# Do not unfreeze player while a climb-over fade is active
			return
		if p.has_method(&"unfreeze"):
			p.unfreeze()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_mutated(_mutation: Dictionary) -> void:
	is_waiting_for_input = false
	if talk_sfx:
		talk_sfx.stop()


func _on_responses_menu_response_focused(_control: Variant) -> void:
	if move_sfx:
		move_sfx.pitch_scale = randf_range(0.96, 1.04)
		move_sfx.play()


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	if not is_instance_valid(dialogue_line):
		return
	if talk_sfx:
		talk_sfx.stop()
	if click_sfx:
		click_sfx.play()
	if responses_menu:
		responses_menu.hide()
	next(response.next_id)


func has_item(item_id: Variant) -> bool:
	var p := _cached_player
	if not is_instance_valid(p) and is_inside_tree() and get_tree():
		p = get_tree().get_first_node_in_group(&"player") as FirstPersonPlayer
	if is_instance_valid(p) and p.has_method(&"has_item"):
		return p.has_item(item_id)
	return false


func proceed() -> void:
	var player_to_proceed := _cached_player
	if not is_instance_valid(player_to_proceed) and is_inside_tree() and get_tree():
		player_to_proceed = get_tree().get_first_node_in_group(&"player") as FirstPersonPlayer

	for state in temporary_game_states:
		if is_instance_valid(state) and state.has_method(&"climb_over_barrier"):
			state.call(&"climb_over_barrier", player_to_proceed)
			return
		elif is_instance_valid(state) and state.has_method(&"proceed") and state != self:
			state.call(&"proceed", player_to_proceed)
			return

	if is_inside_tree() and get_tree():
		var scene_root := get_tree().current_scene if is_instance_valid(get_tree().current_scene) else get_tree().root
		if is_instance_valid(scene_root):
			var barrier := scene_root.find_child("BarrierTree", true, false)
			if is_instance_valid(barrier) and barrier.has_method(&"proceed"):
				barrier.call(&"proceed", player_to_proceed)
				return
			elif is_instance_valid(barrier) and barrier.has_method(&"climb_over_barrier"):
				barrier.call(&"climb_over_barrier", player_to_proceed)
				return


