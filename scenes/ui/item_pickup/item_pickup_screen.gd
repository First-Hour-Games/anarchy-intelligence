extends CanvasLayer

## Silent Hill / Fatal Frame style item acquisition inspection screen.
## Side-by-side layout: Item showcase on the left, item name & description on the right.
## Blurs and dims the background while presenting the item graphic/model,
## item title, description, and bottom-right dismissal controls.

signal opened(item: ItemData)
signal closed(item: ItemData)

static var instance: CanvasLayer = null

@export_group("Atmosphere & Blur")
@export var blur_in_duration: float = 0.30
@export var blur_out_duration: float = 0.22
@export var target_blur_lod: float = 2.6
@export var target_brightness: float = 0.30

var is_active: bool = false
var _is_transitioning: bool = false
var _current_item: ItemData = null
var _close_callback: Callable = Callable()
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

@onready var _overlay: Control = get_node_or_null("Overlay")
@onready var _blur_rect: ColorRect = get_node_or_null("Overlay/BlurRect")
@onready var _blur_material: ShaderMaterial = null
@onready var _dim_rect: ColorRect = get_node_or_null("Overlay/DimRect")
@onready var _content_box: Control = null

@onready var _header_label: Label = null
@onready var _item_image_rect: TextureRect = null
@onready var _model_viewport_container: SubViewportContainer = null
@onready var _model_viewport: SubViewport = null
@onready var _model_pivot: Node3D = null
@onready var _title_label: Label = null
@onready var _description_label: Label = null
@onready var _prompt_label: Label = null
@onready var _sfx_player: AudioStreamPlayer = get_node_or_null("PickupSfxPlayer")


func _init() -> void:
	instance = self


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 98 # Above in-game UI & dialogue (25), behind PauseMenu (99) and CRTOverlay (100)

	if _overlay == null:
		# If instantiated without scene nodes (e.g. script.new()), instantiate scene or procedural fallback
		var scene_res := load("res://scenes/ui/item_pickup/item_pickup_screen.tscn") as PackedScene
		if scene_res:
			var inst := scene_res.instantiate()
			for child in inst.get_children():
				inst.remove_child(child)
				child.owner = null
				add_child(child)
			inst.queue_free()
			_bind_scene_nodes()
		else:
			_build_ui()
	else:
		_bind_scene_nodes()


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _bind_scene_nodes() -> void:
	_overlay = get_node_or_null("Overlay")
	_blur_rect = get_node_or_null("Overlay/BlurRect") if _overlay else null
	_dim_rect = get_node_or_null("Overlay/DimRect") if _overlay else null
	_content_box = _overlay.find_child("ContentBox", true, false) as Control if _overlay else null
	_header_label = _overlay.find_child("HeaderLabel", true, false) as Label if _overlay else null
	_item_image_rect = _overlay.find_child("ItemImageRect", true, false) as TextureRect if _overlay else null
	_model_viewport_container = _overlay.find_child("ModelViewportContainer", true, false) as SubViewportContainer if _overlay else null
	_model_viewport = _overlay.find_child("ModelViewport", true, false) as SubViewport if _overlay else null
	_model_pivot = _overlay.find_child("ModelPivot", true, false) as Node3D if _overlay else null
	_title_label = _overlay.find_child("TitleLabel", true, false) as Label if _overlay else null
	_description_label = _overlay.find_child("DescriptionLabel", true, false) as Label if _overlay else null
	_prompt_label = _overlay.find_child("PromptLabel", true, false) as Label if _overlay else null
	_sfx_player = get_node_or_null("PickupSfxPlayer")

	if is_instance_valid(_blur_rect) and _blur_rect.material is ShaderMaterial:
		_blur_material = _blur_rect.material as ShaderMaterial

	if is_instance_valid(_model_viewport):
		_model_viewport.own_world_3d = true
		if _model_viewport.world_3d == null:
			_model_viewport.world_3d = World3D.new()
		_model_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	if is_instance_valid(_overlay):
		_overlay.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				close()
		)
		_overlay.hide()


