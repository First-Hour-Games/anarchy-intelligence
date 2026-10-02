@tool
class_name InspectionHotspot3D extends Marker3D

## Defines an interactive point of interest in 3D world space during inspection view.
## Projected onto screen space as a clickable glowing circular dot.

signal activated()

@export_category("Hotspot Info")
@export var hotspot_id: String = "map_point"
@export var is_enabled: bool = true
@export var trigger_once: bool = false

@export_category("Dialogue")
@export var dialogue_resource: DialogueResource = null
@export var dialogue_cue: String = ""
@export_multiline var single_line_dialogue: String = ""
@export var speaker_name: String = "Thomas"

@export_category("Dot Visuals")
@export var dot_color: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var glow_color: Color = Color(0.25, 0.75, 1.0, 0.6)
@export var dot_radius: float = 7.0
@export var glow_radius: float = 16.0

var has_triggered: bool = false


func can_activate() -> bool:
	if not is_enabled:
		return false
	if trigger_once and has_triggered:
		return false
	return true


func activate() -> void:
	if not can_activate():
		return
	has_triggered = true
	activated.emit()
