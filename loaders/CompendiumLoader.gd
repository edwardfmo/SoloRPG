## Discovers and loads compendiums from user and bundled directories.
## Compendiums are data-only JSON packages that provide entries for plugin templates.
## A compendium folder contains a compendium.json (metadata + optional entries)
## plus any number of additional .json files whose entries are merged in.
class_name CompendiumLoader
extends RefCounted

var COMPENDIUM_DIRS = [SystemUtils.COMPENDIUMS_DIR, SystemUtils.BUNDLED_COMPENDIUMS_DIR]


## Loads all compendiums and returns array of {id, data, entry_sources} dicts.
func load_all() -> Array:
	var loaded := []

	for dir_path in COMPENDIUM_DIRS:
		var subdirs = SystemUtils.find_subdirs(dir_path)
		for subdir in subdirs:
			var comp_path = subdir + "/compendium.json"
			if FileAccess.file_exists(comp_path):
				var result = _load_compendium(subdir)
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


func _load_compendium(dir_path: String) -> Dictionary:
	var meta_path = dir_path + "/compendium.json"
	var json_text = FileAccess.get_file_as_string(meta_path)
	var data = JSON.parse_string(json_text)
	if data == null:
		push_warning("[CompendiumLoader] Failed to parse: ", meta_path)
		return {}

	var comp_id = data.get("id", "")
	if comp_id == "":
		push_warning("[CompendiumLoader] Compendium missing id: ", meta_path)
		return {}

	if not data.has("entries"):
		data["entries"] = {}

	# Track which file each entry came from: template_id -> entry_id -> filename
	var entry_sources := {}

	# Tag entries from compendium.json
	for template_id in data["entries"]:
		if not entry_sources.has(template_id):
			entry_sources[template_id] = {}
		for entry in data["entries"][template_id]:
			var eid = entry.get("id", "")
			if eid != "":
				entry_sources[template_id][eid] = "compendium.json"

	# Merge additional .json files
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json") and file_name != "compendium.json":
				var extra_path = dir_path + "/" + file_name
				var extra_text = FileAccess.get_file_as_string(extra_path)
				var extra = JSON.parse_string(extra_text)
				if extra is Dictionary:
					for template_id in extra:
						if not extra[template_id] is Array:
							continue
						if not data["entries"].has(template_id):
							data["entries"][template_id] = []
						if not entry_sources.has(template_id):
							entry_sources[template_id] = {}
						for entry in extra[template_id]:
							data["entries"][template_id].append(entry)
							var eid = entry.get("id", "")
							if eid != "":
								entry_sources[template_id][eid] = file_name
				else:
					push_warning("[CompendiumLoader] Failed to parse extra file: ", extra_path)
			file_name = dir.get_next()
		dir.list_dir_end()

	data["_dir"] = dir_path
	print("[CompendiumLoader] Loaded compendium: ", comp_id, " (", data.get("name", ""), ")")
	return {"id": comp_id, "data": data, "entry_sources": entry_sources}
