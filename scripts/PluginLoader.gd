## Loads plugins from .pck files or loose directories at runtime.
## Scans user://plugins/ and res://plugins/ for plugin packs.
class_name PluginLoader
extends RefCounted

const PLUGIN_DIRS = ["user://plugins", "res://plugins"]


## Discovers and loads all plugins, returning an array of {id, plugin} dicts.
func load_all() -> Array:
	var loaded := []

	for dir_path in PLUGIN_DIRS:
		# Load .pck files
		var pck_files = _find_files(dir_path, ".pck")
		for pck_path in pck_files:
			if ProjectSettings.load_resource_pack(pck_path):
				print("[PluginLoader] Loaded pack: ", pck_path)
			else:
				push_warning("[PluginLoader] Failed to load pack: ", pck_path)

		# Find plugin.cfg in subdirectories (works for both loose and pck-loaded plugins)
		var subdirs = _find_subdirs(dir_path)
		for subdir in subdirs:
			var cfg_path = subdir + "/plugin.cfg"
			if FileAccess.file_exists(cfg_path):
				var result = _load_plugin_from_cfg(cfg_path)
				if result:
					loaded.append(result)

	return loaded


## Returns metadata (name, id, version, author, filename) for all discovered plugins
## without instantiating them.
func scan_metadata() -> Array:
	var results := []

	for dir_path in PLUGIN_DIRS:
		# Load .pck files first so their contents are visible
		var pck_files = _find_files(dir_path, ".pck")
		for pck_path in pck_files:
			ProjectSettings.load_resource_pack(pck_path)

		var subdirs = _find_subdirs(dir_path)
		for subdir in subdirs:
			var cfg_path = subdir + "/plugin.cfg"
			if FileAccess.file_exists(cfg_path):
				var json_text = FileAccess.get_file_as_string(cfg_path)
				var data = JSON.parse_string(json_text)
				if data != null:
					data["filename"] = cfg_path.get_base_dir().get_file()
					results.append(data)

	return results


func _load_plugin_from_cfg(cfg_path: String) -> Dictionary:
	var json_text = FileAccess.get_file_as_string(cfg_path)
	var data = JSON.parse_string(json_text)
	if data == null:
		push_warning("[PluginLoader] Failed to parse: ", cfg_path)
		return {}

	var script_path = data.get("script", "")
	if script_path == "":
		push_warning("[PluginLoader] No script in: ", cfg_path)
		return {}

	var script = load(script_path)
	if script == null:
		push_warning("[PluginLoader] Failed to load script: ", script_path)
		return {}

	var instance = script.new()
	if not instance is Plugin:
		push_warning("[PluginLoader] Script does not extend Plugin: ", script_path)
		return {}

	var plugin_id = data.get("id", "")
	print("[PluginLoader] Loaded plugin: ", plugin_id, " (", data.get("name", ""), ")")
	return {"id": plugin_id, "plugin": instance, "metadata": data}


func _find_files(dir_path: String, extension: String) -> Array[String]:
	var results: Array[String] = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(extension):
			results.append(dir_path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return results


func _find_subdirs(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return results
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			results.append(dir_path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return results
