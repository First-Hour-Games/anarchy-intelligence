class_name SaveGem
extends Interactable3D
## A floating, glowing gem save point. Interacting opens the save screen (SaveSlotScreen) to pick
## one of four files (see SaveGame); dying returns the player to the last gem used. The player reappears at RespawnPoint, facing along its -Z,
## so keep that marker on open ground in front of the gem.

## Shown on the save file, e.g. "TOWN ENTRANCE". Leave the area empty to name it after the map.
@export var location_name: String = ""
@export var area_name: String = ""
## Enable only on the first gas-station save point.
@export var introduce_first_save: bool = false
## Your dialogue text. Each nonempty line becomes a separate dialogue line.
## Leave empty to open the save menu without a dialogue.
@export_multiline var first_save_dialogue: String = ""
@export var first_save_speaker: String = "Thomas"

const INTRO_BALLOON := preload("res://scenes/ui/dialogue_box/bottom_dialogue_balloon.tscn")
@export_range(0.2, 3.0, 0.05) var float_height: float = 1.1
@export_range(0.0, 0.5, 0.01) var bob_amplitude: float = 0.07
@export_range(0.05, 3.0, 0.05) var bob_cycles_per_second: float = 0.35
@export_range(-180.0, 180.0, 1.0) var spin_degrees_per_second: float = 25.0
@export_range(0.0, 16.0, 0.1) var glow_energy: float = 1.4
## How much the glow breathes, as a fraction of glow_energy.
@export_range(0.0, 1.0, 0.05) var glow_pulse: float = 0.2
## Extra light added for a moment when the game saves.
@export_range(0.0, 16.0, 0.1) var save_flash_energy: float = 4.0

@onready var model: Node3D = $Model
@onready var glow: OmniLight3D = $Glow
@onready var respawn_point: Marker3D = $RespawnPoint

var _time: float = 0.0
var _flash: float = 0.0
var _screen_open: bool = false


func _ready() -> void:
	super._ready()
	_time = randf() * 10.0
	_update_float(0.0)


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta * 1.2)
	_update_float(delta)


func _update_float(delta: float) -> void:
	model.position.y = float_height + sin(_time * bob_cycles_per_second * TAU) * bob_amplitude
	model.rotate_y(deg_to_rad(spin_degrees_per_second) * delta)
	glow.position.y = model.position.y + 0.12
	var breathe := 1.0 + sin(_time * 1.3) * glow_pulse
	glow.light_energy = glow_energy * breathe + save_flash_energy * _flash


func can_interact(interactor: Node3D) -> bool:
	return not _screen_open and super.can_interact(interactor)


func interact(interactor: Node3D) -> void:
	var player := interactor as FirstPersonPlayer
	if player == null or _screen_open:
		return
	# The picture on the save file is the view just before the screen opens.
	var thumbnail := SaveGame.capture_thumbnail()
	_screen_open = true
	player.freeze()
	if should_show_first_save_dialogue():
		var resource := _first_save_dialogue_resource()
		if resource != null:
			var balloon := INTRO_BALLOON.instantiate() as BottomDialogueBalloon
			# The gem owns the freeze through both dialogue and the save menu.
			balloon.freeze_player = false
			add_child(balloon)
			balloon.start(resource, "start", [self, player])
			await balloon.dialogue_finished
			SaveGame.first_save_dialogue_seen = true
			if not is_instance_valid(player):
				_screen_open = false
				return
	var save_here := func(slot: int) -> bool:
		var done := SaveGame.save_at(self, player, slot, thumbnail)
		if done:
			_flash = 1.0
		return done
	var screen := SaveSlotScreen.open(get_tree().root, SaveSlotScreen.Mode.SAVE, save_here, true, true)
	screen.closed.connect(_on_screen_closed.bind(player))
	interacted.emit(interactor)


func should_show_first_save_dialogue() -> bool:
	return introduce_first_save and not first_save_dialogue.strip_edges().is_empty() \
		and not SaveGame.first_save_dialogue_seen and not SaveGame.has_respawn


func _first_save_dialogue_resource() -> DialogueResource:
	var manager := Engine.get_singleton("DialogueManager")
	if manager == null:
		return null
	var lines := PackedStringArray(["~ start"])
	var speaker := first_save_speaker.strip_edges()
	for line in first_save_dialogue.split("\n"):
		var text := line.strip_edges()
		if not text.is_empty():
			lines.append(text if speaker.is_empty() else "%s: %s" % [speaker, text])
	lines.append("=> END")
	return manager.create_resource_from_text("\n".join(lines)) as DialogueResource


func _on_screen_closed(player: FirstPersonPlayer) -> void:
	_screen_open = false
	if is_instance_valid(player):
		player.unfreeze()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func get_respawn_transform() -> Transform3D:
	return respawn_point.global_transform
