extends Node3D
## Interactive check: move around the bear and confirm it watches from its spot.

@onready var enemy: CharacterBody3D = $CorruptedFriend
@onready var status: Label = $PreviewUI/Status


func _process(_delta: float) -> void:
	var distance := enemy.global_position.distance_to($Player.global_position)
	status.text = "PASSIVE STALKER    |    MOVE AROUND IT    |    DISTANCE: %.1f M    |    %s" % [
		distance,
		"WATCHING" if enemy.watching_player else "IDLE",
	]
