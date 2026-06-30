class_name CompendiumStorage
extends RefCounted

var _api: ModAPI = null
var _compendiums: Array = []
var _dirty: Dictionary = {}
var _dirty_entries: Dictionary = {}
var _is_editor_mode: bool = true
var _module_id: String = ""
var _module_entries: Dictionary = {}
# Track entry source files: comp_id -> template_id -> entry_id -> filename
var _entry_sources: Dictionary = {}


func setup(api: ModAPI):
	_api = api
	_is_editor_mode = OS.has_feature("editor")


func set_module_data(module_id: String, entries: Dictionary):
	_module_id = module_id
	_module_entries = entries


func load_compendiums():
	_compendiums.clear()
	_entry_sources.clear()
	var loader = CompendiumLoader.new()
	var loaded = loader.load_all()
	for entry in loaded:
		_compendiums.append(entry["data"])
		var comp_id = entry["id"]
		_entry_sources[comp_id] = entry.get("entry_sources", {})


func get_compendiums() -> Array:
	return _compendiums


func get_module_id() -> String:
	return _module_id


func get_module_entries() -> Dictionary:
	return _module_entries


func is_dirty(comp_id: String) -> bool:
	return _dirty.has(comp_id)


func is_entry_dirty(comp_id: String, template_id: String, entry_id: String) -> bool:
	return _dirty_entries.has(comp_id + "/" + template_id + "/" + entry_id)


func mark_dirty(comp_id: String):
	_dirty[comp_id] = true


func mark_entry_dirty(comp_id: String, template_id: String, entry_id: String):
	_dirty[comp_id] = true
	_dirty_entries[comp_id + "/" + template_id + "/" + entry_id] = true


func rename_entry_id(comp_id: String, template_id: String, old_id: String, new_id: String):
	# Update entry_sources mapping
	var comp_sources = _entry_sources.get(comp_id, {})
	var tmpl_sources = comp_sources.get(template_id, {})
	if tmpl_sources.has(old_id):
		var file_name = tmpl_sources[old_id]
		tmpl_sources.erase(old_id)
		tmpl_sources[new_id] = file_name
	# Update dirty_entries tracking
	var old_key = comp_id + "/" + template_id + "/" + old_id
	if _dirty_entries.has(old_key):
		_dirty_entries.erase(old_key)
	_dirty_entries[comp_id + "/" + template_id + "/" + new_id] = true
	_dirty[comp_id] = true


func get_entry_source_file(comp_id: String, template_id: String, entry_id: String) -> String:
	var comp_sources = _entry_sources.get(comp_id, {})
	var tmpl_sources = comp_sources.get(template_id, {})
	return tmpl_sources.get(entry_id, "compendium.json")


func set_entry_source_file(comp_id: String, template_id: String, entry_id: String, file_name: String):
	if not _entry_sources.has(comp_id):
		_entry_sources[comp_id] = {}
	if not _entry_sources[comp_id].has(template_id):
		_entry_sources[comp_id][template_id] = {}
	_entry_sources[comp_id][template_id][entry_id] = file_name


func get_compendium_files(comp_id: String) -> Array[String]:
	var files: Array[String] = []
	var comp_sources = _entry_sources.get(comp_id, {})
	for template_id in comp_sources:
		if template_id == "_files":
			for f in comp_sources["_files"]:
				if f not in files:
					files.append(f)
			continue
		for entry_id in comp_sources[template_id]:
			var f = comp_sources[template_id][entry_id]
			if f not in files:
				files.append(f)
	# Always include compendium.json even if empty
	if "compendium.json" not in files:
		files.insert(0, "compendium.json")
	else:
		files.erase("compendium.json")
		files.insert(0, "compendium.json")
	return files


func get_entries_for_file(comp_id: String, file_name: String) -> Dictionary:
	var result := {}
	var comp = get_compendium(comp_id)
	if comp == null:
		return result
	var all_entries = comp.get("entries", {})
	var comp_sources = _entry_sources.get(comp_id, {})
	for template_id in all_entries:
		var tmpl_sources = comp_sources.get(template_id, {})
		for entry in all_entries[template_id]:
			var eid = entry.get("id", "")
			var source = tmpl_sources.get(eid, "compendium.json")
			if source == file_name:
				if not result.has(template_id):
					result[template_id] = []
				result[template_id].append(entry)
	return result


