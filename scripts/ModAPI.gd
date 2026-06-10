class_name ModAPI
extends RefCounted

var plugins := {}
var plugin_metadata := {}  # plugin_name → {name, version, author, ...}

func register_plugin(name: String, plugin: Plugin, metadata: Dictionary = {}):
	plugins[name] = plugin
	plugin_metadata[name] = metadata

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
