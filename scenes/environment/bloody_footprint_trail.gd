class_name BloodyFootprintTrail
extends Node3D
## A trail of BloodyFootprint decals (its children) that stays hidden until the player has the
## flashlight, then fades in one print after another from the first to the last. Loading a save
## where the flashlight was already picked up shows the trail straight away.

@export var player_path: NodePath = NodePath("../Player")
@export var hidden_until_flashlight: bool = true
## Seconds each print takes to fade in.
@export var fade_in_time: float = 0.6
## Seconds between one print starting to fade in and the next.
@export var fade_in_stagger: float = 0.12

var revealed: bool = false
var _inventory: PlayerInventory


func _ready() -> void:
	if not hidden_until_flashlight:
		revealed = true
		return
	for print_decal in _prints():
		print_decal.visible = false
	_connect_inventory.call_deferred()


func reveal(animate: bool = true) -> void:
	if revealed:
		return
	revealed = true
	if is_instance_valid(_inventory) and _inventory.inventory_changed.is_connected(_on_inventory_changed):
		_inventory.inventory_changed.disconnect(_on_inventory_changed)
	var prints := _prints()
	for index in prints.size():
		var print_decal := prints[index]
		print_decal.visible = true
		if not animate:
			continue
		var alpha := print_decal.modulate.a
		var glow := print_decal.emission_energy
		print_decal.modulate.a = 0.0
		print_decal.emission_energy = 0.0
		var tween := create_tween().set_parallel()
		var delay := index * fade_in_stagger
		tween.tween_property(print_decal, "modulate:a", alpha, fade_in_time).set_delay(delay)
		tween.tween_property(print_decal, "emission_energy", glow, fade_in_time).set_delay(delay)


func _connect_inventory() -> void:
	var player := get_node_or_null(player_path) as FirstPersonPlayer
	if player == null or player.inventory == null:
		push_warning("BloodyFootprintTrail needs a player with an inventory at %s." % player_path)
		reveal(false)
		return
	_inventory = player.inventory
	if _inventory.has_item(PlayerInventory.FLASHLIGHT_ITEM):
		reveal(false)
	else:
		_inventory.inventory_changed.connect(_on_inventory_changed)


func _on_inventory_changed() -> void:
	if _inventory.has_item(PlayerInventory.FLASHLIGHT_ITEM):
		reveal()


func _prints() -> Array[Decal]:
	var prints: Array[Decal] = []
	for child in get_children():
		if child is Decal:
			prints.append(child as Decal)
	return prints
