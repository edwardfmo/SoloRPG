class_name ModAPI
extends RefCounted

var plugins := {}
var plugin_metadata := {}  # plugin_name → {name, version, author, ...}
var context_changed_callback: Callable  # set by GameView to notify UI of context updates
var show_overlay_callback: Callable     # set by GameView to show overlay views

func register_plugin(name: String, plugin: Plugin, metadata: Dictionary = {}):
	plugins[name] = plugin
	plugin_metadata[name] = metadata
	plugin.api = self

func get_plugin(name: String):
	return plugins.get(name, null)


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


## Notify plugin UI that context has changed.
func notify_context_changed(context: Dictionary):
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
	plugin.handle_action(action_name, data, context)
