extends Node3D

const SCHOOL_SCENE := "res://scenes/flashbacks/school.tscn"
var _transitioning_to_school := false

func _ready() -> void:
	$ResidenceDialogueZone.dialogue_finished.connect(_transition_to_school)
	# Match Starting Forest's runtime ambient light while keeping editor lighting editable.
	if has_meta("streamed_section"):
		return
	var world_environment := $WorldEnvironment as WorldEnvironment
	world_environment.environment = world_environment.environment.duplicate() as Environment
	world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.environment.ambient_light_color = Color.BLACK


func _transition_to_school() -> void:
	if _transitioning_to_school:
		return
	_transitioning_to_school = true
	var player := get_tree().get_first_node_in_group("player") as FirstPersonPlayer
	var previous_process_mode := player.process_mode
	player.freeze()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var blackout := CanvasLayer.new()
	blackout.name = "SchoolTransitionBlackout"
	blackout.layer = 200
	var screen := ColorRect.new()
	screen.color = Color.BLACK
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blackout.add_child(screen)
	add_child(blackout)
	var loader := get_node("/root/SceneLoader")
	loader.prefetch(SCHOOL_SCENE)
	await get_tree().create_timer(2.0).timeout
	var error: Error = await loader.change_to(SCHOOL_SCENE)
	if error != OK:
		blackout.queue_free()
		player.process_mode = previous_process_mode
		player.unfreeze()
		_transitioning_to_school = false
