extends SceneTree

const ENCOUNTER := preload("res://scenes/environment/gas_station_encounter.gd")
const HEALTH := preload("res://scenes/player/combat_health.gd")
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1

func run() -> void:
	var forest := (load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene).instantiate() as StartingForest
	root.add_child(forest)
	current_scene = forest
	await process_frame
	forest.finish_fade_immediately()
	if is_instance_valid(forest.opening_balloon):
		forest.opening_balloon._end_dialogue()
	var player := forest.get_node("Player") as FirstPersonPlayer
	player.unfreeze()
	player.set_physics_process(false)
	var interior := forest.get_node("GasStation/Interior") as Node3D
	var encounter := interior.get_node("Encounter")
	encounter.set_process(false)
	check(encounter.trailer_enabled, "Current game preview enables the title flythrough by default")
	encounter.trailer_enabled = false
	await physics_frame
	await physics_frame
	for cover: String in ["StockroomDoor", "StockroomFront", "StockroomSide", "StockroomHeader", "TallStorageCabinet"]:
		check(not interior.has_node("Architecture/" + cover), "Open checkout has no " + cover)
	var first := interior.get_node("Furniture/CheckoutCounter") as Node3D
	var extension := interior.get_node("Furniture/CounterExtension") as Node3D
	check(is_equal_approx(first.position.x, -5.9) and is_equal_approx(first.position.x, extension.position.x) and first.rotation.is_equal_approx(extension.rotation) and is_equal_approx(first.rotation.y, PI * 0.5), "Checkout cabinets form one straight line along the left wall, facing customers")
	check(encounter.roar.stream.resource_path == "res://sounds/entities/gas_station/ridgeback_pickup_scream.wav" and is_equal_approx(encounter.roar.stream.get_length(), 1.6), "Pickup scream includes half a second more of the supplied recording")
	check(is_equal_approx(encounter.attack_seconds, 1.28), "Attack presentation lasts half a second longer")
	var models: Array[Node] = [player.flashlight.model_pivot.get_node("Model"), player.inventory.get_node("ItemPreview/ModelPivot/Flashlight"), interior.get_node("Details/CounterFlashlight/Visual/Model")]
	for model: Node in models:
		check(model.scene_file_path == "res://scenes/items/flashlight_visual.tscn", "Flashlight visual is shared by " + str(model.get_path()))
	check(ItemDatabase.get_item(&"flashlight").model_scene.resource_path == "res://scenes/items/flashlight_visual.tscn", "Pickup inspection uses the shared visual without a pickup script")
	for label: String in ["StatusHeading", "InventoryHeading"]:
		var heading := player.inventory._page.get_node(label) as Label
		check(heading.autowrap_mode == TextServer.AUTOWRAP_OFF and heading.size.x >= heading.get_minimum_size().x, label + " fits on one line")
	player.global_position = encounter.preview_mark.global_position
	player.global_basis = interior.global_basis
	var camera_pose := player.camera.transform
	var camera_fov := player.camera.fov
	var camera_near := player.camera.near
	# Forest currently omits the optional health component; exercise survival with it too.
	var health := player.get_node_or_null("CombatHealth")
	if health == null:
		health = HEALTH.new()
		health.name = "CombatHealth"
		player.add_child(health)
	health.health = 37.0
	var health_before: float = health.health
	var health_hud := health.get_child(0) as CanvasLayer
	var energy := player.flashlight.beam.light_energy
	var spill_energy := player.flashlight.spill.light_energy
	var pickup := interior.get_node("Details/CounterFlashlight") as FlashlightPickup
	check(encounter.phase == ENCOUNTER.Phase.HIDDEN and not encounter.ridgeback.visible and not encounter.ridgeback.is_physics_processing() and encounter.ridgeback.visual.animation_player.current_animation == "ManThing_IDLE", "Ridgeback idles invisibly before pickup with normal AI suspended")
	pickup.interact(player)
	check(player.has_item(&"flashlight") and player.is_frozen and player.flashlight.is_enabled(), "Pickup raises the flashlight and locks input for the scare")
	player.inventory.set_open(true, false)
	check(not player.inventory.is_open, "Inventory cannot interrupt the camera sequence")
	encounter._process(encounter.raise_seconds)
	check(encounter.phase == ENCOUNTER.Phase.REVEAL and is_equal_approx(player.camera.fov, 62.0), "Pickup cuts to death-style 62 degree close-up framing")
	check(encounter.ridgeback.visible, "Pickup reveals the Ridgeback for the camera sequence")
	check(player.camera.global_position.distance_to(encounter._head_position()) < 0.9 and not player.flashlight.model_pivot.visible, "Camera moves within a metre of the animated head without the held model blocking the shot")
	check(not health_hud.visible, "Close-up temporarily hides the gameplay HUD")
	encounter._process(encounter.reveal_seconds)
	var visual: Node = encounter.ridgeback.visual
	check(visual.animation_player.current_animation == "ManThing_ATTACK" and not encounter.ridgeback.damage_enabled, "Real attack animation plays without damaging the player")
	check(encounter.roar.playing, "Supplied scream starts with the attack")
	check(is_equal_approx(visual.animation_player.speed_scale, 0.78 / 1.28), "Attack motion slows to fill the longer shot")
	encounter._process(encounter.attack_seconds)
	check(encounter.phase == ENCOUNTER.Phase.FLARE and player.flashlight.beam.light_energy > energy * 2 and encounter._flash_layer.visible, "Visible flashlight flash interrupts the attack")
	encounter._process(encounter.flare_seconds)
	check(encounter.phase == ENCOUNTER.Phase.RETREAT and not encounter.ridgeback.visible, "Flash hides the Ridgeback while the camera returns to gameplay")
	encounter._process(encounter.retreat_seconds)
	check(encounter.phase == ENCOUNTER.Phase.COMPLETE and not encounter.ridgeback.visible and not player.is_frozen, "Scare completes once and returns player control")
	check(player.camera.transform.is_equal_approx(camera_pose) and is_equal_approx(player.flashlight.beam.light_energy, energy) and is_equal_approx(player.flashlight.spill.light_energy, spill_energy), "Camera pose and normal beam/spill intensity are restored")
	check(is_equal_approx(player.camera.fov, camera_fov) and is_equal_approx(player.camera.near, camera_near) and player.flashlight.model_pivot.visible and not encounter._flash_layer.visible, "Lens, held flashlight and flash overlay are restored")
	check(is_equal_approx(health.health, health_before) and not health.is_dead and not is_instance_valid(health.death_scare) and health_hud.visible, "Player survives with unchanged health, restored HUD and no death or retry screen")
	encounter.begin(player)
	check(encounter.phase == ENCOUNTER.Phase.COMPLETE, "Completed encounter cannot retrigger")
	await process_frame
	encounter.reset_encounter()
	check(encounter.phase == ENCOUNTER.Phase.HIDDEN and not player.has_item(&"flashlight") and interior.has_node("Details/CounterFlashlight") and not encounter.ridgeback.visible, "Developer reset restores the pickup and hides the actor")
	var debug_menu := root.get_node("DebugMenu")
	debug_menu.set_open(true)
	debug_menu._gas_station_action("preview_encounter")
	check(not paused and not debug_menu.opened, "Debug preview closes the menu and releases its pause")
	check(encounter.phase == ENCOUNTER.Phase.RAISING and player.has_item(&"flashlight"), "Developer preview plays the same pickup sequence")
	encounter._process(encounter.raise_seconds)
	debug_menu.set_open(true)
	debug_menu._gas_station_action("skip_encounter")
	check(not player.is_frozen and player.has_item(&"flashlight") and encounter.phase == ENCOUNTER.Phase.COMPLETE, "Developer skip keeps the item and restores control")
	check(encounter._hidden_layers.is_empty() and not encounter._flash_layer.visible and is_equal_approx(player.camera.fov, camera_fov), "Skipping during a close-up restores HUD and camera lens")
	await process_frame
	encounter.reset_encounter()
	encounter.trailer_enabled = true
	var world := forest.get_node("WorldEnvironment") as WorldEnvironment
	var gameplay_environment := world.environment
	var ambience := forest.get_node("VisitorBGM") as AudioStreamPlayer
	var ambience_was_paused := ambience.stream_paused
	var distance_fog_was_visible := player.distance_fog.visible
	encounter.preview_encounter()
	encounter._process(encounter.raise_seconds)
	encounter._process(encounter.reveal_seconds)
	encounter._process(encounter.attack_seconds)
	encounter._process(encounter.flare_seconds)
	encounter._process(encounter._duration() - 0.01)
	check(encounter.phase == ENCOUNTER.Phase.RETREAT, "Title transition waits for the full scream duration")
	encounter._process(0.02)
	var outro: GasStationTrailerOutro = encounter.outro
	check(encounter.phase == ENCOUNTER.Phase.OUTRO and outro.active and outro.camera.current and player.is_frozen and not encounter.roar.playing, "Scream ends into an aerial camera while gameplay stays locked")
	check(not health_hud.visible and outro.overlay.visible and ambience.stream_paused, "Flythrough hides gameplay UI and silences ambience")
	check(not player.distance_fog.visible, "Player fog overlay cannot cover the aerial camera")
	var debug_geometry_visible := false
	for node: Node in forest.find_children("_ZoneBoxPreview", "MeshInstance3D", true, false):
		debug_geometry_visible = debug_geometry_visible or (node as MeshInstance3D).visible
	check(not debug_geometry_visible, "Development zone previews stay out of the trailer")
	check(world.environment == gameplay_environment and outro.camera.environment != gameplay_environment, "Trailer lighting uses its own environment without changing the playable forest")
	var aerial_start := outro.camera.global_position
	encounter._process(1.0)
	check(outro.camera.global_position.distance_to(aerial_start) > 5 and outro.camera.global_position.y > 30 and outro.title.modulate.a > 0.99, "High aerial camera flies across the map with the existing title logo")
	encounter._process(outro.flythrough_seconds)
	check(encounter.phase == ENCOUNTER.Phase.END_CARD and outro.flight_finished and is_equal_approx(outro.blackout.color.a, 1.0) and player.is_frozen, "Preview ends on a held black title card")
	check(is_equal_approx(health.health, health_before) and not health.is_dead, "Trailer ending preserves player health")
	encounter.skip_encounter()
	check(player.camera.current and not outro.active and not outro.overlay.visible and not player.is_frozen and ambience.stream_paused == ambience_was_paused, "Skip from final title restores the player camera, audio and controls")
	check(player.distance_fog.visible == distance_fog_was_visible, "Skip restores the player's original distance fog")
	await process_frame
	encounter.preview_encounter()
	encounter._process(encounter.raise_seconds)
	encounter._process(encounter.reveal_seconds)
	encounter._process(encounter.attack_seconds)
	encounter._process(encounter.flare_seconds)
	encounter._process(encounter._duration())
	encounter.reset_encounter()
	check(player.camera.current and not outro.active and not outro.moonlight.visible and not player.is_frozen and ambience.stream_paused == ambience_was_paused, "Reset during flight restores lighting/audio/camera and re-arms the pickup")
	player.freeze()
	interior.get_node("Details/CounterFlashlight").interact(player)
	encounter.skip_encounter()
	check(player.is_frozen, "Cleanup preserves an input lock owned by another system")
	player.unfreeze()
	forest.queue_free()
	await process_frame
	quit(1 if failures else 0)
