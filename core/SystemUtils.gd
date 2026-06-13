extends Node

const SAVE_DIR = "user://saves/"
const QUICKSAVE_PATH = "user://saves/quicksave.sav"
const MODULES_DIR = "user://modules/"
const PLUGINS_DIR = "user://plugins/"
const COMPENDIUMS_DIR = "user://compendiums/"
const PLUGIN_CONFIG_PATH = "user://plugin_config.json"
const BUNDLED_MODULES_DIR = "res://modules"
const BUNDLED_PLUGINS_DIR = "res://plugins"
const BUNDLED_COMPENDIUMS_DIR = "res://compendiums"


static func get_plugin_type(meta: Dictionary) -> String:
	if meta.has("type"):
		return meta["type"]
	if meta.get("core", false):
		return "core"
	return "optional"


static func find_subdirs(dir_path: String) -> Array[String]:
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
