class_name WorldMapOverlay
extends Control

## Full-screen, north-up map for the main neighborhood. A low-resolution
## orthographic viewport renders the real level, with readable 2D markers over it.

const WORLD_BOUNDS := Rect2(-320.0, -25.0, 640.0, 425.0)
const ROAD_RECTS := [
	Rect2(-300.0, -4.0, 600.0, 8.0),
	Rect2(96.0, 0.0, 8.0, 375.0),
	Rect2(-119.0, 122.0, 219.0, 6.0),
	Rect2(-42.0, 221.0, 317.0, 8.0),
]
const HOUSE_POSITIONS := [
	Vector2(-108.0, 103.0), Vector2(-78.0, 103.0), Vector2(-48.0, 103.0),
	Vector2(-18.0, 103.0), Vector2(12.0, 103.0), Vector2(42.0, 103.0),
	Vector2(72.0, 103.0), Vector2(-108.0, 147.0), Vector2(-78.0, 147.0),
	Vector2(-48.0, 147.0), Vector2(-18.0, 147.0), Vector2(12.0, 147.0),
	Vector2(42.0, 147.0), Vector2(72.0, 147.0), Vector2(78.0, 40.0),
	Vector2(78.0, 75.0), Vector2(78.0, 170.0), Vector2(78.0, 195.0),
	Vector2(78.0, 265.0), Vector2(78.0, 295.0), Vector2(78.0, 325.0),
	Vector2(78.0, 355.0), Vector2(122.0, 55.0), Vector2(122.0, 85.0),
	Vector2(122.0, 165.0), Vector2(122.0, 195.0), Vector2(-30.0, 203.0),
	Vector2(10.0, 203.0), Vector2(50.0, 203.0), Vector2(145.0, 203.0),
	Vector2(180.0, 203.0), Vector2(215.0, 203.0), Vector2(250.0, 203.0),
	Vector2(-30.0, 247.0), Vector2(10.0, 247.0), Vector2(50.0, 247.0),
]

const COLOR_SCREEN_DIM := Color(0.008, 0.012, 0.018, 0.94)
const COLOR_PANEL_SHADOW := Color(0.0, 0.0, 0.0, 0.72)
const COLOR_PANEL := Color(0.055, 0.075, 0.086, 1.0)
const COLOR_MAP_GROUND := Color(0.13, 0.16, 0.15, 1.0)
const COLOR_MAP_GRID := Color(0.28, 0.34, 0.31, 0.14)
const COLOR_MAP_TINT := Color(0.045, 0.105, 0.075, 0.20)
const COLOR_BORDER := Color(0.55, 0.67, 0.58, 1.0)
const COLOR_ROAD_EDGE := Color(0.025, 0.032, 0.035, 1.0)
const COLOR_ROAD := Color(0.24, 0.27, 0.27, 1.0)
const COLOR_ROAD_MARKING := Color(0.65, 0.57, 0.34, 0.8)
const COLOR_HOUSE := Color(0.38, 0.35, 0.31, 1.0)
const COLOR_HOUSE_ROOF := Color(0.22, 0.20, 0.19, 1.0)
const COLOR_LANDMARK := Color(0.39, 0.56, 0.51, 1.0)
const COLOR_TEXT := Color(0.82, 0.90, 0.82, 1.0)
const COLOR_MUTED_TEXT := Color(0.56, 0.66, 0.59, 1.0)
const COLOR_PLAYER := Color(0.96, 0.79, 0.32, 1.0)
const PIXEL_STEP := 2.0
const MAP_TEXTURE: Texture2D = preload("res://img/items/cicely_town_map.png")
# Calibrated from the PDF's main-road junction and residential turnarounds.
# Values are pixels in the 2376 x 1836 map texture; +Z runs down the page.
@export_category("Town Map Image")
@export var use_image_map: bool = true
@export var map_texture: Texture2D = MAP_TEXTURE
@export var map_origin: Vector2 = Vector2(1137.893, 229.696)
@export var world_scale: Vector2 = Vector2(3.433656, 3.487944)
@export var require_inventory_item: bool = true
@export var required_item_id: StringName = &"map"
@export var show_coordinates_footer: bool = true