func add_file(comp_id: String, file_name: String):
	if not file_name.ends_with(".json"):
		file_name += ".json"
	# Just ensure it shows up in sources (empty file)
	if not _entry_sources.has(comp_id):
		_entry_sources[comp_id] = {}
	# Create a placeholder so the file appears
	if not _entry_sources[comp_id].has("_files"):
		_entry_sources[comp_id]["_files"] = {}
	_entry_sources[comp_id]["_files"][file_name] = file_name
	mark_dirty(comp_id)


func delete_file(comp_id: String, file_name: String):
	if file_name == "compendium.json":
		return
	# Remove entries belonging to this file
	var comp = get_compendium(comp_id)
	if comp == null:
		return
	var all_entries = comp.get("entries", {})
	var comp_sources = _entry_sources.get(comp_id, {})
	for template_id in all_entries.keys():
		var tmpl_sources = comp_sources.get(template_id, {})
		var i = all_entries[template_id].size() - 1
		while i >= 0:
			var eid = all_entries[template_id][i].get("id", "")
			if tmpl_sources.get(eid, "compendium.json") == file_name:
				all_entries[template_id].remove_at(i)
				tmpl_sources.erase(eid)
			i -= 1
		if all_entries[template_id].is_empty():
			all_entries.erase(template_id)
	# Remove file from _files placeholder
	if comp_sources.has("_files"):
		comp_sources["_files"].erase(file_name)
	# Delete actual file on disk
	var dir_path = comp.get("_dir", "")
	if dir_path != "":
		var file_path = dir_path + "/" + file_name
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	mark_dirty(comp_id)


func file_has_entries(comp_id: String, file_name: String) -> bool:
	var entries = get_entries_for_file(comp_id, file_name)
	for template_id in entries:
		if entries[template_id].size() > 0:
			return true
	return false


func is_module_comp(comp_id: String) -> bool:
	return _module_id != "" and comp_id == _module_id


## Reorder a module entry: move it to a different template or position within a template.
## If before_entry_id is "", appends to the end of dst_template.
func reorder_module_entry(src_template: String, entry_id: String, dst_template: String, before_entry_id: String = "") -> String:
	if not _module_entries.has(src_template):
		return "Source template not found."
	var src_list: Array = _module_entries[src_template]
	var entry = null
	var src_idx := -1
	for i in src_list.size():
		if src_list[i].get("id", "") == entry_id:
			entry = src_list[i]
			src_idx = i
			break
	if entry == null:
		return "Entry not found in source template."

	# Remove from source
	src_list.remove_at(src_idx)
	if src_list.is_empty():
		_module_entries.erase(src_template)

	# Ensure destination template exists
	if not _module_entries.has(dst_template):
		_module_entries[dst_template] = []
	var dst_list: Array = _module_entries[dst_template]

	# Insert at position
	if before_entry_id == "":
		dst_list.append(entry)
	else:
		var insert_idx := -1
		for i in dst_list.size():
			if dst_list[i].get("id", "") == before_entry_id:
				insert_idx = i
				break
		if insert_idx == -1:
			dst_list.append(entry)
		else:
			dst_list.insert(insert_idx, entry)

	mark_dirty(_module_id)
	return ""


func is_compendium_writable(comp_id: String) -> bool:
	if is_module_comp(comp_id):
		return true
	if _is_editor_mode:
		return true
	var user_path = SystemUtils.COMPENDIUMS_DIR + "/" + comp_id
	return DirAccess.dir_exists_absolute(user_path) or not _comp_exists_in_bundled(comp_id)


func get_compendium(comp_id: String):
	if is_module_comp(comp_id):
		return {"id": _module_id, "name": _module_id, "entries": _module_entries}
	for comp in _compendiums:
		if comp.get("id", "") == comp_id:
			return comp
	return null


func find_entry(comp_id: String, template_id: String, entry_id: String):
	if is_module_comp(comp_id):
		var entries = _module_entries.get(template_id, [])
		for entry in entries:
			if entry.get("id", "") == entry_id:
				return entry
		return null
	var comp = get_compendium(comp_id)
	if comp == null:
		return null
	var entries = comp.get("entries", {}).get(template_id, [])
	for entry in entries:
		if entry.get("id", "") == entry_id:
			return entry
	return null


