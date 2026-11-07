extends "res://scenes/chapters/main/residence_area.gd"
## The alt route's residence area: past the Ridgeback road, Thomas's lines about where he used to live lead on
## into the alt route's copy of the town map (map_alt.tscn) instead of the school: Carrie's house, then the
## downtown street to the hospital. He takes the shotgun and its shells with him (AltRouteCarry).

const TOWN_MAP := "res://scenes/chapters/alt_route/map_alt.tscn"


func _ready() -> void:
	next_scene_path = TOWN_MAP
	super._ready()


func _leaving(player: FirstPersonPlayer) -> void:
	AltRouteCarry.keep(player)
