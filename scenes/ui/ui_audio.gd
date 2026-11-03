extends RefCounted
## Common playback policy for non-positional interface sounds.

const NAVIGATION_VOLUME_DB := -10.0
const NAVIGATION_PATHS := ["res://sounds/ui/move.mp3", "res://sounds/ui/click.mp3"]


static func configure(player: AudioStreamPlayer) -> bool:
	if player.stream == null or not player.stream.resource_path.begins_with("res://sounds/ui/"):
		return false
	player.bus = &"Effects"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	if player.stream.resource_path in NAVIGATION_PATHS:
		player.volume_db = NAVIGATION_VOLUME_DB
	return true