## Move an entry from the module into a compendium file.
func move_from_module(template_id: String, entry_id: String, dst_comp_id: String, dst_file: String) -> String:
	if not _module_entries.has(template_id):
		return "Template not found in module."
	var src_list: Array = _module_entries[template_id]
	var entry = null
	var src_idx := -1
	for i in src_list.size():
		if src_list[i].get("id", "") == entry_id:
			entry = src_list[i]
			src_idx = i
			break
	if entry == null:
		return "Entry not found in module."
	if not is_compendium_writable(dst_comp_id):
		return "Destination compendium is not writable."
	var dst_comp: Dictionary = get_compendium(dst_comp_id)
	if dst_comp.is_empty():
		return "Destination compendium not found."
	# Remove from module
	src_list.remove_at(src_idx)
	if src_list.is_empty():
		_module_entries.erase(template_id)
	# Add to destination compendium
	if not dst_comp.has("entries"):
		dst_comp["entries"] = {}
	if not dst_comp["entries"].has(template_id):
		dst_comp["entries"][template_id] = []
	dst_comp["entries"][template_id].append(entry)
	set_entry_source_file(dst_comp_id, template_id, entry_id, dst_file)
	mark_entry_dirty(dst_comp_id, template_id, entry_id)
	mark_dirty(_module_id)
	return ""


## Move an entry from a compendium into the module.
func move_to_module(src_comp_id: String, template_id: String, entry_id: String) -> String:
	var entry = find_entry(src_comp_id, template_id, entry_id)
	if entry == null:
		return "Entry not found."
	var src_comp: Dictionary = get_compendium(src_comp_id)
	if src_comp.is_empty():
		return "Source compendium not found."
	# Remove from source compendium
	var src_entries = src_comp.get("entries", {}).get(template_id, [])
	var idx := -1
	for i in src_entries.size():
		if src_entries[i].get("id", "") == entry_id:
			idx = i
			break
	if idx == -1:
		return "Entry not found in source."
	src_entries.remove_at(idx)
	if src_entries.is_empty():
		src_comp["entries"].erase(template_id)
	# Remove from entry_sources
	var src_sources = _entry_sources.get(src_comp_id, {})
	if src_sources.has(template_id):
		src_sources[template_id].erase(entry_id)
	# Add to module
	if not _module_entries.has(template_id):
		_module_entries[template_id] = []
	_module_entries[template_id].append(entry)
	mark_dirty(src_comp_id)
	mark_dirty(_module_id)
	return ""


## Move an entry to a different file (same compendium) or different compendium.
## Returns "" on success, error message on failure.
func move_entry(src_comp_id: String, template_id: String, entry_id: String, dst_comp_id: String, dst_file: String) -> String:
	var entry = find_entry(src_comp_id, template_id, entry_id)
	if entry == null:
		return "Entry not found."
	if not is_compendium_writable(dst_comp_id):
		return "Destination compendium is not writable."

	if src_comp_id == dst_comp_id:
		# Same compendium, just change source file
		var current_file = get_entry_source_file(src_comp_id, template_id, entry_id)
		if current_file == dst_file:
			return "Entry is already in that file."
		set_entry_source_file(src_comp_id, template_id, entry_id, dst_file)
		mark_entry_dirty(src_comp_id, template_id, entry_id)
	else:
		# Cross-compendium move: remove from source, add to destination
		var src_comp: Dictionary = get_compendium(src_comp_id)
		var dst_comp: Dictionary = get_compendium(dst_comp_id)
		if src_comp.is_empty() or dst_comp.is_empty():
			return "Compendium not found."
		# Remove from source
		var src_entries = src_comp.get("entries", {}).get(template_id, [])
		var idx := -1
		for i in src_entries.size():
			if src_entries[i].get("id", "") == entry_id:
				idx = i
				break
		if idx == -1:
			return "Entry not found in source."
		src_entries.remove_at(idx)
		if src_entries.is_empty():
			src_comp["entries"].erase(template_id)
		# Remove from source entry_sources
		var src_sources = _entry_sources.get(src_comp_id, {})
		if src_sources.has(template_id):
			src_sources[template_id].erase(entry_id)
		# Add to destination
		if not dst_comp.has("entries"):
			dst_comp["entries"] = {}
		if not dst_comp["entries"].has(template_id):
			dst_comp["entries"][template_id] = []
		dst_comp["entries"][template_id].append(entry)
		set_entry_source_file(dst_comp_id, template_id, entry_id, dst_file)
		mark_entry_dirty(dst_comp_id, template_id, entry_id)
		mark_dirty(src_comp_id)
	return ""


