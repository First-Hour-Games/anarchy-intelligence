extends Node3D

## Local power outage: keep the flashlight lit without changing shared station assets.
const NEON_SCRIPT := preload("res://scenes/environment/neon_sign.gd")
@export var power_is_off: bool = true

func _ready() -> void:
	_apply_power_state.call_deferred()

func _apply_power_state() -> void:
	if not power_is_off:
		return
	var station := get_parent()
	if not station is Node3D:
		return # Standalone scene baking has no station shell to power down.
	var pickup := get_node_or_null("Details/CounterFlashlight")
	for node: Node in station.find_children("*", "Light3D", true, false):
		if is_instance_valid(pickup) and pickup.is_ancestor_of(node):
			continue
		var light := node as Light3D
		light.light_energy = 0.0
		light.hide()
	for node: Node in station.find_children("*", "MeshInstance3D", true, false):
		if is_instance_valid(pickup) and pickup.is_ancestor_of(node):
			continue
		var visual := node as MeshInstance3D
		if visual.get_script() == NEON_SCRIPT:
			visual.set_process(false)
			var buzz := visual.get_node_or_null("NeonAmbience") as AudioStreamPlayer3D
			if buzz:
				buzz.stop()
		var override := visual.material_override as BaseMaterial3D
		if override and override.emission_enabled:
			var unlit := override.duplicate() as BaseMaterial3D
			unlit.emission_enabled = false
			visual.material_override = unlit
		if visual.mesh:
			for surface in visual.mesh.get_surface_count():
				var source := visual.get_active_material(surface) as BaseMaterial3D
				if source and source.emission_enabled:
					var unlit := source.duplicate() as BaseMaterial3D
					unlit.emission_enabled = false
					visual.set_surface_override_material(surface, unlit)