@export_category("References & Behavior")
@export var player_path: NodePath = NodePath("../../Player")
@export var environment_path: NodePath = NodePath("../../WorldEnvironment")
@export var toggle_action: StringName = &"map_toggle"
@export var pause_while_open: bool = true
@export_range(100.0, 1000.0, 10.0) var overhead_camera_height: float = 480.0

var _player: Node3D
var _map_viewport: SubViewport
var _map_camera: Camera3D
var _world_environment: WorldEnvironment
var _map_rect := Rect2()
var _is_open: bool = false
var _tree_was_paused: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	add_to_group("world_map")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = _resolve_player()
	_map_viewport = get_node_or_null("../MapViewport") as SubViewport
	if is_instance_valid(_map_viewport):
		_map_viewport.world_3d = get_viewport().world_3d
		_map_camera = _map_viewport.get_node_or_null("TopCamera") as Camera3D
		_configure_overhead_camera()
	_world_environment = get_node_or_null(environment_path) as WorldEnvironment
	visible = false
	set_process(true)
	set_process_unhandled_input(true)


func _resolve_player() -> Node3D:
	if is_instance_valid(_player):
		return _player
	var p: Node3D = get_node_or_null(player_path) as Node3D
	if not is_instance_valid(p):
		p = get_tree().get_first_node_in_group("player") as Node3D
	_player = p
	return _player


func has_town_map() -> bool:
	if not require_inventory_item:
		return true
	var p := _resolve_player()
	if not is_instance_valid(p):
		return true # Default to true in isolated test scenes where no player exists
	if p.has_method(&"has_item"):
		return p.has_item(String(required_item_id))
	if "inventory" in p and is_instance_valid(p.inventory):
		return p.inventory.has_item(required_item_id)
	return false


func _exit_tree() -> void:
	_set_overhead_rendering(false)
	_set_runtime_map_lighting(false)
	if _is_open and pause_while_open and not _tree_was_paused and get_tree() != null:
		get_tree().paused = false


func _process(_delta: float) -> void:
	if _is_open:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return

	if event.is_action_pressed(toggle_action):
		var story := get_tree().get_first_node_in_group("opening_story")
		if story != null and bool(story.get("document_open")):
			return
		if not _is_open:
			if not has_town_map():
				return
			set_map_open(true)
		else:
			set_map_open(false)
		get_viewport().set_input_as_handled()
	elif _is_open and event.is_action_pressed(&"ui_cancel"):
		set_map_open(false)
		get_viewport().set_input_as_handled()


func set_map_open(should_open: bool) -> void:
	if should_open == _is_open:
		return

	_is_open = should_open
	visible = should_open
	if should_open:
		_tree_was_paused = get_tree().paused
		_previous_mouse_mode = Input.mouse_mode
		_set_runtime_map_lighting(true)
		_set_overhead_rendering(true)
		if pause_while_open:
			get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		queue_redraw()
	else:
		_set_overhead_rendering(false)
		_set_runtime_map_lighting(false)
		if pause_while_open and not _tree_was_paused:
			get_tree().paused = false
		Input.mouse_mode = _previous_mouse_mode


func is_map_open() -> bool:
	return _is_open