func save_compendium(comp_id: String):
	if comp_id == "" or is_module_comp(comp_id):
		return
	if not _dirty.has(comp_id):
		return
	var comp = get_compendium(comp_id)
	if comp == null:
		return
	_write_compendium(comp)
	_dirty.erase(comp_id)
	var keys_to_erase := []
	for key in _dirty_entries:
		if key.begins_with(comp_id + "/"):
			keys_to_erase.append(key)
	for key in keys_to_erase:
		_dirty_entries.erase(key)
	_reload_api()


func save_all_dirty():
	for comp_data in _compendiums:
		var comp_id = comp_data.get("id", "")
		if not _dirty.has(comp_id):
			continue
		_write_compendium(comp_data)
	var module_dirty = _dirty.has(_module_id) if _module_id != "" else false
	_dirty.clear()
	if module_dirty:
		_dirty[_module_id] = true
	var module_entry_keys := []
	for key in _dirty_entries:
		if _module_id != "" and key.begins_with(_module_id + "/"):
			module_entry_keys.append(key)
	_dirty_entries.clear()
	for key in module_entry_keys:
		_dirty_entries[key] = true
	_reload_api()


func has_unsaved_changes() -> bool:
	for comp_id in _dirty:
		if not is_module_comp(comp_id):
			return true
	return false


func discard_changes():
	_dirty.clear()
	_dirty_entries.clear()


func add_compendium() -> Dictionary:
	var comp_data = {
		"id": "new_compendium",
		"name": "New Compendium",
		"version": "1.0.0",
		"author": "",
		"entries": {}
	}
	_compendiums.append(comp_data)
	mark_dirty("new_compendium")
	return comp_data


func _write_compendium(comp_data: Dictionary):
	var comp_id = comp_data.get("id", "new_compendium")
	var base_dir: String
	if _is_editor_mode:
		base_dir = SystemUtils.BUNDLED_COMPENDIUMS_DIR
	else:
		base_dir = SystemUtils.COMPENDIUMS_DIR

	var dir_path = comp_data.get("_dir", base_dir + "/" + comp_id)
	DirAccess.make_dir_recursive_absolute(dir_path)

	# Group entries by source file
	var file_entries: Dictionary = {}  # filename -> {template_id -> [entries]}
	var all_entries = comp_data.get("entries", {})
	var comp_sources = _entry_sources.get(comp_id, {})

	for template_id in all_entries:
		var tmpl_sources = comp_sources.get(template_id, {})
		for entry in all_entries[template_id]:
			var eid = entry.get("id", "")
			var source_file = tmpl_sources.get(eid, "compendium.json")
			if not file_entries.has(source_file):
				file_entries[source_file] = {}
			if not file_entries[source_file].has(template_id):
				file_entries[source_file][template_id] = []
			file_entries[source_file][template_id].append(entry)

	# Write compendium.json (metadata + its entries)
	var meta_copy = comp_data.duplicate()
	meta_copy["entries"] = file_entries.get("compendium.json", {})
	meta_copy.erase("_dir")
	var meta_path = dir_path + "/compendium.json"
	var meta_file = FileAccess.open(meta_path, FileAccess.WRITE)
	if meta_file == null:
		push_warning("[CompendiumEditor] Failed to save: " + meta_path)
		return
	meta_file.store_string(JSON.stringify(meta_copy, "\t"))
	meta_file.close()
	print("[CompendiumEditor] Saved: " + meta_path)

	# Write additional entry files
	for file_name in file_entries:
		if file_name == "compendium.json":
			continue
		var file_path = dir_path + "/" + file_name
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if file == null:
			push_warning("[CompendiumEditor] Failed to save: " + file_path)
			continue
		file.store_string(JSON.stringify(file_entries[file_name], "\t"))
		file.close()
		print("[CompendiumEditor] Saved: " + file_path)

	# Write empty files that have no entries but exist in _files placeholder
	if comp_sources.has("_files"):
		for file_name in comp_sources["_files"]:
			if file_name == "compendium.json":
				continue
			if file_entries.has(file_name):
				continue
			var file_path = dir_path + "/" + file_name
			var file = FileAccess.open(file_path, FileAccess.WRITE)
			if file == null:
				continue
			file.store_string(JSON.stringify({}, "\t"))
			file.close()
			print("[CompendiumEditor] Saved (empty): " + file_path)

	# Overwrite files on disk that lost all entries (entry was moved away)
	var da = DirAccess.open(dir_path)
	if da:
		da.list_dir_begin()
		var fname = da.get_next()
		while fname != "":
			if fname.ends_with(".json") and fname != "compendium.json":
				if not file_entries.has(fname) and not (comp_sources.has("_files") and comp_sources["_files"].has(fname)):
					# File exists on disk but has no entries and isn't a tracked empty file — overwrite with empty
					var file_path = dir_path + "/" + fname
					var file = FileAccess.open(file_path, FileAccess.WRITE)
					if file:
						file.store_string(JSON.stringify({}, "\t"))
						file.close()
						print("[CompendiumEditor] Cleared: " + file_path)
			fname = da.get_next()
		da.list_dir_end()


