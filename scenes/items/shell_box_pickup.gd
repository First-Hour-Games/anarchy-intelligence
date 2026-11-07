class_name ShellBoxPickup
extends Interactable3D
## A box of shotgun shells left lying about: taking it adds them to the shotgun's spare shells and says so.
## Whether it has been taken is kept with the map section (the "saved_state" group), so loading a save does
## not hand it out again.

@export_range(1, 20, 1) var shells: int = 6
@export_multiline var taken_line: String = "Thomas: Shells. Six of them."

var taken := false
## A saved state handed over before it was ready, as a section streaming back in does.
var _pending_save_state: Dictionary = {}

@onready var pickup_audio: AudioStreamPlayer3D = $PickupAudio


func _ready() -> void:
	super._ready()
	add_to_group(&"saved_state")
	if not _pending_save_state.is_empty():
		restore_save_state(_pending_save_state)
		_pending_save_state = {}


func can_interact(interactor: Node3D) -> bool:
	return not taken and super.can_interact(interactor)


func interact(interactor: Node3D) -> void:
	if taken or not can_interact(interactor):
		return
	var shotgun := interactor.get_node_or_null("Head/Camera3D/ShotgunWeapon")
	if shotgun == null or not shotgun.has_method("add_shells"):
		return
	shotgun.call("add_shells", shells)
	_take()
	pickup_audio.play()
	get_tree().call_group(&"route_subtitles", &"say", taken_line)
	interacted.emit(interactor)


func _take() -> void:
	taken = true
	remove_from_group(&"interactable")
	var model := get_node_or_null("Model") as Node3D
	if model != null:
		model.hide()


func get_save_state() -> Dictionary:
	return {"taken": taken}


func restore_save_state(state: Dictionary) -> void:
	if not is_node_ready():
		_pending_save_state = state.duplicate()
		return
	if bool(state.get("taken", false)) and not taken:
		_take()
