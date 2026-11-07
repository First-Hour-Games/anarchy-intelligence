class_name KeyDoor
extends Node3D
## A hinged door that a key unlocks. Locked, it rattles and says so; if the player has the key, it asks
## whether to use it, and Yes uses the key up and swings the door open. Unlocked, it opens and closes. The
## door's leaf runs along the Hinge body's +X from its Y axis, and opens toward +Z, away from its front. Its
## lock and whether it stands open are kept with the map section (the "saved_state" group).

signal opened
signal closed

@export_category("Door Motion")
@export_range(10.0, 150.0, 1.0) var open_angle_degrees: float = 100.0
@export_range(0.1, 3.0, 0.05) var swing_duration: float = 1.0

@export_category("Lock")
@export var starts_locked: bool = true
@export var required_key: StringName = &""
@export_multiline var locked_dialogue: String = "It's locked."
@export var choice_balloon_scene: PackedScene = preload("res://scenes/ui/dialogue_box/bottom_dialogue_balloon.tscn")

var is_locked := true
var is_open := false
var is_moving := false
var _motion: Tween
## The player being asked whether to use the key, while the Yes/No choice is open.
var _asking_player: Node3D
## A saved state handed over before the door was ready, as a section streaming back in does.
var _pending_save_state: Dictionary = {}

@onready var hinge: AnimatableBody3D = $Hinge
@onready var interactable: InteractableBlock3D = $Hinge/Interactable
@onready var locked_audio: AudioStreamPlayer3D = $LockedAudio
@onready var swing_audio: AudioStreamPlayer3D = $SwingAudio

func _ready() -> void:
	add_to_group(&"saved_state")
	is_locked = starts_locked
	hinge.sync_to_physics = false
	interactable.triggered.connect(toggle)
	if not _pending_save_state.is_empty():
		restore_save_state(_pending_save_state)
		_pending_save_state = {}

func toggle(player: Node3D = null) -> void:
	if is_moving:
		return
	if is_locked:
		var inventory := _inventory(player)
		if inventory == null or required_key == &"" or not inventory.has_item(required_key):
			interactable.single_line_dialogue = locked_dialogue
			locked_audio.play()
			return
		interactable.single_line_dialogue = ""
		_ask_to_use_key(player)
		return
	interactable.single_line_dialogue = ""
	_swing(not is_open)

## Asks "Open with <key>?" before using the key; No leaves the door locked and asks again next time.
func _ask_to_use_key(player: Node3D) -> void:
	var item := ItemDatabase.get_item(required_key)
	var key_name := item.name if item != null and not item.name.is_empty() else String(required_key).capitalize()
	var text := "~ start\nOpen with %s?\n- Yes\n\tdo open_with_key()\n- No\n=> END" % key_name
	var resource: DialogueResource = Engine.get_singleton("DialogueManager").create_resource_from_text(text)
	var balloon := choice_balloon_scene.instantiate()
	if balloon.get("freeze_player") != null:
		balloon.set("freeze_player", true)
	var scene := get_tree().current_scene if is_instance_valid(get_tree().current_scene) else get_tree().root
	scene.add_child(balloon)
	_asking_player = player
	interactable.is_enabled = false
	if balloon.has_signal("dialogue_finished"):
		balloon.connect("dialogue_finished", _on_choice_closed, CONNECT_ONE_SHOT)
	balloon.start(resource, "start", [self])

## The Yes answer: uses up the key, unlocks the door and opens it.
func open_with_key() -> void:
	var inventory := _inventory(_asking_player)
	if not is_locked or inventory == null or not inventory.remove_one(required_key):
		return
	is_locked = false
	_swing(true)

func _on_choice_closed() -> void:
	_asking_player = null
	if not is_moving:
		interactable.is_enabled = true

func _inventory(player: Node3D) -> PlayerInventory:
	return player.get_node_or_null("InventoryHUD") as PlayerInventory if is_instance_valid(player) else null

func _swing(opening: bool) -> void:
	if is_instance_valid(swing_audio) and swing_audio.stream != null:
		swing_audio.play()
	is_moving = true
	interactable.is_enabled = false
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_motion.tween_property(hinge, "rotation:y", _open_rotation() if opening else 0.0, swing_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.finished.connect(func() -> void:
		is_open = opening
		is_moving = false
		interactable.is_enabled = true
		if is_open:
			opened.emit()
		else:
			closed.emit()
	)

## Turning the hinge by a negative angle round Y swings the leaf's free edge from +X toward +Z.
func _open_rotation() -> float:
	return -deg_to_rad(open_angle_degrees)

func _exit_tree() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()

func get_save_state() -> Dictionary:
	return {"locked": is_locked, "open": is_open if not is_moving else not is_open}

func restore_save_state(state: Dictionary) -> void:
	if not is_node_ready():
		_pending_save_state = state.duplicate()
		return
	if _motion != null and _motion.is_valid():
		_motion.kill()
	is_locked = bool(state.get("locked", starts_locked))
	is_open = bool(state.get("open", false)) and not is_locked
	is_moving = false
	hinge.rotation.y = _open_rotation() if is_open else 0.0
	interactable.is_enabled = true
	interactable.single_line_dialogue = ""