func _reload_api():
	if _api:
		_api._entries.clear()
		var loader = CompendiumLoader.new()
		var loaded = loader.load_all()
		for entry in loaded:
			_api.register_compendium(entry["id"], entry["data"])


func rename_compendium(comp_id: String, new_name: String) -> String:
	new_name = new_name.strip_edges()
	if new_name == "":
		return "Name cannot be empty."
	var new_id = new_name.to_lower().replace(" ", "_")
	new_id = new_id.validate_filename().replace(" ", "_")
	if new_id == "":
		return "Invalid name."
	if new_id != comp_id:
		for comp in _compendiums:
			if comp.get("id", "") == new_id:
				return "A compendium with id '%s' already exists." % new_id
	var comp: Dictionary = get_compendium(comp_id)
	if comp.is_empty():
		return "Compendium not found."
	comp["name"] = new_name
	if new_id != comp_id:
		comp["id"] = new_id
		# Update entry sources key
		if _entry_sources.has(comp_id):
			_entry_sources[new_id] = _entry_sources[comp_id]
			_entry_sources.erase(comp_id)
		# Update dirty tracking
		if _dirty.has(comp_id):
			_dirty.erase(comp_id)
			_dirty[new_id] = true
		var keys_to_update := []
		for key in _dirty_entries:
			if key.begins_with(comp_id + "/"):
				keys_to_update.append(key)
		for key in keys_to_update:
			_dirty_entries[new_id + key.substr(comp_id.length())] = true
			_dirty_entries.erase(key)
		# Rename folder on disk
		var old_dir = comp.get("_dir", "")
		if old_dir != "":
			var base = old_dir.get_base_dir()
			var new_dir = base + "/" + new_id
			if DirAccess.dir_exists_absolute(old_dir):
				DirAccess.rename_absolute(old_dir, new_dir)
			comp["_dir"] = new_dir
	mark_dirty(new_id)
	return ""


func rename_file(comp_id: String, old_name: String, new_name: String) -> String:
	new_name = new_name.strip_edges()
	if new_name == "":
		return "File name cannot be empty."
	if not new_name.ends_with(".json"):
		new_name += ".json"
	new_name = new_name.validate_filename()
	if new_name == "" or new_name == ".json":
		return "Invalid file name."
	if new_name == old_name:
		return ""
	# Check for duplicates
	var files = get_compendium_files(comp_id)
	for f in files:
		if f == new_name:
			return "A file named '%s' already exists in this compendium." % new_name
	# Update entry sources
	var comp_sources = _entry_sources.get(comp_id, {})
	for template_id in comp_sources:
		if template_id == "_files":
			if comp_sources["_files"].has(old_name):
				comp_sources["_files"].erase(old_name)
				comp_sources["_files"][new_name] = new_name
			continue
		for entry_id in comp_sources[template_id]:
			if comp_sources[template_id][entry_id] == old_name:
				comp_sources[template_id][entry_id] = new_name
	# Rename on disk
	var comp = get_compendium(comp_id)
	if comp:
		var dir_path = comp.get("_dir", "")
		if dir_path != "":
			var old_path = dir_path + "/" + old_name
			var new_path = dir_path + "/" + new_name
			if FileAccess.file_exists(old_path):
				DirAccess.rename_absolute(old_path, new_path)
	mark_dirty(comp_id)
	return ""


func _comp_exists_in_bundled(comp_id: String) -> bool:
	var bundled_path = SystemUtils.BUNDLED_COMPENDIUMS_DIR + "/" + comp_id
	return DirAccess.dir_exists_absolute(bundled_path)
