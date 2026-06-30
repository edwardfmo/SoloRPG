class_name ModuleSerializer
extends RefCounted

var graph: GraphEdit
var nodes: Array = []
var frames: Array = []
var _api: ModAPI = null
var _frame_manager: GraphFrameManager = null


func setup(p_graph: GraphEdit, p_nodes: Array, p_frames: Array, p_frame_manager: GraphFrameManager):
	graph = p_graph
	nodes = p_nodes
	frames = p_frames
	_frame_manager = p_frame_manager


func set_api(api: ModAPI):
	_api = api


## Save module to a directory. Creates dir_path/module.json and preserves images/.
func save_to_directory(dir_path: String, metadata: Dictionary, start_node_gn: GraphNode, module_entries: Dictionary, module_settings: Dictionary = {}):
	DirAccess.make_dir_recursive_absolute(dir_path)
	DirAccess.make_dir_recursive_absolute(dir_path + "/images")
	var module = _build_module_dict(metadata, start_node_gn, module_entries, module_settings)
	var json = JSON.stringify(module, "\t")
	var file = FileAccess.open(dir_path + "/module.json", FileAccess.WRITE)
	file.store_string(json)
	print("Saved module to: " + dir_path)


## Export module to a .rpgmod ZIP file.
## If only_referenced_images is true, only images referenced by nodes are included.
func export_to_zip(zip_path: String, dir_path: String, metadata: Dictionary, start_node_gn: GraphNode, module_entries: Dictionary, module_settings: Dictionary = {}, only_referenced_images: bool = false):
	# First save to directory
	save_to_directory(dir_path, metadata, start_node_gn, module_entries, module_settings)

	var referenced := {}
	if only_referenced_images:
		referenced = get_referenced_images()

	var zip = ZIPPacker.new()
	var err = zip.open(zip_path)
	if err != OK:
		push_error("Failed to create ZIP: " + zip_path)
		return

	# Add module.json
	var json_data = FileAccess.get_file_as_bytes(dir_path + "/module.json")
	zip.start_file("module.json")
	zip.write_file(json_data)
	zip.close_file()

	# Add images
	var images_dir = DirAccess.open(dir_path + "/images")
	if images_dir:
		images_dir.list_dir_begin()
		var file_name = images_dir.get_next()
		while file_name != "":
			if not images_dir.current_is_dir():
				var rel_path = "images/" + file_name
				if not only_referenced_images or referenced.has(rel_path):
					var file_data = FileAccess.get_file_as_bytes(dir_path + "/" + rel_path)
					zip.start_file(rel_path)
					zip.write_file(file_data)
					zip.close_file()
			file_name = images_dir.get_next()
		images_dir.list_dir_end()

	zip.close()
	print("Exported .rpgmod to: " + zip_path)


## Import a .rpgmod ZIP into a directory, returns the directory path.
## If overwrite is false and the directory already exists, returns the existing path without extracting.
func import_from_zip(zip_path: String, overwrite: bool = false) -> String:
	var zip = ZIPReader.new()
	var err = zip.open(zip_path)
	if err != OK:
		push_error("Failed to open ZIP: " + zip_path)
		return ""

	# Determine module id from module.json inside zip
	var json_data = zip.read_file("module.json")
	if json_data.is_empty():
		zip.close()
		return ""
	var data = JSON.parse_string(json_data.get_string_from_utf8())
	if data == null:
		zip.close()
		return ""

	var module_id = data.get("id", "imported_module")
	var dest_dir = SystemUtils.MODULES_DIR + module_id

	# If directory already exists and overwrite is false, use existing
	if DirAccess.dir_exists_absolute(dest_dir) and not overwrite:
		zip.close()
		return dest_dir

	DirAccess.make_dir_recursive_absolute(dest_dir)

	# Extract all files
	for file_path in zip.get_files():
		var content = zip.read_file(file_path)
		var full_path = dest_dir + "/" + file_path
		# Ensure subdirectory exists
		var parent_dir = full_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(parent_dir)
		var f = FileAccess.open(full_path, FileAccess.WRITE)
		if f:
			f.store_buffer(content)

	zip.close()
	return dest_dir


## Load module data from either a directory (containing module.json) or a single .json file.
## When opening a .rpgmod, overwrite_on_import controls whether to replace an existing directory.
func load_module(path: String, overwrite_on_import: bool = false) -> Dictionary:
	var json_path := ""
	if DirAccess.dir_exists_absolute(path):
		json_path = path + "/module.json"
	elif path.ends_with(".rpgmod"):
		var dest_dir = import_from_zip(path, overwrite_on_import)
		if dest_dir == "":
			return {}
		json_path = dest_dir + "/module.json"
	else:
		json_path = path

	var json_text = FileAccess.get_file_as_string(json_path)
	var data = JSON.parse_string(json_text)
	if data == null:
		print("Failed to parse module file.")
		return {}
	# Store the directory path in the data for reference
	data["_dir_path"] = json_path.get_base_dir()
	return data


## Get all image paths referenced by nodes in the graph.
func get_referenced_images() -> Dictionary:
	var refs := {}
	for n in nodes:
		var img = n.data.get("image", "")
		if img != "":
			refs[img] = true
		# Also scan actions for image references
		for action in n.data.get("on_enter", []):
			_scan_image_refs(action, refs)
		for choice in n.data.get("choices", []):
			for action in choice.get("actions", []):
				_scan_image_refs(action, refs)
	return refs