func _draw() -> void:
	if not _is_open:
		return

	draw_rect(Rect2(Vector2.ZERO, size), COLOR_SCREEN_DIM)

	if use_image_map and is_instance_valid(map_texture):
		_map_rect = _calculate_panel_rect()
		# Drop shadow
		draw_rect(Rect2(_map_rect.position + Vector2(6.0, 8.0), _map_rect.size), COLOR_PANEL_SHADOW)
		# Paper map texture
		draw_texture_rect(map_texture, _map_rect, false)
		# Vintage map border
		draw_rect(_map_rect, Color(0.35, 0.30, 0.24, 0.85), false, 2.0)
		# Live player waypoint with facing arrow & beacon
		_draw_player_waypoint()
		# Footer
		_draw_footer(_map_rect)
		return

	var panel_rect := _calculate_panel_rect()
	draw_rect(Rect2(panel_rect.position + Vector2(8.0, 8.0), panel_rect.size), COLOR_PANEL_SHADOW)
	draw_rect(panel_rect, COLOR_PANEL)
	draw_rect(panel_rect, COLOR_BORDER, false, 2.0)

	var header_height := 42.0
	var footer_height := 34.0
	_map_rect = Rect2(
		panel_rect.position + Vector2(14.0, header_height),
		panel_rect.size - Vector2(28.0, header_height + footer_height)
	)
	draw_rect(_map_rect, COLOR_MAP_GROUND)
	if not _draw_overhead_map():
		_draw_terrain_speckles()
		_draw_roads()
		_draw_houses()
	_draw_pixel_grid()
	_draw_landmarks()
	_draw_player_marker()
	_draw_scanlines()
	draw_rect(_map_rect, COLOR_BORDER.darkened(0.18), false, 2.0)
	_draw_header_and_footer(panel_rect)


func _calculate_panel_rect() -> Rect2:
	if use_image_map and is_instance_valid(map_texture):
		var tex_sz := map_texture.get_size()
		var target_ratio := tex_sz.x / tex_sz.y
		var available_panel := size - Vector2(48.0, 48.0)
		var map_w := available_panel.x
		var map_h := map_w / target_ratio
		if map_h > available_panel.y:
			map_h = available_panel.y
			map_w = map_h * target_ratio
		map_w = floorf(map_w / PIXEL_STEP) * PIXEL_STEP
		map_h = floorf(map_h / PIXEL_STEP) * PIXEL_STEP
		return Rect2((size - Vector2(map_w, map_h)) * 0.5, Vector2(map_w, map_h))

	var panel_padding := Vector2(28.0, 76.0)
	var available_panel := size - Vector2(48.0, 40.0)
	var map_size := available_panel - panel_padding
	var target_ratio := WORLD_BOUNDS.size.x / WORLD_BOUNDS.size.y
	if map_size.x / map_size.y > target_ratio:
		map_size.x = map_size.y * target_ratio
	else:
		map_size.y = map_size.x / target_ratio
	var panel_size := map_size + panel_padding
	panel_size.x = floorf(panel_size.x / PIXEL_STEP) * PIXEL_STEP
	panel_size.y = floorf(panel_size.y / PIXEL_STEP) * PIXEL_STEP
	return Rect2((size - panel_size) * 0.5, panel_size)


func _configure_overhead_camera() -> void:
	if not is_instance_valid(_map_camera):
		return
	var world_center := WORLD_BOUNDS.get_center()
	_map_camera.global_position = Vector3(world_center.x, overhead_camera_height, world_center.y)
	_map_camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_map_camera.size = WORLD_BOUNDS.size.y


func _set_overhead_rendering(is_active: bool) -> void:
	if not is_instance_valid(_map_viewport):
		return
	_map_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if is_active else SubViewport.UPDATE_DISABLED
	)


func _set_runtime_map_lighting(is_active: bool) -> void:
	if not is_instance_valid(_world_environment):
		_world_environment = get_node_or_null(environment_path) as WorldEnvironment
	if is_instance_valid(_world_environment) and _world_environment.has_method(&"set_runtime_overhead_preview_active"):
		_world_environment.call(&"set_runtime_overhead_preview_active", is_active)


func _draw_overhead_map() -> bool:
	if not is_instance_valid(_map_viewport):
		return false
	var viewport_texture := _map_viewport.get_texture()
	if viewport_texture == null:
		return false
	draw_texture_rect(viewport_texture, _map_rect, false, Color(0.92, 1.04, 0.96, 1.0))
	draw_rect(_map_rect, COLOR_MAP_TINT)
	return true


