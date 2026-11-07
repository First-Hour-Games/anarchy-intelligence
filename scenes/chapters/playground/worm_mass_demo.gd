extends Node3D
## The worm mass demo: a grey-box arena in open sky, after the test level the creature was pitched
## from, with the worm mass (worm_mass.gd) idling, lumbering, climbing a wall and lunging, and an
## FPS counter front and centre. Run it straight:
##   Godot_console.exe --path . scenes/chapters/playground/worm_mass_demo.tscn
## Keys: WASD + mouse to fly (click to grab the mouse), 1/2/3 strands 300/600/900, SPACE the wall
## climb, L a lunge at the camera, T come-here, I stand down.
## With --write-movie it instead plays a scripted half-minute for the review board and quits:
##   Godot_console.exe --path . scenes/chapters/playground/worm_mass_demo.tscn
##     --write-movie <dir>/frames.png --fixed-fps 30 --resolution 1280x720 --windowed

const WALL_CENTRE := Vector3(-5.0, 1.3, -3.0)
const WALL_SIZE := Vector3(6.0, 2.6, 0.4)
## The scripted film: entity beats, strand counts and captions at their moments.
const FILM := [
	[0.4, "caption", "A mass of worms — 600 strands on the GPU"],
	[5.2, "walk", Vector3(0.0, 0.0, 2.6)],
	[5.4, "caption", "The strands cost the CPU nothing"],
	[10.0, "walk", Vector3(-5.0, 0.0, -1.3)],
	[10.2, "caption", ""],
	[15.8, "caption", "It climbs"],
	[16.0, "climb", 0.0],
	[21.6, "walk", Vector3(-2.5, 0.0, -4.6)],
	[21.8, "caption", ""],
	[22.0, "density", 300], [22.1, "caption", "300 strands"],
	[25.0, "density", 600], [25.1, "caption", "600 strands"],
	[28.0, "density", 900], [28.1, "caption", "900 strands"],
	[30.6, "caption", ""],
	[31.2, "lunge", Vector3(-2.5, 0.0, -7.1)],
	[32.3, "fade", 0.0],
	[33.6, "quit", 0.0],
]
## The film's camera: from `t0` to `t1` it slides between the given stands and gazes; a gap in time
## between one key and the next is a cut.
const CAMERA_KEYS := [
	[0.0, 5.2, Vector3(4.5, 2.1, 6.0), Vector3(-4.0, 2.3, 6.0), Vector3(0, 1.3, 0), Vector3(0, 1.3, 0)],
	[5.2, 10.0, Vector3(-4.0, 2.3, 6.0), Vector3(0.0, 1.2, 5.4), Vector3(0, 1.3, 0), Vector3(0, 1.2, 2.0)],
	[10.0, 15.8, Vector3(0.0, 1.2, 5.4), Vector3(-8.6, 1.7, 1.8), Vector3(0, 1.2, 2.0), Vector3(-5.0, 1.2, -2.2)],
	[15.8, 21.6, Vector3(-8.6, 1.7, 1.8), Vector3(-7.4, 2.4, 0.4), Vector3(-5.0, 1.0, -2.2), Vector3(-5.0, 2.5, -3.0)],
	[21.6, 24.6, Vector3(0.4, 1.6, -5.2), Vector3(-1.0, 1.8, -7.4), Vector3(-2.5, 1.2, -4.6), Vector3(-2.5, 1.2, -4.6)],
	[24.6, 27.6, Vector3(-1.0, 1.8, -7.4), Vector3(-4.2, 1.8, -7.3), Vector3(-2.5, 1.2, -4.6), Vector3(-2.5, 1.2, -4.6)],
	[27.6, 30.6, Vector3(-4.2, 1.8, -7.3), Vector3(-5.4, 1.7, -5.0), Vector3(-2.5, 1.2, -4.6), Vector3(-2.5, 1.2, -4.6)],
	[30.6, 33.6, Vector3(-2.5, 1.45, -8.3), Vector3(-2.5, 1.45, -8.3), Vector3(-2.5, 1.0, -4.6), Vector3(-2.5, 1.3, -6.6)],
]

var movie_mode := false
var film_t := 0.0
var film_next := 0
var camera: Camera3D
var fps_label: Label
var detail_label: Label
var strands_label: Label
var caption_label: Label
var fade_rect: ColorRect
var fps_timer := 0.0
var mouse_held := false
var _fly_pitch := 0.0

@onready var worm: WormMass = $WormMass