static func show_pickup(item_id_or_data: Variant, on_closed: Callable = Callable()) -> CanvasLayer:
	if not is_instance_valid(instance):
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			var scene_res := load("res://scenes/ui/item_pickup/item_pickup_screen.tscn") as PackedScene
			if scene_res:
				var new_screen: CanvasLayer = scene_res.instantiate() as CanvasLayer
				tree.root.add_child(new_screen)
			else:
				var script_res := load("res://scenes/ui/item_pickup/item_pickup_screen.gd") as GDScript
				if script_res:
					var new_screen: CanvasLayer = script_res.new() as CanvasLayer
					tree.root.add_child(new_screen)
	if is_instance_valid(instance):
		instance.display_item(item_id_or_data, on_closed)
		return instance
	return null


var _is_closing: bool = false
var _open_tween: Tween = null
var _close_tween: Tween = null


func display_item(item_id_or_data: Variant, on_closed: Callable = Callable()) -> void:
	var item: ItemData = null
	if item_id_or_data is ItemData:
		item = item_id_or_data
	elif item_id_or_data is String or item_id_or_data is StringName:
		item = ItemDatabase.get_item(StringName(item_id_or_data))

	if item == null:
		item = ItemDatabase.get_item(&"map")

	_current_item = item
	_close_callback = on_closed
	_is_closing = false
	_is_transitioning = true
	is_active = true

	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_setup_item_display(item)
	if is_instance_valid(_overlay):
		_overlay.visible = true

	# Reset visual animation states
	if is_instance_valid(_blur_material):
		_blur_material.set_shader_parameter("lod", 0.0)
		_blur_material.set_shader_parameter("brightness", 1.0)
	if is_instance_valid(_dim_rect):
		_dim_rect.modulate.a = 0.0
	if is_instance_valid(_content_box):
		_content_box.modulate.a = 0.0
		_content_box.scale = Vector2(0.96, 0.96)
		_content_box.pivot_offset = _content_box.size * 0.5
	if is_instance_valid(_prompt_label):
		_prompt_label.modulate.a = 0.0

	# Play pickup SFX
	_play_pickup_sound(item)

	if _close_tween and _close_tween.is_valid():
		_close_tween.kill()
	if _open_tween and _open_tween.is_valid():
		_open_tween.kill()

	_open_tween = create_tween().set_parallel(true)
	_open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if is_instance_valid(_blur_material):
		_open_tween.tween_property(_blur_material, "shader_parameter/lod", target_blur_lod, blur_in_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_open_tween.tween_property(_blur_material, "shader_parameter/brightness", target_brightness, blur_in_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_dim_rect):
		_open_tween.tween_property(_dim_rect, "modulate:a", 1.0, blur_in_duration)
	if is_instance_valid(_content_box):
		_open_tween.tween_property(_content_box, "modulate:a", 1.0, blur_in_duration * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_open_tween.tween_property(_content_box, "scale", Vector2.ONE, blur_in_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_prompt_label):
		_open_tween.tween_property(_prompt_label, "modulate:a", 0.8, blur_in_duration)

	_open_tween.chain().tween_callback(func():
		_is_transitioning = false
		opened.emit(_current_item)
	)


func close() -> void:
	if not is_active or _is_closing:
		return
	_is_closing = true
	_is_transitioning = true

	if _open_tween and _open_tween.is_valid():
		_open_tween.kill()
	if _close_tween and _close_tween.is_valid():
		_close_tween.kill()

	_close_tween = create_tween().set_parallel(true)
	_close_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if is_instance_valid(_content_box):
		_close_tween.tween_property(_content_box, "modulate:a", 0.0, blur_out_duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if is_instance_valid(_prompt_label):
		_close_tween.tween_property(_prompt_label, "modulate:a", 0.0, blur_out_duration * 0.5)
	if is_instance_valid(_blur_material):
		_close_tween.tween_property(_blur_material, "shader_parameter/lod", 0.0, blur_out_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_close_tween.tween_property(_blur_material, "shader_parameter/brightness", 1.0, blur_out_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_dim_rect):
		_close_tween.tween_property(_dim_rect, "modulate:a", 0.0, blur_out_duration)

	var finished_item := _current_item
	var finished_cb := _close_callback

	_close_tween.chain().tween_callback(func():
		if is_instance_valid(_overlay):
			_overlay.visible = false
		is_active = false
		_is_closing = false
		_is_transitioning = false
		_current_item = null
		_close_callback = Callable()
		if is_instance_valid(_model_viewport):
			_model_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

		closed.emit(finished_item)
		if finished_cb.is_valid():
			finished_cb.call()
	)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active or _is_transitioning:
		return

	var should_dismiss := false
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"interact"):
		should_dismiss = true
	elif event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
			should_dismiss = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		should_dismiss = true

	if should_dismiss:
		get_viewport().set_input_as_handled()
		close()


func _process(_delta: float) -> void:
	if not is_active:
		return
	# Pulse continue prompt
	if is_instance_valid(_prompt_label) and not _is_transitioning and not _is_closing:
		var flash: float = (sin(Time.get_ticks_msec() * 0.005) + 1.0) * 0.5
		_prompt_label.modulate.a = lerp(0.45, 0.95, flash)

	# Slow rotate 3D preview if active
	if is_instance_valid(_model_pivot) and is_instance_valid(_model_viewport_container) and _model_viewport_container.visible:
		_model_pivot.rotation.y += _delta * 0.6


func _setup_item_display(item: ItemData) -> void:
	if is_instance_valid(_title_label):
		_title_label.text = item.name.to_upper()
	if is_instance_valid(_description_label):
		_description_label.text = item.description

	# 3D Model showcase takes priority if available
	if item.model_scene != null:
		if is_instance_valid(_item_image_rect):
			_item_image_rect.visible = false
		if is_instance_valid(_model_viewport_container):
			_model_viewport_container.visible = true
		if is_instance_valid(_model_viewport):
			_model_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if is_instance_valid(_model_pivot):
			for child in _model_pivot.get_children():
				child.queue_free()
			var model_node := item.model_scene.instantiate()
			_model_pivot.add_child(model_node)
			_model_pivot.rotation = Vector3(deg_to_rad(-10.0), 0.0, deg_to_rad(-5.0))
	else:
		if is_instance_valid(_model_viewport_container):
			_model_viewport_container.visible = false
		if is_instance_valid(_model_viewport):
			_model_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if is_instance_valid(_item_image_rect):
			_item_image_rect.visible = true
			if item.image != null:
				_item_image_rect.texture = item.image
			else:
				_item_image_rect.texture = preload("res://img/items/brochure_map_placeholder.png")


func _play_pickup_sound(item: ItemData) -> void:
	if not is_instance_valid(_sfx_player):
		return
	if item.pickup_sound != null:
		_sfx_player.stream = item.pickup_sound
	else:
		_sfx_player.stream = preload("res://sounds/ui/move.mp3")
	_sfx_player.pitch_scale = randf_range(0.97, 1.03)
	_sfx_player.play()


func _build_ui() -> void:
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close()
	)
	add_child(_overlay)

	# 1. Blur Screen Layer
	_blur_rect = ColorRect.new()
	_blur_rect.name = "BlurRect"
	_blur_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blur_shader: Shader = preload("res://shaders/blur.gdshader")
	_blur_material = ShaderMaterial.new()
	_blur_material.shader = blur_shader
	_blur_material.set_shader_parameter("lod", 0.0)
	_blur_material.set_shader_parameter("brightness", 1.0)
	_blur_rect.material = _blur_material
	_overlay.add_child(_blur_rect)

	# 2. Mood Tint / Dark Vignette Layer
	_dim_rect = ColorRect.new()
	_dim_rect.name = "DimRect"
	_dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_rect.color = Color(0.01, 0.015, 0.02, 0.55)
	_overlay.add_child(_dim_rect)

	# 3. 4:3 Aspect Ratio Container matching CRT & Pause presentation
	var arc := AspectRatioContainer.new()
	arc.name = "AspectRatioContainer"
	arc.ratio = 1.33333
	arc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(arc)

	var content := Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arc.add_child(content)

	# Black bars outside 4:3 window
	_create_black_gutters(content)

	# 4. Main Margins for side-by-side split
	var main_margin := MarginContainer.new()
	main_margin.name = "MainMargin"
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_margin.add_theme_constant_override("margin_left", 50)
	main_margin.add_theme_constant_override("margin_top", 50)
	main_margin.add_theme_constant_override("margin_right", 50)
	main_margin.add_theme_constant_override("margin_bottom", 70)
	content.add_child(main_margin)

	_content_box = HBoxContainer.new()
	_content_box.name = "ContentBox"
	_content_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_content_box.add_theme_constant_override("separation", 40)
	_content_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_margin.add_child(_content_box)

	var font: Font = preload("res://fonts/EuropeanTeletextNuevo.ttf")

	# LEFT SIDE: Item Showcase
	var showcase_area := CenterContainer.new()
	showcase_area.name = "ShowcaseArea"
	showcase_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_box.add_child(showcase_area)

	var showcase_frame := CenterContainer.new()
	showcase_frame.name = "ShowcaseFrame"
	showcase_frame.custom_minimum_size = Vector2(360, 360)
	showcase_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase_area.add_child(showcase_frame)

	_item_image_rect = TextureRect.new()
	_item_image_rect.name = "ItemImageRect"
	_item_image_rect.custom_minimum_size = Vector2(320, 320)
	_item_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item_image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase_frame.add_child(_item_image_rect)

	_model_viewport_container = SubViewportContainer.new()
	_model_viewport_container.name = "ModelViewportContainer"
	_model_viewport_container.custom_minimum_size = Vector2(360, 360)
	_model_viewport_container.stretch = true
	_model_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_model_viewport_container.visible = false
	showcase_frame.add_child(_model_viewport_container)

	_model_viewport = SubViewport.new()
	_model_viewport.name = "ModelViewport"
	_model_viewport.own_world_3d = true
	_model_viewport.world_3d = World3D.new()
	_model_viewport.transparent_bg = true
	_model_viewport.size = Vector2i(360, 360)
	_model_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_model_viewport_container.add_child(_model_viewport)

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0, 0.2, 1.25)
	cam.rotation_degrees = Vector3(-15, 0, 0)
	_model_viewport.add_child(cam)

	var light := DirectionalLight3D.new()
	light.name = "KeyLight"
	light.rotation_degrees = Vector3(-35, 45, 0)
	light.light_energy = 1.3
	_model_viewport.add_child(light)

	var fill_light := DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.rotation_degrees = Vector3(20, -135, 0)
	fill_light.light_energy = 0.45
	_model_viewport.add_child(fill_light)

	_model_pivot = Node3D.new()
	_model_pivot.name = "ModelPivot"
	_model_viewport.add_child(_model_pivot)

	# RIGHT SIDE: Information
	var info_area := VBoxContainer.new()
	info_area.name = "InfoArea"
	info_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_area.alignment = BoxContainer.ALIGNMENT_CENTER
	info_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_box.add_child(info_area)

	var text_column := VBoxContainer.new()
	text_column.name = "TextColumn"
	text_column.add_theme_constant_override("separation", 16)
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_area.add_child(text_column)

	_header_label = Label.new()
	_header_label.name = "HeaderLabel"
	_header_label.text = "ITEM OBTAINED"
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header_label.add_theme_font_override("font", font)
	_header_label.add_theme_font_size_override("font_size", 14)
	_header_label.modulate = Color(0.82, 0.66, 0.35, 0.75)
	text_column.add_child(_header_label)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.add_theme_font_override("font", font)
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.modulate = Color(0.92, 0.85, 0.62, 1.0) # Warm gold like reference
	text_column.add_child(_title_label)

	_description_label = Label.new()
	_description_label.name = "DescriptionLabel"
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size = Vector2(340, 0)
	_description_label.add_theme_font_override("font", font)
	_description_label.add_theme_font_size_override("font_size", 17)
	_description_label.modulate = Color(0.85, 0.87, 0.85, 0.92)
	text_column.add_child(_description_label)

	# BOTTOM RIGHT: Dismiss Prompt
	var prompt_margin := MarginContainer.new()
	prompt_margin.name = "PromptMargin"
	prompt_margin.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	prompt_margin.anchor_left = 1.0
	prompt_margin.anchor_top = 1.0
	prompt_margin.anchor_right = 1.0
	prompt_margin.anchor_bottom = 1.0
	prompt_margin.offset_left = -320.0
	prompt_margin.offset_top = -65.0
	prompt_margin.offset_right = -35.0
	prompt_margin.offset_bottom = -25.0
	prompt_margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	prompt_margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(prompt_margin)

	_prompt_label = Label.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.text = "[ E / ENTER / CLICK ]  TAKE"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_override("font", font)
	_prompt_label.add_theme_font_size_override("font_size", 14)
	_prompt_label.modulate = Color(0.7, 0.7, 0.7, 0.8)
	prompt_margin.add_child(_prompt_label)

	# Pickup SFX AudioPlayer
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "PickupSfxPlayer"
	_sfx_player.bus = &"Master"
	_sfx_player.volume_db = -6.0
	_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sfx_player)

	_overlay.hide()