func _draw_pixel_grid() -> void:
	var grid_spacing := maxf(18.0, floorf(_map_rect.size.x / 24.0))
	var x := _map_rect.position.x
	while x <= _map_rect.end.x:
		draw_line(Vector2(_snap(x), _map_rect.position.y), Vector2(_snap(x), _map_rect.end.y), COLOR_MAP_GRID, 1.0)
		x += grid_spacing
	var y := _map_rect.position.y
	while y <= _map_rect.end.y:
		draw_line(Vector2(_map_rect.position.x, _snap(y)), Vector2(_map_rect.end.x, _snap(y)), COLOR_MAP_GRID, 1.0)
		y += grid_spacing


func _draw_terrain_speckles() -> void:
	for index in range(72):
		var px := fposmod(float(index * 83 + 17), 617.0) / 617.0
		var py := fposmod(float(index * 47 + 31), 409.0) / 409.0
		var point := _map_rect.position + Vector2(px * _map_rect.size.x, py * _map_rect.size.y)
		var color := Color(0.46, 0.52, 0.43, 0.18 if index % 3 else 0.28)
		draw_rect(Rect2(_snap_vector(point), Vector2(2.0, 2.0)), color)


func _draw_roads() -> void:
	for road: Rect2 in ROAD_RECTS:
		var road_rect := _world_rect_to_map(road)
		draw_rect(road_rect.grow(2.0), COLOR_ROAD_EDGE)
		draw_rect(road_rect, COLOR_ROAD)

	var turnaround_center := _world_to_map(Vector2(-50.0, 225.0))
	draw_circle(turnaround_center, maxf(7.0, _world_length_to_map(9.0)), COLOR_ROAD_EDGE)
	draw_circle(turnaround_center, maxf(5.0, _world_length_to_map(7.0)), COLOR_ROAD)

	_draw_dashed_world_line(Vector2(-295.0, 0.0), Vector2(295.0, 0.0))
	_draw_dashed_world_line(Vector2(100.0, 5.0), Vector2(100.0, 372.0))
	_draw_dashed_world_line(Vector2(-116.0, 125.0), Vector2(95.0, 125.0))
	_draw_dashed_world_line(Vector2(-43.0, 225.0), Vector2(270.0, 225.0))


func _draw_dashed_world_line(world_start: Vector2, world_end: Vector2) -> void:
	var start := _world_to_map(world_start)
	var end := _world_to_map(world_end)
	var length := start.distance_to(end)
	if length <= 0.0:
		return
	var direction := start.direction_to(end)
	var cursor := 0.0
	while cursor < length:
		var segment_end := minf(cursor + 7.0, length)
		draw_line(_snap_vector(start + direction * cursor), _snap_vector(start + direction * segment_end), COLOR_ROAD_MARKING, 1.0)
		cursor += 12.0


func _draw_houses() -> void:
	for index in range(HOUSE_POSITIONS.size()):
		var world_position: Vector2 = HOUSE_POSITIONS[index]
		var world_size := Vector2(13.0, 8.0)
		if index >= 14 and index <= 25:
			world_size = Vector2(8.0, 14.0)
		var house_rect := _world_rect_to_map(Rect2(world_position - world_size * 0.5, world_size))
		draw_rect(house_rect.grow(1.0), COLOR_HOUSE_ROOF)
		draw_rect(house_rect, COLOR_HOUSE)
		var door_size := Vector2(2.0, 2.0)
		draw_rect(Rect2(_snap_vector(house_rect.get_center() - door_size * 0.5), door_size), COLOR_MUTED_TEXT)


func _draw_landmarks() -> void:
	_draw_landmark(Vector2(70, -14), "WELCOME CENTER", COLOR_LANDMARK)
	_draw_landmark(Vector2(-166, 125), "CARRIE'S HOUSE", COLOR_LANDMARK)
	var story := get_tree().get_first_node_in_group("opening_story")
	if story != null and int(story.get("stage")) < 5:
		var target: Vector3 = story.get("target_position")
		_draw_landmark(Vector2(target.x, target.z), "SEARCH HERE", COLOR_PLAYER)
	_draw_landmark(Vector2(145.0, 26.0), "GAS STATION", Color(0.88, 0.70, 0.30, 1.0))
	_draw_landmark(Vector2(160.0, 285.0), "CIVIC BLOCK", COLOR_LANDMARK)
	_draw_landmark(Vector2(245.0, 251.0), "HOSPITAL", Color(0.42, 0.72, 0.76, 1.0))


