class_name PlayerInventory
extends CanvasLayer

## Small, two-slot inventory HUD. Items are represented by stable StringName IDs
## so world pickups and held-item presentation stay loosely coupled.

signal inventory_changed
signal selection_changed(slot_index: int, item_id: StringName)

const SLOT_COUNT: int = 2
const EMPTY_ITEM: StringName = &""
const FLASHLIGHT_ITEM: StringName = &"flashlight"

@export var selected_style: StyleBoxFlat
@export var unselected_style: StyleBoxFlat

@onready var _slot_panels: Array[PanelContainer] = [
	$InventoryBar/Slots/Slot1 as PanelContainer,
	$InventoryBar/Slots/Slot2 as PanelContainer,
]
@onready var _item_labels: Array[Label] = [
	$InventoryBar/Slots/Slot1/Margin/Content/ItemName as Label,
	$InventoryBar/Slots/Slot2/Margin/Content/ItemName as Label,
]
@onready var _slot_previews: Array[TextureRect] = [
	$InventoryBar/Slots/Slot1/Margin/Content/Preview as TextureRect,
	$InventoryBar/Slots/Slot2/Margin/Content/Preview as TextureRect,
]
@onready var _active_labels: Array[Label] = [
	$InventoryBar/Slots/Slot1/Margin/Content/Header/Active as Label,
	$InventoryBar/Slots/Slot2/Margin/Content/Header/Active as Label,
]
@onready var _item_preview_viewport: SubViewport = $ItemPreview

var selected_slot_index: int = 0
var _items: Array[StringName] = [EMPTY_ITEM, EMPTY_ITEM]


func _ready() -> void:
	var preview_texture := _item_preview_viewport.get_texture()
	for slot_preview in _slot_previews:
		slot_preview.texture = preview_texture
	_update_hud()


func add_item(item_id: StringName) -> bool:
	if item_id == EMPTY_ITEM or has_item(item_id):
		return false

	for slot_index in SLOT_COUNT:
		if _items[slot_index] != EMPTY_ITEM:
			continue
		_items[slot_index] = item_id
		select_slot(slot_index)
		inventory_changed.emit()
		_update_hud()
		return true
	return false


func has_item(item_id: StringName) -> bool:
	return _items.has(item_id)


func is_full() -> bool:
	return not _items.has(EMPTY_ITEM)


func get_item(slot_index: int) -> StringName:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return EMPTY_ITEM
	return _items[slot_index]


func get_selected_item() -> StringName:
	return get_item(selected_slot_index)


func select_slot(slot_index: int) -> void:
	var next_slot := clampi(slot_index, 0, SLOT_COUNT - 1)
	if next_slot == selected_slot_index:
		_update_hud()
		return
	selected_slot_index = next_slot
	_update_hud()
	selection_changed.emit(selected_slot_index, get_selected_item())


func select_relative(direction: int) -> void:
	if direction == 0:
		return
	select_slot(posmod(selected_slot_index + signi(direction), SLOT_COUNT))


func _update_hud() -> void:
	if not is_node_ready():
		return

	for slot_index in SLOT_COUNT:
		var is_selected := slot_index == selected_slot_index
		var item_id := _items[slot_index]
		_slot_panels[slot_index].add_theme_stylebox_override(
			&"panel",
			selected_style if is_selected else unselected_style
		)
		_active_labels[slot_index].visible = is_selected
		_item_labels[slot_index].text = _get_item_display_name(item_id)
		_slot_previews[slot_index].visible = item_id == FLASHLIGHT_ITEM
		_item_labels[slot_index].modulate = Color.WHITE if item_id != EMPTY_ITEM else Color(0.48, 0.52, 0.50, 1.0)


func _get_item_display_name(item_id: StringName) -> String:
	match item_id:
		FLASHLIGHT_ITEM:
			return "FLASHLIGHT"
		EMPTY_ITEM:
			return "EMPTY"
		_:
			return String(item_id).replace("_", " ").to_upper()
