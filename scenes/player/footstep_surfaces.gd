extends RefCounted

const BANKS := {
	&"concrete": [preload("res://sounds/footsteps/concrete/concrete_1.wav"), preload("res://sounds/footsteps/concrete/concrete_2.wav"), preload("res://sounds/footsteps/concrete/concrete_3.wav")],
	&"tile": [preload("res://sounds/footsteps/tile/tile_1.wav"), preload("res://sounds/footsteps/tile/tile_2.wav"), preload("res://sounds/footsteps/tile/tile_3.wav")],
	&"dirt": [preload("res://sounds/footsteps/dirt/dirt_1.wav"), preload("res://sounds/footsteps/dirt/dirt_2.wav"), preload("res://sounds/footsteps/dirt/dirt_3.wav")],
	&"gravel": [
		preload("res://sounds/footsteps/gravel/gravelFootstep1.ogg"),
		preload("res://sounds/footsteps/gravel/gravelFootstep2.ogg"),
		preload("res://sounds/footsteps/gravel/gravelFootstep3.ogg"),
		preload("res://sounds/footsteps/gravel/gravelFootstep4.ogg"),
		preload("res://sounds/footsteps/gravel/gravelFootstep5.ogg"),
		preload("res://sounds/footsteps/gravel/gravelFootstep6.ogg"),
		preload("res://sounds/footsteps/gravel/gravelFootstep7.ogg"),
	],
}

static func classify(collider: Node) -> StringName:
	var names := ""
	var current := collider
	while current != null:
		if current.has_meta("surface"):
			return StringName(str(current.get_meta("surface")).to_lower())
		if current.has_meta("surface_type"):
			return StringName(str(current.get_meta("surface_type")).to_lower())
		if current.has_meta("footstep_surface"):
			return StringName(str(current.get_meta("footstep_surface")).to_lower())
		names += str(current.name).to_lower() + "/"
		current = current.get_parent()
	if names.contains("groundfloor") or names.contains("gasstation") or names.contains("storefloor"):
		return &"tile"
	if names.contains("house") or names.contains("hallfloor") or names.contains("tutorial"):
		return &"wood"
	for surface: String in ["road"]:
		if names.contains(surface):
			return &"gravel"
	for surface: String in ["walk", "curb", "parking", "drive", "apron", "porch", "portico"]:
		if names.contains(surface):
			return &"concrete"
	return &"dirt"