func _ready() -> void:
	movie_mode = OS.has_feature("movie")
	if movie_mode:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = Vector2i(1280, 720)
		get_viewport().scaling_3d_scale = 1.0
	for autoload_name in ["PauseMenu", "DebugMenu"]:
		var autoload := get_node_or_null("/root/" + autoload_name)
		if autoload != null:
			autoload.set_process_unhandled_input(false)
			autoload.set_process_input(false)
	_build_environment()
	_build_arena()
	_build_camera()
	_build_hud()
	worm.global_position = Vector3.ZERO
	if movie_mode:
		worm.set_density(600)


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.3, 0.46, 0.72)
	sky_material.sky_horizon_color = Color(0.64, 0.71, 0.8)
	sky_material.ground_bottom_color = Color(0.5, 0.56, 0.62)
	sky_material.ground_horizon_color = Color(0.64, 0.71, 0.8)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 1.0
	environment.ambient_light_energy = 1.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)


## The grey tiled arena floating in the sky, like the test level the creature was shown in: a
## floor, the wall it climbs, and a couple of pillars to walk among.
func _build_arena() -> void:
	var tile := _tile_material(Color(0.66, 0.67, 0.69))
	var wall_tile := _tile_material(Color(0.72, 0.74, 0.78))
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(40.0, 0.5, 40.0)
	floor_box.material = tile
	floor_mesh.mesh = floor_box
	floor_mesh.position = Vector3(0.0, -0.25, 0.0)
	add_child(floor_mesh)
	var wall := MeshInstance3D.new()
	wall.name = "ClimbWall"
	var wall_box := BoxMesh.new()
	wall_box.size = WALL_SIZE
	wall_box.material = wall_tile
	wall.mesh = wall_box
	wall.position = WALL_CENTRE
	add_child(wall)
	for entry: Array in [[Vector3(3.0, 1.3, -4.0), Vector3(1.0, 2.6, 1.0)], [Vector3(5.5, 1.3, 0.5), Vector3(1.2, 2.6, 1.2)]]:
		var pillar := MeshInstance3D.new()
		pillar.name = "Pillar"
		var pillar_box := BoxMesh.new()
		pillar_box.size = entry[1]
		pillar_box.material = wall_tile
		pillar.mesh = pillar_box
		pillar.position = entry[0]
		add_child(pillar)


## A one-metre tile drawn in code: flat grey with a darker seam, triplanar so every box wears it.
func _tile_material(base: Color) -> StandardMaterial3D:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var seam := Color(base.r * 0.82, base.g * 0.82, base.b * 0.84)
	for y in size:
		for x in size:
			image.set_pixel(x, y, seam if x < 3 or y < 3 or x >= size - 3 or y >= size - 3 else base)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.roughness = 0.9
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE
	return material


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "DemoCamera"
	camera.fov = 70.0
	add_child(camera)
	camera.position = Vector3(4.5, 2.1, 6.0)
	camera.look_at(Vector3(0.0, 1.3, 0.0))


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "Hud"
	add_child(hud)
	fps_label = Label.new()
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_label.add_theme_font_size_override("font_size", 46)
	fps_label.add_theme_color_override("font_color", Color(0.36, 0.95, 0.83))
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	fps_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fps_label.position.y = 24.0
	hud.add_child(fps_label)
	detail_label = Label.new()
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 15)
	detail_label.add_theme_color_override("font_color", Color(0.8, 0.86, 0.9))
	detail_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	detail_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	detail_label.position.y = 78.0
	hud.add_child(detail_label)
	strands_label = Label.new()
	strands_label.add_theme_font_size_override("font_size", 22)
	strands_label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.88))
	strands_label.position = Vector2(18.0, 16.0)
	hud.add_child(strands_label)
	caption_label = Label.new()
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size", 24)
	caption_label.add_theme_color_override("font_color", Color(0.95, 0.94, 0.92))
	caption_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	caption_label.add_theme_constant_override("shadow_offset_y", 2)
	caption_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	caption_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caption_label.position.y = -64.0
	hud.add_child(caption_label)
	if not movie_mode:
		var hint := Label.new()
		hint.text = "click: grab mouse • WASD/QE fly • 1/2/3 strands • SPACE climb • L lunge • T come here • I stop"
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
		hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		hint.position = Vector2(18.0, -30.0)
		hud.add_child(hint)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade_rect)


func _process(delta: float) -> void:
	worm.scout_focus = Vector3(camera.global_position.x, 0.0, camera.global_position.z)
	_update_hud(delta)
	if movie_mode:
		_run_film(delta)
	else:
		_fly(delta)


