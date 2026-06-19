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

	api._resolve_and_dispatch(plugin, action_name, action.duplicate(true), context)


func are_conditions_met(conditions: Array, context) -> bool:
	# Group conditions into OR-clauses using "or_above" field.
	# Each group is OR-ed internally, groups are AND-ed together.
	var groups: Array[Array] = []
	for cond in conditions:
		if cond.get("or_above", false) and not groups.is_empty():
			groups[groups.size() - 1].append(cond)
		else:
			groups.append([cond])

	for group in groups:
		var group_passed := false
		for cond in group:
			var result = _check_condition(cond, context)
			if cond.get("negate", false):
				result = not result
			if result:
				group_passed = true
				break
		if not group_passed:
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
		return plugin.check_condition(cond_name, cond.duplicate(true), context)

	push_warning(plugin_name + " has no check_condition()")
	return false
