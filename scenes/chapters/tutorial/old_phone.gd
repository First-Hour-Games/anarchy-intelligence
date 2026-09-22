class_name OldPhone
extends Node3D

signal picked_up(interactor: Node3D)
signal dialogue_started()
signal dialogue_finished()

@export var door_path: NodePath = NodePath("../Door3")
@export var ringing_sound: AudioStream = preload("res://sounds/chapters/tutorial/oldPhoneRinging.mp3")
@export_range(5.0, 50.0, 1.0) var ringing_max_distance: float = 35.0
@export var ringing_bus: StringName = &"Reverb"

@export var pickup_sound: AudioStream = preload("res://sounds/chapters/tutorial/phonePickUp.mp3")
@export var pickup_bus: StringName = &"Reverb"

@export_group("Dialogue")
@export var phone_dialogue_resource: DialogueResource = preload("res://scenes/chapters/tutorial/phone.dialogue")
@export var dialogue_start_cue: String = "start"
@export var dialogue_balloon_scene: PackedScene = preload("res://scenes/ui/balloon/balloon.tscn")
@export var dialogue_start_delay: float = 0.5

@onready var interactable: Interactable3D = $Interactable if has_node("Interactable") else null
@onready var ringing_audio: AudioStreamPlayer3D = $RingingAudio if has_node("RingingAudio") else null
@onready var pickup_audio: AudioStreamPlayer = $PickupAudio if has_node("PickupAudio") else null

var _has_rung := false
var _is_picked_up := false
var _black_screen_overlay: CanvasLayer = null
var active_balloon: Node = null


func _ready() -> void:
	if interactable:
		interactable.interacted.connect(_on_phone_interacted)

	if not is_instance_valid(ringing_audio):
		ringing_audio = AudioStreamPlayer3D.new()
		ringing_audio.name = "RingingAudio"
		add_child(ringing_audio)

	ringing_audio.bus = ringing_bus
	ringing_audio.max_distance = ringing_max_distance
	if ringing_sound:
		ringing_sound.set("loop", true)
		ringing_audio.stream = ringing_sound

	if not is_instance_valid(pickup_audio):
		pickup_audio = AudioStreamPlayer.new()
		pickup_audio.name = "PickupAudio"
		add_child(pickup_audio)

	pickup_audio.bus = pickup_bus
	if pickup_sound:
		pickup_audio.stream = pickup_sound

	_connect_door()


func _exit_tree() -> void:
	if is_instance_valid(_black_screen_overlay):
		_black_screen_overlay.queue_free()
		_black_screen_overlay = null
	if is_instance_valid(active_balloon):
		active_balloon.queue_free()
		active_balloon = null


func _connect_door() -> void:
	var door := get_node_or_null(door_path) as Node
	if not is_instance_valid(door):
		return

	if door.has_signal("opened"):
		door.connect("opened", _on_door_opened)


func _on_door_opened(_interactor: Node3D = null) -> void:
	if _has_rung:
		return
	_has_rung = true
	start_ringing()


func start_ringing() -> void:
	if is_instance_valid(ringing_audio) and not ringing_audio.playing:
		ringing_audio.play()


func stop_ringing() -> void:
	if is_instance_valid(ringing_audio) and ringing_audio.playing:
		ringing_audio.stop()


func _on_phone_interacted(interactor: Node3D = null) -> void:
	if _is_picked_up:
		return
	_is_picked_up = true

	stop_ringing()

	if is_instance_valid(pickup_audio):
		pickup_audio.play()

	_show_black_screen()
	_freeze_player(interactor)

	if is_instance_valid(interactable):
		interactable.remove_from_group(&"interactable")

	picked_up.emit(interactor)
	_play_dialogue()


func _play_dialogue() -> void:
	if not is_instance_valid(phone_dialogue_resource) or not is_instance_valid(dialogue_balloon_scene):
		return

	if dialogue_start_delay > 0.0:
		await get_tree().create_timer(dialogue_start_delay).timeout

	if is_instance_valid(active_balloon):
		active_balloon.queue_free()

	active_balloon = dialogue_balloon_scene.instantiate()
	if active_balloon is CanvasLayer:
		(active_balloon as CanvasLayer).layer = 160

	var root_target := get_tree().current_scene if is_instance_valid(get_tree().current_scene) else get_tree().root
	root_target.add_child(active_balloon)

	dialogue_started.emit()

	if Engine.has_singleton("DialogueManager"):
		Engine.get_singleton("DialogueManager").dialogue_ended.connect(func(_resource: DialogueResource) -> void:
			dialogue_finished.emit()
		, CONNECT_ONE_SHOT)

	if active_balloon.has_method(&"start"):
		active_balloon.start(phone_dialogue_resource, dialogue_start_cue, [self])


func _show_black_screen() -> void:
	if is_instance_valid(_black_screen_overlay):
		_black_screen_overlay.visible = true
		return

	_black_screen_overlay = CanvasLayer.new()
	_black_screen_overlay.name = "PhoneBlackScreenOverlay"
	_black_screen_overlay.layer = 150

	var black_rect := ColorRect.new()
	black_rect.name = "BlackScreen"
	black_rect.color = Color.BLACK
	black_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	black_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_black_screen_overlay.add_child(black_rect)

	var root_target := get_tree().current_scene if is_instance_valid(get_tree().current_scene) else get_tree().root
	root_target.add_child(_black_screen_overlay)


func _freeze_player(interactor: Node3D = null) -> void:
	var player: FirstPersonPlayer = null
	if interactor is FirstPersonPlayer:
		player = interactor as FirstPersonPlayer
	else:
		player = get_tree().get_first_node_in_group(&"player") as FirstPersonPlayer

	if is_instance_valid(player):
		player.freeze()
