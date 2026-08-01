class_name CustomDialogueBalloon extends CanvasLayer

@export var dialogue_resource: DialogueResource
@export var start_from_cue: String = ""
@export var auto_start: bool = false
@export var will_block_other_input: bool = true
@export var next_action: StringName = &"ui_accept"
@export var skip_action: StringName = &"ui_cancel"

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

var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			if talk_sfx: talk_sfx.stop()
			if owner == null:
				queue_free()
			else:
				hide()
	get:
		return dialogue_line

var mutation_cooldown: Timer = Timer.new()

func _ready() -> void:
	balloon.hide()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	if responses_menu and responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	if talk_sfx:
		talk_sfx.finished.connect(_on_talk_sfx_finished)

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)

	if auto_start:
		start()

func _play_talk_sfx() -> void:
	if talk_sfx:
		talk_sfx.pitch_scale = randf_range(0.92, 1.08)
		talk_sfx.play()

func _on_talk_sfx_finished() -> void:
	# Loop dialogue sound with randomized pitch as long as text is actively typing out
	if is_instance_valid(dialogue_label) and dialogue_label.is_typing and talk_sfx:
		_play_talk_sfx()

func _process(_delta: float) -> void:
	if is_instance_valid(dialogue_line) and progress_indicator:
		var should_show: bool = not dialogue_label.is_typing and dialogue_line.responses.size() == 0 and is_waiting_for_input
		progress_indicator.visible = should_show
		if should_show:
			# Smooth 1-second pulse/flash effect
			var flash: float = (sin(Time.get_ticks_msec() * 0.006) + 1.0) * 0.5
			progress_indicator.modulate.a = lerp(0.2, 1.0, flash)

func _unhandled_input(event: InputEvent) -> void:
	if will_block_other_input:
		get_viewport().set_input_as_handled()

	if not is_instance_valid(dialogue_line):
		return

	# Handle click / Enter / Space to skip typing or advance dialogue
	if event.is_pressed() and not event.is_echo():
		var is_click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
		var is_advance_key: bool = event.is_action_pressed(next_action) or (event is InputEventKey and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE))
		
		if is_click or is_advance_key:
			if dialogue_label.is_typing:
				if talk_sfx:
					talk_sfx.stop()
				dialogue_label.skip_typing()
			elif (is_waiting_for_input or is_post_typing_delay) and dialogue_line.responses.size() == 0:
				if click_sfx:
					click_sfx.play()
				next(dialogue_line.next_id)

func start(with_dialogue_resource: DialogueResource = null, cue: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	is_post_typing_delay = false
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not cue.is_empty():
		start_from_cue = cue
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_cue, temporary_game_states)
	show()

func apply_dialogue_line() -> void:
	mutation_cooldown.stop()
	if progress_indicator:
		progress_indicator.hide()
	is_waiting_for_input = false
	is_post_typing_delay = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	character_label.visible = not dialogue_line.character.is_empty()
	if not dialogue_line.character.is_empty():
		character_label.text = tr(dialogue_line.character, "dialogue").to_upper()

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses

	balloon.show()
	will_hide_balloon = false

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
	else:
		# Add 0.5 second delay after dialogue typing ends before displaying [ ENTER ]
		is_post_typing_delay = true
		await get_tree().create_timer(0.5).timeout
		is_post_typing_delay = false
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()

func next(next_id: String) -> void:
	if talk_sfx:
		talk_sfx.stop()
	is_waiting_for_input = false
	is_post_typing_delay = false
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)

func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		if talk_sfx: talk_sfx.stop()
		balloon.hide()

func _on_mutated(mutation: Dictionary) -> void:
	if not mutation.is_inline:
		is_waiting_for_input = false
		is_post_typing_delay = false
		will_hide_balloon = true
		if talk_sfx: talk_sfx.stop()
		mutation_cooldown.start(0.1)

func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	if talk_sfx: talk_sfx.stop()
	if click_sfx: click_sfx.play()
	next(response.next_id)
