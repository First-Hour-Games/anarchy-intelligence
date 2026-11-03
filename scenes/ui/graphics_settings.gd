extends Node

signal preset_changed

const SETTINGS_PATH := "user://graphics_settings.cfg"
const PRESET_NAMES: Array[String] = ["Low", "Medium", "High"]
const EFFECT_PROPERTIES: Array[StringName] = [
	&"volumetric_fog_enabled", &"ssao_enabled", &"ssil_enabled",
	&"sdfgi_enabled", &"ssr_enabled", &"glow_enabled"
]
const BASELINE_META := &"graphics_quality_baseline"

var preset: int = 2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	get_tree().node_added.connect(_on_node_added)
	_apply_tree(get_tree().root)


func load_settings() -> void:
	preset = 2
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved: Variant = config.get_value("graphics", "preset", 2)
		preset = clampi(saved, 0, 2) if saved is int else 2


func set_preset(value: int, persist: bool = true) -> void:
	preset = clampi(value, 0, 2)
	_apply_tree(get_tree().root)
	if persist:
		var config := ConfigFile.new()
		config.set_value("graphics", "preset", preset)
		var error := config.save(SETTINGS_PATH)
		if error != OK:
			push_warning("Could not save graphics settings: %s" % error_string(error))
	preset_changed.emit()


func step_preset(direction: int) -> void:
	set_preset(posmod(preset + direction, PRESET_NAMES.size()))


func get_preset_name() -> String:
	return PRESET_NAMES[preset]


func _on_node_added(node: Node) -> void:
	if node is Viewport or node is WorldEnvironment or node is Camera3D or node is Light3D:
		# Scene scripts can assign/duplicate resources or configure lights in _ready.
		_apply_node_id.call_deferred(node.get_instance_id())


func _apply_node_id(instance_id: int) -> void:
	# Streamed sections may unload before a deferred graphics update runs.
	if is_instance_id_valid(instance_id):
		_apply_node(instance_from_id(instance_id) as Node)


func _apply_tree(node: Node) -> void:
	_apply_node(node)
	for child: Node in node.get_children():
		_apply_tree(child)


func _apply_node(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	if node is Viewport:
		var viewport := node as Viewport
		if not viewport.has_meta(BASELINE_META):
			viewport.set_meta(BASELINE_META, {
				"scale": viewport.scaling_3d_scale, "msaa": viewport.msaa_3d,
				"taa": viewport.use_taa, "atlas": viewport.positional_shadow_atlas_size
			})
		var original: Dictionary = viewport.get_meta(BASELINE_META)
		viewport.scaling_3d_scale = float(original.scale) * [0.5, 0.75, 1.0][preset]
		viewport.msaa_3d = original.msaa if preset == 2 else Viewport.MSAA_DISABLED
		viewport.use_taa = bool(original.taa) and preset == 2
		viewport.positional_shadow_atlas_size = int(original.atlas) if preset == 2 else mini(int(original.atlas), 1024 if preset == 1 else 512)
	elif node is WorldEnvironment:
		_apply_environment((node as WorldEnvironment).environment)
	elif node is Camera3D:
		_apply_environment((node as Camera3D).environment)
	elif node is Light3D:
		var light := node as Light3D
		if not light.has_meta(BASELINE_META):
			light.set_meta(BASELINE_META, light.shadow_enabled)
		light.shadow_enabled = bool(light.get_meta(BASELINE_META)) and preset > 0


func _apply_environment(environment: Environment) -> void:
	if environment == null:
		return
	if not environment.has_meta(BASELINE_META):
		var baseline: Dictionary = {}
		for property: StringName in EFFECT_PROPERTIES:
			baseline[property] = environment.get(property)
		environment.set_meta(BASELINE_META, baseline)
	var original: Dictionary = environment.get_meta(BASELINE_META)
	for property: StringName in EFFECT_PROPERTIES:
		# Medium retains bloom; High restores each scene's authored effects.
		var enabled: bool = preset == 2 or (preset == 1 and property == &"glow_enabled")
		environment.set(property, bool(original[property]) and enabled)