func _draw_landmark(world_position: Vector2, label: String, color: Color) -> void:
	var center := _world_to_map(world_position)
	draw_circle(center, 7.0, Color(0.01, 0.015, 0.014, 0.92))
	draw_circle(center, 5.0, color)
	draw_circle(center, 7.0, color.lightened(0.18), false, 1.5)

	var font := ThemeDB.fallback_font
	var font_size := 12
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var text_position := _snap_vector(center + Vector2(11.0, -7.0))
	var label_rect := Rect2(text_position + Vector2(-3.0, -font_size), text_size + Vector2(6.0, 5.0))
	draw_rect(label_rect, Color(0.015, 0.025, 0.022, 0.84))
	draw_rect(label_rect, color.darkened(0.2), false, 1.0)
	draw_string(font, text_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, COLOR_TEXT)


func _draw_player_marker() -> void:
	if not is_instance_valid(_player):
		_player = get_node_or_null(player_path) as Node3D
	if not is_instance_valid(_player):
		return

	var world_position := Vector2(_player.global_position.x, _player.global_position.z)
	var center := _world_to_map(world_position)
	var forward := -_player.global_transform.basis.z.normalized()
	var angle := Vector2(forward.x, forward.z).angle() + PI * 0.5
	var local_points := PackedVector2Array([
		Vector2(0.0, -10.0),
		Vector2(7.0, 7.0),
		Vector2(0.0, 4.0),
		Vector2(-7.0, 7.0),
	])
	var points := PackedVector2Array()
	for point in local_points:
		points.append(_snap_vector(center + point.rotated(angle)))
	draw_circle(center, 13.0, Color(0.02, 0.025, 0.025, 0.9))
	draw_circle(center, 12.0, COLOR_PLAYER.darkened(0.35), false, 2.0)
	draw_colored_polygon(points, COLOR_PLAYER)
	draw_string(ThemeDB.fallback_font, _snap_vector(center + Vector2(14.0, -12.0)), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, COLOR_PLAYER)


func _draw_player_waypoint() -> void:
	if not is_instance_valid(_player):
		_player = _resolve_player()
	if not is_instance_valid(_player):
		return

	var world_pos := Vector2(_player.global_position.x, _player.global_position.z)
	var screen_pos := _world_to_map(world_pos)

	# Clamped to map rect bounds with margin so the player arrow stays visible
	var margin := 16.0
	var clamped_pos := Vector2(
		clampf(screen_pos.x, _map_rect.position.x + margin, _map_rect.end.x - margin),
		clampf(screen_pos.y, _map_rect.position.y + margin, _map_rect.end.y - margin)
	)

	# Live rotation from player's forward direction
	var forward := -_player.global_transform.basis.z
	var angle := atan2(forward.x, -forward.z)

	# Green directional arrow (slightly bigger, clean GPS style)
	var arrow_pts := PackedVector2Array([
		Vector2(0.0, -16.0),   # tip
		Vector2(8.0, 7.5),     # right wing
		Vector2(0.0, 3.5),     # inner notch
		Vector2(-8.0, 7.5),    # left wing
	])
	var rot_pts := PackedVector2Array()
	var shadow_pts := PackedVector2Array()
	for pt in arrow_pts:
		var rotated_pt := pt.rotated(angle)
		rot_pts.append(_snap_vector(clamped_pos + rotated_pt))
		shadow_pts.append(_snap_vector(clamped_pos + Vector2(1.5, 2.0) + rotated_pt))

	# Soft shadow
	draw_colored_polygon(shadow_pts, Color(0.0, 0.0, 0.0, 0.45))
	# Vibrant green arrow body
	draw_colored_polygon(rot_pts, Color(0.16, 0.82, 0.36, 1.0))
	# Crisp dark outline
	draw_polyline(rot_pts + PackedVector2Array([rot_pts[0]]), Color(0.04, 0.24, 0.08, 0.95), 1.5)


