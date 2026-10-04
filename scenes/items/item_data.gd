class_name ItemData
extends Resource

## Data definition for an item in the game.
## Supports both 2D imagery (placeholder/icon) and 3D preview scenes.

@export var id: StringName = &""
@export var name: String = ""
@export_multiline var description: String = ""
@export var image: Texture2D = null
@export var model_scene: PackedScene = null
@export var pickup_sound: AudioStream = null
@export var use_action_text: String = "USE"
