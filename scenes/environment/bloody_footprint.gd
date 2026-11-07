@tool
extends Decal
## One bare footprint left in blood. The toes point along the decal's -Z axis,
## so rotate the node to face the walking direction. Flip `left_foot` for the
## other foot; both feet share one texture set.

const RIGHT_ALBEDO: Texture2D = preload("res://img/materials/footprints_bare/footprint_bare_right_albedo.png")
const LEFT_ALBEDO: Texture2D = preload("res://img/materials/footprints_bare/footprint_bare_left_albedo.png")
const RIGHT_NORMAL: Texture2D = preload("res://img/materials/footprints_bare/footprint_bare_right_normal.png")
const LEFT_NORMAL: Texture2D = preload("res://img/materials/footprints_bare/footprint_bare_left_normal.png")
const RIGHT_EMISSION: Texture2D = preload("res://img/materials/footprints_bare/footprint_bare_right_emission.png")
const LEFT_EMISSION: Texture2D = preload("res://img/materials/footprints_bare/footprint_bare_left_emission.png")
const WET_ORM: Texture2D = preload("res://img/materials/footprints_bare/footprint_wet_orm.png")

@export var left_foot: bool = false:
	set(value):
		left_foot = value
		_apply()
@export var blood_color: Color = Color(0.36, 0.012, 0.012):
	set(value):
		blood_color = value
		_apply()
## Low roughness and a touch of metallic give fresh blood a wet, red sheen under the flashlight.
@export var wet: bool = true:
	set(value):
		wet = value
		_apply()
## A faint red glow, tinted by blood_color, so the trail reads in the dark. 0 turns it off.
@export_range(0.0, 8.0, 0.05) var glow_energy: float = 2.0:
	set(value):
		glow_energy = value
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	texture_albedo = LEFT_ALBEDO if left_foot else RIGHT_ALBEDO
	texture_normal = LEFT_NORMAL if left_foot else RIGHT_NORMAL
	texture_orm = WET_ORM if wet else null
	texture_emission = LEFT_EMISSION if left_foot else RIGHT_EMISSION
	emission_energy = glow_energy
	modulate = blood_color
