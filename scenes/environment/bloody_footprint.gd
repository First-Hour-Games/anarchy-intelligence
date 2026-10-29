@tool
extends Decal
## One bare footprint left in blood. The toes point along the decal's -Z axis,
## so rotate the node to face the walking direction. Flip `left_foot` for the
## other foot; both feet share one texture set.

const RIGHT_ALBEDO: Texture2D = preload("res://img/materials/footprints_bare/footprint_bare_right_albedo.png")
const LEFT_ALBEDO: Texture2D = preload("res://img/materials/footprints_bare/footprint_bare_left_albedo.png")
const RIGHT_NORMAL: Texture2D = preload("res://img/materials/footprints_bare/footprint_bare_right_normal.png")
const LEFT_NORMAL: Texture2D = preload("res://img/materials/footprints_bare/footprint_bare_left_normal.png")
const WET_ORM: Texture2D = preload("res://img/materials/footprints_bare/footprint_wet_orm.png")

@export var left_foot: bool = false:
	set(value):
		left_foot = value
		_apply()
@export var blood_color: Color = Color(0.36, 0.012, 0.012):
	set(value):
		blood_color = value
		_apply()
## Low roughness gives fresh blood a wet sheen under the flashlight.
@export var wet: bool = true:
	set(value):
		wet = value
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	texture_albedo = LEFT_ALBEDO if left_foot else RIGHT_ALBEDO
	texture_normal = LEFT_NORMAL if left_foot else RIGHT_NORMAL
	texture_orm = WET_ORM if wet else null
	modulate = blood_color
