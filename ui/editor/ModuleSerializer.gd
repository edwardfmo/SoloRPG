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


func export_module(path: String, metadata: Dictionary, start_node_gn: GraphNode, module_entries: Dictionary):
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

	for n in nodes:
		module["nodes"][n.data["id"]] = n.data

	var frames_data = _frame_manager.serialize_frames()
	if frames_data.size() > 0:
		module["frames"] = frames_data

	if _api:
		var deps = _build_dependencies(metadata.get("id", ""))
		if deps.size() > 0:
			module["dependencies"] = deps

	var json = JSON.stringify(module, "\t")
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(json)
	print("Exported to: " + path)


func load_module(path: String) -> Dictionary:
	var json_text = FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(json_text)
	if data == null:
		print("Failed to parse module file.")
		return {}
	return data


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
