## Discovers and loads compendiums from user and bundled directories.
## Compendiums are data-only JSON packages that provide entries for plugin templates.
class_name CompendiumLoader
extends RefCounted

var COMPENDIUM_DIRS = [SystemUtils.COMPENDIUMS_DIR, SystemUtils.BUNDLED_COMPENDIUMS_DIR]


## Loads all compendiums and returns array of {id, data} dicts.
func load_all() -> Array:
	var loaded := []

	for dir_path in COMPENDIUM_DIRS:
		var subdirs = SystemUtils.find_subdirs(dir_path)
		for subdir in subdirs:
			var comp_path = subdir + "/compendium.json"
			if FileAccess.file_exists(comp_path):
				var result = _load_compendium(comp_path)
				if result:
					loaded.append(result)

	return loaded


## Returns metadata for all discovered compendiums without loading entries.
func scan_metadata() -> Array:
	var results := []

	for dir_path in COMPENDIUM_DIRS:
		var subdirs = SystemUtils.find_subdirs(dir_path)
		for subdir in subdirs:
			var comp_path = subdir + "/compendium.json"
			if FileAccess.file_exists(comp_path):
				var json_text = FileAccess.get_file_as_string(comp_path)
				var data = JSON.parse_string(json_text)
				if data != null:
					data["_path"] = comp_path
					results.append(data)

	return results


func _load_compendium(path: String) -> Dictionary:
	var json_text = FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(json_text)
	if data == null:
		push_warning("[CompendiumLoader] Failed to parse: ", path)
		return {}

	var comp_id = data.get("id", "")
	if comp_id == "":
		push_warning("[CompendiumLoader] Compendium missing id: ", path)
		return {}

	print("[CompendiumLoader] Loaded compendium: ", comp_id, " (", data.get("name", ""), ")")
	return {"id": comp_id, "data": data}
