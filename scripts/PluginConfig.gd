## Persists plugin enabled/disabled state to user://plugin_config.json.
## All plugins are enabled by default.
class_name PluginConfig
extends RefCounted

var _disabled: Array[String] = []


func _init():
	_load()


func is_enabled(plugin_id: String) -> bool:
	return not _disabled.has(plugin_id)


func set_enabled(plugin_id: String, enabled: bool):
	if enabled:
		_disabled.erase(plugin_id)
	else:
		if not _disabled.has(plugin_id):
			_disabled.append(plugin_id)
	_save()


func _load():
	if not FileAccess.file_exists(SystemUtils.PLUGIN_CONFIG_PATH):
		return
	var json_text = FileAccess.get_file_as_string(SystemUtils.PLUGIN_CONFIG_PATH)
	var data = JSON.parse_string(json_text)
	if data is Dictionary:
		var arr = data.get("disabled", [])
		_disabled.clear()
		for id in arr:
			_disabled.append(id)


func _save():
	var data = {"disabled": _disabled}
	var file = FileAccess.open(SystemUtils.PLUGIN_CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
