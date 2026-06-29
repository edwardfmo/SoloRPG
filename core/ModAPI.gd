class_name ModAPI
extends RefCounted

const SETTINGS_PATH = "user://settings.json"

var plugins := {}
var plugin_metadata := {}  # plugin_name → {name, version, author, ...}
var _evaluators := {}  # prefix → Callable(code: String) -> Variant
var _evaluator_instances := []  # keeps RefCounted evaluators alive
var _templates := {}  # template_id → {id, name, fields, source_plugin}
var _entries := {}  # template_id → {namespace.entry_id → entry_dict}
var _compendium_metadata := {}  # compendium_id → {name, version, author, ...}
var _settings := {}  # path → {path, label, type, scope, default, options?, plugin?}
var _setting_values := {}  # path → current value
var context := {}               # live game context — single source of truth
var context_changed_callback: Callable  # set by GameView to notify UI of context updates
var show_overlay_callback: Callable     # set by GameView to show overlay views
var get_overlay_node_callback: Callable  # set by GameView: func(id: String) -> PluginOverlay
var save_to_path_callback: Callable     # set by Main to allow plugins to trigger saves
var load_from_path_callback: Callable   # set by Main to allow plugins to trigger loads
var restore_state_callback: Callable    # set by Main: func(context: Dictionary)
var pre_choice_callback: Callable       # called before a choice is executed

func register_plugin(name: String, plugin: Plugin, metadata: Dictionary = {}):
	plugins[name] = plugin
	plugin_metadata[name] = metadata
	plugin.api = self
	# Register templates and seed entries from this plugin
	for tmpl in plugin.get_templates():
		var tmpl_id = tmpl.get("id", "")
		if tmpl_id != "":
			tmpl["source_plugin"] = name
			_templates[tmpl_id] = tmpl
			if not _entries.has(tmpl_id):
				_entries[tmpl_id] = {}
	var seed_entries = plugin.get_template_entries()
	for tmpl_id in seed_entries:
		if not _entries.has(tmpl_id):
			_entries[tmpl_id] = {}
		for entry in seed_entries[tmpl_id]:
			var entry_id = entry.get("id", "")
			if entry_id != "":
				_entries[tmpl_id][name + "." + entry_id] = entry
	# Register settings from this plugin
	for setting_def in plugin.get_settings():
		var def_copy = setting_def.duplicate()
		def_copy["plugin"] = name
		register_setting(def_copy)

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


## Resolve a value that may be a reference wrapper {_ref: "@..."}.
## Returns the resolved entry dict, or the original value if not a ref.
func resolve(value: Variant) -> Variant:
	if value is Dictionary and value.has("_ref"):
		return evaluate(value["_ref"])
	return value


## Create a reference wrapper for an entry evaluator string.
static func make_ref(entry_ref: String) -> Dictionary:
	return {"_ref": entry_ref}


## Parse an entry reference string like "@template/namespace.entry_id" or "@namespace.entry_id".
## Returns {"template": String, "namespace": String, "entry_id": String}.
static func parse_entry_ref(ref: String) -> Dictionary:
	var rest = ref.substr(1)  # remove @
	var template := ""
	var slash_idx = rest.find("/")
	if slash_idx > 0:
		template = rest.substr(0, slash_idx)
		rest = rest.substr(slash_idx + 1)
	var dot_idx = rest.find(".")
	if dot_idx > 0:
		return {"template": template, "namespace": rest.substr(0, dot_idx), "entry_id": rest.substr(dot_idx + 1)}
	return {"template": template, "namespace": rest, "entry_id": ""}


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
func notify_context_changed():
	for plugin in plugins.values():
		if plugin is Plugin:
			plugin.on_context_changed()
	if context_changed_callback.is_valid():
		context_changed_callback.call(context)


## Show an overlay view by id with parameters.
func show_overlay(overlay_id: String, params: Dictionary = {}):
	if show_overlay_callback.is_valid():
		show_overlay_callback.call(overlay_id, params)


## Get a reference to an overlay node by id. Returns null if not found.
func get_overlay_node(overlay_id: String) -> PluginOverlay:
	if get_overlay_node_callback.is_valid():
		return get_overlay_node_callback.call(overlay_id)
	return null