func _create_black_gutters(content: Control) -> void:
	var right_gutter := ColorRect.new()
	right_gutter.name = "RightGutter"
	right_gutter.color = Color(0, 0, 0, 1)
	right_gutter.mouse_filter = Control.MOUSE_FILTER_STOP
	right_gutter.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right_gutter.offset_left = 0.0
	right_gutter.offset_right = 4000.0
	right_gutter.offset_top = -2000.0
	right_gutter.offset_bottom = 2000.0
	content.add_child(right_gutter)

	var left_gutter := ColorRect.new()
	left_gutter.name = "LeftGutter"
	left_gutter.color = Color(0, 0, 0, 1)
	left_gutter.mouse_filter = Control.MOUSE_FILTER_STOP
	left_gutter.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_gutter.offset_left = -4000.0
	left_gutter.offset_right = 0.0
	left_gutter.offset_top = -2000.0
	left_gutter.offset_bottom = 2000.0
	content.add_child(left_gutter)

	var top_gutter := ColorRect.new()
	top_gutter.name = "TopGutter"
	top_gutter.color = Color(0, 0, 0, 1)
	top_gutter.mouse_filter = Control.MOUSE_FILTER_STOP
	top_gutter.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_gutter.offset_left = -4000.0
	top_gutter.offset_right = 4000.0
	top_gutter.offset_top = -4000.0
	top_gutter.offset_bottom = 0.0
	content.add_child(top_gutter)

	var bottom_gutter := ColorRect.new()
	bottom_gutter.name = "BottomGutter"
	bottom_gutter.color = Color(0, 0, 0, 1)
	bottom_gutter.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom_gutter.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_gutter.offset_left = -4000.0
	bottom_gutter.offset_right = 4000.0
	bottom_gutter.offset_top = 0.0
	bottom_gutter.offset_bottom = 4000.0
	content.add_child(bottom_gutter)
