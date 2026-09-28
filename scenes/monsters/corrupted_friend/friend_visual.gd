extends Node3D
## Eight-angle selection uses the body heading, not the billboard rotation.

const ATLAS = preload("res://img/characters/corrupted_friend/corrupted_friend_v3_atlas.png")
const SHADER = preload("res://shaders/corrupted_friend.gdshader")
const ATLAS_COLUMNS: int = 8
const ATLAS_ROWS: int = 9
const CELL_WIDTH: int = 320
const CELL_HEIGHT: int = 384
const GROUND_Y: int = 368
const CLIPS := {
	"dormant": [0],
	"activate": [0],
	"alert": [0],
	"search": [0],
	"walk": [1, 2, 3, 4],
	"chase": [1, 2, 3, 4],
	"windup": [5],
	"attack": [6, 0],
	"hit": [7],
	"dead": [8],
}

@export_range(1.5, 2.4, 0.05) var atlas_world_height: float = 1.95

var clip: String = "dormant"
var elapsed: float = 0.0
var surface: MeshInstance3D
var material: ShaderMaterial
var last_frame: int = -1
var direction_index: int = 0


func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("atlas", ATLAS)
	surface = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(
		atlas_world_height * CELL_WIDTH / float(CELL_HEIGHT),
		atlas_world_height
	)
	surface.mesh = quad
	surface.position.y = (GROUND_Y / float(CELL_HEIGHT) - 0.5) * atlas_world_height
	surface.material_override = material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	_show_frame(0, 0)


func play(next_clip: String) -> void:
	if next_clip != clip:
		clip = next_clip
		elapsed = 0.0


static func viewing_direction(body_basis: Basis, offset: Vector3) -> int:
	var local_viewer := body_basis.inverse() * offset.normalized()
	return wrapi(int(round(atan2(local_viewer.x, -local_viewer.z) / (TAU / 8.0))), 0, 8)


func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body == null and get_parent():
		body = get_parent().get_parent() as CharacterBody3D
	if body == null:
		return
	var moving := Vector2(body.velocity.x, body.velocity.z).length() > 0.1
	if clip not in ["walk", "chase"] or moving:
		elapsed += delta
	var camera := get_viewport().get_camera_3d()
	if camera:
		var offset := camera.global_position - global_position
		offset.y = 0.0
		if offset.length_squared() > 0.001:
			direction_index = viewing_direction(body.global_basis, offset)
			look_at(global_position + offset, Vector3.UP, true)
	var frames: Array = CLIPS.get(clip, CLIPS["dormant"])
	var rate := 8.0 if clip == "chase" else 5.0 if clip == "walk" else 3.5
	var index := int(elapsed * rate)
	if clip in ["activate", "attack", "hit", "dead"]:
		index = mini(index, frames.size() - 1)
	else:
		index %= frames.size()
	var row: int = frames[index]
	if clip in ["walk", "chase"] and not moving:
		row = 0
	_show_frame(row, direction_index)
	material.set_shader_parameter("eye_energy", 0.0 if clip in ["dormant", "dead"] else 1.6)


func _show_frame(row: int, direction: int) -> void:
	var frame := row * ATLAS_COLUMNS + direction
	if frame == last_frame:
		return
	last_frame = frame
	material.set_shader_parameter(
		"frame_rect",
		Vector4(
			direction / float(ATLAS_COLUMNS),
			row / float(ATLAS_ROWS),
			1.0 / ATLAS_COLUMNS,
			1.0 / ATLAS_ROWS
		)
	)