## Dispatch an action to the appropriate plugin based on type prefix.
func dispatch_action(type: String, data: Dictionary = {}):
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
	var copy = data.duplicate(true)
	copy["type"] = type
	_resolve_and_dispatch(plugin, action_name, copy)


## Shared action resolution: resolve inputs, dispatch to plugin, write outputs.
func _resolve_and_dispatch(plugin, action_name: String, data: Dictionary):
	# Save output param paths before handle_action overwrites them
	var output_paths := {}
	if plugin.has_method("get_action_params"):
		var params = plugin.get_action_params(action_name)
		for p in params:
			if p.get("direction", "input") == "output" and data.has(p["name"]):
				output_paths[p["name"]] = data[p["name"]]

	# Resolve evaluators in input parameters, preserve original refs
	var _raw_refs := {}
	for key in data:
		if key == "type":
			continue
		if output_paths.has(key):
			continue
		var val = data[key]
		if val is String and val.begins_with("@"):
			_raw_refs[key] = val
		if val is String and val.begins_with("$$"):
			# Read from context and evaluate the result
			var resolved = _get_context_path(val.substr(2))
			data[key] = evaluate(resolved) if resolved is String else resolved
		elif val is String and val.begins_with("$"):
			# Read from context (raw)
			data[key] = _get_context_path(val.substr(1))
		else:
			data[key] = evaluate(val)
	data["_raw_refs"] = _raw_refs

	plugin.handle_action(action_name, data)

	# Clean up internal key
	data.erase("_raw_refs")

	# Write output params to context at their dot-paths
	for key in output_paths:
		if data.has(key):
			_set_context_path(output_paths[key], data[key])


## Write a value into context at a dot-separated path, creating nested dicts as needed.
func _set_context_path(path: String, value):
	var keys = path.split(".")
	var current = context
	for i in keys.size() - 1:
		var k = keys[i]
		if not current.has(k) or not current[k] is Dictionary:
			current[k] = {}
		current = current[k]
	current[keys[keys.size() - 1]] = value


## Read a value from context at a dot-separated path. Resolves _ref wrappers
## transparently. Returns null and warns if the path does not exist.
func _get_context_path(path: String) -> Variant:
	var keys = path.split(".")
	var current: Variant = context
	for k in keys:
		if current is Dictionary and current.has("_ref"):
			current = evaluate(current["_ref"])
		if not current is Dictionary or not current.has(k):
			push_warning("[ModAPI] Context path '$%s' does not exist (failed at '%s')" % [path, k])
			return null
		current = current[k]
	if current is Dictionary and current.has("_ref"):
		current = evaluate(current["_ref"])
	return current


## Remove a key from context at a dot-separated path. No-op if path doesn't exist.
func _erase_context_path(path: String):
	var keys = path.split(".")
	var current: Variant = context
	for i in keys.size() - 1:
		var k = keys[i]
		if not current is Dictionary or not current.has(k):
			return
		current = current[k]
	if current is Dictionary:
		current.erase(keys[keys.size() - 1])


## Write a value into the live context at a dot-separated path.
func set_value(path: String, value):
	_set_context_path(path, value)


## Read a value from the live context at a dot-separated path.
func get_value(path: String) -> Variant:
	return _get_context_path(path)


## Remove a key from the live context at a dot-separated path.
func erase_value(path: String):
	_erase_context_path(path)


## Notify all plugins that a new game has started so they can initialize context.
## Plugins may return a Signal to block until an async operation completes.
func notify_game_started():
	for plugin in plugins.values():
		if plugin is Plugin:
			var result = plugin.on_game_start()
			if result is Signal:
				await result


## Notify all plugins before a choice is executed.
func notify_pre_choice():
	for plugin in plugins.values():
		if plugin is Plugin:
			plugin.on_pre_choice()


# ─── Compendium / Template API ───────────────────────────────────────────────


## Register a compendium's entries into the registry.
func register_compendium(compendium_id: String, data: Dictionary):
	_compendium_metadata[compendium_id] = data
	var entries = data.get("entries", {})
	for tmpl_id in entries:
		if not _entries.has(tmpl_id):
			_entries[tmpl_id] = {}
		for entry in entries[tmpl_id]:
			var entry_id = entry.get("id", "")
			if entry_id != "":
				_entries[tmpl_id][compendium_id + "." + entry_id] = entry


