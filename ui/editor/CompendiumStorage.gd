class_name CompendiumStorage
extends RefCounted

var _api: ModAPI = null
var _compendiums: Array = []
var _dirty: Dictionary = {}
var _dirty_entries: Dictionary = {}
var _is_editor_mode: bool = true
var _module_id: String = ""
var _module_entries: Dictionary = {}


func setup(api: ModAPI):
	_api = api
	_is_editor_mode = OS.has_feature("editor")


func set_module_data(module_id: String, entries: Dictionary):
	_module_id = module_id
	_module_entries = entries


func load_compendiums():
	_compendiums.clear()
	var loader = CompendiumLoader.new()
	var loaded = loader.load_all()
	for entry in loaded:
		_compendiums.append(entry["data"])


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


func is_module_comp(comp_id: String) -> bool:
	return _module_id != "" and comp_id == _module_id


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

	var dir_path = base_dir + "/" + comp_id
	DirAccess.make_dir_recursive_absolute(dir_path)

	var file_path = dir_path + "/compendium.json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_warning("[CompendiumEditor] Failed to save: " + file_path)
		return
	file.store_string(JSON.stringify(comp_data, "\t"))
	file.close()
	print("[CompendiumEditor] Saved: " + file_path)


func _reload_api():
	if _api:
		_api._entries.clear()
		var loader = CompendiumLoader.new()
		var loaded = loader.load_all()
		for entry in loaded:
			_api.register_compendium(entry["id"], entry["data"])


func _comp_exists_in_bundled(comp_id: String) -> bool:
	var bundled_path = SystemUtils.BUNDLED_COMPENDIUMS_DIR + "/" + comp_id
	return DirAccess.dir_exists_absolute(bundled_path)