func _update_hud(delta: float) -> void:
	strands_label.text = "strands: %d" % worm.strands_shown()
	fps_timer -= delta
	if fps_timer > 0.0:
		return
	fps_timer = 0.25
	if movie_mode:
		fps_label.text = ""
		detail_label.text = ""
		return
	var fps := Engine.get_frames_per_second()
	fps_label.text = "%d FPS" % int(fps)
	detail_label.text = "%.1f ms • vsync off • %s" % [1000.0 / maxf(fps, 1.0), "%d×%d" % [get_window().size.x, get_window().size.y]]


# --- The scripted film --------------------------------------------------------------------------

func _run_film(delta: float) -> void:
	film_t += delta
	while film_next < FILM.size() and film_t >= float(FILM[film_next][0]):
		_film_event(String(FILM[film_next][1]), FILM[film_next][2])
		film_next += 1
	for key: Array in CAMERA_KEYS:
		if film_t >= float(key[0]) and film_t <= float(key[1]):
			var s: float = smoothstep(0.0, 1.0, (film_t - float(key[0])) / maxf(float(key[1]) - float(key[0]), 0.01))
			camera.global_position = (key[2] as Vector3).lerp(key[3], s)
			var gaze := (key[4] as Vector3).lerp(key[5], s)
			if camera.global_position.distance_to(gaze) > 0.05:
				camera.look_at(gaze)
			break


func _film_event(kind: String, value: Variant) -> void:
	match kind:
		"caption":
			caption_label.text = String(value)
		"walk":
			worm.walk_to(value)
		"climb":
			_start_climb()
		"lunge":
			worm.lunge_at(value)
		"density":
			worm.set_density(int(value))
		"fade":
			create_tween().tween_property(fade_rect, "color:a", 1.0, 1.0)
		"quit":
			get_tree().quit()


func _start_climb() -> void:
	var toward := signf(worm.global_position.z - WALL_CENTRE.z)
	var top := Vector3(worm.global_position.x, WALL_CENTRE.y + WALL_SIZE.y * 0.5 + 0.1, WALL_CENTRE.z)
	var landing := Vector3(worm.global_position.x, 0.0, WALL_CENTRE.z - toward * 1.9)
	var face := Vector3(worm.global_position.x, 0.9, WALL_CENTRE.z + toward * (WALL_SIZE.z * 0.5 + 0.32))
	worm.climb_over(top, landing, face)


# --- Flying the camera by hand ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if movie_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_held = true
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_held = false
	if event is InputEventMouseMotion and mouse_held:
		camera.rotation.y -= event.relative.x * 0.0028
		_fly_pitch = clampf(_fly_pitch - event.relative.y * 0.0028, -1.5, 1.5)
		camera.rotation.x = _fly_pitch
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: worm.set_density(300)
			KEY_2: worm.set_density(600)
			KEY_3: worm.set_density(900)
			KEY_SPACE:
				worm.walk_to(Vector3(worm.global_position.x, 0.0, WALL_CENTRE.z + 1.7))
				_climb_when_near.call_deferred()
			KEY_L: worm.lunge_at(_camera_floor() + (worm.global_position - _camera_floor()).normalized() * 1.6)
			KEY_T: worm.walk_to(_camera_floor() + (worm.global_position - _camera_floor()).normalized() * 2.2)
			KEY_I: worm.idle()


func _climb_when_near() -> void:
	while worm.state == WormMass.State.WALK:
		await get_tree().physics_frame
	if worm.state == WormMass.State.IDLE:
		_start_climb()


func _camera_floor() -> Vector3:
	return Vector3(camera.global_position.x, 0.0, camera.global_position.z)


func _fly(delta: float) -> void:
	var wish := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		wish -= camera.global_basis.z
	if Input.is_physical_key_pressed(KEY_S):
		wish += camera.global_basis.z
	if Input.is_physical_key_pressed(KEY_A):
		wish -= camera.global_basis.x
	if Input.is_physical_key_pressed(KEY_D):
		wish += camera.global_basis.x
	if Input.is_physical_key_pressed(KEY_Q):
		wish -= Vector3.UP
	if Input.is_physical_key_pressed(KEY_E):
		wish += Vector3.UP
	var speed := 8.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 3.5
	if wish != Vector3.ZERO:
		camera.global_position += wish.normalized() * speed * delta
	camera.global_position.y = maxf(camera.global_position.y, 0.25)
