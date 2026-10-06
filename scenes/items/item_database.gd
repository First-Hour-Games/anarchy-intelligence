class_name ItemDatabase
extends RefCounted

## Central repository for game items, metadata, visual assets, and descriptions.

static var _items: Dictionary = {}
static var _initialized: bool = false


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true

	# Tourist Map / Brochure
	var map_item := ItemData.new()
	map_item.id = &"map"
	map_item.name = "TOURIST MAP"
	map_item.description = "A folded tourist brochure from the welcome center containing the street map of Cicely. Useful for finding your way around the town."
	map_item.image = preload("res://img/items/cicely_town_map.png")
	map_item.model_scene = null # Ready for future 3D model import
	map_item.use_action_text = "OPEN MAP"
	register_item(map_item)

	# Flashlight
	var flashlight_item := ItemData.new()
	flashlight_item.id = &"flashlight"
	flashlight_item.name = "FLASHLIGHT"
	flashlight_item.description = "A working flashlight found at the abandoned gas station. Its beam makes the Ridgeback retreat. Press F anytime while exploring."
	if ResourceLoader.exists("res://scenes/items/flashlight_pickup.tscn"):
		flashlight_item.model_scene = load("res://scenes/items/flashlight_pickup.tscn") as PackedScene
	flashlight_item.use_action_text = "TOGGLE FLASHLIGHT"
	register_item(flashlight_item)

	# Carrie's Notes
	var notebook_item := ItemData.new()
	notebook_item.id = &"notebook"
	notebook_item.name = "CARRIE'S NOTES"
	notebook_item.description = "Carrie's handwriting. She left for the hospital because people said it was safe. Read this with the other clues in your journal."
	notebook_item.use_action_text = "READ NOTES"
	register_item(notebook_item)


static func register_item(item: ItemData) -> void:
	if item == null or item.id.is_empty():
		return
	_items[item.id] = item


static func has_item(id: StringName) -> bool:
	_ensure_initialized()
	return _items.has(id)


static func get_item(id: StringName) -> ItemData:
	_ensure_initialized()
	if _items.has(id):
		return _items[id]

	# Dynamic fallback for unspecified items
	var fallback := ItemData.new()
	fallback.id = id
	fallback.name = str(id).replace("_", " ").capitalize().to_upper()
	fallback.description = "An item found in Cicely."
	fallback.use_action_text = "USE"
	return fallback


static func get_all_items() -> Array:
	_ensure_initialized()
	return _items.values()
