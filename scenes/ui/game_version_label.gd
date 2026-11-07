@tool
extends Label
## One displayed version, read from Project Settings in game and in the editor.

func _ready() -> void:
	_update_version()
	ProjectSettings.settings_changed.connect(_update_version)

func _update_version() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	text = "v" + version.trim_prefix("v") if not version.is_empty() else "Development build"