func _draw_footer(panel_rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 12
	var footer_y := panel_rect.end.y + 18.0
	if footer_y + 6.0 > size.y:
		footer_y = panel_rect.end.y - 8.0

	draw_string(font, Vector2(panel_rect.position.x, footer_y), "M / ESC   CLOSE MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_MUTED_TEXT)

	if show_coordinates_footer and is_instance_valid(_player):
		var location := "X: %d   Z: %d" % [roundi(_player.global_position.x), roundi(_player.global_position.z)]
		draw_string(font, Vector2(panel_rect.end.x - 120.0, footer_y), location, HORIZONTAL_ALIGNMENT_RIGHT, -1, font_size, COLOR_MUTED_TEXT)


func _draw_scanlines() -> void:
	var y := _map_rect.position.y + 2.0
	while y < _map_rect.end.y:
		draw_line(Vector2(_map_rect.position.x, y), Vector2(_map_rect.end.x, y), Color(0.0, 0.0, 0.0, 0.07), 1.0)
		y += 4.0


func _draw_header_and_footer(panel_rect: Rect2) -> void:
	draw_string(ThemeDB.fallback_font, panel_rect.position + Vector2(16.0, 28.0), "NEIGHBORHOOD MAP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, COLOR_TEXT)
	draw_string(ThemeDB.fallback_font, panel_rect.position + Vector2(panel_rect.size.x - 45.0, 28.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, COLOR_PLAYER)
	var compass_x := panel_rect.end.x - 36.0
	draw_line(Vector2(compass_x, panel_rect.position.y + 31.0), Vector2(compass_x, panel_rect.position.y + 39.0), COLOR_PLAYER, 2.0)

	var footer_y := panel_rect.end.y - 12.0
	draw_string(ThemeDB.fallback_font, Vector2(panel_rect.position.x + 16.0, footer_y), "M / ESC  CLOSE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, COLOR_MUTED_TEXT)
	if is_instance_valid(_player):
		var location := "X %d   Z %d" % [roundi(_player.global_position.x), roundi(_player.global_position.z)]
		draw_string(ThemeDB.fallback_font, Vector2(panel_rect.end.x - 130.0, footer_y), location, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, COLOR_MUTED_TEXT)


func _world_to_map(world_xz: Vector2) -> Vector2:
	if use_image_map and is_instance_valid(map_texture):
		var tex_sz := map_texture.get_size()
		var map_px := map_origin.x + world_xz.x * world_scale.x
		var map_py := map_origin.y + world_xz.y * world_scale.y
		var mapped := Vector2(
			_map_rect.position.x + (map_px / tex_sz.x) * _map_rect.size.x,
			_map_rect.position.y + (map_py / tex_sz.y) * _map_rect.size.y
		)
		return _snap_vector(mapped)

	var normalized_x := inverse_lerp(WORLD_BOUNDS.position.x, WORLD_BOUNDS.end.x, world_xz.x)
	var normalized_z := inverse_lerp(WORLD_BOUNDS.position.y, WORLD_BOUNDS.end.y, world_xz.y)
	var mapped := Vector2(
		lerpf(_map_rect.position.x, _map_rect.end.x, normalized_x),
		lerpf(_map_rect.position.y, _map_rect.end.y, normalized_z)
	)
	return _snap_vector(mapped)


func _world_rect_to_map(world_rect: Rect2) -> Rect2:
	var first := _world_to_map(world_rect.position)
	var second := _world_to_map(world_rect.end)
	var position := Vector2(minf(first.x, second.x), minf(first.y, second.y))
	var rect_size := Vector2(absf(second.x - first.x), absf(second.y - first.y))
	return Rect2(_snap_vector(position), _snap_vector(rect_size))


func _world_length_to_map(world_length: float) -> float:
	return world_length * minf(_map_rect.size.x / WORLD_BOUNDS.size.x, _map_rect.size.y / WORLD_BOUNDS.size.y)


func _snap(value: float) -> float:
	return roundf(value / PIXEL_STEP) * PIXEL_STEP


func _snap_vector(value: Vector2) -> Vector2:
	return Vector2(_snap(value.x), _snap(value.y))
