@tool
class_name Streetlight extends StaticBody3D

@export_group("Lighting")
## Toggles the spotlight.
@export var light_enabled: bool = true:
	set(val):
		light_enabled = val
		_apply_light_settings()

## Color of the emitted light.
@export var light_color: Color = Color(1.0, 0.85, 0.65):
	set(val):
		light_color = val
		_apply_light_settings()

## Intensity of the emitted light.
@export_range(0.0, 20.0, 0.1) var light_energy: float = 3.5:
	set(val):
		light_energy = val
		_apply_light_settings()

## Maximum distance the light reaches.
@export_range(1.0, 50.0, 0.5) var light_range: float = 14.0:
	set(val):
		light_range = val
		_apply_light_settings()

## Cone angle for the spotlight in degrees.
@export_range(10.0, 85.0, 1.0) var spot_angle: float = 55.0:
	set(val):
		spot_angle = val
		_apply_light_settings()

## Whether this spotlight casts shadows.
@export var shadow_enabled: bool = false:
	set(val):
		shadow_enabled = val
		_apply_light_settings()

@export_group("Physics")
## Toggles collision on the streetlight pole.
@export var collision_enabled: bool = true:
	set(val):
		collision_enabled = val
		_apply_collision_settings()

@onready var spot_light: SpotLight3D = get_node_or_null("LampSpotLight") as SpotLight3D
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D


func _ready() -> void:
	_apply_light_settings()
	_apply_collision_settings()
	if not Engine.is_editor_hint():
		preload("res://scenes/environment/streetlight_fault.gd").attach.call_deferred(spot_light)


func _apply_light_settings() -> void:
	if not is_instance_valid(spot_light):
		spot_light = get_node_or_null("LampSpotLight") as SpotLight3D
	if is_instance_valid(spot_light):
		spot_light.visible = light_enabled
		spot_light.light_color = light_color
		spot_light.light_energy = light_energy
		spot_light.spot_range = light_range
		spot_light.spot_angle = spot_angle
		spot_light.shadow_enabled = shadow_enabled


func _apply_collision_settings() -> void:
	if not is_instance_valid(collision_shape):
		collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if is_instance_valid(collision_shape):
		collision_shape.disabled = not collision_enabled