## Get all registered templates.
func get_templates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tmpl in _templates.values():
		result.append(tmpl)
	return result


## Get a template by id.
func get_template(template_id: String) -> Dictionary:
	return _templates.get(template_id, {})


## Get all entries for a template (from plugins and compendiums).
func get_entries(template_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var map = _entries.get(template_id, {})
	for entry in map.values():
		result.append(entry)
	return result


## Get a single entry by its namespaced id (e.g. "dnd.dagger" or "srd_items.longsword").
func get_entry(template_id: String, namespaced_id: String) -> Dictionary:
	var map = _entries.get(template_id, {})
	return map.get(namespaced_id, {})


## Query entries matching a filter dict. Each key in filter must match the entry value.
## Array filter values match if the entry's array contains the filter value.
func query_entries(template_id: String, filter: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var map = _entries.get(template_id, {})
	for entry in map.values():
		var matches = true
		for key in filter:
			if not entry.has(key):
				matches = false
				break
			var entry_val = entry[key]
			var filter_val = filter[key]
			if entry_val is Array:
				if not entry_val.has(filter_val):
					matches = false
					break
			elif entry_val != filter_val:
				matches = false
				break
		if matches:
			result.append(entry)
	return result


## Get entry reference hint strings for the given accepted type IDs.
## Returns strings like "@template_id/namespace.entry_id" for use in HintedLineEdit.
func get_entry_ref_hints(type_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for type_id in type_ids:
		var map = _entries.get(type_id, {})
		for namespaced_id in map:
			result.append("@" + type_id + "/" + namespaced_id)
	return result


## Get all loaded compendium ids.
func get_compendium_ids() -> Array[String]:
	var result: Array[String] = []
	for key in _compendium_metadata:
		result.append(key)
	return result


# ─── Settings API ────────────────────────────────────────────────────────────


## Register a setting definition.
## def: {path: String, label: String, type: "int"|"float"|"string"|"bool"|"enum",
##        scope: "global"|"module", default: Variant, options?: Array[String], plugin?: String}
func register_setting(def: Dictionary):
	var path = def.get("path", "")
	if path == "":
		return
	_settings[path] = def
	if not _setting_values.has(path):
		_setting_values[path] = def.get("default")


## Get the current value of a setting by path.
func get_setting(path: String) -> Variant:
	if _setting_values.has(path):
		return _setting_values[path]
	var def = _settings.get(path, {})
	return def.get("default")


## Set a setting value and persist.
func set_setting(path: String, value):
	_setting_values[path] = value
	_save_settings()


## Get all setting definitions for a given scope.
## If plugin_id is provided, only returns settings from that plugin.
func get_settings_for_scope(scope: String, plugin_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for def in _settings.values():
		if def.get("scope", "global") != scope:
			continue
		if plugin_id != "" and def.get("plugin", "") != plugin_id:
			continue
		result.append(def)
	return result


## Get all system settings (path starts with "system.").
func get_system_settings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for def in _settings.values():
		if def.get("path", "").begins_with("system."):
			result.append(def)
	return result


## Get all global settings owned by a specific plugin (non-system paths).
func get_plugin_settings(plugin_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for def in _settings.values():
		if def.get("plugin", "") == plugin_id and not def.get("path", "").begins_with("system."):
			result.append(def)
	return result


## Load settings values from disk.
func load_settings():
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var json_text = FileAccess.get_file_as_string(SETTINGS_PATH)
	var data = JSON.parse_string(json_text)
	if data is Dictionary:
		for path in data:
			_setting_values[path] = data[path]


## Save settings values to disk.
func _save_settings():
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_setting_values, "\t"))


# ─── Module Settings (runtime) ───────────────────────────────────────────────

var _module_settings := {}  # path → value, loaded from module JSON at game start


## Load module-scoped settings for the current game session.
func load_module_settings(settings: Dictionary):
	_module_settings = settings.duplicate()


## Get the value of a module-scoped setting.
func get_module_setting(path: String) -> Variant:
	if _module_settings.has(path):
		return _module_settings[path]
	var def = _settings.get(path, {})
	return def.get("default")


## Get all module-scoped setting definitions.
func get_module_setting_defs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for def in _settings.values():
		if def.get("scope", "global") == "module":
			result.append(def)
	return result
