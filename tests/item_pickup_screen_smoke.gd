extends SceneTree

const ItemDataScript = preload("res://scenes/items/item_data.gd")
const ItemDatabaseScript = preload("res://scenes/items/item_database.gd")
const ItemPickupScreenScript = preload("res://scenes/ui/item_pickup/item_pickup_screen.gd")

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, words: String) -> void:
	print(("PASS: " if value else "FAIL: ") + words)
	if not value:
		failures += 1


func run() -> void:
	print("--- Running Item Pickup Screen & Database Smoke Test ---")

	# 1. Test Item Database
	check(ItemDatabaseScript.has_item(&"map"), "ItemDatabase has 'map'")
	check(ItemDatabaseScript.has_item(&"flashlight"), "ItemDatabase has 'flashlight'")
	check(ItemDatabaseScript.has_item(&"notebook"), "ItemDatabase has 'notebook'")

	var map_data = ItemDatabaseScript.get_item(&"map")
	check(map_data != null and map_data.id == &"map", "ItemData for 'map' successfully retrieved")
	check(map_data.name == "TOURIST MAP", "Map item name is 'TOURIST MAP'")
	check(not map_data.description.is_empty(), "Map item has description: " + map_data.description)
	check(map_data.image != null, "Map item has placeholder illustration texture")

	var unknown = ItemDatabaseScript.get_item(&"mystery_key")
	check(unknown != null and unknown.id == &"mystery_key", "Fallback ItemData returned for unknown item")

	# 2. Test ItemPickupScreen standalone functionality
	var screen: CanvasLayer = ItemPickupScreenScript.new()
	root.add_child(screen)
	await process_frame

	check(screen.get("_blur_material") != null, "ItemPickupScreen created blur material")
	check(screen.get("_item_image_rect") != null, "ItemPickupScreen has TextureRect for 2D items")
	check(screen.get("_model_viewport") != null, "ItemPickupScreen has SubViewport for future 3D models")
	check(screen.layer == 98, "ItemPickupScreen is on layer 98")

	var opened_item: Array = [null]
	screen.opened.connect(func(item): opened_item[0] = item)

	var closed_called: Array = [false]
	screen.display_item(&"map", func(): closed_called[0] = true)
	check(screen.is_active, "ItemPickupScreen is active after display_item")
	check(screen.get("_title_label").text == "TOURIST MAP", "Title label displays TOURIST MAP")
	check(screen.get("_item_image_rect").texture == map_data.image, "TextureRect set to map image")
	check(screen.get("_item_image_rect").visible, "TextureRect is visible for 2D map item")
	check(not screen.get("_model_viewport_container").visible, "3D SubViewportContainer is hidden when item has no 3D model")

	# Test dismiss
	screen.close()
	await create_timer(0.35).timeout
	check(not screen.is_active, "ItemPickupScreen closed and inactive")
	check(closed_called[0], "Close callback was executed")
	screen.queue_free()

	# 3. Test starting_forest scene configuration
	var packed_forest := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	check(packed_forest != null, "starting_forest.tscn loaded")
	var forest := packed_forest.instantiate()
	root.add_child(forest)
	await process_frame

	var map_inspect = forest.get_node_or_null("Interactables/MapInspect/InspectableView")
	check(is_instance_valid(map_inspect), "MapInspect/InspectableView exists in starting_forest")

	var brochure_hotspot = map_inspect.get_node_or_null("BrochurePickUp") if is_instance_valid(map_inspect) else null
	check(is_instance_valid(brochure_hotspot), "BrochurePickUp hotspot exists in starting_forest")
	if is_instance_valid(brochure_hotspot):
		check(brochure_hotspot.is_pickup, "BrochurePickUp is configured as pickup hotspot (is_pickup == true)")
		check(brochure_hotspot.pickup_item_id == &"map", "BrochurePickUp pickup_item_id is 'map'")
		check(brochure_hotspot.trigger_once, "BrochurePickUp trigger_once is true")
		check(brochure_hotspot.dialogue_cue == "visitor_center_map_interact", "BrochurePickUp dialogue cue is visitor_center_map_interact")

	var direct_pickup = brochure_hotspot.get_node_or_null("DirectPickup") if is_instance_valid(brochure_hotspot) else null
	check(direct_pickup == null, "DirectPickup is removed so brochure must be picked up via inspection")

	var center_hotspot = map_inspect.get_node_or_null("MapCenterHotspot") if is_instance_valid(map_inspect) else null
	check(is_instance_valid(center_hotspot), "MapCenterHotspot exists in starting_forest")
	if is_instance_valid(center_hotspot):
		check(center_hotspot.dialogue_cue == "visitor_center_map_info", "MapCenterHotspot dialogue cue is visitor_center_map_info")

	forest.queue_free()

	print("--- Item Pickup Screen & Database Checks Complete ---")
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED with %d errors" % failures)
		quit(1)
