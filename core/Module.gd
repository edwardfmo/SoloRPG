class_name Module
extends RefCounted

var id: String
var display_name: String
var version: String
var author: String
var start_node: String
var nodes: Dictionary = {}

var api # reference to your ModAPI


func init(module_data: Dictionary, _api):
	api = _api

	id = module_data.get("id", "")
	display_name = module_data.get("name", "")
	version = module_data.get("version", "")
	author = module_data.get("author", "")
	start_node = module_data.get("start_node", "")

	nodes = module_data.get("nodes", {})


func get_node(node_id: String) -> Dictionary:
	return nodes.get(node_id, {})


func enter_node(node_id: String, context = {}):
	var node = get_node(node_id)
	if node.is_empty():
		push_error("Node not found: " + node_id)
		return

	var actions = node.get("on_enter", [])

	for action in actions:
		_execute_action(action, context)


func get_available_choices(node_id: String, context = {}) -> Array:
	var node = get_node(node_id)
	var result = []

	for choice in node.get("choices", []):
		if are_conditions_met(choice.get("conditions", []), context):
			result.append(choice)

	return result


func _execute_action(action: Dictionary, context):
	if not action.has("type"):
		push_warning("Action missing type")
		return

	var parts = action["type"].split(".")
	if parts.size() < 2:
		push_warning("Invalid action type: " + action["type"])
		return

	var plugin_name = parts[0]
	var action_name = parts[1]

	var plugin = api.get_plugin(plugin_name)

	if plugin == null:
		push_warning("Missing plugin: " + plugin_name)
		return

	if not plugin.has_method("handle_action"):
		push_warning(plugin_name + " has no handle_action()")
		return

	# Save output param paths before handle_action overwrites them
	var output_paths := {}
	if plugin.has_method("get_action_params"):
		var params = plugin.get_action_params(action_name)
		for p in params:
			if p.get("direction", "input") == "output" and action.has(p["name"]):
				output_paths[p["name"]] = action[p["name"]]

	# Resolve evaluators in input parameters, preserve original refs
	var _raw_refs := {}
	for key in action:
		if key == "type":
			continue
		if output_paths.has(key):
			continue
		var val = action[key]
		if val is String and val.begins_with("@"):
			_raw_refs[key] = val
		if val is String and val.begins_with("$"):
			action[key] = api._get_context_path(context, val.substr(1))
		else:
			action[key] = api.evaluate(val)
	action["_raw_refs"] = _raw_refs

	plugin.handle_action(action_name, action, context)

	# Clean up internal key
	action.erase("_raw_refs")

	# Write output params to context at their dot-paths
	for key in output_paths:
		if action.has(key):
			_set_context_path(context, output_paths[key], action[key])


## Write a value into context at a dot-separated path, creating nested dicts as needed.
func _set_context_path(context: Dictionary, path: String, value):
	var keys = path.split(".")
	var current = context
	for i in keys.size() - 1:
		var k = keys[i]
		if not current.has(k) or not current[k] is Dictionary:
			current[k] = {}
		current = current[k]
	current[keys[keys.size() - 1]] = value


func are_conditions_met(conditions: Array, context) -> bool:
	for cond in conditions:
		if not _check_condition(cond, context):
			return false
	return true


func _check_condition(cond: Dictionary, context) -> bool:
	if not cond.has("type"):
		return false

	var parts = cond["type"].split(".")
	if parts.size() < 2:
		return false

	var plugin_name = parts[0]
	var cond_name = parts[1]

	var plugin = api.get_plugin(plugin_name)

	if plugin == null:
		push_warning("Missing plugin: " + plugin_name)
		return false

	if plugin.has_method("check_condition"):
		return plugin.check_condition(cond_name, cond, context)

	push_warning(plugin_name + " has no check_condition()")
	return false
