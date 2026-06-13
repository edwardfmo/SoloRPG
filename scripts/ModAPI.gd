class_name ModAPI
extends RefCounted

var plugins := {}
var plugin_metadata := {}  # plugin_name → {name, version, author, ...}
var _evaluators := {}  # prefix → Callable(code: String) -> Variant
var _evaluator_instances := []  # keeps RefCounted evaluators alive
var context_changed_callback: Callable  # set by GameView to notify UI of context updates
var show_overlay_callback: Callable     # set by GameView to show overlay views
var save_to_path_callback: Callable     # set by Main to allow plugins to trigger saves
var load_from_path_callback: Callable   # set by Main to allow plugins to trigger loads
var restore_state_callback: Callable    # set by Main: func(context: Dictionary)
var pre_choice_callback: Callable       # called before a choice is executed

func register_plugin(name: String, plugin: Plugin, metadata: Dictionary = {}):
	plugins[name] = plugin
	plugin_metadata[name] = metadata
	plugin.api = self

func get_plugin(name: String):
	return plugins.get(name, null)


## Register an evaluator for a given prefix (e.g. "/r", "/roll").
## handler signature: func(code: String) -> Variant
func register_evaluator(prefix: String, handler: Callable):
	_evaluators[prefix] = handler


## Register an Evaluator instance. Keeps it alive and registers all its prefixes.
func register_evaluator_instance(evaluator: Evaluator):
	_evaluator_instances.append(evaluator)
	for prefix in evaluator.get_prefixes():
		_evaluators[prefix] = evaluator.evaluate


## Evaluate a value. If it's a string starting with a registered prefix,
## pass it to the corresponding evaluator. Otherwise return as-is.
func evaluate(value: Variant) -> Variant:
	if not value is String:
		return value
	var s: String = value
	for prefix in _evaluators:
		if s.begins_with(prefix):
			return _evaluators[prefix].call(s)
	return value


## Returns all published action types from registered plugins.
func get_all_actions() -> Array[String]:
	var result: Array[String] = []
	for plugin in plugins.values():
		if plugin is Plugin:
			result.append_array(plugin.get_actions())
	return result


## Returns all published condition types from registered plugins.
func get_all_conditions() -> Array[String]:
	var result: Array[String] = []
	for plugin in plugins.values():
		if plugin is Plugin:
			result.append_array(plugin.get_conditions())
	return result


## Returns UI panel declarations for a specific slot from all plugins.
func get_ui_panels_for_slot(slot: String) -> Array[Dictionary]:
	var panels: Array[Dictionary] = []
	for plugin in plugins.values():
		if plugin is Plugin:
			for panel in plugin.get_ui_panels():
				if panel.get("slot", "") == slot:
					panels.append(panel)
	return panels


## Returns a dict mapping each action/condition type string to its provider plugin name.
func get_provider_map() -> Dictionary:
	var map := {}
	for plugin_name in plugins:
		var plugin = plugins[plugin_name]
		if plugin is Plugin:
			for action in plugin.get_actions():
				map[action] = plugin_name
			for cond in plugin.get_conditions():
				map[cond] = plugin_name
	return map


## Returns parameter schema for a given type (action or condition).
## Returns array of {name: String, mandatory: bool}.
func get_params_for_type(type: String) -> Array[Dictionary]:
	var dot_idx = type.find(".")
	if dot_idx <= 0:
		return []
	var plugin_name = type.substr(0, dot_idx)
	var entry_name = type.substr(dot_idx + 1)
	var plugin = plugins.get(plugin_name, null)
	if plugin == null or not plugin is Plugin:
		return []
	# Check actions first, then conditions
	if type in plugin.get_actions():
		return plugin.get_action_params(entry_name)
	if type in plugin.get_conditions():
		return plugin.get_condition_params(entry_name)
	return []


## Notify plugin UI that context has changed.
func notify_context_changed(context: Dictionary):
	for plugin in plugins.values():
		if plugin is Plugin:
			plugin.on_context_changed(context)
	if context_changed_callback.is_valid():
		context_changed_callback.call(context)


## Show an overlay view by id with parameters.
func show_overlay(overlay_id: String, params: Dictionary = {}):
	if show_overlay_callback.is_valid():
		show_overlay_callback.call(overlay_id, params)


## Dispatch an action to the appropriate plugin based on type prefix.
func dispatch_action(type: String, data: Dictionary = {}, context: Dictionary = {}):
	var dot_idx = type.find(".")
	if dot_idx <= 0:
		push_warning("[ModAPI] Invalid action type: ", type)
		return
	var plugin_name = type.substr(0, dot_idx)
	var action_name = type.substr(dot_idx + 1)
	var plugin = plugins.get(plugin_name, null)
	if plugin == null:
		push_warning("[ModAPI] Plugin not found for action: ", type)
		return
	data["type"] = type

	# Save output param paths before handle_action overwrites them
	var output_paths := {}
	if plugin.has_method("get_action_params"):
		var params = plugin.get_action_params(action_name)
		for p in params:
			if p.get("direction", "input") == "output" and data.has(p["name"]):
				output_paths[p["name"]] = data[p["name"]]

	# Resolve evaluators in input parameters
	for key in data:
		if key == "type":
			continue
		if output_paths.has(key):
			continue
		data[key] = evaluate(data[key])

	plugin.handle_action(action_name, data, context)

	# Write output params to context at their dot-paths
	for key in output_paths:
		if data.has(key):
			_set_context_path(context, output_paths[key], data[key])


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


## Notify all plugins that a new game has started so they can initialize context.
func notify_game_started(context: Dictionary):
	for plugin in plugins.values():
		if plugin is Plugin:
			plugin.on_game_start(context)


## Notify all plugins before a choice is executed.
func notify_pre_choice(context: Dictionary):
	for plugin in plugins.values():
		if plugin is Plugin:
			plugin.on_pre_choice(context)