## Get list of all image files in the module's images/ directory.
func get_all_images(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var images_dir = DirAccess.open(dir_path + "/images")
	if images_dir == null:
		return result
	images_dir.list_dir_begin()
	var file_name = images_dir.get_next()
	while file_name != "":
		if not images_dir.current_is_dir():
			result.append("images/" + file_name)
		file_name = images_dir.get_next()
	images_dir.list_dir_end()
	return result


## Check if there are unreferenced images in the module directory.
func has_unreferenced_images(dir_path: String) -> bool:
	var referenced = get_referenced_images()
	var all_images = get_all_images(dir_path)
	for img in all_images:
		if not referenced.has(img):
			return true
	return false


## Copy an image file into the module's images/ directory. Returns the relative path.
func copy_image_to_module(source_path: String, dir_path: String) -> String:
	# Globalize paths to ensure copy works across path schemes (res:// vs filesystem)
	var global_dir = dir_path
	if dir_path.begins_with("res://"):
		global_dir = ProjectSettings.globalize_path(dir_path)

	var images_dir = global_dir + "/images"
	DirAccess.make_dir_recursive_absolute(images_dir)
	var file_name = source_path.get_file()
	var dest_path = images_dir + "/" + file_name

	# Handle naming conflicts
	var counter = 2
	while FileAccess.file_exists(dest_path):
		var base = file_name.get_basename()
		var ext = file_name.get_extension()
		var new_name = base + "_" + str(counter) + "." + ext
		dest_path = images_dir + "/" + new_name
		file_name = new_name
		counter += 1

	var global_source = source_path
	if source_path.begins_with("res://"):
		global_source = ProjectSettings.globalize_path(source_path)

	var err = DirAccess.copy_absolute(global_source, dest_path)
	if err != OK:
		push_warning("[ModuleSerializer] Failed to copy image: " + source_path + " → " + dest_path + " (error: " + str(err) + ")")
	return "images/" + file_name


func _scan_image_refs(data: Dictionary, refs: Dictionary):
	for key in data:
		var val = data[key]
		if val is String and _looks_like_image_path(val):
			refs[val] = true


static func _looks_like_image_path(val: String) -> bool:
	var lower = val.to_lower()
	return lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp")


func _build_module_dict(metadata: Dictionary, start_node_gn: GraphNode, module_entries: Dictionary, module_settings: Dictionary) -> Dictionary:
	var start_id = ""
	for conn in graph.get_connection_list():
		if conn["from_node"] == start_node_gn.name:
			var target = graph.get_node(NodePath(conn["to_node"]))
			if target is StoryNode:
				start_id = target.data["id"]
			break

	var module = {
		"id": metadata.get("id", "editor_module"),
		"name": metadata.get("name", ""),
		"version": metadata.get("version", ""),
		"author": metadata.get("author", ""),
		"start_node": start_id,
		"nodes": {}
	}

	if not module_entries.is_empty():
		module["entries"] = module_entries

	if not module_settings.is_empty():
		module["settings"] = module_settings

	for n in nodes:
		module["nodes"][n.data["id"]] = n.data

	var frames_data = _frame_manager.serialize_frames()
	if frames_data.size() > 0:
		module["frames"] = frames_data

	if _api:
		var deps = _build_dependencies(metadata.get("id", ""))
		if deps.size() > 0:
			module["dependencies"] = deps

	return module


func _build_dependencies(module_id: String) -> Array:
	var provider_map = _api.get_provider_map()

	var used_types: Array[String] = []
	var used_compendiums: Dictionary = {}
	for n in nodes:
		for action in n.data.get("on_enter", []):
			var t = action.get("type", "")
			if t != "" and not used_types.has(t):
				used_types.append(t)
			_scan_entry_refs(action, used_compendiums, module_id)
		for choice in n.data.get("choices", []):
			for action in choice.get("actions", []):
				var t = action.get("type", "")
				if t != "" and not used_types.has(t):
					used_types.append(t)
				_scan_entry_refs(action, used_compendiums, module_id)
			for cond in choice.get("conditions", []):
				var t = cond.get("type", "")
				if t != "" and not used_types.has(t):
					used_types.append(t)
				_scan_entry_refs(cond, used_compendiums, module_id)

	var plugin_deps := {}
	for type_str in used_types:
		if provider_map.has(type_str):
			var pname = provider_map[type_str]
			if not plugin_deps.has(pname):
				var meta = _api.plugin_metadata.get(pname, {})
				plugin_deps[pname] = meta.get("version", "")

	var result := []
	var sorted_keys = plugin_deps.keys()
	sorted_keys.sort()
	for pname in sorted_keys:
		result.append({"id": pname, "version": plugin_deps[pname]})

	var comp_loader = CompendiumLoader.new()
	var all_comps = comp_loader.scan_metadata()
	var comp_meta_map := {}
	for meta in all_comps:
		comp_meta_map[meta.get("id", "")] = meta

	var sorted_comps = used_compendiums.keys()
	sorted_comps.sort()
	for comp_id in sorted_comps:
		var version = ""
		if comp_meta_map.has(comp_id):
			version = comp_meta_map[comp_id].get("version", "")
		result.append({"id": comp_id, "type": "compendium", "version": version})

	return result


func _scan_entry_refs(data: Dictionary, out_compendiums: Dictionary, module_id: String):
	for key in data:
		if key == "type":
			continue
		var val = data[key]
		if val is String and val.begins_with("@"):
			var parsed = ModAPI.parse_entry_ref(val)
			var namespace_id = parsed["namespace"]
			if _api.plugins.has(namespace_id):
				continue
			if namespace_id == module_id:
				continue
			out_compendiums[namespace_id] = true
