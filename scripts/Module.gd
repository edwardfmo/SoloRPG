class_name Module
extends RefCounted

var id: String
var start_node: String
var nodes: Dictionary = {}

var api # reference to your ModAPI


func init(module_data: Dictionary, _api):
	api = _api

	id = module_data.get("id", "")
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

	var system_name = parts[0]
	var action_name = parts[1]

	var system = api.get_system(system_name)

	if system == null:
		push_warning("Missing system: " + system_name)
		return

	if system.has_method("handle_action"):
		system.handle_action(action_name, action, context)
	else:
		push_warning(system_name + " has no handle_action()")


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

	var system_name = parts[0]
	var cond_name = parts[1]

	var system = api.get_system(system_name)

	if system == null:
		push_warning("Missing system: " + system_name)
		return false

	if system.has_method("check_condition"):
		return system.check_condition(cond_name, cond, context)

	push_warning(system_name + " has no check_condition()")
	return false
