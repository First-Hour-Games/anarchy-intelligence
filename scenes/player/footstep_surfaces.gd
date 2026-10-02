extends RefCounted

const BANKS := {
	&"concrete": [preload("res://sounds/footsteps/concrete/concrete_1.wav"), preload("res://sounds/footsteps/concrete/concrete_2.wav"), preload("res://sounds/footsteps/concrete/concrete_3.wav")],
	&"tile": [preload("res://sounds/footsteps/tile/tile_1.wav"), preload("res://sounds/footsteps/tile/tile_2.wav"), preload("res://sounds/footsteps/tile/tile_3.wav")],
	&"dirt": [preload("res://sounds/footsteps/dirt/dirt_1.wav"), preload("res://sounds/footsteps/dirt/dirt_2.wav"), preload("res://sounds/footsteps/dirt/dirt_3.wav")],
}

static func classify(collider: Node) -> StringName:
	var names := ""
	var current := collider
	while current != null:
		if current.has_meta("footstep_surface"):
			return StringName(current.get_meta("footstep_surface"))
		names += str(current.name).to_lower() + "/"
		current = current.get_parent()
	if names.contains("groundfloor") or names.contains("gasstation") or names.contains("storefloor"):
		return &"tile"
	if names.contains("house") or names.contains("hallfloor") or names.contains("tutorial"):
		return &"wood"
	for surface: String in ["road", "walk", "curb", "parking", "drive", "apron", "porch", "portico"]:
		if names.contains(surface):
			return &"concrete"
	return &"dirt"
