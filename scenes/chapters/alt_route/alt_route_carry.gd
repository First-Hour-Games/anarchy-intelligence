class_name AltRouteCarry
extends RefCounted
## What Thomas brings from the alt route's residence area (residence_area_alt.gd) into its copy of the town map
## (opening_story_alt.gd), across the change of scene: the shotgun and the shells in it and in his pocket, and
## the flashlight. Taken once, by the map that arrives.

static var _carried: Dictionary = {}


## What the player has now, kept for the next scene.
static func keep(player: FirstPersonPlayer) -> void:
	_carried = {"flashlight": player.has_item(PlayerInventory.FLASHLIGHT_ITEM), "shotgun": player.has_item(&"shotgun")}
	var shotgun := player.get_node_or_null("Head/Camera3D/ShotgunWeapon")
	if shotgun != null:
		_carried["loaded"] = int(shotgun.get("loaded"))
		_carried["reserve"] = int(shotgun.get("reserve"))


## What was kept, once; empty when nothing was.
static func take() -> Dictionary:
	var carried := _carried
	_carried = {}
	return carried
